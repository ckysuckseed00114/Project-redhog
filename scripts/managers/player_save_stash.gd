class_name PlayerSaveStash
extends RefCounted

# Local snapshot taken at warp — applied after scene load so cloud async save cannot overwrite.

static var _snapshot: Dictionary = {}
static var _pending: bool = false


static func stash_for_warp(player: Player, spawn_pos: Vector2, target_scene: String) -> void:
	if player == null:
		return
	var scene_path := WarpHelper.normalize_scene_path(target_scene)
	GlobalData.prepare_warp(spawn_pos, scene_path)
	GlobalData.stash_quest_state(player)
	_snapshot = _build_snapshot(player, spawn_pos, scene_path)
	_pending = true


static func has_pending() -> bool:
	return _pending


static func clear() -> void:
	_pending = false
	_snapshot = {}


static func apply_to_player(player: Player) -> void:
	if player == null or not _pending:
		return

	var s := _snapshot
	player.global_position = Vector2(float(s.get("pos_x", 0.0)), float(s.get("pos_y", 0.0)))
	player.current_job = str(s.get("current_job", player.current_job))
	GlobalData.player_class = player.current_job
	player.level = int(s.get("level", player.level))
	player.current_exp = int(s.get("current_exp", player.current_exp))
	player.max_exp = int(s.get("max_exp", player.max_exp))
	player.stat_points = int(s.get("stat_points", player.stat_points))
	player.job_level = int(s.get("job_level", player.job_level))
	player.job_exp = int(s.get("job_exp", player.job_exp))
	player.max_job_exp = int(s.get("max_job_exp", player.max_job_exp))
	player.job_points = int(s.get("job_points", player.job_points))
	player.max_hp = int(s.get("max_hp", player.max_hp))
	player.hp = int(s.get("hp", player.hp))
	player.max_sp = int(s.get("max_sp", player.max_sp))
	player.sp = int(s.get("sp", player.sp))
	player.str_stat = int(s.get("str_stat", player.str_stat))
	player.agi = int(s.get("agi", player.agi))
	player.vit = int(s.get("vit", player.vit))
	player.int_stat = int(s.get("int_stat", player.int_stat))
	player.dex = int(s.get("dex", player.dex))
	player.luk = int(s.get("luk", player.luk))
	player.zeny = int(s.get("zeny", player.zeny))

	var inv: Variant = s.get("inventory")
	if inv is Array:
		player.inventory = _copy_inventory(inv)

	var equip: Variant = s.get("equipment")
	if equip is Dictionary:
		player.equipment = equip.duplicate(true)

	var slots: Variant = s.get("quick_slots")
	if slots is Array and slots.size() == 6:
		player.quick_slots = slots.duplicate(true)

	var skills: Variant = s.get("skill_levels")
	if skills is Dictionary:
		player.skill_levels = skills.duplicate(true)

	var active: Variant = s.get("active_quests")
	if active is Dictionary:
		player.active_quests = active.duplicate(true)

	player.finished_quests = []
	var finished: Variant = s.get("finished_quests")
	if finished is Array:
		for qid in finished:
			player.finished_quests.append(str(qid))

	player.apply_job_visuals(player.current_job, GlobalData.player_gender)
	GlobalData.warp_spawn_pending = false
	GlobalData.has_saved_position = false
	GlobalData.pending_warp_scene = ""
	GlobalData.clear_pending_quest_state()
	clear()

	player.stats_changed.emit()
	player.inventory_changed.emit()
	player.equipment_changed.emit()
	player.quests_changed.emit()

	var ui := UiAccess.get_ui(player)
	if ui and ui.has_method("refresh_quest_log"):
		ui.refresh_quest_log()


static func _build_snapshot(player: Player, spawn_pos: Vector2, scene_path: String) -> Dictionary:
	return {
		"pos_x": spawn_pos.x,
		"pos_y": spawn_pos.y,
		"current_scene": scene_path,
		"current_job": player.current_job,
		"level": player.level,
		"current_exp": player.current_exp,
		"max_exp": player.max_exp,
		"stat_points": player.stat_points,
		"job_level": player.job_level,
		"job_exp": player.job_exp,
		"max_job_exp": player.max_job_exp,
		"job_points": player.job_points,
		"hp": player.hp,
		"max_hp": player.max_hp,
		"sp": player.sp,
		"max_sp": player.max_sp,
		"str_stat": player.str_stat,
		"agi": player.agi,
		"vit": player.vit,
		"int_stat": player.int_stat,
		"dex": player.dex,
		"luk": player.luk,
		"zeny": player.zeny,
		"inventory": _copy_inventory(player.inventory),
		"equipment": player.equipment.duplicate(true),
		"quick_slots": player.quick_slots.duplicate(true),
		"skill_levels": player.skill_levels.duplicate(true),
		"active_quests": player.active_quests.duplicate(true),
		"finished_quests": player.finished_quests.duplicate(),
	}


static func _copy_inventory(source: Array) -> Array:
	var copy: Array = []
	copy.resize(source.size())
	for i in range(source.size()):
		var item: Variant = source[i]
		if item is Dictionary:
			copy[i] = item.duplicate(true)
		else:
			copy[i] = item
	return copy
