extends Node

var log_file_path = "user://game_error_log.txt"

func _ready() -> void:
	# สร้างไฟล์ Log ใหม่ทุกครั้งที่เปิดเกม
	var file = FileAccess.open(log_file_path, FileAccess.WRITE)
	if file:
		file.store_string("=== Redhog Game Log Started ===\n")
		file.close()

# ฟังก์ชันสำหรับบันทึกข้อความหรือ Error ลงไฟล์
func log_error(error_message: String) -> void:
	var file = FileAccess.open(log_file_path, FileAccess.READ_WRITE)
	if file:
		file.seek_end() # ต่อท้ายข้อความเดิม
		var time_str = Time.get_datetime_string_from_system()
		file.store_string("[%s] ERROR: %s\n" % [time_str, error_message])
		file.close()
		
	# ปริ้นท์โชว์ใน Console ของเครื่องผู้เล่นด้วย (เผื่อรันผ่าน CMD)
	printerr(error_message)
