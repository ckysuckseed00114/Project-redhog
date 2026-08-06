extends Control

var characters: Array = []
const MAX_SLOTS: int = 3
var center_container: CenterContainer
var is_loaded: bool = false
var slots_scroll: HBoxContainer
var back_btn: Button

@onready var main_panel: PanelContainer = $CenterContainer/MainPanel
@onready var v_box: VBoxContainer = $CenterContainer/MainPanel/MarginContainer/VBoxContainer
@onready var title_label: Label = $CenterContainer/MainPanel/MarginContainer/VBoxContainer/TitleLabel

func _ready() -> void:
	UITheme.apply_fonts_recursive(self)
	center_container = $CenterContainer
	
	# สร้างโครงสร้าง UI และเคลียร์ปุ่มซ้ำ
	_init_ui_layout()
	
	print("🚀 เริ่มดึงข้อมูลตัวละครจาก Cloud สำหรับ User ID: ", SupabaseClient.current_user_id)
	
	get_tree().create_timer(3.0).timeout.connect(func():
		if not is_loaded:
			print("⚠️ การเชื่อมต่อฐานข้อมูลรอนานเกินไป บังคับแสดงหน้าจอเลือกตัวละคร")
			is_loaded = true
			_build_slots()
	)
	
	_load_characters()

func _init_ui_layout() -> void:
	var old_list = v_box.get_node_or_null("ItemList")
	if old_list: old_list.queue_free()
	
	var old_actions = v_box.get_node_or_null("ActionButtons")
	if old_actions: old_actions.queue_free()
	
	# ลบปุ่มย้อนกลับตัวเก่า (ถ้ามีค้างอยู่) ป้องกันการแสดงผลซ้ำซ้อน
	var old_back = v_box.get_node_or_null("BackButton")
	if old_back: old_back.queue_free()
	
	var old_scroll = v_box.get_node_or_null("SlotsScroll")
	if old_scroll: old_scroll.queue_free()
	
	slots_scroll = HBoxContainer.new()
	slots_scroll.name = "SlotsScroll"
	slots_scroll.alignment = HBoxContainer.ALIGNMENT_CENTER
	slots_scroll.add_theme_constant_override("separation", 15)
	v_box.add_child(slots_scroll)
	
	for i in range(MAX_SLOTS):
		var slot_panel = _create_single_slot_panel("กำลังโหลด...", null, i, true)
		slots_scroll.add_child(slot_panel)
		
	# สร้างปุ่มย้อนกลับไว้ด้านล่างสุดเพียงปุ่มเดียว
	back_btn = Button.new()
	back_btn.name = "BackButton"
	back_btn.text = "กลับสู่หน้าเข้าสู่ระบบ"
	back_btn.custom_minimum_size = Vector2(0, 38)
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

func _load_characters() -> void:
	var user_id = SupabaseClient.current_user_id
	if user_id == "":
		print("❌ ไม่พบข้อมูลการล็อกอิน กำลังกลับไปหน้า Login")
		get_tree().change_scene_to_file("res://scenes/ui/login_screen.tscn")
		return
		
	var query = "user_id=eq." + user_id
	SupabaseClient.fetch_data("players", query, func(success, response):
		if is_loaded and characters.size() > 0: return
		is_loaded = true
		
		print("📥 ได้รับการตอบกลับจากฐานข้อมูล | Success: ", success)
		
		if success and response is Array:
			characters = response
			print("✅ โหลดสำเร็จ พบตัวละครทั้งหมด: ", characters.size(), " ตัว")
		else:
			characters = []
			print("⚠️ ไม่พบตัวละครเก่า หรือชื่อตาราง 'players' ไม่ถูกต้อง")
			
		_build_slots()
	)

func _build_slots() -> void:
	if not slots_scroll: return
	
	for child in slots_scroll.get_children():
		child.queue_free()
		
	for i in range(MAX_SLOTS):
		var char_data = null
		for c in characters:
			if int(c.get("slot_index", 0)) == i:
				char_data = c
				break
		
		var slot_panel = _create_single_slot_panel("", char_data, i, false)
		slots_scroll.add_child(slot_panel)

func _create_single_slot_panel(loading_text: String, char_data: Variant, i: int, is_loading: bool) -> PanelContainer:
	var slot_panel = PanelContainer.new()
	slot_panel.custom_minimum_size = Vector2(110, 160)
	
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
		lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6, 1))
		lbl.add_theme_font_size_override("font_size", 11)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox_slot.add_child(lbl)
	elif char_data != null:
		var name_lbl = Label.new()
		name_lbl.text = char_data.get("name", "Unknown")
		name_lbl.add_theme_color_override("font_color", Color(0.95, 0.78, 0.25, 1))
		name_lbl.add_theme_font_size_override("font_size", 13)
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox_slot.add_child(name_lbl)
		
		var details_lbl = Label.new()
		var job_id: String = str(char_data.get("current_job", "novice"))
		details_lbl.text = "Lv. %d\n%s" % [char_data.get("level", 1), ClassDatabase.get_display_name(job_id)]
		details_lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8, 1))
		details_lbl.add_theme_font_size_override("font_size", 11)
		details_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox_slot.add_child(details_lbl)
		
		var start_btn = Button.new()
		start_btn.text = "เข้าสู่โลก"
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
		empty_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6, 1))
		empty_lbl.add_theme_font_size_override("font_size", 12)
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox_slot.add_child(empty_lbl)
		
		var create_btn = Button.new()
		create_btn.text = "+"
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
	GlobalData.current_slot_index = int(char_data.get("slot_index", 0))
	
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
	get_tree().change_scene_to_file("res://scenes/ui/login_screen.tscn")
