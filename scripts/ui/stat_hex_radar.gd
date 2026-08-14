class_name StatHexRadar
extends Control

## Hex radar chart — RO axis order: STR, VIT, LUK, INT, DEX, AGI.

const STAT_ORDER: Array[String] = ["str", "vit", "luk", "int", "dex", "agi"]
const MIN_FILL_RATIO := 0.06

var wire_color: Color = Color8(0x44, 0xdd, 0xff, 0.85)
var axis_color: Color = Color8(0x33, 0xaa, 0xcc, 0.65)
var fill_color: Color = Color(0.18, 0.72, 1.0, 0.32)
var fill_stroke_color: Color = Color8(0x66, 0xcc, 0xff, 0.95)
var label_color: Color = Color8(0xaa, 0xee, 0xff, 0.9)
var ring_color: Color = Color8(0x22, 0x88, 0xaa, 0.45)

var stat_min: int = 1
var stat_max: int = 10
var auto_range: bool = true
var draw_labels: bool = true

var _stats: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for key: String in STAT_ORDER:
		_stats[key] = stat_min


func set_stats(stats: Dictionary) -> void:
	for key: String in STAT_ORDER:
		_stats[key] = int(stats.get(key, stat_min))
	if auto_range:
		_update_auto_range()
	queue_redraw()


func set_range(min_val: int, max_val: int) -> void:
	stat_min = mini(min_val, max_val - 1)
	stat_max = maxi(max_val, stat_min + 1)
	queue_redraw()


func _update_auto_range() -> void:
	var peak := stat_min
	for key: String in STAT_ORDER:
		peak = maxi(peak, int(_stats.get(key, stat_min)))
	stat_max = maxi(peak + 2, 10)


func _draw() -> void:
	var center := size * 0.5
	var radius := minf(size.x, size.y) * 0.36
	if radius <= 8.0:
		return

	_draw_wireframe(center, radius)
	_draw_axes(center, radius)
	_draw_stat_polygon(center, radius)
	if draw_labels:
		_draw_axis_labels(center, radius)


func _axis_angle(index: int) -> float:
	return -PI * 0.5 + float(index) * (TAU / 6.0)


func _value_ratio(value: int) -> float:
	var span := maxf(1, stat_max - stat_min)
	var raw := clampf(float(value - stat_min) / float(span), 0.0, 1.0)
	return lerpf(MIN_FILL_RATIO, 1.0, raw)


func _axis_point(center: Vector2, radius: float, index: int, value: int = -1) -> Vector2:
	var ratio := 1.0 if value < 0 else _value_ratio(value)
	var dist := radius * ratio
	var angle := _axis_angle(index)
	return center + Vector2(cos(angle), sin(angle)) * dist


func _draw_wireframe(center: Vector2, radius: float) -> void:
	var outer := PackedVector2Array()
	for i in range(6):
		outer.append(_axis_point(center, radius, i))
	draw_colored_polygon(outer, Color(0.04, 0.08, 0.12, 0.45))
	draw_polyline(outer + PackedVector2Array([outer[0]]), wire_color, 1.5, true)

	for level in [0.33, 0.66]:
		var ring := PackedVector2Array()
		for i in range(6):
			ring.append(center + Vector2(cos(_axis_angle(i)), sin(_axis_angle(i))) * radius * level)
		draw_polyline(ring + PackedVector2Array([ring[0]]), ring_color, 1.0, true)


func _draw_axes(center: Vector2, radius: float) -> void:
	for i in range(6):
		draw_line(center, _axis_point(center, radius, i), axis_color, 1.0, true)
	draw_circle(center, 2.5, fill_stroke_color)


func _draw_stat_polygon(center: Vector2, radius: float) -> void:
	var points := PackedVector2Array()
	for i in range(6):
		var key: String = STAT_ORDER[i]
		points.append(_axis_point(center, radius, i, int(_stats.get(key, stat_min))))

	if points.size() < 3 or _polygon_area(points) < 4.0:
		return

	draw_colored_polygon(points, fill_color)
	draw_polyline(points + PackedVector2Array([points[0]]), fill_stroke_color, 2.0, true)
	for p in points:
		draw_circle(p, 3.0, fill_stroke_color)


func _polygon_area(points: PackedVector2Array) -> float:
	var area := 0.0
	for i in range(points.size()):
		var j := (i + 1) % points.size()
		area += points[i].x * points[j].y - points[j].x * points[i].y
	return absf(area) * 0.5


func _draw_axis_labels(center: Vector2, radius: float) -> void:
	var font := ThemeDB.fallback_font
	var font_size := GameConstants.FONT_XS
	for i in range(6):
		var key: String = STAT_ORDER[i]
		var label := StatRegistry.get_label(key)
		var angle := _axis_angle(i)
		var pos := center + Vector2(cos(angle), sin(angle)) * (radius + 8.0)
		var text_size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
		draw_string(
			font,
			pos - text_size * 0.5 + Vector2(0, text_size.y * 0.35),
			label,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			font_size,
			label_color
		)
