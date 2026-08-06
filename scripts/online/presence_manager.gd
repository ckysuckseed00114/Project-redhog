extends Node

signal presence_updated(remote_count: int)
signal chat_received(sender_name: String, text: String)

const STALE_TIMEOUT_MS := 5000

var _remote_nodes: Dictionary = {}
var _remote_last_seen: Dictionary = {}
var _world_root: Node2D


func _ready() -> void:
	BroadcastRouter.event_received.connect(_on_event_received)
	OnlineSession.session_changed.connect(_on_session_changed)


func register_world(world: Node2D) -> void:
	_world_root = world
	if not OnlineSession.is_logged_in():
		_spawn_demo_players()
	else:
		_clear_remotes()
		OnlineSession.connect_realtime()
		_sync_local_player_from_world()


func unregister_world() -> void:
	_clear_remotes()
	_world_root = null


func sync_local_player(player: Player) -> void:
	PresenceSync.sync_player(player)


func broadcast_chat(message: String) -> void:
	PresenceSync.send_chat(message)


func _process(_delta: float) -> void:
	if not _world_root or not OnlineSession.is_logged_in():
		return
	_prune_stale_remotes()


func _local_scene_path() -> String:
	return SceneContext.from_node(_world_root)


func _on_session_changed() -> void:
	_sync_local_player_from_world()


func _sync_local_player_from_world() -> void:
	if not _world_root or not is_instance_valid(_world_root):
		return
	if _world_root.has_method("get_player"):
		var p: Player = _world_root.get_player()
		if p:
			sync_local_player(p)


func _on_event_received(event: String, payload: Dictionary) -> void:
	if not _world_root or not is_instance_valid(_world_root):
		return
	match event:
		RealtimeEvents.CHAT_MSG:
			_handle_chat(payload)
		RealtimeEvents.POS_UPDATE:
			_handle_pos_update(payload)


func _handle_chat(payload: Dictionary) -> void:
	var char_id := str(payload.get(RealtimeEvents.KEY_CHARACTER_ID, ""))
	var sender := str(payload.get(RealtimeEvents.KEY_SENDER_NAME, "Unknown"))
	var text := str(payload.get(RealtimeEvents.KEY_TEXT, ""))
	chat_received.emit(sender, text)
	if char_id != "" and _remote_nodes.has(char_id):
		var node = _remote_nodes[char_id]
		if is_instance_valid(node) and node.has_method("show_chat_balloon"):
			node.show_chat_balloon(text)


func _handle_pos_update(payload: Dictionary) -> void:
	var char_id := str(payload.get(RealtimeEvents.KEY_CHARACTER_ID, ""))
	if char_id == "" or char_id == GlobalData.character_id:
		return
	var local_scene := _local_scene_path()
	if not SceneContext.is_for_local_scene(payload, local_scene):
		_remove_remote(char_id)
		return
	_remote_last_seen[char_id] = Time.get_ticks_msec()
	var pos := Vector2(
		float(payload.get(RealtimeEvents.KEY_POS_X, 0.0)),
		float(payload.get(RealtimeEvents.KEY_POS_Y, 0.0))
	)
	var pname := str(payload.get(RealtimeEvents.KEY_NAME, "Adventurer"))
	var gender := str(payload.get(RealtimeEvents.KEY_GENDER, "male"))
	var job := str(payload.get(RealtimeEvents.KEY_CURRENT_JOB, "novice"))
	if _remote_nodes.has(char_id):
		var node: RemotePlayer = _remote_nodes[char_id]
		if is_instance_valid(node):
			node.update_state(pname, gender, pos, job)
	else:
		var remote := RemotePlayer.new()
		remote.setup(char_id, pname, gender, pos, job)
		remote.z_index = 10
		_world_root.add_child(remote)
		_remote_nodes[char_id] = remote
	presence_updated.emit(_remote_nodes.size())


func _prune_stale_remotes() -> void:
	var now := Time.get_ticks_msec()
	var stale: Array[String] = []
	for char_id in _remote_last_seen.keys():
		if now - int(_remote_last_seen[char_id]) > STALE_TIMEOUT_MS:
			stale.append(char_id)
	for char_id in stale:
		_remove_remote(char_id)


func _remove_remote(char_id: String) -> void:
	_remote_last_seen.erase(char_id)
	if not _remote_nodes.has(char_id):
		return
	var node: RemotePlayer = _remote_nodes[char_id]
	if is_instance_valid(node):
		node.queue_free()
	_remote_nodes.erase(char_id)
	presence_updated.emit(_remote_nodes.size())


func _clear_remotes() -> void:
	for char_id in _remote_nodes.keys():
		var node: RemotePlayer = _remote_nodes[char_id]
		if is_instance_valid(node):
			node.queue_free()
	_remote_nodes.clear()
	_remote_last_seen.clear()


func find_character_id_by_name(display_name: String) -> String:
	var needle := display_name.strip_edges()
	if needle == "":
		return ""
	for char_id in _remote_nodes.keys():
		var node: RemotePlayer = _remote_nodes[char_id]
		if is_instance_valid(node) and str(node.player_name).strip_edges() == needle:
			return str(char_id)
	return ""


func _spawn_demo_players() -> void:
	if not _world_root:
		return
	_clear_remotes()
	var center := Vector2(GameConstants.MAP_WORLD_WIDTH * 0.5, GameConstants.MAP_WORLD_HEIGHT * 0.5)
	var demos := [
		{"id": "demo_1", "name": "Knight_A", "gender": "male", "pos": center + Vector2(-80, -40)},
		{"id": "demo_2", "name": "Mage_B", "gender": "female", "pos": center + Vector2(90, 30)},
	]
	for d in demos:
		var remote := RemotePlayer.new()
		remote.setup(d.id, d.name, d.gender, d.pos)
		_world_root.add_child(remote)
		_remote_nodes[d.id] = remote
	presence_updated.emit(_remote_nodes.size())
