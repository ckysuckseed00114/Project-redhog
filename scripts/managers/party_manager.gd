extends Node

signal party_updated(members: Array)
signal party_invite_received(inviter_name: String, party_id: String)

const FALLBACK_SYNC_SEC := 30.0

var current_party_id: String = ""
var party_members: Array = []
var sync_timer: Timer


func _ready() -> void:
	sync_timer = Timer.new()
	sync_timer.wait_time = FALLBACK_SYNC_SEC
	sync_timer.autostart = false
	sync_timer.timeout.connect(fetch_party_data)
	add_child(sync_timer)
	if BroadcastRouter:
		BroadcastRouter.event_received.connect(_on_realtime_event)


func create_party() -> void:
	if GlobalData.character_id == "":
		_create_offline_party()
		return

	current_party_id = "party_" + GlobalData.character_id
	_update_my_party_id(current_party_id)
	RealtimeChannelService.join_party(current_party_id)
	print("🤝 สร้างปาร์ตี้สำเร็จ! ID: ", current_party_id)
	sync_timer.start()
	fetch_party_data()


func _create_offline_party() -> void:
	current_party_id = "local_party"
	party_members = [get_local_player_member()]
	party_updated.emit(party_members)
	var ui := UiAccess.get_ui(self)
	if ui and ui.has_method("show_notification"):
		ui.show_notification("Party created (Offline Mode)", Color8(0x16, 0xa0, 0x85))


func join_party(party_id: String) -> void:
	current_party_id = party_id
	_update_my_party_id(current_party_id)
	RealtimeChannelService.join_party(current_party_id)
	print("🤝 เข้าร่วมปาร์ตี้: ", current_party_id)
	sync_timer.start()
	fetch_party_data()


func leave_party() -> void:
	if current_party_id != "" and current_party_id != "local_party":
		PartySync.broadcast_leave(current_party_id, GlobalData.character_id)
		RealtimeChannelService.leave_party()
	_update_my_party_id("null")
	current_party_id = ""
	party_members.clear()
	party_updated.emit(party_members)
	sync_timer.stop()
	print("👋 ออกจากปาร์ตี้แล้ว")


func get_local_player_member() -> Dictionary:
	var world := get_tree().get_first_node_in_group("world")
	var p: Player = null
	if world and world.has_method("get_player"):
		p = world.get_player()
	return {
		"name": GlobalData.player_name,
		"level": p.level if p else 1,
		"hp": p.hp if p else 100,
		"max_hp": p.max_hp if p else 100,
		"is_leader": true,
		"character_id": GlobalData.character_id,
	}


func refresh_local_member_stats() -> void:
	if party_members.is_empty() or current_party_id == "":
		return
	var local := get_local_player_member()
	for i in party_members.size():
		var mem = party_members[i]
		if mem.get("character_id", "") == GlobalData.character_id or mem.get("name", "") == GlobalData.player_name:
			party_members[i] = local
			break
	party_updated.emit(party_members)
	if current_party_id != "" and current_party_id != "local_party":
		PartySync.broadcast_update(current_party_id, party_members)


func _update_my_party_id(p_id: String) -> void:
	if GlobalData.character_id == "":
		return
	var query = "character_id=eq." + GlobalData.character_id
	
	var party_val: Variant = p_id
	if p_id == "null":
		party_val = null
		
	SupabaseClient.update_data("players", query, {"party_id": party_val})


func fetch_party_data() -> void:
	if current_party_id == "" or current_party_id == "local_party":
		sync_timer.stop()
		return

	var query = "party_id=eq." + current_party_id
	SupabaseClient.fetch_data("players", query, func(success, response):
		if success and response is Array:
			party_members = response
			if party_members.is_empty():
				party_members = [get_local_player_member()]
			party_updated.emit(party_members)
			PartySync.broadcast_update(current_party_id, party_members)
		else:
			print("⚠️ ดึงข้อมูลปาร์ตี้ล้มเหลว")
	)


func invite_player(target_character_name: String) -> void:
	if current_party_id == "":
		create_party()
	var target_id := ""
	if OnlinePresenceManager:
		target_id = OnlinePresenceManager.find_character_id_by_name(target_character_name)
	if target_id != "":
		PartySync.send_invite(current_party_id, target_id, GlobalData.player_name)
	print("📨 ส่งคำเชิญปาร์ตี้ไปให้: ", target_character_name)
	var ui = UiAccess.get_ui(self)
	if ui and ui.has_method("show_notification"):
		ui.show_notification("Invited " + target_character_name + " to party!", Color8(0x34, 0x98, 0xdb))


func is_in_party() -> bool:
	return current_party_id != ""


func _on_realtime_event(event: String, payload: Dictionary) -> void:
	match event:
		RealtimeEvents.PARTY_UPDATE:
			_apply_party_update(payload)
		RealtimeEvents.PARTY_INVITE:
			_apply_party_invite(payload)
		RealtimeEvents.PARTY_LEAVE:
			_apply_party_leave(payload)


func _apply_party_update(payload: Dictionary) -> void:
	var party_id := str(payload.get(RealtimeEvents.KEY_PARTY_ID, ""))
	if party_id == "" or party_id != current_party_id:
		return
	if SceneContext.is_local_character(payload):
		return
	var members: Variant = payload.get(RealtimeEvents.KEY_MEMBERS, [])
	if members is Array:
		party_members = members
		if party_members.is_empty():
			party_members = [get_local_player_member()]
		party_updated.emit(party_members)


func _apply_party_invite(payload: Dictionary) -> void:
	var target_id := str(payload.get(RealtimeEvents.KEY_TARGET_CHARACTER_ID, ""))
	if target_id != GlobalData.character_id:
		return
	var party_id := str(payload.get(RealtimeEvents.KEY_PARTY_ID, ""))
	var inviter := str(payload.get(RealtimeEvents.KEY_INVITER_NAME, "Player"))
	party_invite_received.emit(inviter, party_id)
	var ui := UiAccess.get_ui(self)
	if ui and ui.has_method("show_notification"):
		ui.show_notification("%s invited you to party!" % inviter, Color8(0x34, 0x98, 0xdb))


func _apply_party_leave(payload: Dictionary) -> void:
	var party_id := str(payload.get(RealtimeEvents.KEY_PARTY_ID, ""))
	if party_id != current_party_id:
		return
	if SceneContext.is_local_character(payload):
		return
	fetch_party_data()
