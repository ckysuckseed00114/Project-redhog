class_name CharacterCreationStats
extends Control

## Classic RO character-creation stat allocation — opposing pairs, fixed total 30.

signal stats_changed(stats: Dictionary)

const STAT_KEYS: Array[String] = ["str", "agi", "vit", "int", "dex", "luk"]
const STAT_ORDER: Array[String] = ["str", "vit", "luk", "int", "dex", "agi"]

const STAT_DEFAULT := 5
const STAT_MIN := 1
const STAT_MAX := 9

const OPPOSING: Dictionary = {
	"str": "int",
	"int": "str",
	"agi": "luk",
	"luk": "agi",
	"vit": "dex",
	"dex": "vit",
}

const RADAR_SIZE := Vector2(260, 260)
const BTN_SIZE := Vector2(52, 28)

const COLOR_FILL := Color(0.22, 0.55, 0.95, 0.38)
const COLOR_FILL_STROKE := Color8(0x5d, 0xae, 0xff, 0.95)
const COLOR_WIRE := Color8(0x55, 0x50, 0x68, 0.9)
const COLOR_AXIS := Color8(0x66, 0x62, 0x78, 0.85)
const COLOR_BTN := Color8(0x2a, 0x3a, 0x55)
const COLOR_BTN_HOVER := Color8(0x35, 0x4d, 0x72)
const COLOR_BTN_DISABLED := Color8(0x28, 0x28, 0x32)
const COLOR_VALUE := Color8(0xff, 0xf8, 0xe7)
const COLOR_VALUE_MAX := Color8(0xff, 0xd7, 0x00)
const COLOR_VALUE_MIN := Color8(0xe7, 0x4c, 0x3c)

var _stats: Dictionary = {}
var _radar: _RoStatHexRadar
var _stat_buttons: Dictionary = {}
var _value_labels: Dictionary = {}
var _list_root: VBoxContainer


func _ready() -> void:
	reset_stats()
	_build_ui()
	_refresh_ui()


func reset_stats() -> void:
	_stats.clear()
	for key: String in STAT_KEYS:
		_stats[key] = STAT_DEFAULT


func get_stats() -> Dictionary:
	return _stats.duplicate()


func get_total() -> int:
	var sum := 0
	for key: String in STAT_KEYS:
		sum += _stats[key]
	return sum


func can_increase(key: String) -> bool:
	if not OPPOSING.has(key):
		return false
	return _stats[key] < STAT_MAX and _stats[OPPOSING[key]] > STAT_MIN


func increase_stat(key: String) -> bool:
	if not can_increase(key):
		return false
	var opposite: String = OPPOSING[key]
	_stats[key] += 1
	_stats[opposite] -= 1
	_refresh_ui()
	stats_changed.emit(get_stats())
	return true


func _build_ui() -> void:
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.add_theme_constant_override("separation", 18)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(row)

	var radar_wrap := Control.new()
	radar_wrap.custom_minimum_size = RADAR_SIZE
	radar_wrap.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	row.add_child(radar_wrap)

	_radar = _RoStatHexRadar.new()
	_radar.set_anchors_preset(Control.PRESET_FULL_RECT)
	_radar.custom_minimum_size = RADAR_SIZE
	radar_wrap.add_child(_radar)

	for i in range(STAT_ORDER.size()):
		var key: String = STAT_ORDER[i]
		var btn := _make_vertex_button(key)
		radar_wrap.add_child(btn)
		_stat_buttons[key] = btn

	_list_root = VBoxContainer.new()
	_list_root.add_theme_constant_override("separation", 6)
	_list_root.custom_minimum_size = Vector2(130, 0)
	_list_root.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_list_root)

	for key: String in STAT_ORDER:
		_list_root.add_child(_make_list_row(key))


func _make_vertex_button(key: String) -> Button:
	var btn := Button.new()
	btn.text = StatRegistry.get_label(key)
	btn.custom_minimum_size = BTN_SIZE
	btn.focus_mode = Control.FOCUS_NONE
	btn.pressed.connect(_on_vertex_pressed.bind(key))
	_apply_button_style(btn, COLOR_BTN)
	return btn


func _make_list_row(key: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.custom_minimum_size = Vector2(0, 24)

	var name_lbl := Label.new()
	name_lbl.text = StatRegistry.get_label(key)
	name_lbl.custom_minimum_size = Vector2(36, 0)
	UITheme.style_label(name_lbl, GameConstants.FONT_SM, UITheme.GOLD, 0)
	row.add_child(name_lbl)

	var value_lbl := Label.new()
	value_lbl.text = str(STAT_DEFAULT)
	value_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UITheme.style_label(value_lbl, GameConstants.FONT_MD, COLOR_VALUE, 1)
	row.add_child(value_lbl)
	_value_labels[key] = value_lbl

	return row


func _apply_button_style(btn: Button, bg: Color) -> void:
	btn.add_theme_stylebox_override("normal", UITheme.make_button_style(bg))
	btn.add_theme_stylebox_override("hover", UITheme.make_button_style(bg.lightened(0.12)))
	btn.add_theme_stylebox_override("pressed", UITheme.make_button_style(bg.darkened(0.1)))
	btn.add_theme_stylebox_override("disabled", UITheme.make_button_style(COLOR_BTN_DISABLED))
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_color_override("font_disabled_color", Color8(0x77, 0x77, 0x88))
	btn.add_theme_font_size_override("font_size", GameConstants.FONT_XS)


func _on_vertex_pressed(key: String) -> void:
	increase_stat(key)


func _refresh_ui() -> void:
	_radar.set_stats(_stats)

	for key: String in STAT_ORDER:
		var value: int = _stats[key]
		var lbl: Label = _value_labels[key]
		lbl.text = str(value)
		lbl.add_theme_color_override("font_color", _value_color(value))

		var btn: Button = _stat_buttons[key]
		btn.disabled = not can_increase(key)
		_position_vertex_button(btn, key)

	queue_redraw()


func _value_color(value: int) -> Color:
	if value >= STAT_MAX:
		return COLOR_VALUE_MAX
	if value <= STAT_MIN:
		return COLOR_VALUE_MIN
	return COLOR_VALUE


func _position_vertex_button(btn: Button, key: String) -> void:
	var index := STAT_ORDER.find(key)
	if index < 0:
		return
	var center := RADAR_SIZE * 0.5
	var radius := minf(RADAR_SIZE.x, RADAR_SIZE.y) * 0.42
	var angle := -PI * 0.5 + float(index) * (TAU / 6.0)
	var outer := center + Vector2(cos(angle), sin(angle)) * (radius + 18.0)
	btn.position = outer - BTN_SIZE * 0.5
	btn.pivot_offset = BTN_SIZE * 0.5


class _RoStatHexRadar extends Control:
	const MIN_FILL_RATIO := 0.06

	var stat_min: int = CharacterCreationStats.STAT_MIN
	var stat_max: int = CharacterCreationStats.STAT_MAX
	var _stats: Dictionary = {
		"str": CharacterCreationStats.STAT_DEFAULT,
		"vit": CharacterCreationStats.STAT_DEFAULT,
		"luk": CharacterCreationStats.STAT_DEFAULT,
		"int": CharacterCreationStats.STAT_DEFAULT,
		"dex": CharacterCreationStats.STAT_DEFAULT,
		"agi": CharacterCreationStats.STAT_DEFAULT,
	}


	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		for key: String in CharacterCreationStats.STAT_ORDER:
			_stats[key] = CharacterCreationStats.STAT_DEFAULT


	func set_stats(stats: Dictionary) -> void:
		for key: String in CharacterCreationStats.STAT_ORDER:
			_stats[key] = int(stats.get(key, stat_min))
		queue_redraw()


	func _draw() -> void:
		var center := size * 0.5
		var radius := minf(size.x, size.y) * 0.34
		if radius <= 8.0:
			return

		_draw_wireframe(center, radius)
		_draw_axes(center, radius)
		_draw_stat_polygon(center, radius)
		_draw_axis_labels(center, radius)


	func _axis_angle(index: int) -> float:
		return -PI * 0.5 + float(index) * (TAU / 6.0)


	func _value_ratio(value: int) -> float:
		var raw := clampf(float(value - stat_min) / float(stat_max - stat_min), 0.0, 1.0)
		return lerpf(MIN_FILL_RATIO, 1.0, raw)


	func _axis_point(center: Vector2, radius: float, index: int, value: int = stat_max) -> Vector2:
		var ratio := _value_ratio(value) if value != stat_max else 1.0
		var dist := radius * ratio
		var angle := _axis_angle(index)
		return center + Vector2(cos(angle), sin(angle)) * dist


	func _draw_wireframe(center: Vector2, radius: float) -> void:
		var outer := PackedVector2Array()
		for i in range(6):
			outer.append(_axis_point(center, radius, i))
		draw_colored_polygon(outer, Color(0.08, 0.08, 0.12, 0.35))
		draw_polyline(outer + PackedVector2Array([outer[0]]), CharacterCreationStats.COLOR_WIRE, 1.5, true)

		for level in [0.33, 0.66]:
			var ring := PackedVector2Array()
			for i in range(6):
				ring.append(center + Vector2(cos(_axis_angle(i)), sin(_axis_angle(i))) * radius * level)
			draw_polyline(ring + PackedVector2Array([ring[0]]), CharacterCreationStats.COLOR_WIRE.darkened(0.15), 1.0, true)


	func _draw_axes(center: Vector2, radius: float) -> void:
		for i in range(6):
			draw_line(center, _axis_point(center, radius, i), CharacterCreationStats.COLOR_AXIS, 1.0, true)
		draw_circle(center, 2.5, CharacterCreationStats.COLOR_AXIS)


	func _draw_stat_polygon(center: Vector2, radius: float) -> void:
		var points := PackedVector2Array()
		for i in range(6):
			var key: String = CharacterCreationStats.STAT_ORDER[i]
			points.append(_axis_point(center, radius, i, int(_stats.get(key, CharacterCreationStats.STAT_DEFAULT))))

		if points.size() < 3 or _polygon_area(points) < 4.0:
			return

		draw_colored_polygon(points, CharacterCreationStats.COLOR_FILL)
		draw_polyline(points + PackedVector2Array([points[0]]), CharacterCreationStats.COLOR_FILL_STROKE, 2.0, true)
		for p in points:
			draw_circle(p, 3.0, CharacterCreationStats.COLOR_FILL_STROKE)


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
			var key: String = CharacterCreationStats.STAT_ORDER[i]
			var label := StatRegistry.get_label(key)
			var angle := _axis_angle(i)
			var pos := center + Vector2(cos(angle), sin(angle)) * (radius + 6.0)
			var text_size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
			draw_string(font, pos - text_size * 0.5 + Vector2(0, text_size.y * 0.35), label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color8(0xcc, 0xc6, 0xdd))
