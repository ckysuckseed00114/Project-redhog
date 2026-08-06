class_name ShopService
extends RefCounted

static func buy(player: Player, item_id: String, count: int = 1) -> Dictionary:
	if player == null or count <= 0:
		return {"ok": false, "message": "Invalid request"}
	var item_def := ItemDatabase.get_item(item_id)
	if item_def.is_empty():
		return {"ok": false, "message": "Unknown item"}
	var unit_price: int = int(item_def.get("buy_price", 0))
	if unit_price <= 0:
		return {"ok": false, "message": "Item not for sale"}
	var total := unit_price * count
	if player.zeny < total:
		return {"ok": false, "message": "Zeny not enough (%d needed)" % total}
	if not player.can_fit_item(item_id, count):
		return {"ok": false, "message": "Inventory full"}
	if not player.spend_zeny(total):
		return {"ok": false, "message": "Zeny not enough"}
	if not player.grant_item(item_id, count):
		player.add_zeny(total)
		return {"ok": false, "message": "Inventory full"}
	player.inventory_changed.emit()
	player.stats_changed.emit()
	return {"ok": true, "message": "Bought %dx %s" % [count, item_def.get("name", item_id)]}


static func sell(player: Player, inv_index: int, count: int = 1) -> Dictionary:
	if player == null or count <= 0:
		return {"ok": false, "message": "Invalid request"}
	if inv_index < 0 or inv_index >= player.inventory.size():
		return {"ok": false, "message": "Invalid slot"}
	var item: Variant = player.inventory[inv_index]
	if item == null:
		return {"ok": false, "message": "Empty slot"}
	var item_id: String = ItemDatabase.resolve_item_id(item)
	if item_id == "":
		return {"ok": false, "message": "Cannot sell this item"}
	var _item_def := ItemDatabase.get_item(item_id)
	var unit_price: int = ItemDatabase.get_sell_price(item_id)
	if unit_price <= 0:
		return {"ok": false, "message": "Shop won't buy this"}
	var have: int = int(item.get("count", 1))
	var sell_count := mini(count, have)
	var payout := unit_price * sell_count
	var removed := player.remove_item_at(inv_index, sell_count)
	if removed.is_empty():
		return {"ok": false, "message": "Could not sell item"}
	player.add_zeny(payout)
	player.inventory_changed.emit()
	player.stats_changed.emit()
	return {"ok": true, "message": "Sold for %d zeny" % payout}
