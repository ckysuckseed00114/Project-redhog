class_name big_monster
extends CharacterBody2D

signal died(monster)

@export var monster_id: String = "big_poring"
var sync_id: String = ""
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@export var is_aggressive: bool = true 

var is_provoked: bool = true          
var max_hp: float = 100.0
var hp: float = 100.0
var speed: float = 50.0
var attack_range: float = 48.0
var attack_cooldown: float = 1.0

var chase_range: float = 120.0        
var chase_range_sq: float = 14400.0   
var attack_range_sq: float = 1600.0   

var home_position: Vector2 = Vector2.ZERO
var max_leash_range: float = 250.0    
var max_leash_sq: float = 62500.0     
var is_returning: bool = false        

var is_active_monster: bool = true 
var last_hit_time: float = 0.0
var is_selected: bool = false

var click_area: Area2D
var _hit_center_local := Vector2.ZERO
var _sync_mute: bool = false
var _facing_dir := Vector2.DOWN

func _ready() -> void:
	add_to_group("monsters")
	add_to_group("boss")
	
	home_position = global_position 
	
	var data = MonsterDB.get_monster(monster_id)
	if not data.is_empty():
		max_hp = data.get("max_hp", 100)
		hp = max_hp
		speed = data.get("speed", 50.0)
		attack_range = data.get("attack_range", 48.0)
		attack_cooldown = data.get("attack_cooldown", 1.0)
		var visual := MonsterDB.apply_sprite_visual(animated_sprite, data)
		if animated_sprite:
			animated_sprite.visible = true
		_setup_click_area(visual.get("click_radius", 28.0))

	chase_range_sq = chase_range * chase_range
	attack_range_sq = attack_range * attack_range

	collision_layer = 2
	collision_mask = 0

	_hit_center_local = _get_sprite_local_center()
	var body_data := MonsterDB.get_monster(monster_id)
	var body_visual := MonsterDB.resolve_visual(body_data)
	var b_radius: float = body_visual.get("body_radius", 16.0)

	var data_col := get_node_or_null("CollisionShape2D")
	if data_col:
		if data_col.shape is CircleShape2D:
			data_col.shape.radius = b_radius
		data_col.position = _hit_center_local

	call_deferred("_refresh_hitboxes")


func _refresh_hitboxes() -> void:
	var body_data := MonsterDB.get_monster(monster_id)
	var visual := MonsterDB.resolve_visual(body_data)
	var b_radius: float = visual.get("body_radius", 16.0)
	var c_radius: float = visual.get("click_radius", 40.0)
	_hit_center_local = _get_sprite_local_center()

	var data_col := get_node_or_null("CollisionShape2D")
	if data_col:
		if data_col.shape is CircleShape2D:
			data_col.shape.radius = b_radius
		data_col.position = _hit_center_local

	if click_area:
		click_area.position = _hit_center_local
		var click_col = click_area.get_node_or_null("CollisionShape2D")
		if click_col and click_col.shape is CircleShape2D:
			click_col.shape.radius = c_radius


func _get_sprite_local_center() -> Vector2:
	if not is_instance_valid(animated_sprite):
		return Vector2.ZERO
	var tex: Texture2D = null
	if animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation(animated_sprite.animation):
		tex = animated_sprite.sprite_frames.get_frame_texture(animated_sprite.animation, animated_sprite.frame)
	if tex == null:
		return animated_sprite.position
	var frame_size := tex.get_size() * animated_sprite.scale
	if animated_sprite.centered:
		return animated_sprite.position
	return animated_sprite.position + frame_size * 0.5


func get_hit_center() -> Vector2:
	return global_position + _hit_center_local


func _setup_click_area(c_radius: float) -> void:
	click_area = Area2D.new()
	click_area.name = "ClickArea"
	click_area.collision_layer = GameConstants.MONSTER_CLICK_LAYER
	click_area.collision_mask = 0
	click_area.input_pickable = true
	click_area.position = _hit_center_local
	add_child(click_area)

	var click_col := CollisionShape2D.new()
	var click_shape := CircleShape2D.new()
	click_shape.radius = c_radius
	click_col.shape = click_shape
	click_area.add_child(click_col)
	click_area.input_event.connect(_on_click_area_input)


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

func update_ai(_delta: float, player: Node2D, player_pos: Vector2, time_sec: float) -> void:
	if not player or not is_active_monster:
		return
	
	var my_pos := get_hit_center()
	var dist_to_player_sq := my_pos.distance_squared_to(player_pos)
	var dist_to_home_sq := global_position.distance_squared_to(home_position)
	
	if is_returning:
		if dist_to_home_sq < 100.0:
			is_returning = false
			velocity = Vector2.ZERO
			MonsterSpriteLoader.play_facing(animated_sprite, _facing_dir)
		else:
			var dir := (home_position - global_position).normalized()
			velocity = dir * speed
			move_and_slide()
			_facing_dir = dir
			MonsterSpriteLoader.play_facing(animated_sprite, _facing_dir)
		return

	if dist_to_home_sq > max_leash_sq:
		is_returning = true
		hp = max_hp
		return

	if dist_to_player_sq <= chase_range_sq and dist_to_player_sq > attack_range_sq:
		var dir := (player_pos - my_pos).normalized()
		velocity = dir * speed
		move_and_slide()
		_facing_dir = dir
		MonsterSpriteLoader.play_facing(animated_sprite, _facing_dir)
				
	elif dist_to_player_sq <= attack_range_sq:
		velocity = Vector2.ZERO
		_facing_dir = player_pos - my_pos
		MonsterSpriteLoader.play_facing(animated_sprite, _facing_dir)
			
		if time_sec - last_hit_time >= attack_cooldown:
			last_hit_time = time_sec
			if player.has_method("take_damage"):
				player.take_damage(10)
				
	else:
		velocity = Vector2.ZERO
		MonsterSpriteLoader.play_facing(animated_sprite, _facing_dir)

func take_damage(amount: float) -> void:
	if not is_active_monster:
		return
	hp -= amount
	is_returning = false 
	
	if hp <= 0:
		is_active_monster = false
		set_selected(false)
		
		set_physics_process(false)
		var col = get_node_or_null("CollisionShape2D")
		if col:
			col.set_deferred("disabled", true)
			
		# 🌟 แก้ไขตรงนี้: ประกาศและเช็กตัวแปร click_col ให้ถูกต้องใน Scope เดียวกัน
		if click_area:
			var click_col = click_area.get_node_or_null("CollisionShape2D")
			if click_col:
				click_col.set_deferred("disabled", true)
		
		emit_signal("died", self)
	elif not _sync_mute:
		var world := get_tree().get_first_node_in_group("world")
		if world and world.has_method("notify_boss_hp"):
			world.notify_boss_hp(hp)
			
func apply_sync_hp(new_hp: float) -> void:
	if not is_active_monster:
		return
	_sync_mute = true
	hp = new_hp
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
	set_selected(false)
	set_physics_process(false)
	var col = get_node_or_null("CollisionShape2D")
	if col:
		col.set_deferred("disabled", true)
	if click_area:
		var click_col = click_area.get_node_or_null("CollisionShape2D")
		if click_col:
			click_col.set_deferred("disabled", true)

func respawn(pos: Vector2) -> void:
	global_position = pos
	home_position = pos
	hp = max_hp
	is_active_monster = true
	is_returning = false
	visible = true
	
	set_physics_process(true)
	var col = get_node_or_null("CollisionShape2D")
	if col:
		col.disabled = false
	if click_area:
		var click_col = click_area.get_node_or_null("CollisionShape2D")
		if click_col:
			click_col.disabled = false
	
	if animated_sprite and animated_sprite.sprite_frames.has_animation("walk_down"):
		animated_sprite.play("walk_down")
	_facing_dir = Vector2.DOWN

func set_selected(p_selected: bool) -> void:
	if is_selected != p_selected:
		is_selected = p_selected
		queue_redraw()

func _draw() -> void:
	if is_selected and is_active_monster:
		draw_arc(_hit_center_local, 16, 0, TAU, 32, Color8(0xe7, 0x4c, 0x3c, 255), 2.0)
