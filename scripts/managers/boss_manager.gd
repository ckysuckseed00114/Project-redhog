extends Node

signal timers_updated(entries: Array)

const BOSS_ID := "big_poring"

var active_boss: Node = null
var _world: World = null
var _timer_refresh_accum: float = 0.0

const TIMER_REFRESH_INTERVAL := 0.5


func _ready() -> void:
	if WorldSyncManager:
		WorldSyncManager.boss_state_changed.connect(_refresh_timer)


func register_world(world: World) -> void:
	_world = world
	WorldSyncManager.register_world(world)
	_refresh_timer()


func unregister_world() -> void:
	WorldSyncManager.unregister_world()
	_world = null
	active_boss = null


func _process(delta: float) -> void:
	WorldSyncManager.tick(delta)
	_timer_refresh_accum += delta
	if _timer_refresh_accum >= TIMER_REFRESH_INTERVAL:
		_timer_refresh_accum = 0.0
		_refresh_timer()


func _refresh_timer() -> void:
	var entries := WorldSyncManager.get_boss_entries()
	timers_updated.emit(entries)


func request_synced_spawn() -> void:
	if not _world or not is_instance_valid(_world):
		return
	if is_instance_valid(active_boss) and active_boss.get("is_active_monster"):
		return
	var boss := _world.spawn_boss(BOSS_ID)
	if boss:
		_bind_boss(boss)
		WorldSyncManager.on_local_boss_spawned(boss.global_position)
	else:
		push_warning("World Boss spawn failed on %s" % WorldSyncManager.get_scene_path())


func spawn_synced_boss(pos: Vector2) -> void:
	if not _world or not is_instance_valid(_world):
		return
	if is_instance_valid(active_boss) and active_boss.get("is_active_monster"):
		return
	var boss := _world.spawn_boss(BOSS_ID, pos)
	if boss:
		_bind_boss(boss)
		WorldSyncManager.mark_boss_spawned()
		WorldSyncManager.boss_state_changed.emit()


func sync_boss_defeated() -> void:
	if is_instance_valid(active_boss):
		if active_boss.died.is_connected(_on_boss_died):
			active_boss.died.disconnect(_on_boss_died)
		if active_boss.has_method("apply_sync_kill"):
			active_boss.apply_sync_kill()
	active_boss = null
	_refresh_timer()


func _bind_boss(boss: Node) -> void:
	active_boss = boss
	if not boss.died.is_connected(_on_boss_died):
		boss.died.connect(_on_boss_died)
	_announce("⚠ BOSS %s has appeared!" % boss_display_name())
	_refresh_timer()


func _on_boss_died(_monster: Node) -> void:
	active_boss = null
	WorldSyncManager.on_local_boss_defeated()
	_announce("✦ %s has been defeated!" % boss_display_name())
	_refresh_timer()


func boss_display_name() -> String:
	var data := MonsterDB.get_monster(BOSS_ID)
	return data.get("name", "Boss")


func _announce(text: String) -> void:
	var ui := UiAccess.get_ui(self)
	if ui and ui.has_method("add_log"):
		ui.add_log(text, Color8(0xff, 0x66, 0x22))
	if ui and ui.has_method("show_notification"):
		ui.show_notification(text, Color8(0xff, 0x66, 0x22))
