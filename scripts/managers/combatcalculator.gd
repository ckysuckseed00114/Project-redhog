class_name combatcalculator
extends Node

# คำนวณพลังโจมตีทางกายภาพ
static func calculate_attack_damage(str_stat: int, equipment: Dictionary) -> int:
	var base_atk = 2 + int(floor(float(str_stat) * 0.5))
	var weapon_atk = 0
	if equipment.has("weapon") and equipment["weapon"] != null:
		weapon_atk = equipment["weapon"].get("attack", 0)
	return base_atk + weapon_atk

# คำนวณพลังป้องกัน
static func calculate_defense(vit: int, equipment: Dictionary) -> int:
	var base_def = int(floor(float(vit) * 0.2))
	var eq_def = 0
	for key in ["armor", "helm", "garment", "shield", "boots"]:
		if equipment.has(key) and equipment[key] != null:
			eq_def += equipment[key].get("defense", 0)
	return base_def + eq_def

# คำนวณพลังโจมตีเวทมนตร์
static func calculate_magic_attack(int_stat: int) -> int:
	return int_stat * 2

# คำนวณพลังป้องกันเวทมนตร์
static func calculate_magic_defense(int_stat: int, equipment: Dictionary) -> int:
	var base_mdef := int(floor(float(int_stat) * 0.2))
	var eq_mdef := 0
	for key in ["armor", "helm", "garment", "shield", "boots"]:
		if equipment.has(key) and equipment[key] != null:
			eq_mdef += int(equipment[key].get("mdef", 0))
	return base_mdef + eq_mdef

# คำนวณความเร็วในการโจมตี (ASPD)
static func calculate_attack_speed(agi: int) -> float:
	return 1.0 + (float(agi) * 0.02)

# คำนวณความเร็วในการเคลื่อนที่
static func calculate_movement_speed(agi: int) -> float:
	return float(GameConstants.PLAYER_SPEED) + ((float(agi) - 1.0) * 0.8)

# คำนวณความแม่นยำ (HIT)
static func calculate_accuracy(level: int, dex: int) -> int:
	return level + dex

# คำนวณอัตราการหลบหลีก (FLEE)
static func calculate_evasion(agi: int, luk: int) -> int:
	return int(floor(float(agi) * 0.5)) + int(floor(float(luk) * 0.2))
