extends Control

# --- Constants ---

const STAT_KEYS: Array[String] = ["str", "agi", "vit", "int", "dex", "luk"]
const STAT_GRID_ROWS: Array = [
	["str", "vit", "luk"],
	["agi", "int", "dex"],
]

const STAT_DEFAULT := 5
const STAT_MIN := 1
const STAT_MAX := 10
const FREE_POINTS := 5
const RADAR_SIZE := Vector2(200, 200)

const COLOR_READY := Color8(0x2e, 0xcc, 0x71)
const COLOR_POINTS := Color8(0xf1, 0xc4, 0x0f)
const COLOR_STAT_MAX := Color8(0xff, 0xd7, 0x00)
const COLOR_STAT_MIN := Color8(0xe7, 0x4c, 0x3c)
const COLOR_STAT_NORMAL := Color8(0xff, 0xf8, 0xe7)
const COLOR_BTN_MINUS := Color8(0x8e, 0x44, 0x44)
const COLOR_BTN_PLUS := Color8(0x27, 0xae, 0x60)
const COLOR_BTN_DISABLED := Color8(0x33, 0x33, 0x3a)
const COLOR_BTN_CREATE := Color8(0x27, 0xae, 0x60)
const COLOR_BTN_CREATE_OFF := Color8(0x44, 0x44, 0x4a)

const SCENE_CHARACTER_SELECTION := "res://scenes/ui/character_selection.tscn"
const SCENE_CAPITAL_CITY := "res://scenes/maps/capital_city.tscn"

# --- Node references ---

@onready var _male_btn: TextureButton = %MaleButton
@onready var _female_btn: TextureButton = %FemaleButton
@onready var _name_input: LineEdit = %NameInput
@onready var _create_btn: Button = %CreateButton
@onready var _back_btn: Button = %BackButton
@onready var _status_label: Label = %StatusLabel
@onready var _remaining_label: Label = %RemainingLabel
@onready var _radar_host: Control = %RadarHost
@onready var _stat_grid: GridContainer = %StatGrid

# --- State ---

var _selected_gender: String = "male"
var _stats: Dictionary = {}
var _stat_value_labels: Dictionary = {}
var _plus_buttons: Dictionary = {}
var _minus_buttons: Dictionary = {}
var _radar_chart: StatRadarChart
var _is_creating: bool = false


# --- Setup ---

func _ready() -> void:
	UITheme.apply_fonts_recursive(self)
	_init_stats()
	_setup_radar_chart()
	_build_stat_rows()
	_connect_signals()
	_apply_gender_previews()
	_refresh_stat_ui()
	_status_label.text = ""


func _init_stats() -> void:
	_stats.clear()
	for key: String in STAT_KEYS:
		_stats[key] = STAT_DEFAULT


func _setup_radar_chart() -> void:
	_radar_chart = StatRadarChart.new()
	_radar_chart.stat_min = STAT_MIN
	_radar_chart.stat_max = STAT_MAX
	_radar_chart.set_anchors_preset(Control.PRESET_FULL_RECT)
	_radar_chart.custom_minimum_size = RADAR_SIZE
	_radar_host.add_child(_radar_chart)


func _build_stat_rows() -> void:
	for row_keys: Array in STAT_GRID_ROWS:
		for key: String in row_keys:
			_stat_grid.add_child(_make_stat_row(key))


func _connect_signals() -> void:
	_male_btn.pressed.connect(_on_gender_selected.bind("male"))
	_female_btn.pressed.connect(_on_gender_selected.bind("female"))
	_create_btn.pressed.connect(_on_create_pressed)
	_back_btn.pressed.connect(_on_back_pressed)
	_name_input.text_submitted.connect(_on_name_submitted)


# --- UI Logic ---

func _make_stat_row(key: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.custom_minimum_size = Vector2(118, 30)

	var name_lbl := Label.new()
	name_lbl.text = StatRegistry.get_label(key)
	name_lbl.custom_minimum_size = Vector2(34, 0)
	UITheme.style_label(name_lbl, GameConstants.FONT_XS, UITheme.GOLD, 0)
	row.add_child(name_lbl)

	var minus := _make_stat_button("−", COLOR_BTN_MINUS)
	minus.pressed.connect(_on_minus_pressed.bind(key))
	row.add_child(minus)
	_minus_buttons[key] = minus

	var value_lbl := Label.new()
	value_lbl.text = str(STAT_DEFAULT)
	value_lbl.custom_minimum_size = Vector2(20, 0)
	value_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UITheme.style_label(value_lbl, GameConstants.FONT_SM, COLOR_STAT_NORMAL, 1)
	row.add_child(value_lbl)
	_stat_value_labels[key] = value_lbl

	var plus := _make_stat_button("+", COLOR_BTN_PLUS)
	plus.pressed.connect(_on_plus_pressed.bind(key))
	row.add_child(plus)
	_plus_buttons[key] = plus

	return row


func _make_stat_button(text: String, bg: Color) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(26, 26)
	btn.add_theme_stylebox_override("normal", UITheme.make_button_style(bg))
	btn.add_theme_stylebox_override("hover", UITheme.make_button_style(bg.lightened(0.15)))
	btn.add_theme_stylebox_override("pressed", UITheme.make_button_style(bg.darkened(0.12)))
	btn.add_theme_stylebox_override("disabled", UITheme.make_button_style(COLOR_BTN_DISABLED))
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_font_size_override("font_size", GameConstants.FONT_SM)
	return btn


func _remaining_points() -> int:
	var used := 0
	for key: String in STAT_KEYS:
		used += _stats[key] - STAT_DEFAULT
	return FREE_POINTS - used


func _refresh_stat_ui() -> void:
	var remaining := _remaining_points()

	for key: String in STAT_KEYS:
		var value: int = _stats[key]
		var lbl: Label = _stat_value_labels[key]
		lbl.text = str(value)
		lbl.add_theme_color_override("font_color", _stat_value_color(value))
		_plus_buttons[key].disabled = remaining <= 0 or value >= STAT_MAX
		_minus_buttons[key].disabled = value <= STAT_MIN

	_radar_chart.set_stats(_stats)
	_update_remaining_label(remaining)
	_update_create_button(remaining == 0 and not _is_creating)


func _stat_value_color(value: int) -> Color:
	if value >= STAT_MAX:
		return COLOR_STAT_MAX
	if value <= STAT_MIN:
		return COLOR_STAT_MIN
	return COLOR_STAT_NORMAL


func _update_remaining_label(remaining: int) -> void:
	if remaining <= 0:
		_remaining_label.text = "✦ Free Points: 0 — Ready!"
		UITheme.style_label(_remaining_label, GameConstants.FONT_SM, COLOR_READY, 1)
	else:
		_remaining_label.text = "Free Points: %d" % remaining
		UITheme.style_label(_remaining_label, GameConstants.FONT_SM, COLOR_POINTS, 0)


func _update_create_button(enabled: bool) -> void:
	_create_btn.disabled = not enabled
	if enabled:
		_create_btn.add_theme_stylebox_override("normal", UITheme.make_button_style(COLOR_BTN_CREATE))
		_create_btn.add_theme_color_override("font_color", Color.WHITE)
	else:
		_create_btn.add_theme_stylebox_override("normal", UITheme.make_button_style(COLOR_BTN_CREATE_OFF))
		_create_btn.add_theme_color_override("font_color", Color8(0x99, 0x99, 0xaa))


func _apply_gender_previews() -> void:
	var male_tex := PlayerSpriteLoader.load_preview("novice", "male")
	var female_tex := PlayerSpriteLoader.load_preview("novice", "female")
	if male_tex:
		_male_btn.texture_normal = male_tex
	if female_tex:
		_female_btn.texture_normal = female_tex
	_update_gender_visual()


func _update_gender_visual() -> void:
	var selected: TextureButton = _male_btn if _selected_gender == "male" else _female_btn
	var other: TextureButton = _female_btn if _selected_gender == "male" else _male_btn
	selected.modulate = Color.WHITE
	other.modulate = Color(0.45, 0.45, 0.45, 1.0)


func _show_status(message: String, color: Color) -> void:
	_status_label.text = message
	_status_label.add_theme_color_override("font_color", color)


func _release_focus() -> void:
	if _name_input.has_focus():
		_name_input.release_focus()
	get_viewport().gui_release_focus()


# --- Stat allocation ---

func _on_plus_pressed(key: String) -> void:
	if _remaining_points() <= 0 or _stats[key] >= STAT_MAX:
		return
	_stats[key] += 1
	_refresh_stat_ui()


func _on_minus_pressed(key: String) -> void:
	if _stats[key] <= STAT_MIN:
		return
	_stats[key] -= 1
	_refresh_stat_ui()


# --- Input ---

func _unhandled_input(event: InputEvent) -> void:
	if _name_input.has_focus() and event.is_action_pressed("ui_cancel"):
		_release_focus()
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("ui_cancel"):
		_on_back_pressed()
		get_viewport().set_input_as_handled()


# --- Character creation ---

func _compute_max_hp(vit: int) -> int:
	return 50 + (vit - 1) * StatRegistry.VIT_HP_BONUS


func _build_player_data(char_name: String) -> Dictionary:
	var vit: int = _stats["vit"]
	var max_hp := _compute_max_hp(vit)
	return {
		"user_id": SupabaseClient.current_user_id,
		"character_id": GlobalData.character_id,
		"slot_index": GlobalData.current_slot_index,
		"name": char_name,
		"gender": _selected_gender,
		"current_job": "novice",
		"level": 1,
		"current_exp": 0,
		"max_exp": 100,
		"stat_points": 0,
		"hp": max_hp,
		"max_hp": max_hp,
		"sp": 10,
		"max_sp": 10,
		"str_stat": _stats["str"],
		"agi": _stats["agi"],
		"vit": vit,
		"int_stat": _stats["int"],
		"dex": _stats["dex"],
		"luk": _stats["luk"],
		"pos_x": 0,
		"pos_y": 0,
		"current_scene": SCENE_CAPITAL_CITY,
	}

func _on_create_pressed() -> void:
	if _is_creating:
		return

	if _remaining_points() != 0:
		_show_status("❌ Spend all Free Points before creating.", COLOR_STAT_MIN)
		return

	var char_name := _name_input.text.strip_edges()
	if char_name.is_empty():
		_show_status("❌ กรุณาตั้งชื่อตัวละคร!", COLOR_STAT_MIN)
		_name_input.grab_focus()
		return

	_is_creating = true
	_update_create_button(false)
	_show_status("⏳ กำลังตรวจสอบชื่อ...", COLOR_POINTS)

	DatabaseManager.check_name_available(char_name, _on_name_check_finished.bind(char_name))


# 🌟 สลับลำดับให้ is_available (bool) มาอยู่ตัวแรก เพื่อรับค่าที่ส่งมาจาก DatabaseManager พอดี
func _on_name_check_finished(is_available: bool, char_name: String) -> void:
	if not is_available:
		_is_creating = false
		_refresh_stat_ui()
		_show_status("❌ ชื่อนี้ถูกใช้งานไปแล้ว กรุณาตั้งชื่อใหม่!", COLOR_STAT_MIN)
		_name_input.text = ""
		_name_input.grab_focus()
		return

	_show_status("✅ ชื่อผ่าน! กำลังสร้างตัวละคร...", COLOR_READY)
	GlobalData.player_name = char_name
	GlobalData.player_gender = _selected_gender
	GlobalData.player_class = "novice"
	GlobalData.character_id = "%s_%d" % [SupabaseClient.current_user_id, Time.get_ticks_msec()]

	var player_data := _build_player_data(char_name)
	SupabaseClient.insert_data("players", player_data, _on_player_insert_finished.bind(player_data))

# 🌟 สลับลำดับพารามิเตอร์ให้ตรงกับที่ระบบส่งมา (success, _response) และนำตัวที่ bind ไว้ (player_data) ไว้ท้ายสุด
func _on_player_insert_finished(success: bool, _response: Variant, player_data: Dictionary) -> void:
	_is_creating = false
	_refresh_stat_ui()

	if not success:
		_show_status("❌ บันทึกตัวละครไม่สำเร็จ ลองใหม่อีกครั้ง", COLOR_STAT_MIN)
		return

	GlobalData.remember_created_character(player_data)
	GlobalData.spawn_x = 638.0
	GlobalData.spawn_y = 400.0
	GlobalData.has_saved_position = true
	_release_focus()
	get_tree().change_scene_to_file(SCENE_CAPITAL_CITY)


func _on_gender_selected(gender: String) -> void:
	_selected_gender = gender
	_update_gender_visual()


func _on_back_pressed() -> void:
	if _is_creating:
		return
	_release_focus()
	get_tree().change_scene_to_file(SCENE_CHARACTER_SELECTION)


func _on_name_submitted(_text: String) -> void:
	if _remaining_points() == 0 and not _is_creating:
		_on_create_pressed()
