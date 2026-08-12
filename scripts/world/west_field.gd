class_name WestField
extends World

# west_field.gd — ทุ่งทางตะวันตกของเมืองหลวง (3 มอนสเตอร์)


func get_scenery_exclusions() -> Array[Vector2]:
	return [
		Vector2(1264, 400),
		Vector2(640, 400),
	]
