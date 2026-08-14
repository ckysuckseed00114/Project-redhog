extends Node

# world_sync_manager.gd — ซิงค์มอนสเตอร์ + World Boss ผ่าน BroadcastRouter

signal boss_state_changed

const SPAWN_INTERVAL := 180.0
const BOSS_EPOCH := 1735689600
const BOSS_ID := "big_poring"
const BOSS_SYNC_ID := "world_boss"
const RESPAWN_DELAY := 10.0
const BOSS_SPAWN_WINDOW := 3.0

const WORLD_BOSSES: Array[Dictionary] = [
	{
		"scene": ProjectPaths.WORLD,
		"map_label": "Training Field",
		"boss_id": "big_poring",
		"epoch_offset": 0.0,
	},
	{
		"scene": ProjectPaths.CAPITAL,
		"map_label": "Capital City",
		"boss_id": "big_poring",
		"epoch_offset": 90.0,
	},
]

const MOB_SLOTS: Array[Dictionary] = [
	{"sync_id": "poring_0", "type": "poring", "pos": Vector2(160, 140)},
	{"sync_id": "poring_1", "type": "poring", "pos": Vector2(360, 120)},
	{"sync_id": "poring_2", "type": "poring", "pos": Vector2(560, 160)},
	{"sync_id": "poring_3", "type": "poring", "pos": Vector2(760, 140)},
	{"sync_id": "poring_4", "type": "poring", "pos": Vector2(960, 180)},
	{"sync_id": "poring_5", "type": "poring", "pos": Vector2(280, 320)},
	{"sync_id": "poring_6", "type": "poring", "pos": Vector2(720, 300)},
	{"sync_id": "fabre_0", "type": "fabre", "pos": Vector2(200, 480)},
	{"sync_id": "fabre_1", "type": "fabre", "pos": Vector2(480, 520)},
	{"sync_id": "fabre_2", "type": "fabre", "pos": Vector2(640, 460)},
	{"sync_id": "fabre_3", "type": "fabre", "pos": Vector2(880, 500)},
	{"sync_id": "fabre_4", "type": "fabre", "pos": Vector2(1040, 420)},
]

const WEST_FIELD_MOB_SLOTS: Array[Dictionary] = [
	{"sync_id": "west_batty_0", "type": "batty", "pos": Vector2(320, 280)},
	{"sync_id": "west_boby_0", "type": "boby", "pos": Vector2(640, 360)},
	{"sync_id": "west_jibby_0", "type": "jibby", "pos": Vector2(960, 440)},
]

var _world: World = null
var _dead_mobs: Dictionary = {}
var _boss_defeated_cycles: Dictionary = {}
var _boss_alive_on_map: Dictionary = {}
var _boss_spawned_cycles: Dictionary = {}


func _ready() -> void:
	BroadcastRouter.event_received.connect(_on_event_received)


func is_online() -> bool:
	return OnlineSession.is_online()


func get_scene_path() -> String:
	return SceneContext.from_node(_world)


func register_world(world: World) -> void:
	_world = world
	_dead_mobs.clear()
	_sync_boss_alive_state()
	call_deferred("_try_spawn_boss_on_register")
	boss_state_changed.emit()


func unregister_world() -> void:
	var scene := get_scene_path()
	if scene != "":
		_boss_alive_on_map[scene] = false
	_world = null
	boss_state_changed.emit()


func get_boss_elapsed_for(scene: String) -> float:
	var now := Time.get_unix_time_from_system()
	return fmod(now - BOSS_EPOCH - get_epoch_offset(scene), SPAWN_INTERVAL)


func _sync_boss_alive_state() -> void:
	var scene := get_scene_path()
	if scene == "":
		return
	var alive := false
	if BossManager and is_instance_valid(BossManager.active_boss) and BossManager.active_boss.get("is_active_monster"):
		alive = true
	_boss_alive_on_map[scene] = alive


func get_boss_def_for_scene(scene: String) -> Dictionary:
	for def in WORLD_BOSSES:
		if str(def.get("scene", "")) == scene:
			return def
	return {}


func get_epoch_offset(scene: String) -> float:
	var def := get_boss_def_for_scene(scene)
	return float(def.get("epoch_offset", 0.0))


func get_boss_cycle_index_for(scene: String) -> int:
	var now := Time.get_unix_time_from_system()
	return int(floor((now - BOSS_EPOCH - get_epoch_offset(scene)) / SPAWN_INTERVAL))


func get_boss_seconds_left_for(scene: String) -> float:
	if is_boss_alive_on_map(scene):
		return 0.0
	var elapsed := get_boss_elapsed_for(scene)
	var remaining := SPAWN_INTERVAL - elapsed
	if is_boss_defeated_this_cycle_for(scene):
		return remaining
	var cycle := get_boss_cycle_index_for(scene)
	if int(_boss_spawned_cycles.get(scene, -1)) != cycle:
		return 0.0
	return remaining


func is_boss_spawn_window_for(scene: String) -> bool:
	return get_boss_elapsed_for(scene) < BOSS_SPAWN_WINDOW


func is_boss_defeated_this_cycle_for(scene: String) -> bool:
	return int(_boss_defeated_cycles.get(scene, -1)) == get_boss_cycle_index_for(scene)


func is_boss_alive_on_map(scene: String) -> bool:
	return _boss_alive_on_map.get(scene, false)


func get_boss_entries() -> Array:
	var current := get_scene_path()
	var entries: Array = []
	for def in WORLD_BOSSES:
		var scene := str(def.get("scene", ""))
		var boss_id := str(def.get("boss_id", BOSS_ID))
		var data := MonsterDB.get_monster(boss_id)
		entries.append({
			"scene": scene,
			"map_label": str(def.get("map_label", scene)),
			"boss_name": str(data.get("name", boss_id)),
			"seconds_left": get_boss_seconds_left_for(scene),
			"alive": is_boss_alive_on_map(scene),
			"is_current_map": scene != "" and scene == current,
		})
	return entries


func get_boss_seconds_left() -> float:
	if _world == null:
		return get_boss_seconds_left_for(ProjectPaths.WORLD)
	return get_boss_seconds_left_for(get_scene_path())


func get_boss_cycle_index() -> int:
	if _world == null:
		return get_boss_cycle_index_for(ProjectPaths.WORLD)
	return get_boss_cycle_index_for(get_scene_path())


func is_boss_spawn_window() -> bool:
	if _world == null:
		return false
	return is_boss_spawn_window_for(get_scene_path())


func is_boss_defeated_this_cycle() -> bool:
	if _world == null:
		return false
	return is_boss_defeated_this_cycle_for(get_scene_path())


func should_spawn_boss() -> bool:
	if _world == null:
		return false
	var scene := get_scene_path()
	if scene == "" or get_boss_def_for_scene(scene).is_empty():
		return false
	if is_boss_defeated_this_cycle_for(scene):
		return false
	var cycle := get_boss_cycle_index_for(scene)
	if int(_boss_spawned_cycles.get(scene, -1)) == cycle:
		return false
	if is_boss_alive_on_map(scene):
		return false
	if BossManager and is_instance_valid(BossManager.active_boss) and BossManager.active_boss.get("is_active_monster"):
		return false
	return true


func mark_boss_spawned(scene: String = "") -> void:
	if scene == "":
		scene = get_scene_path()
	if scene == "":
		return
	_boss_spawned_cycles[scene] = get_boss_cycle_index_for(scene)
	_boss_alive_on_map[scene] = true


func get_slot_respawn_pos(sync_id: String) -> Vector2:
	for slot in _all_mob_slot_sources():
		if str(slot.get("sync_id", "")) == sync_id:
			return slot.get("pos", Vector2.ZERO)
	return Vector2(
		GameConstants.MAP_WORLD_WIDTH * 0.5,
		GameConstants.MAP_WORLD_HEIGHT * 0.5
	)


func on_local_mob_died(sync_id: String) -> void:
	if sync_id == "":
		return
	var respawn_at := Time.get_unix_time_from_system() + RESPAWN_DELAY
	_dead_mobs[sync_id] = respawn_at
	if is_online():
		_send(RealtimeEvents.MOB_DIE, {
			RealtimeEvents.KEY_SYNC_ID: sync_id,
			RealtimeEvents.KEY_RESPAWN_AT: respawn_at,
		})


func on_local_mob_hp(sync_id: String, hp: int) -> void:
	if sync_id == "" or not is_online():
		return
	_send(RealtimeEvents.MOB_HP, {
		RealtimeEvents.KEY_SYNC_ID: sync_id,
		RealtimeEvents.KEY_HP: hp,
	})


func on_local_boss_spawned(pos: Vector2) -> void:
	var scene := get_scene_path()
	mark_boss_spawned(scene)
	if is_online():
		_send(RealtimeEvents.BOSS_SPAWN, {
			RealtimeEvents.KEY_BOSS_ID: BOSS_ID,
			RealtimeEvents.KEY_POS_X: pos.x,
			RealtimeEvents.KEY_POS_Y: pos.y,
			RealtimeEvents.KEY_MAP_SCENE: scene,
			RealtimeEvents.KEY_CYCLE: get_boss_cycle_index_for(scene),
		})
	boss_state_changed.emit()


func on_local_boss_hp(hp: float) -> void:
	if is_online():
		_send(RealtimeEvents.BOSS_HP, {
			RealtimeEvents.KEY_HP: hp,
			RealtimeEvents.KEY_MAP_SCENE: get_scene_path(),
		})


func on_local_boss_defeated() -> void:
	var scene := get_scene_path()
	_boss_defeated_cycles[scene] = get_boss_cycle_index_for(scene)
	_boss_alive_on_map[scene] = false
	if is_online():
		_send(RealtimeEvents.BOSS_DEFEATED, {
			RealtimeEvents.KEY_CYCLE: _boss_defeated_cycles[scene],
			RealtimeEvents.KEY_MAP_SCENE: scene,
		})
	boss_state_changed.emit()


func get_mob_slots() -> Array:
	var scene := WarpHelper.normalize_scene_path(get_scene_path())
	if scene == ProjectPaths.WEST_FIELD:
		return WEST_FIELD_MOB_SLOTS.duplicate(true)
	if scene == ProjectPaths.WORLD:
		return MOB_SLOTS.duplicate(true)
	return []


func _all_mob_slot_sources() -> Array[Dictionary]:
	var all: Array[Dictionary] = []
	all.append_array(MOB_SLOTS)
	all.append_array(WEST_FIELD_MOB_SLOTS)
	return all


func tick_global(_delta: float) -> void:
	pass


func tick_world(_delta: float) -> void:
	if not _world or not is_instance_valid(_world):
		return
	_tick_mob_respawns()
	_tick_boss_spawn()


func tick(delta: float) -> void:
	tick_global(delta)
	tick_world(delta)


func _tick_boss_spawn() -> void:
	if not should_spawn_boss():
		return
	if BossManager:
		BossManager.request_synced_spawn()


func _try_spawn_boss_on_register() -> void:
	if not _world or not is_instance_valid(_world):
		return
	_sync_boss_alive_state()
	_tick_boss_spawn()


func _tick_mob_respawns() -> void:
	if _dead_mobs.is_empty():
		return
	var now := Time.get_unix_time_from_system()
	var revived: Array[String] = []
	for sync_id in _dead_mobs.keys():
		if now >= float(_dead_mobs[sync_id]):
			revived.append(sync_id)
	for sync_id in revived:
		_dead_mobs.erase(sync_id)
		if _world and _world.has_method("respawn_mob"):
			_world.respawn_mob(sync_id)


func _send(event_name: String, data: Dictionary) -> void:
	BroadcastRouter.send(event_name, data, get_scene_path())


func _on_event_received(event: String, payload: Dictionary) -> void:
	if event.begins_with("boss_"):
		_handle_boss_broadcast(event, payload)
		return
	if not _world or not is_instance_valid(_world):
		return
	if SceneContext.is_local_character(payload):
		return
	if not SceneContext.is_for_local_scene(payload, get_scene_path()):
		return
	match event:
		RealtimeEvents.MOB_DIE:
			_apply_mob_die(
				str(payload.get(RealtimeEvents.KEY_SYNC_ID, "")),
				float(payload.get(RealtimeEvents.KEY_RESPAWN_AT, 0.0))
			)
		RealtimeEvents.MOB_HP:
			_apply_mob_hp(str(payload.get(RealtimeEvents.KEY_SYNC_ID, "")), int(payload.get(RealtimeEvents.KEY_HP, 0)))


func _handle_boss_broadcast(event: String, payload: Dictionary) -> void:
	if SceneContext.is_local_character(payload):
		return
	var map_scene := str(payload.get(RealtimeEvents.KEY_MAP_SCENE, ""))
	match event:
		RealtimeEvents.BOSS_SPAWN:
			var cycle := int(payload.get(RealtimeEvents.KEY_CYCLE, get_boss_cycle_index_for(map_scene)))
			_boss_spawned_cycles[map_scene] = cycle
			_boss_alive_on_map[map_scene] = true
			if _world and map_scene == get_scene_path():
				_apply_boss_spawn(payload)
			boss_state_changed.emit()
		RealtimeEvents.BOSS_HP:
			if _world and map_scene == get_scene_path():
				_apply_boss_hp(float(payload.get(RealtimeEvents.KEY_HP, 0.0)))
		RealtimeEvents.BOSS_DEFEATED:
			_boss_defeated_cycles[map_scene] = int(payload.get(RealtimeEvents.KEY_CYCLE, 0))
			_boss_alive_on_map[map_scene] = false
			if _world and map_scene == get_scene_path():
				BossManager.sync_boss_defeated()
			boss_state_changed.emit()


func _apply_mob_die(sync_id: String, respawn_at: float) -> void:
	if sync_id == "":
		return
	if respawn_at <= 0.0:
		respawn_at = Time.get_unix_time_from_system() + RESPAWN_DELAY
	_dead_mobs[sync_id] = respawn_at
	if _world and _world.has_method("sync_kill_mob"):
		_world.sync_kill_mob(sync_id)


func _apply_mob_hp(sync_id: String, hp: int) -> void:
	if _world and _world.has_method("sync_set_mob_hp"):
		_world.sync_set_mob_hp(sync_id, hp)


func _apply_boss_spawn(payload: Dictionary) -> void:
	if BossManager and is_instance_valid(BossManager.active_boss) and BossManager.active_boss.get("is_active_monster"):
		return
	var pos := Vector2(
		float(payload.get(RealtimeEvents.KEY_POS_X, 0.0)),
		float(payload.get(RealtimeEvents.KEY_POS_Y, 0.0))
	)
	if BossManager:
		BossManager.spawn_synced_boss(pos)


func _apply_boss_hp(hp: float) -> void:
	if BossManager and is_instance_valid(BossManager.active_boss):
		if BossManager.active_boss.has_method("apply_sync_hp"):
			BossManager.active_boss.apply_sync_hp(hp)
