extends Control

# --- Constants ---

const MAX_SLOTS := 3
const MAX_FETCH_RETRIES := 3
const LOAD_TIMEOUT_SEC := 20.0

const SCENE_LOGIN := "res://scenes/ui/login_screen.tscn"
const SCENE_CREATION := "res://scenes/ui/charactercreation.tscn"

const COLOR_STATUS_DEFAULT := Color(0.75, 0.75, 0.75, 1)
const COLOR_STATUS_ERROR := Color8(0xe7, 0x4c, 0x3c)
const COLOR_STATUS_OK := Color8(0x2e, 0xcc, 0x71)
const COLOR_STATUS_PENDING := Color8(0xf1, 0xc4, 0x0f)
const COLOR_GOLD := Color(0.95, 0.78, 0.25, 1)
const COLOR_MUTED := Color(0.6, 0.6, 0.6, 1)
const COLOR_BORDER_GOLD := Color(0.85, 0.68, 0.2, 1)

const SLOT_SIZE := Vector2(110, 185)

# --- Node references ---

@onready var _slots_scroll: HBoxContainer = %SlotsScroll
@onready var _status_label: Label = %StatusLabel
@onready var _back_btn: Button = %BackButton

# --- State ---

var characters: Array[Dictionary] = []
var is_loaded: bool = false
var _fetch_generation: int = 0
var _fetch_attempt: int = 0
var _confirm_dialog: ConfirmationDialog
var _pending_delete_char: Dictionary = {}
var _is_deleting: bool = false


# --- Setup ---

func _ready() -> void:
	UITheme.apply_fonts_recursive(self)
	_setup_dialog()
	_back_btn.pressed.connect(_on_back_pressed)
	_set_status("กำลังโหลดตัวละคร...")
	_show_loading_slots()
	get_tree().create_timer(LOAD_TIMEOUT_SEC).timeout.connect(_on_load_timeout, CONNECT_ONE_SHOT)
	call_deferred("_load_characters")


func _setup_dialog() -> void:
	_confirm_dialog = ConfirmationDialog.new()
	_confirm_dialog.title = "ยืนยันการลบตัวละคร"
	_confirm_dialog.ok_button_text = "ลบถาวร"
	_confirm_dialog.cancel_button_text = "ยกเลิก"
	_confirm_dialog.confirmed.connect(_on_delete_confirmed)
	add_child(_confirm_dialog)


# --- UI helpers ---

func _set_status(text: String, color: Color = COLOR_STATUS_DEFAULT) -> void:
	_status_label.text = text
	_status_label.add_theme_color_override("font_color", color)


func _make_flat_style(
	bg: Color,
	border: Color = Color.TRANSPARENT,
	radius: int = 6,
	border_w: int = 0
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.border_width_left = border_w
	style.border_width_top = border_w
	style.border_width_right = border_w
	style.border_width_bottom = border_w
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_right = radius
	style.corner_radius_bottom_left = radius
	return style


func _show_loading_slots() -> void:
	_clear_slots_scroll()
	for i in range(MAX_SLOTS):
		_slots_scroll.add_child(_create_slot_panel("", null, i, true))


func _clear_slots_scroll() -> void:
	for child in _slots_scroll.get_children():
		_slots_scroll.remove_child(child)
		child.queue_free()


func _build_slots() -> void:
	_clear_slots_scroll()
	var slot_rows: Array = _assign_slots()
	for i in range(MAX_SLOTS):
		_slots_scroll.add_child(_create_slot_panel("", slot_rows[i], i, false))


func _create_slot_panel(loading_text: String, char_data: Variant, slot_index: int, is_loading: bool) -> PanelContainer:
	var slot_panel := PanelContainer.new()
	slot_panel.custom_minimum_size = SLOT_SIZE
	slot_panel.add_theme_stylebox_override(
		"panel",
		_make_flat_style(Color(0.12, 0.09, 0.09, 1), COLOR_BORDER_GOLD, 8, 1)
	)

	var vbox_slot := VBoxContainer.new()
	vbox_slot.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox_slot.add_theme_constant_override("separation", 8)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	margin.add_child(vbox_slot)
	slot_panel.add_child(margin)

	if is_loading:
		vbox_slot.add_child(_make_center_label(loading_text, 11, COLOR_MUTED))
	elif char_data is Dictionary:
		_populate_character_slot(vbox_slot, char_data)
	else:
		_populate_empty_slot(vbox_slot, slot_index)

	return slot_panel


func _populate_character_slot(vbox: VBoxContainer, char_data: Dictionary) -> void:
	vbox.add_child(_make_center_label(str(char_data.get("name", "Unknown")), 13, COLOR_GOLD))

	var job_id := str(char_data.get("current_job", "novice"))
	var details := "Lv. %d\n%s" % [int(char_data.get("level", 1)), ClassDatabase.get_display_name(job_id)]
	vbox.add_child(_make_center_label(details, 11, Color(0.8, 0.8, 0.8, 1)))

	var start_btn := Button.new()
	start_btn.text = "เข้าสู่โลก"
	start_btn.custom_minimum_size = Vector2(90, 30)
	UITheme.apply_font(start_btn)
	start_btn.add_theme_stylebox_override("normal", _make_flat_style(Color(0.75, 0.12, 0.12, 1), Color.TRANSPARENT, 4))
	start_btn.pressed.connect(_on_start_game_pressed.bind(char_data))
	vbox.add_child(start_btn)

	var delete_btn := Button.new()
	delete_btn.text = "ลบ"
	delete_btn.custom_minimum_size = Vector2(90, 26)
	delete_btn.add_theme_font_size_override("font_size", 11)
	UITheme.apply_font(delete_btn)
	delete_btn.add_theme_stylebox_override(
		"normal",
		_make_flat_style(Color(0.14, 0.1, 0.1, 1), Color(0.9, 0.35, 0.35, 1), 4, 1)
	)
	delete_btn.add_theme_color_override("font_color", Color(0.95, 0.55, 0.55, 1))
	delete_btn.pressed.connect(_on_delete_character_pressed.bind(char_data))
	vbox.add_child(delete_btn)


func _populate_empty_slot(vbox: VBoxContainer, slot_index: int) -> void:
	vbox.add_child(_make_center_label("ช่องว่าง", 12, COLOR_MUTED))

	var create_btn := Button.new()
	create_btn.text = "+"
	create_btn.custom_minimum_size = Vector2(40, 40)
	create_btn.add_theme_font_size_override("font_size", 22)
	UITheme.apply_font(create_btn)
	create_btn.add_theme_stylebox_override(
		"normal",
		_make_flat_style(Color(0.18, 0.14, 0.14, 1), COLOR_BORDER_GOLD, 20, 1)
	)
	create_btn.pressed.connect(_on_create_character_pressed.bind(slot_index))

	var center_btn := CenterContainer.new()
	center_btn.add_child(create_btn)
	vbox.add_child(center_btn)


func _make_center_label(text: String, font_size: int, color: Color) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UITheme.apply_font(lbl)
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", color)
	return lbl


# --- Data ---

func _slot_index_of(row: Dictionary) -> int:
	var raw: Variant = row.get("slot_index", 0)
	if raw is int:
		return raw
	if raw is float:
		return int(raw)
	if raw is String and str(raw).is_valid_int():
		return str(raw).to_int()
	return 0


func _assign_slots() -> Array:
	var slots: Array = [null, null, null]
	var overflow: Array[Dictionary] = []

	for row in characters:
		var idx := _slot_index_of(row)
		if idx >= 0 and idx < MAX_SLOTS and slots[idx] == null:
			slots[idx] = row
		else:
			overflow.append(row)

	var slot_i := 0
	for row in overflow:
		while slot_i < MAX_SLOTS and slots[slot_i] != null:
			slot_i += 1
		if slot_i < MAX_SLOTS:
			slots[slot_i] = row
			slot_i += 1

	return slots


func _remove_character_from_list(character_id: String) -> void:
	var kept: Array[Dictionary] = []
	for row in characters:
		if str(row.get("character_id", "")) != character_id:
			kept.append(row)
	characters = kept


# --- Network ---

func _load_characters() -> void:
	if not SupabaseClient.is_authenticated():
		print("❌ Web/Desktop session ไม่ครบ (user/token) — กลับหน้า Login")
		_set_status("Session หมดอายุ กรุณาเข้าสู่ระบบใหม่", COLOR_STATUS_ERROR)
		get_tree().create_timer(0.8).timeout.connect(func() -> void:
			get_tree().change_scene_to_file(SCENE_LOGIN)
		)
		return

	var user_id := SupabaseClient.current_user_id
	_fetch_generation += 1
	var fetch_gen := _fetch_generation
	var query := "user_id=eq.%s&order=slot_index.asc" % user_id.uri_encode()

	SupabaseClient.fetch_data("players", query, func(success: bool, response: Variant) -> void:
		if fetch_gen != _fetch_generation:
			return

		is_loaded = true
		if OS.is_debug_build():
			var row_count: int = (response as Array).size() if response is Array else 0
			print("📥 players fetch | success=", success, " rows=", row_count)

		if success and response is Array:
			characters.assign(GlobalData.merge_character_rows(response, user_id))
		else:
			characters.assign(GlobalData.merge_character_rows([], user_id))
			if _fetch_attempt + 1 < MAX_FETCH_RETRIES:
				_fetch_attempt += 1
				_set_status(
					"โหลดไม่สำเร็จ กำลังลองใหม่ (%d/%d)..." % [_fetch_attempt, MAX_FETCH_RETRIES]
				)
				get_tree().create_timer(1.0).timeout.connect(_load_characters)
				return

		_fetch_attempt = 0
		if not success:
			_set_status("โหลดตัวละครไม่สำเร็จ — ลองเข้าสู่ระบบใหม่", COLOR_STATUS_ERROR)
		elif characters.is_empty():
			_set_status("ยังไม่มีตัวละคร — กด + เพื่อสร้างใหม่")
		else:
			_set_status("พบ %d ตัวละคร" % characters.size(), COLOR_STATUS_OK)

		call_deferred("_build_slots")
	)


func _on_load_timeout() -> void:
	if is_loaded:
		return
	print("⚠️ โหลดตัวละครหมดเวลา — แสดงช่องว่าง")
	is_loaded = true
	characters.assign(GlobalData.merge_character_rows([], SupabaseClient.current_user_id))
	_set_status("โหลดตัวละครหมดเวลา — กดกลับแล้วเข้าใหม่", COLOR_STATUS_ERROR)
	call_deferred("_build_slots")


# --- Actions ---

func _on_start_game_pressed(char_data: Dictionary) -> void:
	GlobalData.player_name = str(char_data.get("name", "Player"))
	GlobalData.character_id = str(char_data.get("character_id", ""))
	GlobalData.player_gender = str(char_data.get("gender", "male"))
	GlobalData.player_class = str(char_data.get("current_job", "novice"))
	GlobalData.current_slot_index = _slot_index_of(char_data)

	if char_data.get("pos_x") != null and char_data.get("pos_y") != null:
		GlobalData.spawn_x = float(char_data.get("pos_x"))
		GlobalData.spawn_y = float(char_data.get("pos_y"))
		GlobalData.has_saved_position = true
	else:
		GlobalData.has_saved_position = false

	var target_scene := WarpHelper.normalize_scene_path(
		str(char_data.get("current_scene", ProjectPaths.WORLD))
	)
	get_tree().change_scene_to_file(target_scene)


func _on_create_character_pressed(slot_index: int) -> void:
	GlobalData.character_id = ""
	GlobalData.current_slot_index = slot_index
	get_tree().change_scene_to_file(SCENE_CREATION)


func _on_delete_character_pressed(char_data: Dictionary) -> void:
	if _is_deleting:
		return
	_pending_delete_char = char_data.duplicate(true)
	var char_name := str(char_data.get("name", "Unknown"))
	_confirm_dialog.dialog_text = (
		"ลบตัวละคร \"%s\" ถาวร?\nการกระทำนี้ไม่สามารถย้อนกลับได้" % char_name
	)
	_confirm_dialog.popup_centered()


func _on_delete_confirmed() -> void:
	if _is_deleting or _pending_delete_char.is_empty():
		return

	var char_id := str(_pending_delete_char.get("character_id", ""))
	if char_id.is_empty():
		_pending_delete_char = {}
		_set_status("ไม่พบรหัสตัวละคร — ลบไม่สำเร็จ", COLOR_STATUS_ERROR)
		return

	_is_deleting = true
	_set_status("กำลังลบตัวละคร...", COLOR_STATUS_PENDING)

	DatabaseManager.delete_character(char_id, func(success: bool) -> void:
		_is_deleting = false
		_pending_delete_char = {}

		if not success:
			_set_status("ลบตัวละครไม่สำเร็จ ลองใหม่อีกครั้ง", COLOR_STATUS_ERROR)
			return

		GlobalData.forget_character(char_id)
		_remove_character_from_list(char_id)
		if characters.is_empty():
			_set_status("ลบสำเร็จ — ยังไม่มีตัวละคร กด + เพื่อสร้างใหม่", COLOR_STATUS_OK)
		else:
			_set_status("ลบตัวละครสำเร็จ", COLOR_STATUS_OK)
		_build_slots()
	)


func _on_back_pressed() -> void:
	SupabaseClient.clear_session()
	get_tree().change_scene_to_file(SCENE_LOGIN)
