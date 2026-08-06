class_name PlayerAutoPotion
extends RefCounted

# Auto-use HP/SP potions when ratio drops below configured thresholds.

const HP_POTION_IDS: Array[String] = ["white_potion", "red_potion"]
const SP_POTION_IDS: Array[String] = ["blue_potion"]

const DEFAULT_COOLDOWN := 0.45

var enabled: bool = true
var hp_threshold: float = 0.50
var sp_threshold: float = 0.30
var cooldown_sec: float = DEFAULT_COOLDOWN

var _cooldown_left: float = 0.0


func tick(player: Player, delta: float) -> void:
	if not enabled or player == null or player.is_dead or player.is_talking:
		return

	_cooldown_left -= delta
	if _cooldown_left > 0.0:
		return

	var max_hp := maxi(1, player.max_hp)
	var max_sp := maxi(1, player.max_sp)
	var hp_ratio := float(player.hp) / float(max_hp)
	var sp_ratio := float(player.sp) / float(max_sp)

	if hp_ratio <= hp_threshold and player.hp < player.max_hp:
		var hp_idx := ConsumableService.find_inventory_index_for_heal(player, HP_POTION_IDS, "hp")
		if hp_idx >= 0:
			var result := ConsumableService.use_from_inventory(player, hp_idx)
			if bool(result.get("ok", false)):
				_cooldown_left = cooldown_sec
				return

	if sp_ratio <= sp_threshold and player.sp < player.max_sp:
		var sp_idx := ConsumableService.find_inventory_index_for_heal(player, SP_POTION_IDS, "sp")
		if sp_idx >= 0:
			var result := ConsumableService.use_from_inventory(player, sp_idx)
			if bool(result.get("ok", false)):
				_cooldown_left = cooldown_sec
