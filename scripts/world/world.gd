class_name World
extends BaseMap

var selected_target: CharacterBody2D = null
@onready var monsters_root: Node2D = $Monsters if has_node("Monsters") else null
@onready var effects = $WorldEffects if has_node("WorldEffects") else null

var _big_poring_scene: PackedScene
var _generic_monster_scene: PackedScene
var _monsters: Array[CharacterBody2D] = []
var _mob_by_sync_id: Dictionary = {}
var _quest_nav_monster_id: String = ""
var _quest_nav_quest_id: String = ""

# world.gd — สารบัญ: Lifecycle | Targeting | Spawn | Combat | Drops | Movement

# --- Lifecycle ---

func get_map_theme() -> String:
	return "field"


func get_scenery_exclusions() -> Array[Vector2]:
	return [
		Vector2(640, 14),
		Vector2(640, 400),
	]


func get_boss_spawn_pos() -> Vector2:
	return Vector2(
		GameConstants.MAP_WORLD_WIDTH * 0.5,
		GameConstants.MAP_WORLD_HEIGHT * 0.35
	)


func _ready() -> void:
	super._ready()

	_big_poring_scene = preload("res://scenes/characters/big_poring.tscn")
	_generic_monster_scene = preload("res://scenes/characters/generic_monster.tscn")
	
	_spawn_monsters()

	if effects and player and effects.has_method("setup"):
		effects.setup(player)
	
	if monsters_root and monsters_root.has_method("setup"):
		monsters_root.setup(player)
	
	if player and player.has_signal("died"):
		player.died.connect(_on_player_died)


func _exit_tree() -> void:
	super._exit_tree()


func notify_mob_hp(sync_id: String, hp: int) -> void:
	if sync_id != "" and OnlineSession.is_online():
		WorldSyncManager.on_local_mob_hp(sync_id, hp)


func notify_mob_died(sync_id: String) -> void:
	if sync_id != "" and OnlineSession.is_online():
		WorldSyncManager.on_local_mob_died(sync_id)


func notify_boss_hp(hp: float) -> void:
	if OnlineSession.is_online():
		WorldSyncManager.on_local_boss_hp(hp)


func _set_selected_target(new_target: CharacterBody2D) -> void:
	if selected_target == new_target:
		return
	if is_instance_valid(selected_target) and selected_target.has_method("set_selected"):
		selected_target.set_selected(false)
	
	selected_target = new_target
	
	if is_instance_valid(selected_target) and selected_target.has_method("set_selected"):
		selected_target.set_selected(true)


# --- Targeting ---

func select_monster(monster: CharacterBody2D) -> void:
	if not player:
		return
	if not is_instance_valid(monster) or not monster.get("is_active_monster"):
		return
	_set_selected_target(monster)
	move_target = null
	
	# 🌟 เปลี่ยนมาดึงค่าผ่าน property ตรงๆ แทนการใช้ .get() เพื่อตัดปัญหา
	var m_id := "poring"
	if "monster_id" in monster and monster.monster_id != null:
		m_id = str(monster.monster_id)
		
	var m_data = MonsterDB.get_monster(m_id)
	var ui := UiAccess.get_ui(self)
	if ui and ui.has_method("add_log"):
		ui.add_log("Target: %s" % m_data.get("name", "Monster"), Color8(0xff, 0x66, 0x22))

func try_attack_selected() -> void:
	if not is_instance_valid(selected_target) or not selected_target.get("is_active_monster"):
		return
	var p_pos := player.global_position
	if p_pos.distance_squared_to(_get_monster_hit_center(selected_target)) <= GameConstants.PLAYER_MELEE_RANGE_SQ:
		inflict_damage_to_monster(selected_target)


func _on_map_click(world_pos: Vector2) -> bool:
	if super._on_map_click(world_pos):
		return true
	var clicked := _find_monster_at(world_pos)
	if clicked:
		select_monster(clicked)
		try_attack_selected()
		return true
	_set_selected_target(null)
	return false


func _allow_click_move_to(world_pos: Vector2) -> bool:
	if _find_monster_at(world_pos):
		return false
	return true


func _apply_click_move_to(world_pos: Vector2) -> bool:
	if not _allow_click_move_to(world_pos):
		return false
	world_pos = MapClickInput.clamp_map_pos(world_pos)
	GlobalData.clear_auto_quest_state()
	GlobalData.clear_auto_quest()
	cancel_quest_navigation()
	_set_selected_target(null)
	_release_player_combat_for_move()
	pending_npc_talk = null
	move_target = world_pos
	return true


func _set_move_target_from_click(world_pos: Vector2) -> bool:
	return _apply_click_move_to(world_pos)


func _on_player_died() -> void:
	cancel_quest_navigation()
	_set_selected_target(null)
	move_target = null


func get_monsters() -> Array[CharacterBody2D]:
	return _monsters


func start_quest_hunt(quest_id: String, monster_id: String) -> Dictionary:
	if player == null or monster_id == "" or quest_id == "":
		return {"ok": false, "message": "ไม่พบตัวละครหรือเควส"}
	if not player.active_quests.has(quest_id):
		return {"ok": false, "message": "ไม่พบเควสที่กำลังทำ"}
	var q_data: Dictionary = player.active_quests[quest_id]
	if q_data.get("completed", false):
		return {"ok": false, "message": "เควสนี้ทำครบแล้ว — ไปส่งที่ Quest Board"}

	cancel_quest_navigation()
	_quest_nav_quest_id = quest_id
	_quest_nav_monster_id = monster_id
	mark_quest_navigation_active()

	var acquired := _acquire_quest_hunt_target()
	if not acquired:
		cancel_quest_navigation()
		return {"ok": false, "message": "ไม่พบ %s บนแผนที่นี้" % monster_id}

	var m_data := MonsterDB.get_monster(monster_id)
	var m_name := str(m_data.get("name", monster_id))
	var def := QuestDatabase.get_quest(quest_id)
	var title := str(def.get("title", quest_id))
	return {
		"ok": true,
		"message": "ล่า %s จนจบ [%s]" % [m_name, title],
	}


func cancel_quest_navigation() -> void:
	var was_hunting := is_quest_navigation_active()
	super.cancel_quest_navigation()
	_quest_nav_monster_id = ""
	_quest_nav_quest_id = ""
	if was_hunting:
		_release_player_combat_for_move()


func _release_player_combat_for_move() -> void:
	if not player:
		return
	if player.has_method("_cancel_attack"):
		player._cancel_attack(true)
	else:
		player.pending_attack_target = null
		player.is_attacking = false
	player.is_hurt = false
	# ให้ฟังก์ชัน _handle_movement จัดการความเร็วเดินใหม่เอง

func _finish_quest_hunt() -> void:
	var quest_id := _quest_nav_quest_id
	var def := QuestDatabase.get_quest(quest_id)
	var title := str(def.get("title", quest_id))
	_quest_nav_monster_id = ""
	_quest_nav_quest_id = ""
	super.cancel_quest_navigation()
	_set_selected_target(null)
	_release_player_combat_for_move()
	GlobalData.is_auto_returning_quest = true
	GlobalData.returning_quest_id = quest_id
	var ui := UiAccess.get_ui(self)
	if ui and ui.has_method("show_notification"):
		ui.show_notification("เควส [%s] ครบแล้ว! กำลังเดินกลับไปส่ง..." % title, Color8(0x2e, 0xcc, 0x71))
	if ui and ui.has_method("add_log"):
		ui.add_log("🎯 เควส [%s] สำเร็จ — เริ่มเดินกลับส่งเควส" % title, Color8(0x2e, 0xcc, 0x71))
	QuestNavigation.navigate_to_npc(player, "quest_board", self)


func _process_quest_hunt() -> void:
	if not is_quest_navigation_active() or _quest_nav_quest_id == "":
		return
	if player == null or player.is_dead or player.is_sitting or player.is_talking:
		cancel_quest_navigation()
		return
	if not player.active_quests.has(_quest_nav_quest_id):
		cancel_quest_navigation()
		return
	var q_data: Dictionary = player.active_quests[_quest_nav_quest_id]
	if q_data.get("completed", false):
		_finish_quest_hunt()
		return

	if is_instance_valid(selected_target) and selected_target.get("is_active_monster"):
		var tid := str(selected_target.monster_id) if "monster_id" in selected_target and selected_target.monster_id != null else ""
		if tid == _quest_nav_monster_id:
			return

	_acquire_quest_hunt_target()


func _acquire_quest_hunt_target() -> bool:
	if player == null or _quest_nav_monster_id == "":
		return false

	var live := _find_nearest_monster_by_type(_quest_nav_monster_id)
	if live:
		select_monster(live)
		move_target = null
		return true

	var slot := WorldSyncManager.get_nearest_spawn_slot_for_type(_quest_nav_monster_id, player.global_position)
	if slot.is_empty():
		return false

	move_target = slot.get("pos", Vector2.ZERO)
	_set_selected_target(null)
	return true


func _on_hunt_destination_reached() -> void:
	if not is_quest_navigation_active() or _quest_nav_monster_id == "":
		return
	if not _acquire_quest_hunt_target():
		return
	if is_instance_valid(selected_target) and selected_target.get("is_active_monster"):
		try_attack_selected()


func _find_nearest_monster_by_type(monster_id: String) -> CharacterBody2D:
	if player == null or monster_id == "":
		return null
	var best: CharacterBody2D = null
	var best_dist_sq := INF
	var p_pos := player.global_position
	for m in _monsters:
		if not is_instance_valid(m) or not m.get("is_active_monster"):
			continue
			
		var m_id := str(m.monster_id) if "monster_id" in m and m.monster_id != null else ""
		if m_id != monster_id:
			continue
			
		var dist_sq := p_pos.distance_squared_to(_get_monster_hit_center(m))
		if dist_sq < best_dist_sq:
			best = m
			best_dist_sq = dist_sq
	return best


func _get_random_spawn_pos() -> Vector2:
	return Vector2(
		randi_range(64, GameConstants.MAP_WORLD_WIDTH - 64),
		randi_range(64, GameConstants.MAP_WORLD_HEIGHT - 64)
	)


# --- Spawn ---

func _spawn_monsters() -> void:
	if not monsters_root:
		return

	for slot in WorldSyncManager.get_mob_slots():
		if not slot is Dictionary:
			continue
		var sync_id := str(slot.get("sync_id", ""))
		var mob_type := str(slot.get("type", "poring"))
		var pos: Vector2 = slot.get("pos", Vector2.ZERO)
		var mob := _instantiate_mob(mob_type)
		if mob == null:
			continue
		mob.sync_id = sync_id
		mob.global_position = pos
		mob.died.connect(_on_poring_died)
		monsters_root.add_child(mob)
		_monsters.append(mob)
		_mob_by_sync_id[sync_id] = mob


func _instantiate_mob(mob_type: String) -> Monster:
	if MonsterDB.get_monster(mob_type).is_empty():
		mob_type = "poring"
	var mob: Monster = _generic_monster_scene.instantiate() as Monster
	if mob:
		mob.monster_id = mob_type
	return mob


func get_mob_by_sync_id(sync_id: String) -> CharacterBody2D:
	return _mob_by_sync_id.get(sync_id, null) as CharacterBody2D


func sync_kill_mob(sync_id: String) -> void:
	var mob := get_mob_by_sync_id(sync_id)
	if mob and is_instance_valid(mob) and mob.get("is_active_monster") and mob.has_method("apply_sync_kill"):
		mob.apply_sync_kill()


func sync_set_mob_hp(sync_id: String, hp: int) -> void:
	var mob := get_mob_by_sync_id(sync_id)
	if mob and is_instance_valid(mob) and mob.has_method("apply_sync_hp"):
		mob.apply_sync_hp(hp)


func respawn_mob(sync_id: String) -> void:
	var mob := get_mob_by_sync_id(sync_id)
	if mob and is_instance_valid(mob) and mob.has_method("respawn"):
		mob.respawn(WorldSyncManager.get_slot_respawn_pos(sync_id))


func spawn_boss(boss_id: String, pos: Vector2 = Vector2.ZERO) -> CharacterBody2D:
	if not monsters_root:
		return null
	var boss: big_monster = _big_poring_scene.instantiate() as big_monster
	if not boss:
		return null
	boss.monster_id = boss_id
	boss.sync_id = WorldSyncManager.BOSS_SYNC_ID
	var spawn_pos := pos if pos != Vector2.ZERO else get_boss_spawn_pos()
	boss.global_position = spawn_pos
	boss.died.connect(_on_poring_died)
	monsters_root.add_child(boss)
	_monsters.append(boss)
	_mob_by_sync_id[boss.sync_id] = boss
	return boss


# --- Drops ---

func _on_poring_died(monster: CharacterBody2D) -> void:
	if selected_target == monster:
		_set_selected_target(null)

	var sync_id := str(monster.get("sync_id")) if monster.get("sync_id") else ""
	var m_id := "poring"
	if "monster_id" in monster and monster.monster_id != null:
		m_id = str(monster.monster_id)
	var m_data = MonsterDB.get_monster(m_id)
	player.add_exp(m_data.get("exp", 25))
	flash_hit()
	if m_data.has("drops"):
		for drop_info in m_data["drops"]:
			if randf() <= drop_info["chance"]:
				_grant_loot(drop_info["id"])
	if sync_id == WorldSyncManager.BOSS_SYNC_ID:
		return
	if player and player.has_method("update_quest_progress"):
		player.update_quest_progress("kill", m_id, 1)
	var timer := get_tree().create_timer(WorldSyncManager.RESPAWN_DELAY)
	var respawn_pos := WorldSyncManager.get_slot_respawn_pos(sync_id) if sync_id != "" else _get_random_spawn_pos()
	if sync_id != "" and OnlineSession.is_online():
		notify_mob_died(sync_id)
		return
	timer.timeout.connect(func():
		if is_instance_valid(monster):
			monster.respawn(respawn_pos)
	)

func _grant_loot(item_id: String) -> void:
	if not player:
		return
	var item_data := itemfactory.create_loot_item(item_id)
	if item_data.is_empty():
		return

	var ui := UiAccess.get_ui(self)

	if not player.add_item_to_inventory(item_data):
		if ui and ui.has_method("add_log"):
			ui.add_log("กระเป๋าเต็ม — ไม่ได้รับ %s" % item_data.get("name", "Item"), Color8(0xe7, 0x4c, 0x3c))
		return

	var item_name := str(item_data.get("name", "Item"))
	var log_text := "Received: %s" % item_name
	var item_atk: int = int(item_data.get("attack", 0))
	var item_def: int = int(item_data.get("defense", 0))
	if item_atk > 0:
		log_text += " [Atk:%d]" % item_atk
	if item_def > 0:
		log_text += " [Def:%d]" % item_def

	if ui and ui.has_method("add_log"):
		ui.add_log(log_text, Color8(0xf1, 0xc4, 0x0f))
	if ui and ui.has_method("show_notification"):
		ui.show_notification("Obtained: " + item_name, Color8(0xf1, 0xc4, 0x0f))


func _get_monster_hit_center(monster: Node2D) -> Vector2:
	if monster.has_method("get_hit_center"):
		return monster.get_hit_center()
	return monster.global_position


func _find_monster_at(world_pos: Vector2) -> CharacterBody2D:
	var space := get_world_2d().direct_space_state
	var query := PhysicsPointQueryParameters2D.new()
	query.position = world_pos
	query.collide_with_areas = true
	query.collide_with_bodies = true
	query.collision_mask = GameConstants.MONSTER_CLICK_LAYER | GameConstants.MONSTER_BODY_LAYER
	var hits := space.intersect_point(query, 16)
	for hit in hits:
		var collider = hit.collider
		if not is_instance_valid(collider):
			continue
		if collider is Area2D:
			var monster_from_area: Node = collider.get_parent()
			if monster_from_area and monster_from_area.get("is_active_monster"):
				return monster_from_area as CharacterBody2D
		elif collider is CharacterBody2D and collider.is_in_group("monsters"):
			if collider.get("is_active_monster"):
				return collider

	var best: CharacterBody2D = null
	var best_dist_sq := INF
	var candidates: Array = _monsters.duplicate()
	for node in get_tree().get_nodes_in_group("monsters"):
		if node is CharacterBody2D and not candidates.has(node):
			candidates.append(node)
	for m in candidates:
		if is_instance_valid(m) and m.get("is_active_monster"):
			var m_id = m.get("monster_id") if m.get("monster_id") != null else "poring"
			var m_data = MonsterDB.get_monster(m_id)
			var c_rad: float = maxf(m_data.get("click_radius", 32.0), 28.0)
			var center := _get_monster_hit_center(m)
			var dist_sq := center.distance_squared_to(world_pos)
			if dist_sq < (c_rad * c_rad) and dist_sq < best_dist_sq:
				best = m
				best_dist_sq = dist_sq
	return best


# --- Combat ---

func interrupt_combat() -> void:
	_set_selected_target(null)
	move_target = null
	if player and player.has_method("_cancel_attack"):
		player._cancel_attack(true)


func inflict_damage_to_monster(monster: CharacterBody2D) -> void:
	if not is_instance_valid(monster) or not monster.get("is_active_monster"):
		return

	var base_dmg = player.get_attack_damage()
	var crit_chance = 0.10 + (float(player.luk) * 0.005)
	var is_crit = randf() < crit_chance
	var final_dmg = int(float(base_dmg) * 1.5) if is_crit else base_dmg

	player.pending_attack_target = monster
	player.pending_attack_damage = final_dmg
	player.pending_attack_crit = is_crit
	player.has_dealt_damage = false

	if player.has_method("trigger_attack_animation"):
		player.trigger_attack_animation(_get_monster_hit_center(monster))

	if is_crit:
		_hitstop(0.06)
	else:
		_hitstop(0.02)

# 🌟 ฟังก์ชันช่วยหยุดเวลาชั่วคราว เพื่อสร้างน้ำหนักการโจมตี (Hitstop)
func _hitstop(duration: float) -> void:
	Engine.time_scale = 0.1 
	var timer = get_tree().create_timer(duration * 0.1) 
	timer.timeout.connect(func():
		Engine.time_scale = 1.0 
	)


func do_attack() -> void:
	if player.is_sitting or player.is_talking:
		return

	var p_pos := player.global_position
	var attack_range_sq := GameConstants.PLAYER_MELEE_RANGE_SQ

	if is_instance_valid(selected_target) and selected_target.get("is_active_monster"):
		if p_pos.distance_squared_to(_get_monster_hit_center(selected_target)) <= attack_range_sq:
			inflict_damage_to_monster(selected_target)
	else:
		for m in _monsters:
			if is_instance_valid(m) and m.get("is_active_monster"):
				if p_pos.distance_squared_to(_get_monster_hit_center(m)) <= attack_range_sq:
					inflict_damage_to_monster(m)
					break

func _physics_process(delta: float) -> void:
	if not player:
		return
	if player.is_dead:
		player.apply_velocity(0, 0)
		return

	if Input.is_action_just_pressed("attack"):
		do_attack()

	if player.get("is_auto_mode") and not is_quest_navigation_active():
		_process_auto_ai()
	elif is_quest_navigation_active() and _quest_nav_quest_id != "":
		_process_quest_hunt()

	_update_click_move_target()
	_handle_movement(delta)
	_process_pending_npc_talk()

	if monsters_root and monsters_root.has_method("update_monsters_ai"):
		monsters_root.update_monsters_ai(delta)

	var valid_target = selected_target if is_instance_valid(selected_target) else null
	if effects and effects.has_method("update_effects"):
		effects.update_effects(valid_target, move_target)

	_process_auto_return_turn_in()
	_try_auto_portal_warp()


func _walk_to_move_target() -> void:
	if move_target == null or not player:
		return
	var p_pos := player.global_position
	var target: Vector2 = move_target
	if p_pos.distance_squared_to(target) > 16.0:
		var dir := (target - p_pos).normalized()
		var pos_before := player.global_position
		player.apply_velocity(dir.x, dir.y)
		if player.global_position.distance_squared_to(pos_before) < 0.01:
			move_target = null
			if is_quest_navigation_active() and _quest_nav_monster_id != "":
				_on_hunt_destination_reached()
			elif not _should_keep_auto_quest_nav():
				cancel_quest_navigation()
			player.apply_velocity(0, 0)
	else:
		move_target = null
		if is_quest_navigation_active() and _quest_nav_monster_id != "":
			_on_hunt_destination_reached()
		elif not _should_keep_auto_quest_nav() and is_quest_navigation_active():
			cancel_quest_navigation()
		player.apply_velocity(0, 0)


func _handle_movement(_delta: float) -> void:
	if not player or player.is_sitting or player.is_talking:
		move_target = null
		if player:
			player.apply_velocity(0, 0)
		return

	var map_move_only := _is_map_click_move_active()
	var ui_blocks := blocks_player_movement() and not map_move_only

	var vx := Input.get_axis("move_left", "move_right")
	var vy := Input.get_axis("move_up", "move_down")
	if ui_blocks:
		vx = 0.0
		vy = 0.0

	if vx != 0.0 or vy != 0.0:
		_is_dragging_map = false
		GlobalData.clear_auto_quest_state()
		GlobalData.clear_auto_quest()
		cancel_quest_navigation()
		move_target = null
		_set_selected_target(null)
		_release_player_combat_for_move()
		player.apply_velocity(vx, vy)
		return

	var p_pos := player.global_position

	# --- ระบบเซฟตี้หนีบอสอัตโนมัติ (Flee Boss) ---
	if player.get("is_auto_mode") and player.get("auto_flee_boss"):
		var flee_radius_sq := 160000.0
		var boss_to_flee_from: CharacterBody2D = null
		var boss: Node = BossManager.active_boss if BossManager else null
		if is_instance_valid(boss) and boss.get("is_active_monster"):
			var dist_sq := p_pos.distance_squared_to(boss.global_position)
			if dist_sq < flee_radius_sq and _is_path_clear(p_pos, boss.global_position, boss):
				boss_to_flee_from = boss as CharacterBody2D

		if boss_to_flee_from:
			_set_selected_target(null)
			move_target = null
			var dir := (p_pos - boss_to_flee_from.global_position).normalized()
			player.apply_velocity(dir.x, dir.y)
			return

	if move_target != null:
		_walk_to_move_target()
		return

	if is_instance_valid(selected_target) and selected_target.get("is_active_monster"):
		var target_pos: Vector2 = _get_monster_hit_center(selected_target)
		var dist_sq := p_pos.distance_squared_to(target_pos)

		if dist_sq > GameConstants.PLAYER_MELEE_RANGE_SQ:
			var dir := (target_pos - p_pos).normalized()
			player.apply_velocity(dir.x, dir.y)
		else:
			player.apply_velocity(0, 0)
			var now := Time.get_ticks_msec() / 1000.0
			var attack_cooldown = 1.0
			if player.has_method("get_attack_speed"):
				attack_cooldown = 1.0 / player.get_attack_speed()

			if not player.is_attacking and not player.is_hurt and now - player.last_auto_attack >= attack_cooldown:
				player.last_auto_attack = now
				inflict_damage_to_monster(selected_target)
		return
	else:
		_set_selected_target(null)

	player.apply_velocity(0, 0)

func set_move_target_from_minimap(local_x: float, local_y: float, map_w: float, map_h: float) -> void:
	super.set_move_target_from_minimap(local_x, local_y, map_w, map_h)
	_set_selected_target(null)


func spawn_damage_text(pos: Vector2, amount: int, is_crit: bool = false, custom_color: Color = Color.WHITE) -> void:
	var container := Node2D.new()
	var random_x_offset = randf_range(-12.0, 12.0)
	container.global_position = pos + Vector2(random_x_offset, -18)
	container.z_index = 100
	add_child(container)
	
	var lbl := Label.new()
	lbl.text = str(amount)
	lbl.add_theme_font_size_override("font_size", 11 if is_crit else 8)
	
	var final_color = custom_color if custom_color != Color.WHITE else (Color8(0xff, 0x47, 0x57) if is_crit else Color.WHITE)
	lbl.add_theme_color_override("font_color", final_color)
	lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	lbl.add_theme_constant_override("outline_size", 3)
	
	var lbl_size = lbl.get_minimum_size()
	lbl.position = -lbl_size / 2.0 
	container.add_child(lbl)
	
	container.scale = Vector2(0.2, 0.2)
	var tween = create_tween().set_parallel(true)
	
	tween.tween_property(container, "scale", Vector2(1.2, 1.2), 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.chain().tween_property(container, "scale", Vector2(1.0, 1.0), 0.1)
	
	var float_height = 25.0 if is_crit else 15.0
	tween.tween_property(container, "position:y", container.position.y - float_height, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(lbl, "modulate:a", 0.0, 0.3).set_delay(0.4)
	
	tween.chain().tween_callback(container.queue_free)

# 🌟 ฟังก์ชันเรดาร์เช็คกำแพงขั้นสูง (ชนทุกกำแพง ทะลุจุดวาร์ป)
func _is_path_clear(start_pos: Vector2, end_pos: Vector2, target_node: Node2D) -> bool:
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(start_pos, end_pos)
	
	query.collision_mask = 0xFFFFFFFF # เช็คกำแพงทุก Layer ที่มีในเกม
	query.collide_with_areas = false  # เมิน Area2D (เช่น จุดวาร์ป จะได้ไม่โดนบล็อก)
	
	# เอาตัวเองและเป้าหมายออกจากเรดาร์ จะได้ไม่บังกันเอง
	var excludes = []
	if is_instance_valid(player) and player is CollisionObject2D:
		excludes.append(player.get_rid())
	if is_instance_valid(target_node) and target_node is CollisionObject2D:
		excludes.append(target_node.get_rid())
	query.exclude = excludes
	
	var result = space_state.intersect_ray(query)
	
	# ถ้าไม่มีอะไรขวางเลย แปลว่าทางสะดวก
	return result.is_empty()

func _process_auto_ai() -> void:
	if player.is_dead or player.is_sitting or player.is_talking:
		return
	if move_target != null:
		return

	if is_instance_valid(selected_target) and selected_target.get("is_active_monster"):
		# 🌟 ถ้าเป้าหมายโดนกำแพงบัง ให้ทิ้งเป้าหมายนั้นทันที
		if not _is_path_clear(player.global_position, selected_target.global_position, selected_target):
			_set_selected_target(null) 
		else:
			return

	var nearest = _find_nearest_active_monster()
	if nearest:
		select_monster(nearest)
		move_target = null

func _find_nearest_active_monster() -> CharacterBody2D:
	var best: CharacterBody2D = null
	var best_dist_sq := INF
	var p_pos := player.global_position
	var max_chase_sq := 250000.0 
	
	for m in _monsters:
		if is_instance_valid(m) and m.get("is_active_monster"):
			if player.get("auto_flee_boss"):
				var is_boss = (m.get("sync_id") == "world_boss" or m.get("monster_id") == "big_poring")
				if is_boss:
					continue
				
			var m_pos = m.global_position
			var dist_sq := p_pos.distance_squared_to(m_pos)
			if dist_sq < best_dist_sq and dist_sq <= max_chase_sq:
				
				# 🌟 ส่ง m ไปให้เรดาร์ตรวจสอบด้วย
				if _is_path_clear(p_pos, m_pos, m):
					best = m
					best_dist_sq = dist_sq
					
	return best
