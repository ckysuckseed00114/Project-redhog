extends Node2D

@onready var parent_monster = get_parent()

func _draw() -> void:
	if not is_instance_valid(parent_monster) or not parent_monster.get("is_active_monster"):
		return
		
	var bar_w := 16.0
	var bar_h := 3.0
	var bx := -bar_w / 2.0
	var by := -16.0
	
	# พื้นหลังหลอดเลือด
	draw_rect(Rect2(bx, by, bar_w, bar_h), Color(0, 0, 0, 0.5), true)
	
	# คำนวณเปอร์เซ็นต์และวาดสีแดง
	var max_hp = parent_monster.get("max_hp")
	var current_hp = parent_monster.get("hp")
	if max_hp != null and current_hp != null and max_hp > 0:
		var pct := maxf(0.0, float(current_hp) / float(max_hp))
		draw_rect(Rect2(bx, by, bar_w * pct, bar_h), Color8(0xe7, 0x4c, 0x3c), true)
