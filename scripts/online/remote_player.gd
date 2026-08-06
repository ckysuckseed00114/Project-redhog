class_name RemotePlayer
extends Node2D

var player_name: String = "Player"
var player_gender: String = "male"
var player_job: String = "novice"
var character_id: String = ""

var _sprite: AnimatedSprite2D
var _name_label: Label
var _target_pos: Vector2


func setup(char_id: String, p_name: String, gender: String, pos: Vector2, job: String = "novice") -> void:
	character_id = char_id
	player_name = p_name
	player_gender = gender
	player_job = job
	_target_pos = pos
	global_position = pos
	_build_visuals()


func update_state(p_name: String, gender: String, pos: Vector2, job: String = "") -> void:
	player_name = p_name
	player_gender = gender
	if job != "":
		player_job = job
		_apply_sprite_frames()
	_target_pos = pos
	if _name_label:
		_name_label.text = _format_name_label()


func _format_name_label() -> String:
	return "%s\n[%s]" % [player_name, ClassDatabase.get_display_name(player_job)]


func _build_visuals() -> void:
	_sprite = AnimatedSprite2D.new()
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.modulate = Color(0.85, 0.95, 1.0)
	add_child(_sprite)
	_apply_sprite_frames()

	_name_label = Label.new()
	_name_label.text = _format_name_label()
	_name_label.position = Vector2(-40, -52)
	_name_label.custom_minimum_size = Vector2(80, 28)
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UITheme.style_label(_name_label, GameConstants.FONT_XS, Color8(0x66, 0xcc, 0xff), 2)
	add_child(_name_label)


func _apply_sprite_frames() -> void:
	var frames := PlayerSpriteLoader.build_sprite_frames(player_job, player_gender)
	if frames.get_animation_names().is_empty():
		return
	_sprite.sprite_frames = frames
	_sprite.scale = PlayerSpriteLoader.get_sprite_scale(frames)
	if frames.has_animation("idle"):
		_sprite.play("idle")
		_sprite.stop()
		_sprite.frame = 0


func _process(delta: float) -> void:
	global_position = global_position.lerp(_target_pos, clampf(delta * 12.0, 0.0, 1.0))
	if _sprite == null or _sprite.sprite_frames == null:
		return
	if _target_pos.distance_squared_to(global_position) > 4.0:
		if _sprite.sprite_frames.has_animation("walking") and _sprite.animation != "walking":
			_sprite.play("walking")
		if _target_pos.x < global_position.x:
			_sprite.flip_h = true
		elif _target_pos.x > global_position.x:
			_sprite.flip_h = false
	elif _sprite.sprite_frames.has_animation("idle"):
		_sprite.play("idle")


func show_chat_balloon(text: String) -> void:
	if has_node("ChatBalloon"):
		get_node("ChatBalloon").queue_free()

	var balloon = Node2D.new()
	balloon.name = "ChatBalloon"
	balloon.z_index = 100
	balloon.scale = Vector2(0.125, 0.125)
	add_child(balloon)

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
	label.add_theme_font_size_override("font_size", 40)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	label.add_theme_constant_override("outline_size", 8)
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
