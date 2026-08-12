class_name CapitalCity
extends BaseMap

# capital_city.gd — Hub map (NPC, Quest Board, Job Master, Warp Guide)


func get_map_theme() -> String:
	return "city"


func get_scenery_exclusions() -> Array[Vector2]:
	return [
		Vector2(634, 407),
		Vector2(520, 520),
		Vector2(714, 421),
		Vector2(480, 421),
		Vector2(600, 421),
		Vector2(780, 421),
		Vector2(440, 560),
		Vector2(640, 782),
		Vector2(640, 400),
	]
