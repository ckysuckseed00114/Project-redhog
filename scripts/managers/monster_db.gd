class_name MonsterDB
extends Node

const MONSTERS = {
	"poring": {
		"name": "Poring",
		"max_hp": 6,
		"speed": 14.0,
		"chase_range": 100.0,
		"attack_range": 36.0,
		"attack_cooldown": 1.5,
		"exp": 25,
		"scale": Vector2(1.0, 1.0),
		"body_radius": 8.0,
		"click_radius": 32.0,
		"texture_key": "poring",
		"drops": [
			{ "id": "sword01", "chance": 0.5 },
			{ "id": "armor01", "chance": 0.4 }
		]
	},
	"big_poring": {
		"name": "Big Poring",
		"max_hp": 100,
		"speed": 50.0,
		"chase_range": 300.0,
		"attack_range": 48.0,
		"attack_cooldown": 1.0,
		"exp": 120,
		"scale": Vector2(2.0, 2.0),     # ตัวใหญ่คูณ 2 อัตโนมัติจากข้อมูล
		"body_radius": 16.0,            # วงกลมชนใหญ่ขึ้น
		"click_radius": 40.0,
		"is_boss": true,
		"texture_key": "ogre",
		"drops": [
			{ "id": "sword01", "chance": 1.0 },
			{ "id": "armor01", "chance": 1.0 }
		]
	},
	"fabre": {
		"name": "Fabre",
		"max_hp": 10,
		"speed": 10.0,
		"chase_range": 80.0,
		"attack_range": 32.0,
		"attack_cooldown": 2.0,
		"exp": 35,
		"scale": Vector2(1.0, 1.0),
		"body_radius": 8.0,
		"click_radius": 32.0,
		"texture_key": "fabre",
		"drops": [
			{ "id": "armor01", "chance": 0.3 }
		]
	},
	"meadow_goblin": {
		"name": "Meadow Goblin",
		"creature": "Goblin",
		"max_hp": 8,
		"speed": 12.0,
		"chase_range": 90.0,
		"attack_range": 34.0,
		"attack_cooldown": 1.6,
		"exp": 30,
		"scale": Vector2(1.0, 1.0),
		"body_radius": 8.0,
		"click_radius": 32.0,
		"drops": [
			{ "id": "sword01", "chance": 0.25 }
		]
	},
	"thicket_orc": {
		"name": "Thicket Orc",
		"creature": "Orc",
		"max_hp": 14,
		"speed": 11.0,
		"chase_range": 95.0,
		"attack_range": 36.0,
		"attack_cooldown": 1.8,
		"exp": 45,
		"scale": Vector2(1.0, 1.0),
		"body_radius": 9.0,
		"click_radius": 34.0,
		"drops": [
			{ "id": "armor01", "chance": 0.35 }
		]
	},
	"boulder_ogre": {
		"name": "Boulder Ogre",
		"creature": "Ogre",
		"max_hp": 22,
		"speed": 8.0,
		"chase_range": 85.0,
		"attack_range": 40.0,
		"attack_cooldown": 2.2,
		"exp": 70,
		"scale": Vector2(1.15, 1.15),
		"body_radius": 11.0,
		"click_radius": 36.0,
		"drops": [
			{ "id": "sword01", "chance": 0.4 },
			{ "id": "armor01", "chance": 0.3 }
		]
	}
}

static func get_monster(monster_id: String) -> Dictionary:
	if MONSTERS.has(monster_id):
		return MONSTERS[monster_id].duplicate()
	return {}
