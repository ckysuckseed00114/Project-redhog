class_name SkillDatabase
extends Node

const TYPE_SINGLE := "single_attack"
const TYPE_PASSIVE := "passive"
const TYPE_BUFF := "buff"

const TYPE_LABELS := {
	TYPE_SINGLE: "โจมตีเดี่ยว",
	TYPE_PASSIVE: "พาสซีฟ",
	TYPE_BUFF: "บัพ",
}

const TYPE_COLORS := {
	TYPE_SINGLE: Color8(0xe7, 0x4c, 0x3c),
	TYPE_PASSIVE: Color8(0x95, 0xa5, 0xa6),
	TYPE_BUFF: Color8(0x9b, 0x59, 0xb6),
}

const SKILLS := {
	"first_aid": {
		"name": "First Aid",
		"type_tag": TYPE_BUFF, # 🌟 เปลี่ยนเป็นกดใช้งาน
		"max_level": 1,        # 🌟 ตันที่ 1 (ได้มาแต่เกิด)
		"sp_cost": 10,
		"hp_restore": 5,
		"description": "ฟื้น HP 5 หน่วย (สกิลติดตัวตั้งแต่เริ่ม)",
		"icon_label": "FA",
	},
	"basic_training": {
		"name": "Basic Training",
		"type_tag": TYPE_PASSIVE,
		"max_level": 4,        # 🌟 อัพได้ 4 ขั้น
		"description": "ทักษะพื้นฐาน เพิ่ม Max HP และ Max SP พื้นฐาน",
		"icon_label": "BT",
	},
	"quick_cut": {
		"name": "Quick Cut",
		"type_tag": TYPE_SINGLE,
		"max_level": 5,
		"description": "ฟันอย่างรวดเร็ว โจมตีศัตรูเดี่ยว",
		"icon_label": "QC",
	},
	"skill_pocket": {
		"name": "Skill Pocket",
		"type_tag": TYPE_PASSIVE,
		"max_level": 5,
		"prerequisite": "quick_cut",
		"prereq_level": 1,
		"description": "เพิ่มช่องสกิลที่ใช้งานได้",
		"icon_label": "SP",
	},
	"sugar_stab": {
		"name": "Sugar Stab",
		"type_tag": TYPE_SINGLE,
		"max_level": 5,
		"prerequisite": "skill_pocket",
		"prereq_level": 1,
		"description": "แทงเป้าหมายด้วยพลังหวาน",
		"icon_label": "SS",
	},
	"power_buff": {
		"name": "Power Buff",
		"type_tag": TYPE_BUFF,
		"max_level": 3,
		"prerequisite": "quick_cut",
		"prereq_level": 2,
		"description": "บัพพลังโจมตีชั่วคราว",
		"icon_label": "PB",
	},
}

const JOB_SKILL_ORDER := {
	"novice": ["first_aid", "basic_training"], # 🌟 อัพเดตสกิลสาย Novice
	"sword": ["quick_cut", "skill_pocket", "sugar_stab", "power_buff"],
	"mage": ["quick_cut", "power_buff"],
	"thief": ["quick_cut", "skill_pocket"],
	"acolyte": ["first_aid", "power_buff"],
	"hunter": ["quick_cut", "sugar_stab"],
}


static func get_skill(skill_id: String) -> Dictionary:
	if SKILLS.has(skill_id):
		return SKILLS[skill_id].duplicate()
	return {}


static func get_job_skill_ids(job_id: String) -> Array[String]:
	var ids: Array[String] = []
	if JOB_SKILL_ORDER.has(job_id):
		for sid in JOB_SKILL_ORDER[job_id]:
			ids.append(str(sid))
	elif job_id == "novice":
		ids.append("first_aid")
	return ids


static func get_type_label(type_tag: String) -> String:
	return str(TYPE_LABELS.get(type_tag, type_tag))


static func get_type_color(type_tag: String) -> Color:
	return TYPE_COLORS.get(type_tag, UITheme.MUTED)


static func is_unlocked(player: Player, skill_id: String) -> bool:
	var def := get_skill(skill_id)
	if def.is_empty() or player == null:
		return false
	var prereq := str(def.get("prerequisite", ""))
	if prereq == "":
		return true
	var need := int(def.get("prereq_level", 1))
	return player.get_skill_level(prereq) >= need


static func is_passive(skill_id: String) -> bool:
	var def := get_skill(skill_id)
	return str(def.get("type_tag", "")) == TYPE_PASSIVE


static func can_assign_to_quick_slot(player: Player, skill_id: String) -> bool:
	if player == null or is_passive(skill_id):
		return false
	return player.get_skill_level(skill_id) > 0
