class_name World
extends BaseMap

var selected_target: CharacterBody2D = null
@onready var monsters_root: Node2D = $Monsters if has_node("Monsters") else null
@onready var effects = $WorldEffects if has_node("WorldEffects") else null

var _poring_scene: PackedScene
var _big_poring_scene: PackedScene
var _fabre_scene: PackedScene
var _monsters: Array[CharacterBody2D] = []
var _mob_by_sync_id: Dictionary = {}

# world.gd — สารบัญ: Lifecycle | Targeting | Spawn | Combat | Drops | Movement

# --- Lifecycle ---

func _ready() -> void:
	super._ready()

	_poring_scene = preload("res://scenes/characters/poring.tscn")
	_big_poring_scene = preload("res://scenes/characters/big_poring.tscn")
	_fabre_scene = preload("res://scenes/characters/fabre.tscn")
	
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
	if is_modal_open() or not player:
		return
	if not is_instance_valid(monster) or not monster.get("is_active_monster"):
		return
	_set_selected_target(monster)
	move_target = null
	var m_id = monster.get("monster_id") if monster.get("monster_id") != null else "poring"
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
	if selected_target != null and is_instance_valid(selected_target):
		return false
	return true


func _on_player_died() -> void:
	_set_selected_target(null)
	move_target = null


func get_monsters() -> Array[CharacterBody2D]:
	return _monsters


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
	match mob_type:
		"fabre":
			var fabre: Monster = _fabre_scene.instantiate() as Monster
			if fabre:
				fabre.monster_id = "fabre"
			return fabre
		_:
			return _poring_scene.instantiate() as Monster


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
	var spawn_pos := pos if pos != Vector2.ZERO else Vector2(
		GameConstants.MAP_WORLD_WIDTH * 0.5,
		GameConstants.MAP_WORLD_HEIGHT * 0.35
	)
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
	var m_id = monster.get("monster_id") if monster.get("monster_id") != null else "poring"
	var m_data = MonsterDB.get_monster(m_id)
	player.add_exp(m_data.get("exp", 25))

	flash_hit()

	if m_data.has("drops"):
		for drop_info in m_data["drops"]:
			if randf() <= drop_info["chance"]:
				_grant_loot(drop_info["id"])

	if sync_id == WorldSyncManager.BOSS_SYNC_ID:
		return

	if m_id == "poring" and player and player.has_method("update_quest_progress"):
		player.update_quest_progress("kill", "poring", 1)

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


# --- Movement (override BaseMap) ---

func _physics_process(delta: float) -> void:
	if not player:
		return
	if player.is_dead:
		player.apply_velocity(0, 0)
		return

	if Input.is_action_just_pressed("attack"):
		do_attack()

	# 🌟 แทรกโค้ด AI ตรงนี้: ถ้าเปิด Auto ไว้ ให้มันคิดหาเป้าหมาย
	if player.get("is_auto_mode"):
		_process_auto_ai()

	_update_click_move_target()
	_handle_movement(delta)

	if monsters_root and monsters_root.has_method("update_monsters_ai"):
		monsters_root.update_monsters_ai(delta)

	var valid_target = selected_target if is_instance_valid(selected_target) else null
	if effects and effects.has_method("update_effects"):
		effects.update_effects(valid_target, move_target)


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
		move_target = null
		_set_selected_target(null)
		player.apply_velocity(vx, vy)
		return

	var p_pos := player.global_position

	# 🌟 --- ระบบเซฟตี้หนีบอสอัตโนมัติ (ใส่เกียร์หมาทันทีที่เข้าใกล้บอส) ---
	if player.get("is_auto_mode") and player.get("auto_flee_boss"):
		var flee_radius_sq := 160000.0 # รัศมีอันตราย
		var boss_to_flee_from: CharacterBody2D = null
		
		for m in _monsters:
			if is_instance_valid(m) and m.get("is_active_monster"):
				var is_boss = (m.get("sync_id") == "world_boss" or m.get("monster_id") == "big_poring")
				if is_boss:
					var dist_sq = p_pos.distance_squared_to(m.global_position)
					# 🌟 แก้ตรงนี้: เช็คระยะทาง AND เช็คว่าบอสไม่ได้อยู่หลังกำแพง ถึงจะหนี!
					if dist_sq < flee_radius_sq and _is_path_clear(p_pos, m.global_position, m):
						boss_to_flee_from = m
						break
		
		# ถ้าเจอบอสในระยะอันตราย ให้วิ่งหนีสุดชีวิต!
		if boss_to_flee_from:
			_set_selected_target(null) 
			move_target = null
			var dir := (p_pos - boss_to_flee_from.global_position).normalized()
			player.apply_velocity(dir.x, dir.y)
			return
	# 🌟 --------------------------------------------------------

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

	if move_target != null:
		var target: Vector2 = move_target
		if p_pos.distance_squared_to(target) > 16.0:
			var dir := (target - p_pos).normalized()
			player.apply_velocity(dir.x, dir.y)
		else:
			move_target = null
			player.apply_velocity(0, 0)
		return

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
