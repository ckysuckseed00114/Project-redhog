class_name ClassDatabase
extends Node

const JOB_CHANGE_LEVEL := 15

const CLASSES = {
	"novice": {
		"name": "Novice",
		"base_hp": 50,
		"base_sp": 10,
		"base_attack": 5,
		"base_defense": 2,
		"job_level_max": 10,
		"next_classes": ["sword", "mage", "thief", "acolyte", "hunter"],
		"description": "Starting class for all adventurers."
	},
	"sword": {
		"name": "Swordman",
		"base_hp": 150,
		"base_sp": 20,
		"base_attack": 12,
		"base_defense": 10,
		"job_level_max": 50,
		"skills": ["bash", "provoke", "endure"],
		"description": "Strong melee fighter specialized in defense and swords."
	},
	"mage": {
		"name": "Mage",
		"base_hp": 60,
		"base_sp": 100,
		"base_attack": 6,
		"base_defense": 3,
		"job_level_max": 50,
		"skills": ["firebolt", "cold_bolt", "lightning_bolt"],
		"description": "Powerful spellcaster wielding elemental magic."
	},
	"thief": {
		"name": "Thief",
		"base_hp": 100,
		"base_sp": 30,
		"base_attack": 10,
		"base_defense": 5,
		"job_level_max": 50,
		"skills": ["double_attack", "steal", "hiding"],
		"description": "Agile fighter focused on speed and evasion."
	},
	"acolyte": {
		"name": "Acolyte",
		"base_hp": 80,
		"base_sp": 50,
		"base_attack": 6,
		"base_defense": 4,
		"job_level_max": 50,
		"skills": ["heal", "cure", "blessing"],
		"description": "Divine servant supporting allies with healing and buffs."
	},
	"hunter": {
		"name": "Hunter",
		"base_hp": 110,
		"base_sp": 40,
		"base_attack": 14,
		"base_defense": 6,
		"job_level_max": 50,
		"skills": ["double_strafe", "arrow_shower", "setting_trap"],
		"description": "Ranged specialist utilizing bows and traps."
	}
}


static func get_class_info(class_id: String) -> Dictionary:
	if CLASSES.has(class_id.to_lower()):
		return CLASSES[class_id.to_lower()].duplicate()
	return {}


static func get_display_name(class_id: String) -> String:
	var info := get_class_info(class_id)
	return info.get("name", class_id.capitalize())


static func get_next_jobs(from_job: String) -> Array:
	var info := get_class_info(from_job)
	return info.get("next_classes", []).duplicate()


static func can_advance_from_novice(level: int) -> bool:
	return level >= JOB_CHANGE_LEVEL


static func is_valid_job_change(from_job: String, to_job: String) -> bool:
	if from_job != "novice":
		return false
	return to_job in get_next_jobs("novice")
