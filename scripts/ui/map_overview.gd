class_name MapOverview
extends Control

var world: Node2D

const MAP_BOX_SIZE := Vector2(130, 60)

const COLOR_BOX := Color(0.06, 0.06, 0.08, 0.95)
const COLOR_BOX_BORDER := Color(0.22, 0.22, 0.28, 1.0)
const COLOR_ACTIVE := Color(0.10, 0.12, 0.18, 1.0)
const COLOR_PLAYER := Color8(0x2e, 0xcc, 0x71)
const COLOR_NAME_IDLE := Color(0.75, 0.75, 0.8)

# id ต้องตรงกับ ProjectPaths.MAP_ID_* และ root node ของ scene
const MAP_REGIONS := [
	{"id": ProjectPaths.MAP_ID_WEST_FIELD, "name": "West Field", "pos": Vector2(16, 24)},
	{"id": ProjectPaths.MAP_ID_CAPITAL, "name": "Capital", "pos": Vector2(166, 24)},
	{"id": ProjectPaths.MAP_ID_WORLD, "name": "South Field", "pos": Vector2(166, 104)},
]


func setup(w: Node2D, _p: Player) -> void:
	world = w
	queue_redraw()


func _get_current_map_id() -> String:
	if is_instance_valid(world):
		return str(world.name)
	var root := get_tree().current_scene
	return str(root.name) if root else ""


func _region_rect(region: Dictionary) -> Rect2:
	return Rect2(region.get("pos", Vector2.ZERO), MAP_BOX_SIZE)


func _draw() -> void:
	var current_id := _get_current_map_id()
	for region in MAP_REGIONS:
		_draw_region(region, _region_rect(region), current_id == str(region["id"]))


func _draw_region(region: Dictionary, rect: Rect2, is_here: bool) -> void:
	var bg: Color = COLOR_ACTIVE if is_here else COLOR_BOX
	var border: Color = UITheme.GOLD if is_here else COLOR_BOX_BORDER
	var border_w: float = 2.0 if is_here else 1.0

	draw_rect(rect, bg)
	draw_rect(rect, border, false, border_w)

	draw_string(
		ThemeDB.fallback_font,
		rect.position + Vector2(0, 18),
		str(region["name"]),
		HORIZONTAL_ALIGNMENT_CENTER,
		int(rect.size.x),
		GameConstants.FONT_MD if is_here else GameConstants.FONT_SM,
		UITheme.GOLD if is_here else COLOR_NAME_IDLE
	)

	if is_here:
		var center := rect.position + Vector2(rect.size.x * 0.5, rect.size.y * 0.62)
		draw_circle(center, 8.0, Color(COLOR_PLAYER, 0.35))
		draw_circle(center, 5.0, COLOR_PLAYER)
