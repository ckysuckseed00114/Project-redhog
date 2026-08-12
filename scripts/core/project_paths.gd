class_name ProjectPaths
extends RefCounted

const SCENES := "res://scenes/"
const UI := SCENES + "ui/ui.tscn"
const WORLD := SCENES + "maps/world.tscn"
const CAPITAL := SCENES + "maps/capital_city.tscn"
const WEST_FIELD := SCENES + "maps/west_field.tscn"
const PLAYER := SCENES + "characters/player.tscn"

# Root node names — ต้องตรงกับ scene root (ใช้ใน map_overview)
const MAP_ID_CAPITAL := "CapitalCity"
const MAP_ID_WORLD := "World"
const MAP_ID_WEST_FIELD := "WestField"

static func get_map_display_name(from_world: Node) -> String:
	if from_world == null:
		return "Unknown"
	match str(from_world.name):
		MAP_ID_CAPITAL:
			return "Capital"
		MAP_ID_WEST_FIELD:
			return "West Field"
		MAP_ID_WORLD:
			return "Training Field"
		_:
			return str(from_world.name)
