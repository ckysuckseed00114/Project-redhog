class_name WestField
extends World

# west_field.gd — ทุ่งทางตะวันตก (3 มอนสเตอร์ + World Boss ฝั่งซ้าย)

const BOSS_SPAWN_FALLBACK := Vector2(160, 360)

@onready var _boss_spawn: Marker2D = $BossSpawn if has_node("BossSpawn") else null


func get_boss_spawn_pos() -> Vector2:
	if _boss_spawn:
		return _boss_spawn.global_position
	return BOSS_SPAWN_FALLBACK


func get_scenery_exclusions() -> Array[Vector2]:
	return [
		Vector2(1264, 400),
		Vector2(640, 400),
		get_boss_spawn_pos(),
	]
