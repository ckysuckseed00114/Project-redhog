extends Control

# --- Constants ---

const COLOR_READY := Color8(0x2e, 0xcc, 0x71)
const COLOR_POINTS := Color8(0xf1, 0xc4, 0x0f)
const COLOR_STAT_MIN := Color8(0xe7, 0x4c, 0x3c)
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
@onready var _stats_panel: CharacterCreationStats = %StatsPanel

# --- State ---

var _selected_gender: String = "male"
var _is_creating: bool = false


# --- Setup ---

func _ready() -> void:
	UITheme.apply_fonts_recursive(self)
	_connect_signals()
	_apply_gender_previews()
	_update_create_button(not _is_creating)
	_status_label.text = ""


func _connect_signals() -> void:
	_male_btn.pressed.connect(_on_gender_selected.bind("male"))
	_female_btn.pressed.connect(_on_gender_selected.bind("female"))
	_create_btn.pressed.connect(_on_create_pressed)
	_back_btn.pressed.connect(_on_back_pressed)
	_name_input.text_submitted.connect(_on_name_submitted)
	if _stats_panel:
		_stats_panel.stats_changed.connect(_on_stats_changed)


# --- UI Logic ---

func _on_stats_changed(_stats: Dictionary) -> void:
	pass


func _current_stats() -> Dictionary:
	return _stats_panel.get_stats() if _stats_panel else {}


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
	var stats := _current_stats()
	var vit: int = stats["vit"]
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
		"str_stat": stats["str"],
		"agi": stats["agi"],
		"vit": vit,
		"int_stat": stats["int"],
		"dex": stats["dex"],
		"luk": stats["luk"],
		"pos_x": 0,
		"pos_y": 0,
		"current_scene": SCENE_CAPITAL_CITY,
	}

func _on_create_pressed() -> void:
	if _is_creating:
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
		_update_create_button(true)
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
	_update_create_button(true)

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
	if not _is_creating:
		_on_create_pressed()
