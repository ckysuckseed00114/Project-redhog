class_name StatRegistry
extends RefCounted

# Primary stat key → player property name
const PRIMARY := {
	"str": "str_stat",
	"agi": "agi",
	"vit": "vit",
	"int": "int_stat",
	"dex": "dex",
	"luk": "luk",
}

const PRIMARY_LABELS := {
	"str": "STR",
	"agi": "AGI",
	"vit": "VIT",
	"int": "INT",
	"dex": "DEX",
	"luk": "LUK",
}

const DERIVED := {
	"atk": "Attack (ATK)",
	"def": "Defense (DEF)",
	"matk": "Magic ATK (MATK)",
	"mdef": "Magic DEF (MDEF)",
	"aspd": "Attack Speed",
	"hit": "Accuracy (HIT)",
	"flee": "Evasion (FLEE)",
	"hp": "Max HP",
	"mspd": "Move Speed",
}

const VIT_HP_BONUS := 20


static func primary_keys() -> Array:
	return PRIMARY.keys()


static func derived_keys() -> Array:
	return DERIVED.keys()


static func get_label(stat_key: String) -> String:
	if PRIMARY_LABELS.has(stat_key):
		return PRIMARY_LABELS[stat_key]
	if DERIVED.has(stat_key):
		return DERIVED[stat_key]
	return stat_key.to_upper()


static func get_primary(player: Player, key: String) -> int:
	var field: String = PRIMARY.get(key, "")
	if field == "":
		return 0
	return int(player.get(field))


static func spend_point(player: Player, key: String) -> bool:
	if player.stat_points <= 0 or player.is_dead:
		return false
	if not PRIMARY.has(key):
		return false
	var field: String = PRIMARY[key]
	player.set(field, int(player.get(field)) + 1)
	if key == "vit":
		recalculate_max_hp(player)
	player.stat_points -= 1
	player.stats_changed.emit()
	return true


static func recalculate_max_hp(player: Player) -> void:
	var class_info := ClassDatabase.get_class_info(player.current_job)
	var base_hp: int = int(class_info.get("base_hp", 50))
	var vit_bonus := (get_primary(player, "vit") - 1) * VIT_HP_BONUS
	player.max_hp = base_hp + vit_bonus
	player.hp = mini(player.hp, player.max_hp)


static func recalculate_max_sp(player: Player) -> void:
	var class_info := ClassDatabase.get_class_info(player.current_job)
	player.max_sp = int(class_info.get("base_sp", 10))
	player.sp = mini(player.sp, player.max_sp)


static func apply_job_bases(player: Player, _job_id: String) -> void:
	recalculate_max_hp(player)
	recalculate_max_sp(player)


static func get_derived(player: Player, key: String) -> Variant:
	match key:
		"atk":
			return combatcalculator.calculate_attack_damage(get_primary(player, "str"), player.equipment)
		"def":
			return combatcalculator.calculate_defense(get_primary(player, "vit"), player.equipment)
		"matk":
			return combatcalculator.calculate_magic_attack(get_primary(player, "int"))
		"mdef":
			return combatcalculator.calculate_magic_defense(get_primary(player, "int"), player.equipment)
		"aspd":
			return combatcalculator.calculate_attack_speed(get_primary(player, "agi"))
		"hit":
			return combatcalculator.calculate_accuracy(player.level, get_primary(player, "dex"))
		"flee":
			return combatcalculator.calculate_evasion(get_primary(player, "agi"), get_primary(player, "luk"))
		"hp":
			return player.max_hp
		"mspd":
			return combatcalculator.calculate_movement_speed(get_primary(player, "agi"))
	return 0
