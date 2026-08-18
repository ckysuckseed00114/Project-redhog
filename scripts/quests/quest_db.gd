class_name QuestDatabase
extends RefCounted

# quests/quest_db.gd — นิยามเควสทั้งหมด

const QUESTS := {
	"hunt_porings": {
		"title": "กำจัด Poring มือใหม่",
		"description": "ออกเดินทางไปที่ทุ่งหญ้าแล้วกำจัด Poring จำนวน 3 ตัว",
		"objective_type": "kill",
		"target_id": "poring",
		"target_count": 3,
		"target_map": "res://scenes/maps/world.tscn",
		"nav_hint_pos": Vector2(560, 160),
		"reward_exp": 150,
		"reward_job_exp": 100,
		"reward_zeny": 100,
	},
	"gather_herbs": {
		"title": "เก็บสมุนไพร",
		"description": "รวบรวมสมุนไพร 3 ชิ้น (ระบบเก็บของจะเชื่อมต่อภายหลัง)",
		"objective_type": "gather",
		"target_id": "herb",
		"target_count": 3,
		"target_map": "res://scenes/maps/west_field.tscn",
		"nav_hint_pos": Vector2(640, 360),
		"reward_exp": 80,
		"reward_job_exp": 50,
		"reward_zeny": 50,
	},
}


static func get_quest(quest_id: String) -> Dictionary:
	if QUESTS.has(quest_id):
		return QUESTS[quest_id].duplicate()
	return {}


static func get_display_name(quest_id: String) -> String:
	var q := get_quest(quest_id)
	return str(q.get("title", quest_id))


static func get_target_count(quest_id: String) -> int:
	return int(get_quest(quest_id).get("target_count", 1))


static func get_target_map(quest_id: String) -> String:
	return str(get_quest(quest_id).get("target_map", ""))


static func get_nav_hint_pos(quest_id: String) -> Vector2:
	var hint: Variant = get_quest(quest_id).get("nav_hint_pos", Vector2.ZERO)
	return hint if hint is Vector2 else Vector2.ZERO


static func get_objective_summary(quest_id: String) -> String:
	var def := get_quest(quest_id)
	if def.is_empty():
		return ""
	var obj_type := str(def.get("objective_type", ""))
	var target := str(def.get("target_id", ""))
	var count := int(def.get("target_count", 1))
	match obj_type:
		"kill":
			return "กำจัด %s %d ตัว" % [target, count]
		"gather":
			return "เก็บ %s %d ชิ้น" % [target, count]
		_:
			return str(def.get("description", ""))


static func get_reward_summary(quest_id: String) -> String:
	var def := get_quest(quest_id)
	if def.is_empty():
		return ""
	var parts: PackedStringArray = []
	var reward_exp_val := int(def.get("reward_exp", 0))  # 🌟 เปลี่ยนจาก exp เป็น reward_exp_val
	var job_exp := int(def.get("reward_job_exp", 0))
	var zeny := int(def.get("reward_zeny", 0))
	if reward_exp_val > 0:
		parts.append("EXP %d" % reward_exp_val)
	if job_exp > 0:
		parts.append("Job EXP %d" % job_exp)
	if zeny > 0:
		parts.append("%d Z" % zeny)
	return " | ".join(parts)
