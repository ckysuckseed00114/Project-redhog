extends Control

var characters: Array = []
const MAX_SLOTS: int = 3
const MAX_FETCH_RETRIES: int = 3

var center_container: CenterContainer
var is_loaded: bool = false
var slots_scroll: HBoxContainer
var back_btn: Button
var _status_label: Label
var _fetch_generation: int = 0
var _fetch_attempt: int = 0

@onready var main_panel: PanelContainer = $CenterContainer/MainPanel
@onready var v_box: VBoxContainer = $CenterContainer/MainPanel/MarginContainer/VBoxContainer
@onready var title_label: Label = $CenterContainer/MainPanel/MarginContainer/VBoxContainer/TitleLabel


func _ready() -> void:
	UITheme.apply_fonts_recursive(self)
	center_container = $CenterContainer
	_init_ui_layout()
	_set_status("กำลังโหลดตัวละคร...")
	get_tree().create_timer(12.0).timeout.connect(_on_load_timeout, CONNECT_ONE_SHOT)
	call_deferred("_load_characters")


func _on_load_timeout() -> void:
	if is_loaded:
		return
	print("⚠️ โหลดตัวละครหมดเวลา — แสดงช่องว่าง")
	is_loaded = true
	characters = GlobalData.merge_character_rows([], SupabaseClient.current_user_id)
	_set_status("โหลดตัวละครหมดเวลา — กดกลับแล้วเข้าใหม่", Color8(0xe7, 0x4c, 0x3c))
	call_deferred("_build_slots")


func _init_ui_layout() -> void:
	var old_list = v_box.get_node_or_null("ItemList")
	if old_list:
		old_list.queue_free()

	var old_actions = v_box.get_node_or_null("ActionButtons")
	if old_actions:
		old_actions.queue_free()

	var old_back = v_box.get_node_or_null("BackButton")
	if old_back:
		old_back.queue_free()

	var old_scroll = v_box.get_node_or_null("SlotsScroll")
	if old_scroll:
		old_scroll.queue_free()

	var old_status = v_box.get_node_or_null("StatusLabel")
	if old_status:
		old_status.queue_free()

	_status_label = Label.new()
	_status_label.name = "StatusLabel"
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.custom_minimum_size = Vector2(0, 28)
	UITheme.apply_font(_status_label)
	_status_label.add_theme_font_size_override("font_size", 12)
	_status_label.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75, 1))
	v_box.add_child(_status_label)
	if title_label:
		v_box.move_child(_status_label, title_label.get_index() + 1)

	slots_scroll = HBoxContainer.new()
	slots_scroll.name = "SlotsScroll"
	slots_scroll.alignment = HBoxContainer.ALIGNMENT_CENTER
	slots_scroll.add_theme_constant_override("separation", 15)
	slots_scroll.custom_minimum_size = Vector2(0, 170)
	v_box.add_child(slots_scroll)

	for i in range(MAX_SLOTS):
		slots_scroll.add_child(_create_single_slot_panel("กำลังโหลด...", null, i, true))

	back_btn = Button.new()
	back_btn.name = "BackButton"
	back_btn.text = "กลับสู่หน้าเข้าสู่ระบบ"
	back_btn.custom_minimum_size = Vector2(0, 38)
	UITheme.apply_font(back_btn)
	var back_style = StyleBoxFlat.new()
	back_style.bg_color = Color(0.18, 0.14, 0.14, 1)
	back_style.border_width_left = 1
	back_style.border_width_top = 1
	back_style.border_width_right = 1
	back_style.border_width_bottom = 1
	back_style.border_color = Color(0.85, 0.68, 0.2, 1)
	back_style.corner_radius_top_left = 6
	back_style.corner_radius_top_right = 6
	back_style.corner_radius_bottom_right = 6
	back_style.corner_radius_bottom_left = 6
	back_btn.add_theme_stylebox_override("normal", back_style)
	back_btn.add_theme_color_override("font_color", Color(0.95, 0.78, 0.25, 1))
	if not back_btn.pressed.is_connected(_on_back_pressed):
		back_btn.pressed.connect(_on_back_pressed)
	v_box.add_child(back_btn)


func _set_status(text: String, color: Color = Color(0.75, 0.75, 0.75, 1)) -> void:
	if _status_label:
		_status_label.text = text
		_status_label.add_theme_color_override("font_color", color)


func _load_characters() -> void:
	if not SupabaseClient.is_authenticated():
		print("❌ Web/Desktop session ไม่ครบ (user/token) — กลับหน้า Login")
		_set_status("Session หมดอายุ กรุณาเข้าสู่ระบบใหม่", Color8(0xe7, 0x4c, 0x3c))
		get_tree().create_timer(0.8).timeout.connect(func():
			get_tree().change_scene_to_file("res://scenes/ui/login_screen.tscn")
		)
		return

	var user_id := SupabaseClient.current_user_id
	_fetch_generation += 1
	var fetch_gen := _fetch_generation
	var query := "user_id=eq.%s&order=slot_index.asc" % user_id.uri_encode()

	print("🚀 ดึงตัวละคร | User ID: ", user_id, " | token: ", SupabaseClient.current_access_token.length(), " chars")

	SupabaseClient.fetch_data("players", query, func(success, response):
		if fetch_gen != _fetch_generation:
			return

		is_loaded = true
		print("📥 players fetch | success=", success, " rows=", response.size() if response is Array else 0)

		if success and response is Array:
			characters = GlobalData.merge_character_rows(response, user_id)
		else:
			characters = GlobalData.merge_character_rows([], user_id)
			if _fetch_attempt + 1 < MAX_FETCH_RETRIES:
				_fetch_attempt += 1
				_set_status("โหลดไม่สำเร็จ กำลังลองใหม่ (%d/%d)..." % [_fetch_attempt, MAX_FETCH_RETRIES])
				get_tree().create_timer(1.0).timeout.connect(_load_characters)
				return

		_fetch_attempt = 0
		if not success:
			_set_status("โหลดตัวละครไม่สำเร็จ — ลองเข้าสู่ระบบใหม่", Color8(0xe7, 0x4c, 0x3c))
		elif characters.is_empty():
			_set_status("ยังไม่มีตัวละคร — กด + เพื่อสร้างใหม่")
		else:
			_set_status("พบ %d ตัวละคร" % characters.size(), Color8(0x2e, 0xcc, 0x71))

		call_deferred("_build_slots")
	)


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
	var overflow: Array = []
	for row in characters:
		if not row is Dictionary:
			continue
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


func _clear_slots_scroll() -> void:
	if slots_scroll == null:
		return
	for child in slots_scroll.get_children():
		slots_scroll.remove_child(child)
		child.queue_free()


func _build_slots() -> void:
	if slots_scroll == null:
		return

	_clear_slots_scroll()
	var slot_rows := _assign_slots()

	for i in range(MAX_SLOTS):
		var char_data = slot_rows[i]
		slots_scroll.add_child(_create_single_slot_panel("", char_data, i, false))


func _create_single_slot_panel(loading_text: String, char_data: Variant, i: int, is_loading: bool) -> PanelContainer:
	var slot_panel = PanelContainer.new()
	slot_panel.custom_minimum_size = Vector2(110, 160)
	slot_panel.visible = true

	var slot_style = StyleBoxFlat.new()
	slot_style.bg_color = Color(0.12, 0.09, 0.09, 1)
	slot_style.border_width_left = 1
	slot_style.border_width_top = 1
	slot_style.border_width_right = 1
	slot_style.border_width_bottom = 1
	slot_style.border_color = Color(0.85, 0.68, 0.2, 1)
	slot_style.corner_radius_top_left = 8
	slot_style.corner_radius_top_right = 8
	slot_style.corner_radius_bottom_right = 8
	slot_style.corner_radius_bottom_left = 8
	slot_panel.add_theme_stylebox_override("panel", slot_style)

	var vbox_slot = VBoxContainer.new()
	vbox_slot.alignment = VBoxContainer.ALIGNMENT_CENTER
	vbox_slot.add_theme_constant_override("separation", 8)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	margin.add_child(vbox_slot)
	slot_panel.add_child(margin)

	if is_loading:
		var lbl = Label.new()
		lbl.text = loading_text
		UITheme.apply_font(lbl)
		lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6, 1))
		lbl.add_theme_font_size_override("font_size", 11)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox_slot.add_child(lbl)
	elif char_data != null:
		var name_lbl = Label.new()
		name_lbl.text = str(char_data.get("name", "Unknown"))
		UITheme.apply_font(name_lbl)
		name_lbl.add_theme_color_override("font_color", Color(0.95, 0.78, 0.25, 1))
		name_lbl.add_theme_font_size_override("font_size", 13)
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox_slot.add_child(name_lbl)

		var details_lbl = Label.new()
		var job_id: String = str(char_data.get("current_job", "novice"))
		details_lbl.text = "Lv. %d\n%s" % [int(char_data.get("level", 1)), ClassDatabase.get_display_name(job_id)]
		UITheme.apply_font(details_lbl)
		details_lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8, 1))
		details_lbl.add_theme_font_size_override("font_size", 11)
		details_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox_slot.add_child(details_lbl)

		var start_btn = Button.new()
		start_btn.text = "เข้าสู่โลก"
		UITheme.apply_font(start_btn)
		start_btn.custom_minimum_size = Vector2(90, 30)

		var btn_style = StyleBoxFlat.new()
		btn_style.bg_color = Color(0.75, 0.12, 0.12, 1)
		btn_style.corner_radius_top_left = 4
		btn_style.corner_radius_top_right = 4
		btn_style.corner_radius_bottom_right = 4
		btn_style.corner_radius_bottom_left = 4
		start_btn.add_theme_stylebox_override("normal", btn_style)
		start_btn.pressed.connect(_on_start_game_pressed.bind(char_data))
		vbox_slot.add_child(start_btn)
	else:
		var empty_lbl = Label.new()
		empty_lbl.text = "ช่องว่าง"
		UITheme.apply_font(empty_lbl)
		empty_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6, 1))
		empty_lbl.add_theme_font_size_override("font_size", 12)
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox_slot.add_child(empty_lbl)

		var create_btn = Button.new()
		create_btn.text = "+"
		UITheme.apply_font(create_btn)
		create_btn.add_theme_font_size_override("font_size", 22)
		create_btn.custom_minimum_size = Vector2(40, 40)

		var create_style = StyleBoxFlat.new()
		create_style.bg_color = Color(0.18, 0.14, 0.14, 1)
		create_style.border_width_left = 1
		create_style.border_width_top = 1
		create_style.border_width_right = 1
		create_style.border_width_bottom = 1
		create_style.border_color = Color(0.85, 0.68, 0.2, 1)
		create_style.corner_radius_top_left = 20
		create_style.corner_radius_top_right = 20
		create_style.corner_radius_bottom_right = 20
		create_style.corner_radius_bottom_left = 20
		create_btn.add_theme_stylebox_override("normal", create_style)
		create_btn.pressed.connect(_on_create_character_pressed.bind(i))

		var center_btn = CenterContainer.new()
		center_btn.add_child(create_btn)
		vbox_slot.add_child(center_btn)

	return slot_panel


func _on_start_game_pressed(char_data: Dictionary) -> void:
	GlobalData.player_name = char_data.get("name", "Player")
	GlobalData.character_id = str(char_data.get("character_id", ""))
	GlobalData.player_gender = char_data.get("gender", "male")
	GlobalData.player_class = str(char_data.get("current_job", "novice"))
	GlobalData.current_slot_index = _slot_index_of(char_data)

	if char_data.get("pos_x") != null and char_data.get("pos_y") != null:
		GlobalData.spawn_x = float(char_data.get("pos_x"))
		GlobalData.spawn_y = float(char_data.get("pos_y"))
		GlobalData.has_saved_position = true
	else:
		GlobalData.has_saved_position = false

	var target_scene = WarpHelper.normalize_scene_path(
		str(char_data.get("current_scene", ProjectPaths.WORLD))
	)

	get_tree().change_scene_to_file(target_scene)


func _on_create_character_pressed(slot_index: int) -> void:
	GlobalData.character_id = ""
	GlobalData.current_slot_index = slot_index
	get_tree().change_scene_to_file("res://scenes/ui/charactercreation.tscn")


func _on_back_pressed() -> void:
	SupabaseClient.clear_session()
	get_tree().change_scene_to_file("res://scenes/ui/login_screen.tscn")
