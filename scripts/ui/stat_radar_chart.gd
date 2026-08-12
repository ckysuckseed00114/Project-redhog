class_name StatRadarChart
extends Control

## 6-axis radar chart — clockwise from top: STR, VIT, LUK, INT, DEX, AGI

const STAT_ORDER := ["str", "vit", "luk", "int", "dex", "agi"]

const GRID_LEVELS := [0.25, 0.5, 0.75, 1.0]
const GRID_COLOR := Color8(0x3a, 0x36, 0x48, 0.9)
const GRID_ACCENT := Color8(0xd4, 0xaf, 0x37, 0.55)
const AXIS_COLOR := Color8(0x66, 0x62, 0x78, 0.85)
const FILL_COLOR := Color8(0xf1, 0xc4, 0x0f, 0.28)
const FILL_GLOW := Color8(0xff, 0xd7, 0x00, 0.12)
const STROKE_COLOR := Color8(0xff, 0xd7, 0x00, 0.95)

@export var stat_min: int = 1
@export var stat_max: int = 10

var _stats: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for key in STAT_ORDER:
		_stats[key] = stat_min


func set_stats(stats: Dictionary) -> void:
	for key: String in STAT_ORDER:
		_stats[key] = int(stats.get(key, stat_min))
	queue_redraw()


func _draw() -> void:
	var center := size * 0.5
	var radius := minf(size.x, size.y) * 0.34
	if radius <= 8.0:
		return

	_draw_grid(center, radius)
	_draw_axes(center, radius)
	_draw_stat_polygon(center, radius)


func _axis_angle(index: int) -> float:
	return -PI * 0.5 + float(index) * (TAU / 6.0)


func _value_ratio(value: int) -> float:
	return clampf(float(value - stat_min) / float(stat_max - stat_min), 0.0, 1.0)


func _axis_point(center: Vector2, radius: float, index: int, value: int = stat_max) -> Vector2:
	var ratio := _value_ratio(value) if value != stat_max else 1.0
	var dist := radius * ratio
	var angle := _axis_angle(index)
	return center + Vector2(cos(angle), sin(angle)) * dist


func _draw_grid(center: Vector2, radius: float) -> void:
	for level_i in GRID_LEVELS.size():
		var level: float = GRID_LEVELS[level_i]
		var ring := PackedVector2Array()
		for i in range(6):
			ring.append(center + Vector2(cos(_axis_angle(i)), sin(_axis_angle(i))) * radius * level)
		var is_outer := level >= 0.99
		draw_colored_polygon(ring, FILL_GLOW if is_outer else Color(0, 0, 0, 0))
		draw_polyline(ring + PackedVector2Array([ring[0]]), GRID_ACCENT if is_outer else GRID_COLOR, 1.5 if is_outer else 1.0, true)


func _draw_axes(center: Vector2, radius: float) -> void:
	for i in range(6):
		draw_line(center, _axis_point(center, radius, i), AXIS_COLOR, 1.0, true)


func _draw_stat_polygon(center: Vector2, radius: float) -> void:
	var points := PackedVector2Array()
	for i in range(6):
		var key: String = STAT_ORDER[i]
		points.append(_axis_point(center, radius, i, int(_stats.get(key, stat_min))))

	if points.size() < 3:
		return

	draw_colored_polygon(points, FILL_COLOR)
	draw_polyline(points + PackedVector2Array([points[0]]), STROKE_COLOR, 2.5, true)

	for p in points:
		draw_circle(p, 3.0, STROKE_COLOR)
