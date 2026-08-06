class_name NpcDatabase
extends RefCounted

# npc_db.gd — ศูนย์กลางนิยาม NPC ทั้งหมด
# เพิ่ม/แก้ NPC: แก้ DEFINITIONS ด้านล่าง แล้วตั้ง npc_id ใน scene

const ROLE_QUEST := "quest"
const ROLE_SHOP := "shop"
const ROLE_WARP := "warp"
const ROLE_UPGRADE := "upgrade"
const ROLE_JOB_MASTER := "job_master"
const ROLE_SAVE_POINT := "save_point"

const DEFINITIONS := {
	"quest_board": {
		"name": "Quest Board",
		"role": ROLE_QUEST,
		"dialog": "สวัสดีนักผจญภัย! เลือกเควสที่ต้องการรับ",
		"accept_text": "ดูเควส",
		"show_complete": true,
		"quest_ids": ["hunt_porings", "gather_herbs"],
	},
	"potion_shop": {
		"name": "Potion Merchant",
		"role": ROLE_SHOP,
		"shop_id": "potion_shop",
		"dialog": "ยาบำรุงพลัง ราคาถูก! ซื้อหรือขายได้เลย",
	},
	"weapon_shop": {
		"name": "Weapon Dealer",
		"role": ROLE_SHOP,
		"shop_id": "weapon_shop",
		"dialog": "อาวุธคุณภาพดี สำหรับนักผจญภัย!",
	},
	"general_merchant": {
		"name": "General Merchant",
		"role": ROLE_SHOP,
		"shop_id": "general_store",
		"dialog": "ยินดีต้อนรับ! มีของทุกอย่างที่ต้องการ",
	},
	"job_master": {
		"name": "Job Master",
		"role": ROLE_JOB_MASTER,
		"dialog": "Novice ที่ถึง Lv.15 สามารถรับเควสเปลี่ยนอาชีพได้\nSwordman, Hunter, Thief, Acolyte, Mage",
	},
	"upgrade_master": {
		"name": "Blacksmith",
		"role": ROLE_UPGRADE,
		"dialog": "นำอาวุธและเกราะมาให้ข้าตีบวก!\n(ระบบตีบวกจะเปิดใช้เร็วๆ นี้)",
		"accept_text": "ตีบวก",
	},
	"warp_guide": {
		"name": "Warp Guide",
		"role": ROLE_WARP,
		"dialog": "ต้องการไปที่ไหน? เลือกจุดหมายด้านล่าง",
		"accept_text": "วาร์ป",
		"warp_destinations": [
			{
				"id": "training_field",
				"label": "Training Field",
				"scene": "res://scenes/maps/world.tscn",
				"spawn": Vector2(638, 80),
			},
		],
	},
	"save_point": {
		"name": "Save Point",
		"role": ROLE_SAVE_POINT,
		"dialog": "ยินดีต้อนรับที่จุดบันทึก\nบันทึกที่นี่เพื่อใช้ฟื้นชีพเมื่อตาย",
		"accept_text": "บันทึกจุดเซฟ",
	},
}


static func get_definition(npc_id: String) -> Dictionary:
	if not DEFINITIONS.has(npc_id):
		return {}
	return DEFINITIONS[npc_id].duplicate(true)


static func get_ids_by_role(role: String) -> Array[String]:
	var out: Array[String] = []
	for id in DEFINITIONS.keys():
		if str(DEFINITIONS[id].get("role", "")) == role:
			out.append(id)
	return out


static func role_to_enum(role: String) -> NPC.NpcRole:
	match role:
		ROLE_SHOP:
			return NPC.NpcRole.SHOP
		ROLE_WARP:
			return NPC.NpcRole.WARP
		ROLE_UPGRADE:
			return NPC.NpcRole.UPGRADE
		ROLE_JOB_MASTER:
			return NPC.NpcRole.JOB_MASTER
		ROLE_SAVE_POINT:
			return NPC.NpcRole.SAVE_POINT
		_:
			return NPC.NpcRole.QUEST


static func apply_to_npc(npc: NPC, npc_id: String) -> bool:
	var def := get_definition(npc_id)
	if def.is_empty():
		push_warning("NpcDatabase: ไม่พบ npc_id '%s'" % npc_id)
		return false

	npc.npc_id = npc_id
	npc.npc_name = str(def.get("name", npc.npc_name))
	npc.npc_role = role_to_enum(str(def.get("role", ROLE_QUEST)))
	npc.dialog_message = str(def.get("dialog", npc.dialog_message))

	if def.has("shop_id"):
		npc.shop_id = str(def.get("shop_id", npc.shop_id))

	var warps: Variant = def.get("warp_destinations", [])
	if warps is Array and warps.size() > 0:
		npc.warp_destinations = warps.duplicate(true)
		var first: Dictionary = warps[0]
		npc.warp_target_scene = str(first.get("scene", ""))
		npc.warp_destination_name = str(first.get("label", ""))
		var spawn: Variant = first.get("spawn", Vector2.ZERO)
		npc.warp_spawn_position = spawn if spawn is Vector2 else Vector2.ZERO

	var quests: Variant = def.get("quest_ids", [])
	if quests is Array:
		npc.quest_ids = []
		for qid in quests:
			npc.quest_ids.append(str(qid))

	return true
