extends Node

# online_session.gd — facade สถานะออนไลน์ (auth + character)

signal session_changed


func _ready() -> void:
	if not SupabaseClient.realtime_channel_joined.is_connected(_on_realtime_ready):
		SupabaseClient.realtime_channel_joined.connect(_on_realtime_ready)


func is_logged_in() -> bool:
	return SupabaseClient.current_user_id != ""


func has_character() -> bool:
	return GlobalData.character_id != ""


func is_online() -> bool:
	return is_logged_in() and has_character()


func user_id() -> String:
	return SupabaseClient.current_user_id


func character_id() -> String:
	return GlobalData.character_id


func connect_realtime() -> void:
	if is_logged_in():
		SupabaseClient.connect_realtime()


func _on_realtime_ready() -> void:
	session_changed.emit()
