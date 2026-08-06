extends Control

# โครงสร้างหน้า Login (ดึงผ่านโครงสร้าง Panel ใหม่)
@onready var login_vbox: VBoxContainer = $CenterContainer/MainPanel/MarginContainer/VBoxContainer
@onready var login_id_input: LineEdit = $CenterContainer/MainPanel/MarginContainer/VBoxContainer/IDInput
@onready var login_pass_input: LineEdit = $CenterContainer/MainPanel/MarginContainer/VBoxContainer/PasswordInput
@onready var login_button: Button = $CenterContainer/MainPanel/MarginContainer/VBoxContainer/LoginButton
@onready var to_register_button: Button = $CenterContainer/MainPanel/MarginContainer/VBoxContainer/RegisterButton
@onready var login_status_label: Label = $CenterContainer/MainPanel/MarginContainer/VBoxContainer/StatusLabel

# โครงสร้างหน้า Register
@onready var register_view: VBoxContainer = $CenterContainer/MainPanel/MarginContainer/RegisterView
@onready var reg_id_input: LineEdit = $CenterContainer/MainPanel/MarginContainer/RegisterView/IDInput
@onready var reg_pass_input: LineEdit = $CenterContainer/MainPanel/MarginContainer/RegisterView/PasswordInput
@onready var reg_email_input: LineEdit = $CenterContainer/MainPanel/MarginContainer/RegisterView/EmailInput
@onready var submit_register_button: Button = $CenterContainer/MainPanel/MarginContainer/RegisterView/RegisterButton
@onready var back_to_login_button: Button = $CenterContainer/MainPanel/MarginContainer/RegisterView/BackButton
@onready var reg_status_label: Label = $CenterContainer/MainPanel/MarginContainer/RegisterView/StatusLabel

func _ready() -> void:
	
	# ตั้งค่าให้ Label ตัดบรรทัดอัตโนมัติป้องกันข้อความล้นจอ
	login_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	reg_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	
	# เริ่มต้นเปิดเกมมา ให้แสดงแค่หน้า Login และซ่อนหน้า Register
	login_vbox.visible = true
	register_view.visible = false
	
	# เชื่อมสัญญาณปุ่มหน้า Login
	login_button.pressed.connect(_on_login_pressed)
	to_register_button.pressed.connect(_on_switch_to_register_pressed)
	
	# เชื่อมสัญญาณปุ่มหน้า Register
	submit_register_button.pressed.connect(_on_register_pressed)
	back_to_login_button.pressed.connect(_on_switch_to_login_pressed)
	
	# 🌟 เชื่อมสัญญาณเวลากด Enter ที่ช่องพิมพ์ (หน้า Login)
	if login_id_input:
		login_id_input.text_submitted.connect(_on_login_id_entered)
	if login_pass_input:
		login_pass_input.text_submitted.connect(_on_login_password_entered)

	# 🎁 แถมพิเศษ! ทำให้หน้า Register กด Enter เลื่อนช่องและสมัครได้เหมือนกัน
	if reg_id_input:
		reg_id_input.text_submitted.connect(func(_t): if reg_pass_input: reg_pass_input.grab_focus())
	if reg_pass_input:
		reg_pass_input.text_submitted.connect(func(_t): if reg_email_input: reg_email_input.grab_focus())
	if reg_email_input:
		reg_email_input.text_submitted.connect(func(_t): _on_register_pressed())

# สลับไปหน้าสมัครสมาชิก
func _on_switch_to_register_pressed() -> void:
	login_vbox.visible = false
	register_view.visible = true
	login_status_label.text = ""
	reg_id_input.text = ""
	reg_pass_input.text = ""
	reg_email_input.text = ""
	reg_status_label.text = ""

# สลับกลับมาหน้าล็อกอิน
func _on_switch_to_login_pressed() -> void:
	login_vbox.visible = true
	register_view.visible = false
	reg_status_label.text = ""

# กดเข้าสู่ระบบ (ใช้ ID แปลงเป็นอีเมลเบื้องหลังเพื่อให้ตรงกับตอนสมัคร)
func _on_login_pressed() -> void:
	var raw_id = login_id_input.text.strip_edges()
	var password = login_pass_input.text
	
	if raw_id == "" or password == "":
		login_status_label.text = "⚠️ กรุณากรอก ID และ Password ให้ครบถ้วน"
		return
		
	var email = raw_id + "@game.com"
		
	login_status_label.text = "⏳ กำลังเข้าสู่ระบบ..."
	SupabaseClient.sign_in(email, password, func(success, _response):
		if success:
			login_status_label.text = "✅ เข้าสู่ระบบสำเร็จ! กำลังโหลดข้อมูลบัญชี..."
			await get_tree().create_timer(0.5).timeout
			
			# เปลี่ยนฉากไปหน้าเลือกตัวละครแทนการเข้าเกมโดยตรง
			get_tree().change_scene_to_file("res://scenes/ui/character_selection.tscn")
		else:
			login_status_label.text = "❌ เข้าสู่ระบบไม่สำเร็จ (ID หรือรหัสผ่านไม่ถูกต้อง)"
	)

# กดสมัครสมาชิก
func _on_register_pressed() -> void:
	var raw_id = reg_id_input.text.strip_edges()
	var user_email = reg_email_input.text.strip_edges()
	var password = reg_pass_input.text
	
	if raw_id == "" or user_email == "" or password == "":
		reg_status_label.text = "⚠️ กรุณากรอกข้อมูลให้ครบทุกช่อง"
		return
		
	var auth_email = raw_id + "@game.com"
		
	reg_status_label.text = "⏳ กำลังสมัครสมาชิก..."
	SupabaseClient.sign_up(auth_email, password, func(success, _response):
		if success:
			reg_status_label.text = "✅ สมัครสมาชิกสำเร็จ!"
			await get_tree().create_timer(1.0).timeout
			_on_switch_to_login_pressed()
			login_status_label.text = "✅ สมัครสมาชิกสำเร็จ!\nกรุณากรอก ID เพื่อเข้าสู่ระบบ"
		else:
			reg_status_label.text = "❌ สมัครสมาชิกไม่สำเร็จ (ID นี้อาจถูกใช้แล้ว หรือรหัสสั้นเกินไป)"
	)

# 🌟 ฟังก์ชันนี้จะทำงานเมื่อกด Enter ที่ช่อง ID
func _on_login_id_entered(_new_text: String) -> void:
	if login_pass_input:
		# เด้งเคอร์เซอร์ไปรอที่ช่อง Password
		login_pass_input.grab_focus()

# 🌟 ฟังก์ชันนี้จะทำงานเมื่อกด Enter ที่ช่อง Password
func _on_login_password_entered(_new_text: String) -> void:
	# สั่งรันฟังก์ชันเข้าสู่ระบบของบอสทันที
	_on_login_pressed()
