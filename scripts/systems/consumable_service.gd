class_name ConsumableService
extends RefCounted

# consumable_service.gd — ใช้ยา / potion effects

static func is_potion(item: Dictionary) -> bool:
	if item.is_empty() or str(item.get("type", "")) != "consumable":
		return false
	if str(item.get("subtype", "")) == "potion":
		return true
	return item.has("heal_hp") or item.has("heal_sp")


static func use_from_inventory(player: Player, inv_index: int) -> Dictionary:
	if player == null or inv_index < 0 or inv_index >= player.inventory.size():
		return _fail("ช่องไอเทมไม่ถูกต้อง")
	var item: Variant = player.inventory[inv_index]
	if item == null:
		return _fail("ไม่มีไอเทมในช่องนี้")
	return _use_potion(player, item, inv_index)


static func use_by_item_id(player: Player, item_id: String) -> Dictionary:
	if player == null or item_id == "":
		return _fail("ไม่พบไอเทม")
	for i in range(player.inventory.size()):
		var item: Variant = player.inventory[i]
		if item != null and str(item.get("id", "")) == item_id:
			return _use_potion(player, item, i)
	return _fail("ไม่มียาในกระเป๋า")


static func find_inventory_index_for_heal(player: Player, item_ids: Array, heal_type: String) -> int:
	if player == null:
		return -1
	for item_id in item_ids:
		for i in range(player.inventory.size()):
			var item: Variant = player.inventory[i]
			if item == null or not is_potion(item):
				continue
			if str(item.get("id", "")) != str(item_id):
				continue
			var heal_hp := int(item.get("heal_hp", 0))
			var heal_sp := int(item.get("heal_sp", 0))
			match heal_type:
				"hp":
					if heal_hp > 0 and player.hp < player.max_hp:
						return i
				"sp":
					if heal_sp > 0 and player.sp < player.max_sp:
						return i
	return -1


static func _use_potion(player: Player, item: Dictionary, inv_index: int) -> Dictionary:
	if player.is_dead:
		return _fail("ไม่สามารถใช้ไอเทมขณะตาย")
	if not is_potion(item):
		return _fail("Quick Slot ใส่ได้เฉพาะยา")

	var heal_hp := int(item.get("heal_hp", 0))
	var heal_sp := int(item.get("heal_sp", 0))
	if heal_hp <= 0 and heal_sp <= 0:
		return _fail("ยานี้ยังใช้งานไม่ได้")

	var hp_full := player.hp >= player.max_hp
	var sp_full := player.sp >= player.max_sp
	if heal_hp > 0 and heal_sp <= 0 and hp_full:
		return _fail("HP เต็มแล้ว")
	if heal_sp > 0 and heal_hp <= 0 and sp_full:
		return _fail("SP เต็มแล้ว")
	if heal_hp > 0 and heal_sp > 0 and hp_full and sp_full:
		return _fail("HP/SP เต็มแล้ว")

	var actual_hp := 0
	var actual_sp := 0
	if heal_hp > 0:
		var before := player.hp
		player.hp = mini(player.max_hp, player.hp + heal_hp)
		actual_hp = player.hp - before
	if heal_sp > 0:
		var before_sp := player.sp
		player.sp = mini(player.max_sp, player.sp + heal_sp)
		actual_sp = player.sp - before_sp

	_show_heal_fx(player, actual_hp, actual_sp)

	var count := int(item.get("count", 1)) - 1
	if count <= 0:
		player.inventory[inv_index] = null
	else:
		item["count"] = count

	player.inventory_changed.emit()
	player.stats_changed.emit()

	var name := str(item.get("name", "Potion"))
	var parts: Array[String] = []
	if actual_hp > 0:
		parts.append("HP +%d" % actual_hp)
	if actual_sp > 0:
		parts.append("SP +%d" % actual_sp)
	return {
		"ok": true,
		"message": "ใช้ %s (%s)" % [name, ", ".join(parts)],
		"heal_hp": actual_hp,
		"heal_sp": actual_sp,
		"item_id": str(item.get("id", "")),
	}


static func _show_heal_fx(player: Player, heal_hp: int, heal_sp: int) -> void:
	var world := player.get_tree().get_first_node_in_group("world")
	if world == null or not world.has_method("spawn_damage_text"):
		return
	if heal_hp > 0:
		world.spawn_damage_text(player.global_position, heal_hp, false, Color8(0x2e, 0xcc, 0x71))
	if heal_sp > 0:
		world.spawn_damage_text(player.global_position + Vector2(0, -14), heal_sp, false, Color8(0x34, 0x98, 0xdb))


static func _fail(message: String) -> Dictionary:
	return {"ok": false, "message": message, "heal_hp": 0, "heal_sp": 0, "item_id": ""}
