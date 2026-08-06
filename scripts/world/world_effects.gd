extends Node2D

var _player: Player
var _move_target: Variant

func setup(player: Player) -> void:
	_player = player


func update_effects(_target: Variant, move_target: Variant) -> void:
	_move_target = move_target
	set_process(move_target != null)
	queue_redraw()


func _process(_delta: float) -> void:
	if _move_target != null:
		queue_redraw()


func _draw() -> void:
	if not _player:
		return

	if _move_target != null:
		_draw_move_arrow(_move_target)


func _draw_move_arrow(target: Vector2) -> void:
	var player_pos := _player.global_position
	var angle := player_pos.angle_to_point(target)
	
	var time = Time.get_ticks_msec() / 1000.0
	var radius := 16.0 + sin(time * 15.0) * 3.0 
	
	var cx := player_pos.x + cos(angle) * radius
	var cy := player_pos.y + sin(angle) * radius
	var head_size := 5.0

	var tip := Vector2(cx + cos(angle) * head_size, cy + sin(angle) * head_size)
	var back := Vector2(cx - cos(angle) * head_size, cy - sin(angle) * head_size)
	var left_angle := angle + PI / 2.0
	var right_angle := angle - PI / 2.0
	var left := back + Vector2(cos(left_angle), sin(left_angle)) * head_size
	var right := back + Vector2(cos(right_angle), sin(right_angle)) * head_size

	draw_colored_polygon([tip, left, right], Color8(0x34, 0x98, 0xdb, 255))
	draw_polyline([tip, left, right, tip], Color8(0xff, 0xff, 0xff, 255), 1.0)
