class_name Monster
extends CharacterBody2D

signal died(monster: Monster)

@export var monster_id: String = "poring"
@export var sync_id: String = ""
@export var is_aggressive: bool = false

var speed: float = 14.0
var chase_range: float = 100.0
var attack_range: float = GameConstants.MONSTER_MELEE_RANGE_DEFAULT
var attack_cooldown: float = 1.5
var is_provoked: bool = false
var chase_range_sq: float = 10000.0
var attack_range_sq: float = 400.0

var max_hp: int = 6
var hp: int = 6
var wander_timer: float = 0.0
var wander_dir: Vector2 = Vector2.ZERO
var last_hit_time: float = 0.0
var is_active_monster: bool = true
var is_selected: bool = false
var is_stunned: bool = false
var stun_end_time: float = 0.0
var _sync_mute: bool = false

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var hp_bar: Node2D = $HpBar
@onready var click_area: Area2D = $ClickArea

var _hit_center_local := Vector2.ZERO
var _facing_dir := Vector2.DOWN


func _ready() -> void:
	add_to_group("monsters")
	hp_bar.visible = false

	var data = MonsterDB.get_monster(monster_id)
	if not data.is_empty():
		max_hp = data.get("max_hp", 6)
		hp = max_hp
		speed = data.get("speed", 14.0)
		chase_range = data.get("chase_range", 100.0)
		attack_range = data.get("attack_range", GameConstants.MONSTER_MELEE_RANGE_DEFAULT)
		attack_cooldown = data.get("attack_cooldown", 1.5)
		var visual := MonsterDB.apply_sprite_visual(sprite, data)
		_setup_collision(visual.get("body_radius", 8.0), visual.get("click_radius", 32.0))
		
	chase_range_sq = chase_range * chase_range
	attack_range_sq = attack_range * attack_range
		
	if sprite.sprite_frames and sprite.sprite_frames.has_animation("walk_down"):
		sprite.play("walk_down")
		
	_reset_wander()
	set_process(false)
	call_deferred("_refresh_hitboxes")


func _update_facing_sprite(dir: Vector2) -> void:
	if dir.length_squared() > 0.0001:
		_facing_dir = dir.normalized()
	MonsterSpriteLoader.play_facing(sprite, _facing_dir)


func _refresh_hitboxes() -> void:
	var data := MonsterDB.get_monster(monster_id)
	if data.is_empty():
		return
	var visual := MonsterDB.resolve_visual(data)
	_setup_collision(visual.get("body_radius", 8.0), visual.get("click_radius", 32.0))


func _setup_collision(b_radius: float, c_radius: float) -> void:
	_hit_center_local = _get_sprite_local_center()

	var body_shape := CircleShape2D.new()
	body_shape.radius = b_radius
	var body_col: CollisionShape2D = $CollisionShape2D
	body_col.shape = body_shape
	body_col.position = _hit_center_local
	
	collision_layer = 2
	collision_mask = 0

	click_area.collision_layer = GameConstants.MONSTER_CLICK_LAYER
	click_area.collision_mask = 0
	click_area.input_pickable = true
	click_area.position = _hit_center_local
	if not click_area.input_event.is_connected(_on_click_area_input):
		click_area.input_event.connect(_on_click_area_input)

	var click_col = click_area.get_node_or_null("CollisionShape2D")
	if click_col:
		var click_shape := CircleShape2D.new()
		click_shape.radius = c_radius
		click_col.shape = click_shape


func _get_sprite_local_center() -> Vector2:
	if not is_instance_valid(sprite):
		return Vector2.ZERO
	var tex: Texture2D = null
	if sprite.sprite_frames and sprite.sprite_frames.has_animation(sprite.animation):
		tex = sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
	if tex == null:
		return sprite.position
	var frame_size := tex.get_size() * sprite.scale
	if sprite.centered:
		return sprite.position
	return sprite.position + frame_size * 0.5


func get_hit_center() -> Vector2:
	return global_position + _hit_center_local


func _on_click_area_input(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if not is_active_monster:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var world := get_tree().get_first_node_in_group("world")
		if world and world.has_method("select_monster"):
			world.select_monster(self)
			if world.has_method("try_attack_selected"):
				world.try_attack_selected()
			get_viewport().set_input_as_handled()


func _reset_wander() -> void:
	wander_timer = randf_range(1.5, 4.0)
	wander_dir = Vector2.from_angle(randf() * TAU)

func take_damage(amount: int) -> void:
	if not is_active_monster:
		return
		
	hp -= amount
	print("💥 มอนสเตอร์โดนโจมตี! เลือดเหลือ: ", hp)

	is_provoked = true

	sprite.modulate = Color(2.5, 2.5, 2.5, 1)
	var tween = create_tween()
	tween.tween_property(sprite, "modulate", Color(1, 1, 1, 1), 0.15)

	if hp_bar.visible:
		hp_bar.queue_redraw()
		
	apply_hit_stun(0.25)

	if hp <= 0:
		_die()
	elif not _sync_mute and sync_id != "":
		var world := get_tree().get_first_node_in_group("world")
		if world and world.has_method("notify_mob_hp"):
			world.notify_mob_hp(sync_id, hp)


func apply_sync_hp(new_hp: int) -> void:
	if not is_active_monster:
		return
	_sync_mute = true
	hp = new_hp
	if hp_bar.visible:
		hp_bar.queue_redraw()
	if hp <= 0:
		_apply_sync_death_visual()
	_sync_mute = false


func apply_sync_kill() -> void:
	if not is_active_monster:
		return
	_sync_mute = true
	hp = 0
	_apply_sync_death_visual()
	_sync_mute = false


func _apply_sync_death_visual() -> void:
	is_active_monster = false
	visible = true
	velocity = Vector2.ZERO
	set_physics_process(false)
	set_selected(false)
	$CollisionShape2D.disabled = true
	var click_col = click_area.get_node_or_null("CollisionShape2D")
	if click_col:
		click_col.disabled = true
	hp_bar.visible = false

func apply_hit_stun(duration: float) -> void:
	is_stunned = true
	velocity = Vector2.ZERO
	
	var current_time = Time.get_ticks_msec() / 1000.0
	stun_end_time = max(stun_end_time, current_time + duration)

func _die() -> void:
	is_active_monster = false
	visible = true 
	velocity = Vector2.ZERO
	set_physics_process(false)
	set_selected(false)
	
	$CollisionShape2D.disabled = true
	var click_col = click_area.get_node_or_null("CollisionShape2D")
	if click_col:
		click_col.disabled = true
		
	hp_bar.visible = false
	
	died.emit(self)

func respawn(new_pos: Vector2) -> void:
	global_position = new_pos
	hp = max_hp
	is_active_monster = true
	is_provoked = false
	visible = true
	set_physics_process(true)
	
	$CollisionShape2D.disabled = false
	var click_col = click_area.get_node_or_null("CollisionShape2D")
	if click_col:
		click_col.disabled = false
		
	hp_bar.visible = false
	sprite.modulate = Color(1, 1, 1, 1)
	_facing_dir = Vector2.DOWN
	if sprite.sprite_frames and sprite.sprite_frames.has_animation("walk_down"):
		sprite.play("walk_down")

func set_selected(p_selected: bool) -> void:
	if is_selected != p_selected:
		is_selected = p_selected
		set_process(is_selected)
		queue_redraw()

func update_ai(delta: float, player: Node2D, player_pos: Vector2, time_sec: float) -> void:
	var current_time = Time.get_ticks_msec() / 1000.0
	is_stunned = current_time < stun_end_time

	if not is_active_monster or is_stunned:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	var my_pos := get_hit_center()
	var dist_sq := my_pos.distance_squared_to(player_pos)

	if (is_aggressive or is_provoked) and dist_sq < chase_range_sq:
		if dist_sq <= attack_range_sq:
			wander_dir = Vector2.ZERO
			_update_facing_sprite(player_pos - my_pos)

			if time_sec - last_hit_time >= attack_cooldown:
				last_hit_time = time_sec
				
				var base_monster_atk := randi_range(5, 9)
				var total_def = player.get_defense() if player.has_method("get_defense") else 0
				var incoming := maxi(1, base_monster_atk - total_def)
				
				player.take_damage(incoming)
		else:
			wander_dir = (player_pos - my_pos).normalized()
	else:
		if not is_aggressive:
			is_provoked = false
			
		wander_timer -= delta
		if wander_timer <= 0.0:
			_reset_wander()

	# 🌟 1. เก็บพิกัดก่อนเดิน (แก้จุดที่ตัวแปรหายไป)
	var pos_before := global_position

	velocity = wander_dir * speed
	move_and_slide()
	
	global_position.x = clampf(global_position.x, 20, GameConstants.MAP_WORLD_WIDTH - 20)
	global_position.y = clampf(global_position.y, 20, GameConstants.MAP_WORLD_HEIGHT - 20)

	# 🌟 2. เช็กว่าขยับจริงไหม
	var actually_moved := global_position.distance_squared_to(pos_before) > 0.01

	var face_dir := wander_dir
	if actually_moved and velocity.length_squared() > 0.01:
		face_dir = velocity
	elif face_dir.length_squared() < 0.0001 and player_pos != my_pos:
		face_dir = player_pos - my_pos
	_update_facing_sprite(face_dir)

	if not actually_moved:
		if not (is_aggressive or is_provoked) or dist_sq >= chase_range_sq:
			if wander_dir != Vector2.ZERO:
				_reset_wander()

func _process(_delta: float) -> void:
	if is_selected and is_active_monster:
		queue_redraw()

func _draw() -> void:
	if is_selected and is_active_monster:
		var time := Time.get_ticks_msec() / 1000.0
		var pulse_radius := 7.0 + sin(time * 6.0) * 1.5 
		var alpha := int(200 + sin(time * 6.0) * 55)
		draw_arc(_hit_center_local, pulse_radius, 0, TAU, 32, Color8(0xe7, 0x4c, 0x3c, alpha), 1.5)
