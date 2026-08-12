extends Node

# broadcast_router.gd — ศูนย์กลางส่ง/รับ Realtime broadcast

signal event_received(event: String, payload: Dictionary)


func _ready() -> void:
	SupabaseClient.broadcast_received.connect(_on_raw_broadcast)


func send(event: String, data: Dictionary, scene_path: String = "") -> void:
	if not OnlineSession.is_logged_in():
		return
	var payload := data.duplicate(true)
	if scene_path != "":
		payload[RealtimeEvents.KEY_CURRENT_SCENE] = SceneContext.normalize(scene_path)
	if GlobalData.character_id != "":
		payload[RealtimeEvents.KEY_CHARACTER_ID] = GlobalData.character_id
	var channel := RealtimeChannel.for_scene(scene_path) if scene_path != "" else SupabaseClient.get_primary_channel()
	SupabaseClient.send_broadcast(event, payload, channel)


func send_party(event: String, data: Dictionary, party_id: String) -> void:
	if not OnlineSession.is_logged_in() or party_id == "":
		return
	var payload := data.duplicate(true)
	if GlobalData.character_id != "":
		payload[RealtimeEvents.KEY_CHARACTER_ID] = GlobalData.character_id
	var channel := RealtimeChannel.for_party(party_id)
	if channel == "":
		return
	SupabaseClient.send_broadcast(event, payload, channel)


func send_global(event: String, data: Dictionary) -> void:
	if not OnlineSession.is_logged_in():
		return
	var payload := data.duplicate(true)
	if GlobalData.character_id != "":
		payload[RealtimeEvents.KEY_CHARACTER_ID] = GlobalData.character_id
	SupabaseClient.send_broadcast(event, payload, RealtimeChannel.GLOBAL)


func _on_raw_broadcast(payload: Dictionary) -> void:
	var event := str(payload.get(RealtimeEvents.KEY_EVENT, ""))
	if event == "":
		return
	event_received.emit(event, payload)
