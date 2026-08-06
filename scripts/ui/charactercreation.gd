extends Control

@onready var name_input: LineEdit = $CenterContainer/MainPanel/MarginContainer/VBoxContainer/lineedit 
@onready var male_btn = $CenterContainer/MainPanel/MarginContainer/VBoxContainer/HBoxContainer/malebutton     
@onready var female_btn = $CenterContainer/MainPanel/MarginContainer/VBoxContainer/HBoxContainer/femalebutton 
@onready var start_btn = $CenterContainer/MainPanel/MarginContainer/VBoxContainer/button
@onready var back_btn = $CenterContainer/MainPanel/MarginContainer/VBoxContainer/BackButton

# 🌟 เพิ่มการดึง StatusLabel ที่เราเพิ่งสร้างมาใช้งาน
@onready var status_label: Label = $CenterContainer/MainPanel/MarginContainer/VBoxContainer/StatusLabel 

var selected_gender: String = "male"

func _ready() -> void:
	UITheme.apply_fonts_recursive(self)
	if male_btn and not male_btn.pressed.is_connected(_on_male_pressed):
		male_btn.pressed.connect(_on_male_pressed)
			
	if female_btn and not female_btn.pressed.is_connected(_on_female_pressed):
		female_btn.pressed.connect(_on_female_pressed)
	
	if start_btn and not start_btn.pressed.is_connected(_on_button_pressed):
		start_btn.pressed.connect(_on_button_pressed)
			
	if back_btn and not back_btn.pressed.is_connected(_on_back_pressed):
		back_btn.pressed.connect(_on_back_pressed)
		
	# ล้างข้อความแจ้งเตือนตอนเริ่มฉาก
	if status_label:
		status_label.text = ""
		
	# 🌟 [เพิ่มตรงนี้!] เชื่อมสัญญาณเมื่อกด Enter ในช่องกรอกชื่อ
	if name_input and not name_input.text_submitted.is_connected(_on_name_entered):
		name_input.text_submitted.connect(_on_name_entered)
		
	_update_gender_ui()

func _on_male_pressed() -> void:
	selected_gender = "male"
	_update_gender_ui()

func _on_female_pressed() -> void:
	selected_gender = "female"
	_update_gender_ui()

func _update_gender_ui() -> void:
	if male_btn and female_btn:
		if selected_gender == "male":
			male_btn.modulate = Color(1, 1, 1, 1)
			female_btn.modulate = Color(0.4, 0.4, 0.4, 1)
		else:
			male_btn.modulate = Color(0.4, 0.4, 0.4, 1)
			female_btn.modulate = Color(1, 1, 1, 1)

# 🌟 ฟังก์ชันโชว์ข้อความแจ้งเตือนแบบเปลี่ยนสีได้ (เนียนๆ ใต้ปุ่ม)
func _show_status(msg: String, color: Color) -> void:
	if status_label:
		status_label.text = msg
		status_label.add_theme_color_override("font_color", color)

func _on_button_pressed() -> void:
	var typed_name = name_input.text.strip_edges()
	if typed_name == "":
		_show_status("❌ กรุณาตั้งชื่อตัวละคร!", Color8(0xe7, 0x4c, 0x3c)) # เตือนสีแดง
		return
		
	# 🌟 ปิดปุ่มไว้ชั่วคราวระหว่างรอตรวจสอบเน็ตเวิร์ค
	if start_btn:
		start_btn.disabled = true
		
	_show_status("⏳ กำลังตรวจสอบชื่อ...", Color8(0xf1, 0xc4, 0x0f)) # สถานะสีเหลือง
		
	# 1. ส่งไปเช็คก่อนว่าชื่อนี้ถูกใช้ไปหรือยัง
	DatabaseManager.check_name_available(typed_name, func(is_available: bool):
		if is_available:
			# ✅ 2. ถ้าชื่อว่าง ให้ดำเนินการสร้างตัวละคร
			_show_status("✅ ชื่อผ่าน! กำลังสร้างตัวละคร...", Color8(0x2e, 0xcc, 0x71)) # สถานะสีเขียว
			
			GlobalData.player_name = typed_name
			GlobalData.player_gender = selected_gender
			GlobalData.player_class = "novice"
			
			GlobalData.character_id = SupabaseClient.current_user_id + "_" + str(Time.get_ticks_msec())
			
			var initial_player_data = {
				"user_id": SupabaseClient.current_user_id,
				"character_id": GlobalData.character_id,
				"slot_index": GlobalData.current_slot_index,
				"name": GlobalData.player_name,
				"gender": GlobalData.player_gender,
				"current_job": "novice",
				"level": 1,
				"current_exp": 0,
				"max_exp": 100,
				"stat_points": 0,
				"hp": 100,
				"max_hp": 100,
				"sp": 50,
				"max_sp": 50,
				"str_stat": 1,
				"agi": 1,
				"vit": 1,
				"int_stat": 1,
				"dex": 1,
				"luk": 1,
				"pos_x": 0,
				"pos_y": 0,
				"current_scene": "res://scenes/maps/capital_city.tscn"
			}
			
			SupabaseClient.insert_data("players", initial_player_data, func(success, _res):
				if start_btn:
					start_btn.disabled = false
				if not success:
					_show_status("❌ บันทึกตัวละครไม่สำเร็จ ลองใหม่อีกครั้ง", Color8(0xe7, 0x4c, 0x3c))
					return

				print("✅ บันทึกข้อมูลตัวละครใหม่ลง Cloud สำเร็จ")
				GlobalData.remember_created_character(initial_player_data)
				GlobalData.spawn_x = 638.0
				GlobalData.spawn_y = 400.0
				GlobalData.has_saved_position = true
				get_tree().change_scene_to_file("res://scenes/maps/capital_city.tscn")
			)
			
		else:
			# ❌ 3. ถ้าชื่อซ้ำ แจ้งเตือนข้อความสีแดงและเปิดปุ่มใหม่
			if start_btn:
				start_btn.disabled = false
				
			_show_status("❌ ชื่อนี้ถูกใช้งานไปแล้ว กรุณาตั้งชื่อใหม่!", Color8(0xe7, 0x4c, 0x3c)) # เตือนสีแดง
			name_input.text = "" # ล้างช่องแชท
	)

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/character_selection.tscn")
	
# 🌟 ฟังก์ชันนี้จะทำงานเมื่อผู้เล่นกด Enter ในช่องตั้งชื่อ
func _on_name_entered(_new_text: String) -> void:
	_on_button_pressed()
