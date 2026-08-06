extends Node

# realtime_channel_service.gd — สลับ scene channel + party channel

var _scene_channel: String = ""
var _party_channel: String = ""


func _ready() -> void:
	SupabaseClient.realtime_channel_joined.connect(_on_realtime_ready)


func switch_scene_for_map(map: BaseMap) -> void:
	if not OnlineSession.is_logged_in() or map == null:
		return
	var new_channel := RealtimeChannel.for_scene(SceneContext.from_node(map))
	if new_channel == _scene_channel:
		return
	if _scene_channel != "":
		SupabaseClient.leave_channel(_scene_channel)
	_scene_channel = new_channel
	SupabaseClient.join_channel(_scene_channel)
	SupabaseClient.set_primary_channel(_scene_channel)


func clear_scene_channel() -> void:
	if _scene_channel == "":
		return
	SupabaseClient.leave_channel(_scene_channel)
	_scene_channel = ""
	SupabaseClient.set_primary_channel(RealtimeChannel.GLOBAL)


func join_party(party_id: String) -> void:
	if not OnlineSession.is_logged_in():
		return
	var new_channel := RealtimeChannel.for_party(party_id)
	if new_channel == "":
		return
	if _party_channel != "" and _party_channel != new_channel:
		SupabaseClient.leave_channel(_party_channel)
	_party_channel = new_channel
	SupabaseClient.join_channel(_party_channel)


func leave_party() -> void:
	if _party_channel == "":
		return
	SupabaseClient.leave_channel(_party_channel)
	_party_channel = ""


func get_scene_channel() -> String:
	return _scene_channel


func get_party_channel() -> String:
	return _party_channel


func _on_realtime_ready() -> void:
	if _scene_channel != "":
		SupabaseClient.join_channel(_scene_channel)
	if _party_channel != "":
		SupabaseClient.join_channel(_party_channel)
