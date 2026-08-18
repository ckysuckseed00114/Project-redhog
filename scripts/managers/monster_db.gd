class_name MonsterDB
extends Node

const DEFAULT_DISPLAY_HEIGHT := 48.0
const DEFAULT_BODY_RADIUS_RATIO := 0.17
const DEFAULT_CLICK_RADIUS_RATIO := 0.62

const SPRITE_FOLDER_DEFAULTS := {
	"grassy": { "display_height": 44.0 },
	"slopy": { "display_height": 50.0 },
	"spoey": { "display_height": 56.0 },
	"batty": { "display_height": 46.0 },
	"boby": { "display_height": 52.0 },
	"jibby": { "display_height": 58.0 },
}

const MONSTERS := {
	"poring": {
		"name": "Poring",
		"sprite_folder": "grassy",
		"display_height": 10.0,
		"max_hp": 6,
		"speed": 14.0,
		"chase_range": 100.0,
		"attack_range": 36.0,
		"attack_cooldown": 1.5,
		"exp": 25,
		"drops": [
			{ "id": "sword01", "chance": 0.5 },
			{ "id": "armor01", "chance": 0.4 }
		]
	},
	"big_poring": {
		"name": "Big Poring",
		"sprite_folder": "spoey",
		"display_height": 88.0,
		"max_hp": 100,
		"speed": 50.0,
		"chase_range": 300.0,
		"attack_range": 48.0,
		"attack_cooldown": 1.0,
		"exp": 120,
		"body_radius": 18.0,
		"click_radius": 44.0,
		"is_boss": true,
		"drops": [
			{ "id": "sword01", "chance": 1.0 },
			{ "id": "armor01", "chance": 1.0 }
		]
	},
	"fabre": {
		"name": "Fabre",
		"sprite_folder": "slopy",
		"display_height": 10.0,
		"max_hp": 10,
		"speed": 10.0,
		"chase_range": 80.0,
		"attack_range": 32.0,
		"attack_cooldown": 2.0,
		"exp": 35,
		"drops": [
			{ "id": "armor01", "chance": 0.3 }
		]
	},
	"batty": {
		"name": "Batty",
		"sprite_folder": "batty",
		"display_height": 10.0,
		"max_hp": 8,
		"speed": 12.0,
		"chase_range": 90.0,
		"attack_range": 34.0,
		"attack_cooldown": 1.6,
		"exp": 30,
		"drops": [
			{ "id": "sword01", "chance": 0.25 }
		]
	},
	"boby": {
		"name": "Boby",
		"sprite_folder": "boby",
		"display_height": 10.0,
		"max_hp": 14,
		"speed": 11.0,
		"chase_range": 95.0,
		"attack_range": 36.0,
		"attack_cooldown": 1.8,
		"exp": 45,
		"drops": [
			{ "id": "armor01", "chance": 0.35 }
		]
	},
	"jibby": {
		"name": "Jibby",
		"sprite_folder": "jibby",
		"display_height": 10.0,
		"max_hp": 22,
		"speed": 8.0,
		"chase_range": 85.0,
		"attack_range": 40.0,
		"attack_cooldown": 2.2,
		"exp": 70,
		"drops": [
			{ "id": "sword01", "chance": 0.4 },
			{ "id": "armor01", "chance": 0.3 }
		]
	}
}

# Cloud (Supabase) may override these balance/display-name keys only.
const CLOUD_OVERLAY_KEYS := PackedStringArray([
	"name",
	"hp",
	"max_hp",
	"atk",
	"def",
	"attack",
	"defense",
])

const CLOUD_KEY_ALIASES := {
	"hp": "max_hp",
	"attack": "atk",
	"defense": "def",
}


static func get_monster(monster_id: String) -> Dictionary:
	if monster_id.is_empty():
		return {}

	var local: Dictionary = MONSTERS.get(monster_id, {})
	var cloud: Dictionary = CloudDB.get_monster_row(monster_id)

	if local.is_empty() and cloud.is_empty():
		return {}

	var base := local.duplicate(true) if not local.is_empty() else _base_from_cloud_monster(monster_id, cloud)
	var merged := CloudDB.merge_records(base, cloud, CLOUD_OVERLAY_KEYS, CLOUD_KEY_ALIASES)
	_finalize_monster_record(monster_id, merged)
	return merged


static func get_local_monster(monster_id: String) -> Dictionary:
	if not MONSTERS.has(monster_id):
		return {}
	return MONSTERS[monster_id].duplicate(true)


static func get_sprite_folder(monster_id: String) -> String:
	return str(get_monster(monster_id).get("sprite_folder", ""))


static func resolve_visual(data: Dictionary) -> Dictionary:
	var folder := str(data.get("sprite_folder", ""))
	var folder_defaults: Dictionary = SPRITE_FOLDER_DEFAULTS.get(folder, {})

	var display_height := float(data.get("display_height", folder_defaults.get("display_height", DEFAULT_DISPLAY_HEIGHT)))
	var scale_mul := float(data.get("sprite_scale_mul", 1.0))

	var body_ratio := float(data.get("body_radius_ratio", DEFAULT_BODY_RADIUS_RATIO))
	var click_ratio := float(data.get("click_radius_ratio", DEFAULT_CLICK_RADIUS_RATIO))

	var body_radius := float(data.get("body_radius", display_height * body_ratio))
	var click_radius := float(data.get("click_radius", display_height * click_ratio))

	return {
		"sprite_folder": folder,
		"display_height": display_height,
		"sprite_scale_mul": scale_mul,
		"body_radius": body_radius,
		"click_radius": click_radius,
	}


static func apply_sprite_visual(sprite: AnimatedSprite2D, data: Dictionary) -> Dictionary:
	var visual := resolve_visual(data)
	if sprite != null and not str(visual.get("sprite_folder", "")).is_empty():
		MonsterSpriteLoader.apply_visual(sprite, visual)
	return visual


static func _base_from_cloud_monster(monster_id: String, cloud: Dictionary) -> Dictionary:
	var base := cloud.duplicate(true)
	if cloud.has("hp") and not base.has("max_hp"):
		base["max_hp"] = int(cloud["hp"])
	base["monster_id"] = str(cloud.get("monster_id", monster_id))
	return base


static func _finalize_monster_record(monster_id: String, record: Dictionary) -> void:
	if record.has("hp") and not record.has("max_hp"):
		record["max_hp"] = int(record["hp"])
	elif record.has("max_hp") and not record.has("hp"):
		record["hp"] = int(record["max_hp"])
	if not record.has("monster_id"):
		record["monster_id"] = monster_id
