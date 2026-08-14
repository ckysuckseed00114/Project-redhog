class_name Player
extends CharacterBody2D

signal stats_changed
signal inventory_changed
signal equipment_changed
signal quests_changed
signal died

var direction: String = "down"
var is_moving: bool = false
var is_sitting: bool = false
var is_dead: bool = false
var is_talking: bool = false
var is_auto_mode: bool = false
var auto_flee_boss: bool = true
var max_hp: int = 100
var hp: int = 100
var max_sp: int = 50
var sp: int = 50
var max_exp: int = 100
var current_exp: int = 0  
var level: int = 1
var stat_points: int = 0

var current_job: String = "novice"
var zeny: int = 500
var job_points: int = 0   # 🌟 เริ่มต้นที่ 0 แต้ม
var job_level: int = 1    # 🌟 เพิ่ม Job Level
var job_exp: int = 0      # 🌟 เพิ่ม Job EXP
var max_job_exp: int = 50 # 🌟 เพิ่ม Max Job EXP
var skill_levels: Dictionary = {}
var has_dealt_damage: bool = false

var str_stat: int = 5
var agi: int = 5
var vit: int = 5
var int_stat: int = 5
var dex: int = 5
var luk: int = 5

var inventory: Array = []
var quick_slots: Array = []
var equipment := {
	"helm": null,
	"armor": null,
	"garment": null,
	"weapon": null,
	"shield": null,
	"boots": null,
	"acc1": null,
	"acc2": null
}

var last_attack_time: float = 0.0
var last_auto_attack: float = 0.0
var is_attacking: bool = false
var is_hurt: bool = false
var _attack_hit_frame: int = 2
var pending_attack_target: Node = null
var pending_attack_damage: int = 0
var pending_attack_crit: bool = false

var _presence_timer: float = 2.8
var _death_position: Vector2 = Vector2.ZERO
var _auto_potion := PlayerAutoPotion.new()

var auto_potion_enabled: bool = true
var auto_potion_hp_pct: float = 0.50
var auto_potion_sp_pct: float = 0.30


@export var attack_duration: float = 0.4  
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var camera: Camera2D = $Camera2D

var auto_save_timer: Timer

const MAX_HURT_LOCKOUT := 0.35

# player.gd — สารบัญ: Setup | Visuals | Stats/Job | Combat | Inventory | Movement | Input

# --- Setup ---

func _ready() -> void:
	add_to_group("player")
	current_job = GlobalData.player_class if GlobalData.player_class != "" else "novice"
	
	if not skill_levels.has("first_aid"):
		skill_levels["first_aid"] = 1

	_auto_potion.enabled = auto_potion_enabled
	_auto_potion.hp_threshold = auto_potion_hp_pct
	_auto_potion.sp_threshold = auto_potion_sp_pct
		
	_setup_collision()
	_init_inventory()
	_init_quick_slots()
	apply_job_visuals(current_job, GlobalData.player_gender)
	_apply_class_stats(current_job)

	if camera:
		camera.zoom = Vector2(5.5, 5.5)

	# Warp stash มีความจริงสูงสุด — ไม่ดึง Cloud ทับหลัง warp
	if PlayerSaveStash.has_pending():
		PlayerSaveStash.apply_to_player(self)
		call_deferred("reveal_from_load")
	elif OnlineSession.is_online():
		DatabaseManager.load_game_data(self)
	else:
		if GlobalData.apply_pending_character_to(self):
			apply_job_visuals(current_job, GlobalData.player_gender)
			stats_changed.emit()
		call_deferred("reveal_from_load")
		if GlobalData.pending_revive_at_save:
			call_deferred("_apply_pending_revive_spawn")
			if not SupabaseClient.realtime_channel_joined.is_connected(_on_realtime_channel_joined):
				SupabaseClient.realtime_channel_joined.connect(_on_realtime_channel_joined)
			call_deferred("_sync_presence_now")
		
	auto_save_timer = Timer.new()
	auto_save_timer.wait_time = 180.0
	auto_save_timer.autostart = true
	auto_save_timer.timeout.connect(_on_auto_save_timeout)
	add_child(auto_save_timer)
	call_deferred("emit_signal", "inventory_changed")

func _on_auto_save_timeout() -> void:
	if is_dead:
		return
	if OnlineSession.is_logged_in():
		DatabaseManager.save_game_data(self)
		print("💾 [Auto-Save] บันทึกข้อมูลอัตโนมัติสำเร็จเรียบร้อย")
		
		var ui := UiAccess.get_ui(self)
		if ui and ui.has_method("refresh_inventory_and_equipment_ui"):
			ui.refresh_inventory_and_equipment_ui()

func _apply_class_stats(class_id: String) -> void:
	var class_info = ClassDatabase.get_class_info(class_id)
	if not class_info.is_empty():
		current_job = class_id
		StatRegistry.apply_job_bases(self, class_id)
		hp = max_hp
		sp = max_sp
		stats_changed.emit()

# --- Visuals ---

func apply_job_visuals(job: String = "", gender: String = "") -> void:
	if job == "":
		job = current_job
	if gender == "":
		gender = GlobalData.player_gender
	var frames := PlayerSpriteLoader.build_sprite_frames(job, gender)
	if frames.get_animation_names().is_empty():
		push_warning("No sprite frames for job=%s gender=%s — using fallback" % [job, gender])
		_apply_fallback_visual()
		return
	var prev_anim := "idle"
	if sprite.sprite_frames:
		prev_anim = String(sprite.animation)
	sprite.visible = true
	sprite.sprite_frames = frames
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.scale = PlayerSpriteLoader.get_sprite_scale(frames)
	_attack_hit_frame = PlayerSpriteLoader.get_attack_hit_frame(job, gender, frames)
	if frames.has_animation(prev_anim):
		sprite.play(prev_anim)
	elif frames.has_animation("idle"):
		sprite.play("idle")
	else:
		sprite.play(String(frames.get_animation_names()[0]))


func _apply_fallback_visual() -> void:
	var tex := load("res://icon.svg") as Texture2D
	if tex == null:
		return
	var frames := SpriteFrames.new()
	frames.add_animation("idle")
	frames.add_frame("idle", tex)
	sprite.visible = true
	sprite.sprite_frames = frames
	sprite.scale = Vector2(0.15, 0.15)
	sprite.play("idle")


func reveal_from_load() -> void:
	visible = true
	modulate = Color.WHITE
	set_physics_process(true)
	set_process(true)
	if sprite and not sprite.visible:
		sprite.visible = true
	if _has_sprite_anim("idle"):
		sprite.play("idle")
	elif sprite and sprite.sprite_frames and sprite.sprite_frames.get_animation_names().size() > 0:
		sprite.play(String(sprite.sprite_frames.get_animation_names()[0]))
		
	if not SavePointService.has_save_point():
		var current_scene := ""
		if get_tree() and get_tree().current_scene:
			current_scene = WarpHelper.normalize_scene_path(get_tree().current_scene.scene_file_path)
			
		if current_scene != "":
			GlobalData.save_point_scene = current_scene
			GlobalData.save_point_x = global_position.x
			GlobalData.save_point_y = global_position.y
			GlobalData.has_save_point = true
			
			if OnlineSession.is_online():
				DatabaseManager.save_game_data(self)

func _has_sprite_anim(anim_name: String) -> bool:
	return sprite.sprite_frames != null and sprite.sprite_frames.has_animation(anim_name)

func _play_sprite_anim(anim_name: String) -> bool:
	if not _has_sprite_anim(anim_name):
		return false
	sprite.play(anim_name)
	return true


func _resolve_walk_animation() -> String:
	match direction:
		"down":
			if _has_sprite_anim("walking_down"):
				sprite.flip_v = false
				return "walking_down"
		"down_right", "down_left":
			if _has_sprite_anim("walking_down_right"):
				sprite.flip_v = false
				return "walking_down_right"
		"up":
			if _has_sprite_anim("walking_up"):
				sprite.flip_v = false
				return "walking_up"
			if _has_sprite_anim("walking_down"):
				sprite.flip_v = true
				return "walking_down"
		"up_right", "up_left":
			if _has_sprite_anim("walking_up_right"):
				sprite.flip_v = false
				return "walking_up_right"
		"left", "right":
			if _has_sprite_anim("walking_side"):
				sprite.flip_v = false
				return "walking_side"
	if _has_sprite_anim("walking"):
		sprite.flip_v = false
		return "walking"
	return "idle"


func _apply_facing_flip() -> void:
	match direction:
		"left", "down_left", "up_left":
			sprite.flip_h = true
		"right", "down_right", "up_right":
			sprite.flip_h = false


func _play_movement_animation(moving: bool) -> void:
	if not moving:
		sprite.flip_v = false
		if not _play_sprite_anim("idle"):
			_play_sprite_anim("walking")
		return
	_apply_facing_flip()
	var anim_name := _resolve_walk_animation()
	if _has_sprite_anim(anim_name):
		if sprite.animation != anim_name or not sprite.is_playing():
			sprite.play(anim_name)


func _play_idle_or_walk() -> void:
	_play_movement_animation(is_moving or velocity.length_squared() > 0.01)

# --- Job ---

func can_change_job() -> bool:
	return current_job == "novice" and ClassDatabase.can_advance_from_novice(level)


func change_job(new_job: String) -> bool:
	if not ClassDatabase.can_advance_from_novice(level):
		return false
	if not ClassDatabase.is_valid_job_change(current_job, new_job):
		return false
	_apply_class_stats(new_job)
	GlobalData.player_class = new_job
	apply_job_visuals(new_job, GlobalData.player_gender)
	stats_changed.emit()
	if OnlineSession.is_logged_in():
		DatabaseManager.save_game_data(self)
	var ui := UiAccess.get_ui(self)
	if ui and ui.has_method("show_notification"):
		ui.show_notification("Job changed to %s!" % ClassDatabase.get_display_name(new_job), Color8(0x2e, 0xcc, 0x71))
	return true


func _setup_collision() -> void:
	var shape := RectangleShape2D.new()
	shape.size = Vector2(9, 6)
	$CollisionShape2D.shape = shape
	$CollisionShape2D.position = Vector2(8.5, 13)


func _init_inventory() -> void:
	inventory.resize(GameConstants.INVENTORY_SIZE)
	inventory.fill(null)


func _init_quick_slots() -> void:
	quick_slots.resize(6)
	quick_slots.fill(null)


func can_assign_quick_slot(item: Dictionary) -> bool:
	return ItemDatabase.is_potion(item)


func assign_quick_slot_from_inventory(slot_idx: int, inv_index: int) -> bool:
	if inv_index < 0 or inv_index >= inventory.size():
		return false
	var item: Variant = inventory[inv_index]
	if item == null or not can_assign_quick_slot(item):
		return false
	return assign_quick_slot_entry(slot_idx, {"kind": "item", "item_id": str(item.get("id", ""))}, -1)


func first_empty_quick_slot(exclude: int = -1) -> int:
	for i in range(quick_slots.size()):
		if i == exclude:
			continue
		if quick_slots[i] == null:
			return i
	return -1


func assign_quick_slot_entry(target_idx: int, entry: Dictionary, from_slot: int = -1) -> bool:
	if target_idx < 0 or target_idx >= quick_slots.size():
		return false
	if entry == null or not entry is Dictionary:
		return false

	var kind := str(entry.get("kind", ""))
	if kind == "skill":
		var skill_id := str(entry.get("skill_id", ""))
		if skill_id == "":
			return false
		for i in range(quick_slots.size()):
			if i == target_idx or i == from_slot:
				continue
			var e: Variant = quick_slots[i]
			if e is Dictionary and str(e.get("kind", "")) == "skill" and str(e.get("skill_id", "")) == skill_id:
				quick_slots[i] = null
	elif kind == "item":
		var item_id := str(entry.get("item_id", ""))
		if item_id == "":
			return false
		for i in range(quick_slots.size()):
			if i == target_idx or i == from_slot:
				continue
			var e: Variant = quick_slots[i]
			if e is Dictionary and str(e.get("kind", "")) == "item" and str(e.get("item_id", "")) == item_id:
				quick_slots[i] = null
	else:
		return false

	var displaced: Variant = quick_slots[target_idx]
	var new_entry := entry.duplicate(true)

	if from_slot >= 0 and from_slot != target_idx:
		quick_slots[target_idx] = new_entry
		quick_slots[from_slot] = displaced.duplicate(true) if displaced is Dictionary else null
	elif from_slot >= 0:
		return true
	else:
		quick_slots[target_idx] = new_entry
		if displaced is Dictionary:
			var empty := first_empty_quick_slot(target_idx)
			if empty >= 0:
				quick_slots[empty] = displaced
	return true


func clear_quick_slot(slot_idx: int) -> void:
	if slot_idx < 0 or slot_idx >= quick_slots.size():
		return
	quick_slots[slot_idx] = null


func use_quick_slot(slot_idx: int) -> Dictionary:
	if is_dead or slot_idx < 0 or slot_idx >= quick_slots.size():
		return {"ok": false, "message": "", "heal_hp": 0, "heal_sp": 0, "item_id": ""}
	var entry: Variant = quick_slots[slot_idx]
	if entry == null or not entry is Dictionary:
		return {"ok": false, "message": "", "heal_hp": 0, "heal_sp": 0, "item_id": ""}
		
	var kind = str(entry.get("kind", ""))
	
	# ถ้าเป็นไอเทม
	if kind == "item":
		var item_id := str(entry.get("item_id", ""))
		var result := ConsumableService.use_by_item_id(self, item_id)
		if result.get("ok", false):
			if get_quick_slot_item_count(slot_idx) <= 0:
				clear_quick_slot(slot_idx)
		return result
		
	# ถ้าเป็นสกิล
	elif kind == "skill":
		var skill_id := str(entry.get("skill_id", ""))
		if skill_id == "first_aid":
			cast_first_aid()
		else:
			# สกิลโจมตีอื่นๆ ที่เราจะสร้างเพิ่มในอนาคต
			print("ร่ายสกิล: ", skill_id)
		return {"ok": true, "message": ""}
		
	return {"ok": false, "message": "", "heal_hp": 0, "heal_sp": 0, "item_id": ""}

func get_quick_slot_item_count(slot_idx: int) -> int:
	if slot_idx < 0 or slot_idx >= quick_slots.size():
		return 0
	var entry: Variant = quick_slots[slot_idx]
	if entry == null or str(entry.get("kind", "")) != "item":
		return 0
	var item_id := str(entry.get("item_id", ""))
	var total := 0
	for item in inventory:
		if item != null and str(item.get("id", "")) == item_id:
			total += int(item.get("count", 1))
	return total

func _update_max_hp() -> void:
	StatRegistry.recalculate_max_hp(self)

func get_attack_damage() -> int:
	return int(StatRegistry.get_derived(self, "atk"))

func get_defense() -> int:
	return int(StatRegistry.get_derived(self, "def"))

func get_magic_attack() -> int:
	return int(StatRegistry.get_derived(self, "matk"))

func get_attack_speed() -> float:
	return float(StatRegistry.get_derived(self, "aspd"))

func get_movement_speed() -> float:
	return float(StatRegistry.get_derived(self, "mspd"))

func get_accuracy() -> int:
	return int(StatRegistry.get_derived(self, "hit"))

func get_evasion() -> int:
	return int(StatRegistry.get_derived(self, "flee"))

func add_exp(amount: int) -> void:
	if is_dead:
		return
		
	var final_amount = amount
	
	if PartyManager.current_party_id != "" and PartyManager.party_members.size() > 1:
		var party_bonus = int(float(amount) * 1.20)
		final_amount = int(float(party_bonus) / float(PartyManager.party_members.size()))
		print("🎉 Party EXP Shared! ได้รับ: ", final_amount)
		
	current_exp += final_amount
	_add_job_exp(final_amount) # 🌟 แจก EXP ให้สายอาชีพด้วย
	
	while current_exp >= max_exp:
		current_exp -= max_exp
		level += 1
		max_exp = int(floor(float(max_exp) * 1.4))
		stat_points += 1
		_update_max_hp()
		hp = max_hp
		sp = max_sp
		_flash_level_up()
		
		var ui := UiAccess.get_ui(self)
		if ui and ui.has_method("show_notification"):
			ui.show_notification("BASE LEVEL UP! (Lv. %d)" % level, Color8(0x34, 0x98, 0xdb))
			
	stats_changed.emit()

# 🌟 ฟังก์ชันใหม่ จัดการเรื่อง Job Level ล้วนๆ
func _add_job_exp(amount: int) -> void:
	var max_jl = 5 if current_job == "novice" else 50
	if job_level >= max_jl:
		return
		
	job_exp += amount
	while job_exp >= max_job_exp and job_level < max_jl:
		job_exp -= max_job_exp
		job_level += 1
		max_job_exp = int(floor(float(max_job_exp) * 1.5))
		job_points += 1 # ได้แต้มไปอัพสมุดสกิล
		
		var ui := UiAccess.get_ui(self)
		if ui and ui.has_method("show_notification"):
			ui.show_notification("JOB LEVEL UP! (Job Lv. %d)" % job_level, Color8(0xf1, 0xc4, 0x0f))
			
	if job_level >= max_jl:
		job_exp = 0

func take_damage(amount: int) -> void:
	if is_dead:
		return

	_resolve_pending_attack_hit()

	hp = maxi(0, hp - amount)
	stats_changed.emit()
	
	var world := get_tree().get_first_node_in_group("world")
	if world and world.has_method("spawn_damage_text"):
		world.spawn_damage_text(global_position, amount, false, Color8(0xf1, 0xc4, 0x0f))
	
	_cancel_attack(false)
	_play_hurt_animation()
	
	if hp == 0:
		_die()


func _resolve_pending_attack_hit() -> void:
	if not is_attacking or sprite.animation != "attack" or has_dealt_damage:
		return
	if sprite.frame >= _attack_hit_frame:
		execute_melee_hit()

func _cancel_attack(clear_pending: bool = false) -> void:
	is_attacking = false
	sprite.speed_scale = 1.0
	_disconnect_attack_signals()
	if clear_pending:
		pending_attack_target = null
		pending_attack_damage = 0
		pending_attack_crit = false
	has_dealt_damage = false

func _play_hurt_animation() -> void:
	if not _has_sprite_anim("hurt"):
		return
	is_hurt = true
	sprite.play("hurt")
	var hurt_timer := get_tree().create_timer(_get_hurt_duration())
	hurt_timer.timeout.connect(_on_hurt_finished, CONNECT_ONE_SHOT)

func _get_hurt_duration() -> float:
	if sprite.sprite_frames and sprite.sprite_frames.has_animation("hurt"):
		var frame_count := sprite.sprite_frames.get_frame_count("hurt")
		var fps := sprite.sprite_frames.get_animation_speed("hurt")
		if fps > 0.0:
			return minf(float(frame_count) / fps, MAX_HURT_LOCKOUT)
	return 0.25

func _on_hurt_finished() -> void:
	is_hurt = false
	if is_dead or is_attacking:
		return
	if sprite.animation != "hurt":
		return
	if _try_resume_interrupted_attack():
		return
	if velocity == Vector2.ZERO:
		_play_movement_animation(false)
	else:
		_play_movement_animation(true)

func _try_resume_interrupted_attack() -> bool:
	if pending_attack_target == null or not is_instance_valid(pending_attack_target):
		return false
	if not pending_attack_target.get("is_active_monster"):
		pending_attack_target = null
		return false
	var world := get_tree().get_first_node_in_group("world")
	if world == null or not world.has_method("inflict_damage_to_monster"):
		return false
	var target_pos: Vector2 = (pending_attack_target as Node2D).global_position
	if world.has_method("_get_monster_hit_center"):
		target_pos = world._get_monster_hit_center(pending_attack_target as Node2D)
	if global_position.distance_squared_to(target_pos) > GameConstants.PLAYER_MELEE_RANGE_SQ:
		return false
	world.inflict_damage_to_monster(pending_attack_target)
	return true

func _die() -> void:
	is_dead = true
	is_hurt = false
	_death_position = global_position
	_cancel_attack(true)
	
	sprite.modulate = Color(1, 0.2, 0.2, 0.6)
	
	if _has_sprite_anim("dying"):
		sprite.play("dying")
		
	died.emit()
	set_physics_process(false)
	apply_velocity(0, 0)
	
	var ui := UiAccess.get_ui(self)
	if ui and ui.has_method("open_death_dialog"):
		ui.open_death_dialog(self)


func revive_at_death_spot() -> void:
	if not is_dead:
		return
	_finish_revive(_death_position)


func revive_at_save_point() -> bool:
	if not is_dead or not SavePointService.has_save_point():
		return false
	var save_scene := SavePointService.get_scene()
	var save_pos := SavePointService.get_position()
	var tree := get_tree()
	var current := ""
	if tree.current_scene:
		current = WarpHelper.normalize_scene_path(tree.current_scene.scene_file_path)

	if current == WarpHelper.normalize_scene_path(save_scene):
		restore_after_save_point_revive(save_pos)
		return true

	GlobalData.pending_revive_at_save = true
	var dest_name = SavePointService.get_display_name()
	WarpHelper.execute(tree, save_scene, save_pos, dest_name, self)
	return true


func restore_after_save_point_revive(pos: Vector2 = global_position) -> void:
	global_position = pos
	hp = max_hp
	sp = max_sp
	is_dead = false
	is_attacking = false
	is_hurt = false
	set_physics_process(true)
	set_process(true)
	visible = true
	modulate = Color.WHITE
	if sprite:
		sprite.modulate = Color(1, 1, 1, 1)
		_play_sprite_anim("idle")
	stats_changed.emit()
	var ui := UiAccess.get_ui(self)
	if ui:
		if ui.has_method("close_death_dialog"):
			ui.close_death_dialog()
		if ui.has_method("_update_player_stats_ui"):
			ui._update_player_stats_ui()
		if ui.has_method("show_notification"):
			ui.show_notification("ฟื้นชีพที่จุดเซฟ", Color8(0x2e, 0xcc, 0x71))


func _finish_revive(pos: Vector2, restore_full: bool = false) -> void:
	if restore_full:
		restore_after_save_point_revive(pos)
		return
	global_position = pos
	hp = maxi(1, int(float(max_hp) * 0.5))
	sp = maxi(1, int(float(max_sp) * 0.5))
	is_dead = false
	is_attacking = false
	is_hurt = false
	set_physics_process(true)
	sprite.modulate = Color(1, 1, 1, 1)
	_play_sprite_anim("idle")
	stats_changed.emit()
	var ui := UiAccess.get_ui(self)
	if ui and ui.has_method("close_death_dialog"):
		ui.close_death_dialog()
	if ui and ui.has_method("_update_player_stats_ui"):
		ui._update_player_stats_ui()
	if ui and ui.has_method("show_notification"):
		ui.show_notification("ฟื้นชีพแล้ว!", Color8(0x2e, 0xcc, 0x71))


func _apply_pending_revive_spawn() -> void:
	if not GlobalData.pending_revive_at_save:
		return
	GlobalData.pending_revive_at_save = false
	restore_after_save_point_revive()

# วางทับฟังก์ชัน spend_stat_point เดิม และเพิ่มฟังก์ชัน confirm_stat_allocation ต่อท้าย
func spend_stat_point(stat_key: String) -> bool:
	# ปิดการเซฟอัตโนมัติรายคลิก
	return StatRegistry.spend_point(self, stat_key)

func confirm_stat_allocation(pending_stats: Dictionary) -> int:
	var total_spent = 0
	for key in pending_stats.keys():
		total_spent += int(pending_stats[key])
	if total_spent <= 0 or stat_points < total_spent:
		return -1
		
	for key in pending_stats.keys():
		var count = int(pending_stats[key])
		if count > 0 and StatRegistry.PRIMARY.has(key):
			var field: String = StatRegistry.PRIMARY[key]
			set(field, int(get(field)) + count)
			if key == "vit":
				StatRegistry.recalculate_max_hp(self)
			stat_points -= count
			
	stats_changed.emit()

	if OnlineSession.is_logged_in():
		return DatabaseManager.save_game_data(self)
	return 0

func get_stat(stat_key: String) -> int:
	return StatRegistry.get_primary(self, stat_key)

func add_zeny(amount: int) -> void:
	if amount <= 0:
		return
	zeny += amount
	stats_changed.emit()

func spend_zeny(amount: int) -> bool:
	if amount <= 0 or zeny < amount:
		return false
	zeny -= amount
	stats_changed.emit()
	return true

func can_fit_item(item_id: String, count: int = 1) -> bool:
	var def := ItemDatabase.get_item(item_id)
	if def.is_empty():
		return false
	if def.get("stackable", false):
		for item in inventory:
			if item != null and item.get("id", "") == item_id:
				return true
		return inventory.find(null) != -1
	for _i in range(count):
		if inventory.find(null) == -1:
			return false
	return true

func grant_item(item_id: String, count: int = 1) -> bool:
	var def := ItemDatabase.get_item(item_id)
	if def.is_empty() or count <= 0:
		return false
	var to_add := def.duplicate()
	to_add["count"] = count
	return add_item_to_inventory(to_add)

func remove_item_at(inv_index: int, count: int = 1) -> Dictionary:
	if inv_index < 0 or inv_index >= inventory.size():
		return {}
	var item: Variant = inventory[inv_index]
	if item == null:
		return {}
	var have: int = int(item.get("count", 1))
	var remove_count := mini(count, have)
	var removed = item.duplicate()
	removed["count"] = remove_count
	if remove_count >= have:
		inventory[inv_index] = null
	else:
		item["count"] = have - remove_count
	inventory_changed.emit()
	return removed

# --- Inventory ---

func add_item_to_inventory(newItem: Dictionary) -> bool:
	var item_type = newItem.get("type", "")
	var item_id: String = str(newItem.get("id", ""))
	var is_equipment = item_type in ["weapon", "helm", "armor", "garment", "shield", "boots", "acc1", "acc2"]
	var stackable: bool = bool(newItem.get("stackable", item_type == "consumable"))
	
	if stackable and item_id != "":
		for i in range(inventory.size()):
			if inventory[i] != null and inventory[i].get("id", "") == item_id:
				inventory[i]["count"] += newItem.get("count", 1)
				inventory_changed.emit()
				return true
	elif not is_equipment and item_id == "":
		for i in range(inventory.size()):
			if inventory[i] != null and inventory[i].name == newItem.name:
				inventory[i]["count"] += newItem.get("count", 1)
				inventory_changed.emit()
				return true

	for i in range(inventory.size()):
		if inventory[i] == null:
			var item_to_add = newItem.duplicate()
			if item_to_add.get("id", "") == "":
				item_to_add["id"] = ItemDatabase.resolve_item_id(item_to_add)
			if is_equipment:
				item_to_add.count = 1
			inventory[i] = item_to_add
			inventory_changed.emit()
			return true
			
	return false

func use_item_from_inventory(inv_index: int) -> bool:
	var result := ConsumableService.use_from_inventory(self, inv_index)
	return bool(result.get("ok", false))


func use_item_from_inventory_verbose(inv_index: int) -> Dictionary:
	return ConsumableService.use_from_inventory(self, inv_index)


func equip_item_from_inventory(inv_index: int) -> bool:
	if is_dead or inv_index < 0 or inv_index >= inventory.size():
		return false

	var item = inventory[inv_index]
	if not item or not item.has("type"):
		return false

	var item_type = item.type
	if item_type == "consumable":
		var result := ConsumableService.use_from_inventory(self, inv_index)
		return bool(result.get("ok", false))

	if equipment.has(item_type):
		var current_equipped = equipment[item_type]
		equipment[item_type] = item
		inventory[inv_index] = current_equipped

		inventory_changed.emit()
		equipment_changed.emit()
		return true

	return false

func equip_inventory_to_slot(inv_index: int, slot_key: String) -> bool:
	if is_dead or inv_index < 0 or inv_index >= inventory.size():
		return false
	var item = inventory[inv_index]
	if item == null or str(item.get("type", "")) != slot_key:
		return false
	if not equipment.has(slot_key):
		return false
	var prev = equipment[slot_key]
	equipment[slot_key] = item
	inventory[inv_index] = prev
	inventory_changed.emit()
	equipment_changed.emit()
	return true


func move_equipment_to_inventory(slot_key: String, inv_index: int) -> bool:
	if is_dead or not equipment.has(slot_key) or inv_index < 0 or inv_index >= inventory.size():
		return false
	var equipped = equipment[slot_key]
	if equipped == null:
		return false
	var target = inventory[inv_index]
	if target == null:
		inventory[inv_index] = equipped
		equipment[slot_key] = null
	elif str(target.get("type", "")) == slot_key:
		equipment[slot_key] = target
		inventory[inv_index] = equipped
	else:
		return false
	inventory_changed.emit()
	equipment_changed.emit()
	return true


func swap_inventory_slots(a: int, b: int) -> bool:
	if a == b or a < 0 or b < 0 or a >= inventory.size() or b >= inventory.size():
		return false
	var tmp = inventory[a]
	inventory[a] = inventory[b]
	inventory[b] = tmp
	inventory_changed.emit()
	return true


func swap_equipment_slots(a: String, b: String) -> bool:
	if is_dead or a == b or not equipment.has(a) or not equipment.has(b):
		return false
	var item_a = equipment[a]
	if item_a == null or str(item_a.get("type", "")) != b:
		return false
	var item_b = equipment[b]
	if item_b != null and str(item_b.get("type", "")) != a:
		return false
	equipment[a] = item_b
	equipment[b] = item_a
	inventory_changed.emit()
	equipment_changed.emit()
	return true


func unequip_item(slot_key: String) -> bool:
	if is_dead or not equipment.has(slot_key) or equipment[slot_key] == null:
		return false
	
	var empty_slot_idx = inventory.find(null)
			
	if empty_slot_idx == -1:
		return false
		
	inventory[empty_slot_idx] = equipment[slot_key]
	equipment[slot_key] = null
	
	inventory_changed.emit()
	equipment_changed.emit()
	return true

func trigger_attack_animation(target_pos: Vector2 = Vector2.ZERO) -> void:
	if is_dead or is_attacking or is_hurt or is_talking:
		return
	
	is_attacking = true
	has_dealt_damage = false
	
	if target_pos != Vector2.ZERO:
		if target_pos.x < global_position.x:
			direction = "left"
			sprite.flip_h = true
		elif target_pos.x > global_position.x:
			direction = "right"
			sprite.flip_h = false
			
	var aspd_rate = get_attack_speed() 
	var attack_duration_calc = 1.0 / aspd_rate
	attack_duration_calc = clampf(attack_duration_calc, 0.15, 1.0) 
	
	if _has_sprite_anim("attack"):
		var base_duration = 0.4
		sprite.speed_scale = base_duration / attack_duration_calc
		sprite.play("attack")
		
		if not sprite.frame_changed.is_connected(_on_player_animation_frame_changed):
			sprite.frame_changed.connect(_on_player_animation_frame_changed)
			
		if not sprite.animation_finished.is_connected(_on_player_attack_finished):
			sprite.animation_finished.connect(_on_player_attack_finished)

func _on_player_animation_frame_changed() -> void:
	if not is_attacking or sprite.animation != "attack" or has_dealt_damage:
		return
	if sprite.frame == _attack_hit_frame:
		has_dealt_damage = true
		execute_melee_hit()

func _on_player_attack_finished() -> void:
	if sprite.animation == "attack":
		if not has_dealt_damage:
			execute_melee_hit()
		is_attacking = false
		sprite.speed_scale = 1.0
		_disconnect_attack_signals()
		
		if not is_dead:
			_play_movement_animation(velocity.length_squared() > 0.01)

func _disconnect_attack_signals() -> void:
	if sprite.frame_changed.is_connected(_on_player_animation_frame_changed):
		sprite.frame_changed.disconnect(_on_player_animation_frame_changed)
	if sprite.animation_finished.is_connected(_on_player_attack_finished):
		sprite.animation_finished.disconnect(_on_player_attack_finished)

func execute_melee_hit() -> void:
	if pending_attack_target and is_instance_valid(pending_attack_target):
		if pending_attack_target.has_method("take_damage"):
			pending_attack_target.take_damage(pending_attack_damage)
			var world := get_tree().get_first_node_in_group("world")
			if world and world.has_method("spawn_damage_text"):
				world.spawn_damage_text(pending_attack_target.global_position, pending_attack_damage, pending_attack_crit)
			if world and world.has_method("flash_hit"):
				world.flash_hit()
		pending_attack_target = null
		has_dealt_damage = true
		return

	var hit_radius := GameConstants.MELEE_HIT_REACH
	var forward_offset = Vector2.ZERO
	
	match direction:
		"down": forward_offset = Vector2(0, hit_radius)
		"up": forward_offset = Vector2(0, -hit_radius)
		"left": forward_offset = Vector2(-hit_radius, 0)
		"right": forward_offset = Vector2(hit_radius, 0)
		
	var check_pos = global_position + forward_offset
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsShapeQueryParameters2D.new()
	
	var shape = CircleShape2D.new()
	shape.radius = hit_radius
	query.shape = shape
	query.transform = Transform2D(0, check_pos)
	query.collision_mask = 2 
	
	var results = space_state.intersect_shape(query)
	for result in results:
		var collider = result.collider
		if collider and collider.is_in_group("monsters") and collider.has_method("take_damage"):
			var dmg = get_attack_damage()
			collider.take_damage(dmg)
			
			var world := get_tree().get_first_node_in_group("world")
			if world and world.has_method("flash_hit"):
				world.flash_hit()
			print("⚔️ ฟันโดนเป้าหมาย สร้างดาเมจ: ", dmg)

# --- Movement ---

const DIAGONAL_BLEND := 0.45


func _resolve_move_direction(move_vec: Vector2) -> String:
	var ax := absf(move_vec.x)
	var ay := absf(move_vec.y)
	if ax < 0.01 and ay < 0.01:
		return direction
	if ax > 0.01 and ay > 0.01 and minf(ax, ay) / maxf(ax, ay) >= DIAGONAL_BLEND:
		if move_vec.x > 0.0 and move_vec.y > 0.0:
			return "down_right"
		if move_vec.x < 0.0 and move_vec.y > 0.0:
			return "down_left"
		if move_vec.x > 0.0 and move_vec.y < 0.0:
			return "up_right"
		return "up_left"
	if ax > ay:
		return "right" if move_vec.x > 0.0 else "left"
	return "down" if move_vec.y > 0.0 else "up"


func apply_velocity(vx: float, vy: float) -> void:
	if is_dead or is_attacking or is_hurt or is_talking:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	var move_vec := Vector2(vx, vy)
	if move_vec.length() > 0.0:
		move_vec = move_vec.normalized()
		velocity = move_vec * get_movement_speed()
		
		direction = _resolve_move_direction(move_vec)
		
		# 🌟 1. เก็บพิกัดก่อนเดิน
		var pos_before := global_position
		
		# 🌟 2. เดินจริง และล็อกขอบจอ
		move_and_slide()
		global_position.x = clampf(global_position.x, 8, GameConstants.MAP_WORLD_WIDTH - 8)
		global_position.y = clampf(global_position.y, 8, GameConstants.MAP_WORLD_HEIGHT - 8)
		
		# 🌟 3. เช็กว่าตัวละครขยับจริงไหม? (ถ้าไม่ขยับแปลว่าชนขอบ/กำแพง)
		if global_position.distance_squared_to(pos_before) < 0.01:
			if is_moving:
				is_moving = false
				sprite.stop()
				_play_movement_animation(false)
				sprite.frame = 0
		else:
			is_moving = true
			_play_movement_animation(true)
	else:
		velocity = Vector2.ZERO
		move_and_slide()
		global_position.x = clampf(global_position.x, 8, GameConstants.MAP_WORLD_WIDTH - 8)
		global_position.y = clampf(global_position.y, 8, GameConstants.MAP_WORLD_HEIGHT - 8)
		
		if is_moving:
			is_moving = false
			sprite.stop()
			_play_movement_animation(false)
			sprite.frame = 0

func _flash_level_up() -> void:
	var flash := camera.get_node_or_null("FlashOverlay")
	if flash:
		flash.do_flash(Color(1, 0.84, 0, 0.6), 0.3)

func _on_realtime_channel_joined() -> void:
	_sync_presence_now()


func _sync_presence_now() -> void:
	if OnlineSession.is_online():
		OnlinePresenceManager.sync_local_player(self)

func _process(delta: float) -> void:
	_auto_potion.tick(self, delta)
	_presence_timer += delta
	
	var sync_interval := 0.3 if is_moving else 2.0
	
	if _presence_timer >= sync_interval and OnlineSession.is_online():
		_presence_timer = 0.0
		_sync_presence_now()
			
	if camera:
		camera.offset = Vector2.ZERO
		camera.global_position = global_position.round()


func get_skill_level(skill_id: String) -> int:
	return int(skill_levels.get(skill_id, 0))


func upgrade_skill(skill_id: String) -> bool:
	var def := SkillDatabase.get_skill(skill_id)
	if def.is_empty() or job_points <= 0:
		return false
	if not SkillDatabase.is_unlocked(self, skill_id):
		return false
	var cur := get_skill_level(skill_id)
	var max_lv := int(def.get("max_level", 5))
	if cur >= max_lv:
		return false
	skill_levels[skill_id] = cur + 1 if cur > 0 else 1
	job_points -= 1
	return true


func cast_first_aid() -> void:
	if is_dead:
		return
		
	var skill_data = SkillDatabase.get_skill("first_aid")
	if skill_data.is_empty():
		return
		
	if sp < skill_data["sp_cost"]:
		var ui := UiAccess.get_ui(self)
		if ui and ui.has_method("add_log"):
			ui.add_log("SP ไม่พอสำหรับ First Aid!", Color8(0xe7, 0x4c, 0x3c))
		return
		
	sp -= skill_data["sp_cost"]
	hp = mini(max_hp, hp + skill_data["hp_restore"])
	stats_changed.emit()
	
	var world := get_tree().get_first_node_in_group("world")
	if world and world.has_method("spawn_damage_text"):
		world.spawn_damage_text(global_position, skill_data["hp_restore"], false, Color8(0x2e, 0xcc, 0x71))

func show_chat_balloon(text: String) -> void:
	if has_node("ChatBalloon"):
		get_node("ChatBalloon").queue_free()

	var balloon = Node2D.new()
	balloon.name = "ChatBalloon"
	balloon.z_index = 100
	
	# 🌟 1. ลดสเกลลงเหลือ 0.125 (เล็กลงอีกครึ่งนึงจากรอบที่แล้ว)
	balloon.scale = Vector2(0.125, 0.125) 
	add_child(balloon)

	# 🌟 2. ขยับลงมาใกล้ตัวมากขึ้น (-140 พอโดนย่อ 0.125 จะลอยอยู่เหนือจุดกึ่งกลางตัวละครแค่ ~17 พิกเซล)
	var control = Control.new()
	control.position = Vector2(0, -140)
	balloon.add_child(control)

	var panel = PanelContainer.new()
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN 
	panel.position = Vector2.ZERO 

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.12, 0.85) 
	style.border_color = Color8(0x7f, 0x8c, 0x8d)
	
	# ชดเชยความหนาของเส้นต่างๆ ให้สัมพันธ์กับสเกลที่เล็กลงมาก
	style.set_border_width_all(8) 
	style.corner_radius_top_left = 16
	style.corner_radius_top_right = 16
	style.corner_radius_bottom_left = 16
	style.corner_radius_bottom_right = 16
	style.content_margin_left = 24
	style.content_margin_right = 24
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", style)

	var label = Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	# 🌟 3. ปรับฟอนต์ให้สมดุล (พอแสดงผลจริงจะเล็กและเนียนตามาก)
	label.add_theme_font_size_override("font_size", 40)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	label.add_theme_constant_override("outline_size", 8)
	
	# ใช้โหมดลบเหลี่ยมให้ตัวอักษรไม่แตกเป็นเม็ดพิกเซล
	label.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR

	panel.add_child(label)
	control.add_child(panel)

	balloon.modulate.a = 0.0
	balloon.position.y = 8
	var tween = create_tween().set_parallel(true)
	tween.tween_property(balloon, "modulate:a", 1.0, 0.15)
	tween.tween_property(balloon, "position:y", 0.0, 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	var fade = create_tween()
	fade.tween_property(balloon, "modulate:a", 0.0, 0.3).set_delay(4.0)
	fade.tween_callback(balloon.queue_free)

# --- Quest System ---

var active_quests: Dictionary = {}   # เก็บเควสที่กำลังทำ { "quest_id": {"progress": 0, "completed": false} }
var finished_quests: Array[String] = [] # เควสที่ทำสำเร็จแล้ว

func accept_quest(quest_id: String) -> bool:
	if active_quests.has(quest_id) or quest_id in finished_quests:
		return false
	var def := QuestDatabase.get_quest(quest_id)
	if def.is_empty():
		return false
		
	active_quests[quest_id] = {
		"progress": 0,
		"completed": false
	}
	
	var ui := UiAccess.get_ui(self)
	if ui and ui.has_method("show_notification"):
		ui.show_notification("รับเควสใหม่: %s" % def.get("title", ""), Color8(0x34, 0x98, 0xdb))
	if ui and ui.has_method("add_log"):
		ui.add_log("รับเควส: %s" % def.get("title", ""), Color8(0x34, 0x98, 0xdb))
	quests_changed.emit()
	if ui and ui.has_method("refresh_quest_log"):
		ui.refresh_quest_log()
	return true

func update_quest_progress(objective_type: String, target_id: String, amount: int = 1) -> void:
	for q_id in active_quests.keys():
		var q_data: Dictionary = active_quests[q_id]
		if q_data.get("completed", false):
			continue
			
		var def := QuestDatabase.get_quest(q_id)
		if def.get("objective_type", "") == objective_type and def.get("target_id", "") == target_id:
			var current := int(q_data.get("progress", 0))
			var target := int(def.get("target_count", 1))
			current = mini(target, current + amount)
			q_data["progress"] = current
			
			var ui := UiAccess.get_ui(self)
			if ui and ui.has_method("add_log"):
				ui.add_log("ความคืบหน้าเควส [%s]: %d/%d" % [def.get("title", ""), current, target], Color8(0xf1, 0xc4, 0x0f))
				
			if current >= target:
				q_data["completed"] = true
				if ui and ui.has_method("show_notification"):
					ui.show_notification("เควสสำเร็จ! กลับไปส่งเควสได้เลย", Color8(0x2e, 0xcc, 0x71))
			quests_changed.emit()
			if ui and ui.has_method("refresh_quest_log"):
				ui.refresh_quest_log()
  
func turn_in_quest(quest_id: String) -> bool:
	if not active_quests.has(quest_id):
		return false
	var q_data: Dictionary = active_quests[quest_id]
	if not q_data.get("completed", false):
		return false
		
	var def := QuestDatabase.get_quest(quest_id)
	if def.is_empty():
		return false
		
	# แจกรางวัล
	add_exp(int(def.get("reward_exp", 0)))
	if has_method("_add_job_exp"):
		_add_job_exp(int(def.get("reward_job_exp", 0)))
	add_zeny(int(def.get("reward_zeny", 0)))
	
	active_quests.erase(quest_id)
	finished_quests.append(quest_id)
	
	var ui := UiAccess.get_ui(self)
	if ui and ui.has_method("show_notification"):
		ui.show_notification("ส่งเควสสำเร็จ รับรางวัลเรียบร้อย!", Color8(0x2e, 0xcc, 0x71))
	if ui and ui.has_method("add_log"):
		ui.add_log("ส่งเควส: %s (%s)" % [def.get("title", ""), QuestDatabase.get_reward_summary(quest_id)], Color8(0x2e, 0xcc, 0x71))
	quests_changed.emit()
	if ui and ui.has_method("refresh_quest_log"):
		ui.refresh_quest_log()
	return true

func set_auto_mode(enabled: bool) -> void:
	is_auto_mode = enabled
	var ui := UiAccess.get_ui(self)
	if ui and ui.has_method("show_notification"):
		if is_auto_mode:
			ui.show_notification("Auto-Battle: ON", Color8(0x2e, 0xcc, 0x71))
		else:
			ui.show_notification("Auto-Battle: OFF", Color8(0xe7, 0x4c, 0x3c))

func set_auto_flee_boss(enabled: bool) -> void:
	auto_flee_boss = enabled


func set_auto_potion_enabled(enabled: bool) -> void:
	auto_potion_enabled = enabled
	_auto_potion.enabled = enabled
	var ui := UiAccess.get_ui(self)
	if ui and ui.has_method("show_notification"):
		if enabled:
			ui.show_notification("Auto Potion: ON", Color8(0x2e, 0xcc, 0x71))
		else:
			ui.show_notification("Auto Potion: OFF", Color8(0xe7, 0x4c, 0x3c))


func set_auto_potion_hp_pct(pct: float) -> void:
	auto_potion_hp_pct = clampf(pct, 0.05, 0.95)
	_auto_potion.hp_threshold = auto_potion_hp_pct


func set_auto_potion_sp_pct(pct: float) -> void:
	auto_potion_sp_pct = clampf(pct, 0.05, 0.95)
	_auto_potion.sp_threshold = auto_potion_sp_pct
