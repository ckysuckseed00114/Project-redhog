class_name ProjectPaths
extends RefCounted

const SCENES := "res://scenes/"
const SCRIPTS := "res://scripts/"

const LOGIN := SCENES + "ui/login_screen.tscn"
const CHAR_SELECT := SCENES + "ui/character_selection.tscn"
const CHAR_CREATE := SCENES + "ui/charactercreation.tscn"
const UI := SCENES + "ui/ui.tscn"
const WORLD := SCENES + "maps/world.tscn"
const CAPITAL := SCENES + "maps/capital_city.tscn"
const PORTAL := SCENES + "objects/portal.tscn"

# Root node names — ต้องตรงกับ scene root (ใช้ใน map_overview)
const MAP_ID_CAPITAL := "CapitalCity"
const MAP_ID_WORLD := "World"
const PLAYER := SCENES + "characters/player.tscn"
const NPC_SCENE := SCENES + "characters/npc.tscn"
const NPCS := SCENES + "characters/npcs/"
const JOB_MASTER := SCENES + "characters/job_master.tscn"
const BIG_PORING := SCENES + "characters/big_poring.tscn"

static func get_map_display_name(from_world: Node) -> String:
	if from_world == null:
		return "Unknown"
	match str(from_world.name):
		MAP_ID_CAPITAL:
			return "Capital"
		MAP_ID_WORLD:
			return "Training Field"
		_:
			return str(from_world.name)
