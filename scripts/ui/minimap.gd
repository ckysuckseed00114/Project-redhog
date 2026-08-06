class_name Minimap
extends Control

var world: Node2D
var player: Player
var circular: bool = true
var allow_click: bool = false
var player_centered: bool = false

var _update_timer: float = 0.0
var _pulse: float = 0.0

const COLOR_BOSS := Color(1.0, 0.45, 0.1)
const COLOR_MONSTER := Color(0.95, 0.26, 0.21)
const COLOR_PLAYER := Color(0.18, 0.8, 0.44)
const COLOR_PORTAL := Color(0.2, 0.6, 1.0)
const COLOR_TARGET := Color(1.0, 0.84, 0.0, 0.85)
const COLOR_NPC := Color(1.0, 0.84, 0.0)
const OFFSCREEN := Vector2(-99999.0, -99999.0)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP if allow_click else Control.MOUSE_FILTER_IGNORE
	z_index = 20
	_apply_size()


func configure(
	p_circular: bool,
	p_allow_click: bool,
	map_size: Vector2,
	p_player_centered: bool = false
) -> void:
	circular = p_circular
	allow_click = p_allow_click
	player_centered = p_player_centered
	custom_minimum_size = map_size
	size = map_size
	mouse_filter = Control.MOUSE_FILTER_STOP if allow_click else Control.MOUSE_FILTER_IGNORE
	_apply_size()


func setup(w: Node2D, p: Player) -> void:
	world = w
	player = p
	queue_redraw()


func _apply_size() -> void:
	if size.x <= 0 or size.y <= 0:
		var mini_size := float(GameConstants.MINIMAP_SIZE)
		custom_minimum_size = Vector2(mini_size, mini_size)
		size = Vector2(mini_size, mini_size)


func _process(delta: float) -> void:
	if not is_instance_valid(world):
		return

	if not is_instance_valid(player) and world.has_method("get_player"):
		player = world.get_player()

	_pulse += delta * 3.0
	_update_timer += delta
	if _update_timer >= 0.1:
		_update_timer = 0.0
		queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if not allow_click:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if is_instance_valid(world) and world.has_method("set_move_target_from_minimap"):
			var map_rect := _map_draw_rect()
			if map_rect.size.x <= 0 or map_rect.size.y <= 0:
				return
			var local_pos := get_local_mouse_position()
			if circular and not _is_inside_circle(local_pos):
				return
			local_pos.x = clampf(local_pos.x, map_rect.position.x, map_rect.end.x)
			local_pos.y = clampf(local_pos.y, map_rect.position.y, map_rect.end.y)
			var norm_x := (local_pos.x - map_rect.position.x) / map_rect.size.x
			var norm_y := (local_pos.y - map_rect.position.y) / map_rect.size.y
			world.set_move_target_from_minimap(
				norm_x * map_rect.size.x,
				norm_y * map_rect.size.y,
				map_rect.size.x,
				map_rect.size.y
			)
			queue_redraw()
			accept_event()


func _circle_center() -> Vector2:
	return size * 0.5


func _circle_radius() -> float:
	return minf(size.x, size.y) * 0.5 - 4.0


func _is_inside_circle(point: Vector2) -> bool:
	return point.distance_to(_circle_center()) <= _circle_radius()


func _map_draw_rect() -> Rect2:
	var rect_size := size
	if rect_size.x <= 0 or rect_size.y <= 0:
		rect_size = Vector2(GameConstants.MINIMAP_SIZE, GameConstants.MINIMAP_SIZE)
	if circular:
		var r := _circle_radius() - 2.0
		var center := _circle_center()
		return Rect2(center - Vector2(r, r), Vector2(r * 2.0, r * 2.0))
	return Rect2(Vector2(4, 4), rect_size - Vector2(8, 8))


func _view_span(world_w: float, world_h: float, map_rect: Rect2) -> Vector2:
	if player_centered:
		return Vector2(world_w * 0.38, world_h * 0.38)
	return map_rect.size


func _world_to_mini(world_pos: Vector2, map_rect: Rect2, world_w: float, world_h: float) -> Vector2:
	if player_centered and is_instance_valid(player):
		var center := _circle_center() if circular else map_rect.position + map_rect.size * 0.5
		var span := _view_span(world_w, world_h, map_rect)
		var m_scale_x := map_rect.size.x / span.x
		var m_scale_y := map_rect.size.y / span.y
		var offset := world_pos - player.global_position
		var m_mini_pos := center + Vector2(offset.x * m_scale_x, offset.y * m_scale_y)
		if circular and not _is_inside_circle(m_mini_pos):
			return OFFSCREEN
		if not circular:
			if not map_rect.has_point(m_mini_pos):
				return OFFSCREEN
		return m_mini_pos

	var scale_x := map_rect.size.x / world_w
	var scale_y := map_rect.size.y / world_h
	var mini_pos := map_rect.position + Vector2(world_pos.x * scale_x, world_pos.y * scale_y)
	if circular:
		mini_pos = _clamp_to_circle(mini_pos)
	else:
		mini_pos.x = clampf(mini_pos.x, map_rect.position.x + 4, map_rect.end.x - 4)
		mini_pos.y = clampf(mini_pos.y, map_rect.position.y + 4, map_rect.end.y - 4)
	return mini_pos


func _clamp_to_circle(point: Vector2) -> Vector2:
	var center := _circle_center()
	var radius := _circle_radius() - 4.0
	var offset := point - center
	if offset.length() > radius:
		return center + offset.normalized() * radius
	return point


func _is_on_minimap(mini_pos: Vector2) -> bool:
	return mini_pos != OFFSCREEN


func _draw() -> void:
	var rect_size := size
	if rect_size.x <= 0 or rect_size.y <= 0:
		rect_size = Vector2(GameConstants.MINIMAP_SIZE, GameConstants.MINIMAP_SIZE)

	if circular:
		var center := _circle_center()
		var radius := _circle_radius()
		draw_circle(center, radius, Color(0.04, 0.06, 0.08, 0.95))
		draw_arc(center, radius, 0.0, TAU, 64, UITheme.GOLD, 2.0)
	else:
		draw_rect(Rect2(Vector2.ZERO, rect_size), Color(0.05, 0.05, 0.1, 0.94))
		draw_rect(Rect2(Vector2(2, 2), rect_size - Vector2(4, 4)), Color(0.02, 0.03, 0.05, 1.0))
		_draw_panel_grid(_map_draw_rect())
		draw_rect(Rect2(Vector2.ZERO, rect_size), UITheme.GOLD, false, 2.0)

	if not is_instance_valid(world) or not is_instance_valid(player):
		return

	var world_w := float(GameConstants.MAP_WORLD_WIDTH)
	var world_h := float(GameConstants.MAP_WORLD_HEIGHT)
	if world_w <= 0 or world_h <= 0:
		return

	var map_rect := _map_draw_rect()
	var p_mini_pos := _circle_center() if player_centered else _world_to_mini(player.global_position, map_rect, world_w, world_h)

	var move_target = world.get("move_target") if world.get("move_target") != null else null
	if move_target != null:
		var target_mini_pos := _world_to_mini(move_target, map_rect, world_w, world_h)
		if _is_on_minimap(target_mini_pos):
			_draw_minimap_dashed_line(p_mini_pos, target_mini_pos)
			draw_circle(target_mini_pos, 4.0, COLOR_TARGET)

	if world.is_inside_tree():
		for p in get_tree().get_nodes_in_group("portal"):
			if is_instance_valid(p):
				var mini_portal_pos := _world_to_mini(p.global_position, map_rect, world_w, world_h)
				if _is_on_minimap(mini_portal_pos):
					draw_circle(mini_portal_pos, 4.0, COLOR_PORTAL)

		for npc in get_tree().get_nodes_in_group("npc"):
			if is_instance_valid(npc):
				var mini_npc_pos := _world_to_mini(npc.global_position, map_rect, world_w, world_h)
				if _is_on_minimap(mini_npc_pos):
					draw_circle(mini_npc_pos, 3.5, COLOR_NPC)

	if world.has_method("get_monsters"):
		for m in world.get_monsters():
			if not is_instance_valid(m) or not m.get("is_active_monster"):
				continue
			var mini_pos := _world_to_mini(m.global_position, map_rect, world_w, world_h)
			if not _is_on_minimap(mini_pos):
				continue
			var m_id: String = str(m.get("monster_id")) if m.get("monster_id") != null else "poring"
			if _is_large_monster(m_id):
				var pulse_r := 5.5 + sin(_pulse) * 1.5
				draw_circle(mini_pos, pulse_r + 2.0, Color(COLOR_BOSS, 0.25))
				draw_circle(mini_pos, 5.0, COLOR_BOSS)
				draw_circle(mini_pos, 2.5, Color(1.0, 0.75, 0.2))
			else:
				draw_circle(mini_pos, 3.0, COLOR_MONSTER)

	draw_circle(p_mini_pos, 4.5, COLOR_PLAYER)
	draw_circle(p_mini_pos, 2.0, Color(0.9, 1.0, 0.9))


func _draw_panel_grid(map_rect: Rect2) -> void:
	var grid_color := Color(0.12, 0.16, 0.22, 0.45)
	var step := 32.0
	var scale_x := map_rect.size.x / float(GameConstants.MAP_WORLD_WIDTH)
	var scale_y := map_rect.size.y / float(GameConstants.MAP_WORLD_HEIGHT)
	var grid_step_x := step * scale_x
	var grid_step_y := step * scale_y
	if grid_step_x < 8.0:
		return
	var x := map_rect.position.x
	while x <= map_rect.end.x:
		draw_line(Vector2(x, map_rect.position.y), Vector2(x, map_rect.end.y), grid_color, 1.0)
		x += grid_step_x
	var y := map_rect.position.y
	while y <= map_rect.end.y:
		draw_line(Vector2(map_rect.position.x, y), Vector2(map_rect.end.x, y), grid_color, 1.0)
		y += grid_step_y


func _is_large_monster(monster_id: String) -> bool:
	var data := MonsterDB.get_monster(monster_id)
	if data.is_empty():
		return false
	var scale_value: Vector2 = data.get("scale", Vector2.ONE)
	return scale_value.x >= 1.5 or data.get("body_radius", 8.0) >= 14.0 or data.get("is_boss", false)


func _draw_minimap_dashed_line(from: Vector2, to: Vector2) -> void:
	var total_dist := from.distance_to(to)
	if total_dist <= 0:
		return
	var dash_length := 4.0
	var gap_length := 3.0
	var current_dist := 0.0
	var dir := (to - from).normalized()
	while current_dist < total_dist:
		var start_pos := from + dir * current_dist
		var end_pos := from + dir * minf(current_dist + dash_length, total_dist)
		draw_line(start_pos, end_pos, Color8(0x34, 0x98, 0xdb, 200), 1.5)
		current_dist += dash_length + gap_length
