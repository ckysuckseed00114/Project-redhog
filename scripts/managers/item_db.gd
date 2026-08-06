class_name ItemDatabase
extends Node

const ITEMS = {
	"sword01": {
		"id": "sword01",
		"name": "Sword",
		"type": "weapon",
		"attack": 5,
		"defense": 0,
		"count": 1,
		"buy_price": 150,
		"sell_price": 75,
		"stackable": false,
		"icon": "sword01",
		"texture_path": "res://weapon/sword01.tres"
	},
	"armor01": {
		"id": "armor01",
		"name": "Armor",
		"type": "armor",
		"attack": 0,
		"defense": 3,
		"count": 1,
		"buy_price": 120,
		"sell_price": 60,
		"stackable": false,
		"icon": "armor01",
		"texture_path": "res://armor/armor01.tres"
	},
	"red_potion": {
		"id": "red_potion",
		"name": "Red Potion",
		"type": "consumable",
		"subtype": "potion",
		"heal_hp": 50,
		"count": 1,
		"buy_price": 50,
		"sell_price": 25,
		"stackable": true,
		"icon": "item_red_potion",
	},
	"blue_potion": {
		"id": "blue_potion",
		"name": "Blue Potion",
		"type": "consumable",
		"subtype": "potion",
		"heal_sp": 30,
		"count": 1,
		"buy_price": 40,
		"sell_price": 20,
		"stackable": true,
		"icon": "item_blue_potion",
	},
	"white_potion": {
		"id": "white_potion",
		"name": "White Potion",
		"type": "consumable",
		"subtype": "potion",
		"heal_hp": 325,
		"count": 1,
		"buy_price": 1200,
		"sell_price": 600,
		"stackable": true,
		"icon": "item_white_potion",
	},
}

static func get_item(item_id: String) -> Dictionary:
	if ITEMS.has(item_id):
		var data = ITEMS[item_id].duplicate()
		if not data.has("id"):
			data["id"] = item_id
		return data
	return {}


static func is_potion(item: Dictionary) -> bool:
	return ConsumableService.is_potion(item)


static func resolve_item_id(item: Dictionary) -> String:
	var id := str(item.get("id", ""))
	if id != "" and ITEMS.has(id):
		return id
	var icon := str(item.get("icon", ""))
	if icon != "" and ITEMS.has(icon):
		return icon
	var item_name := str(item.get("name", ""))
	var item_type := str(item.get("type", ""))
	for key in ITEMS:
		var def: Dictionary = ITEMS[key]
		if str(def.get("name", "")) == item_name and str(def.get("type", "")) == item_type:
			return key
	if item_name != "":
		for key in ITEMS:
			var base_name := str(ITEMS[key].get("name", ""))
			if base_name != "" and item_name.find(base_name) >= 0:
				return key
	return ""


static func get_sell_price(item_id: String) -> int:
	var def := get_item(item_id)
	if def.is_empty():
		return 0
	var sell_price := int(def.get("sell_price", 0))
	if sell_price > 0:
		return sell_price
	var buy_price := int(def.get("buy_price", 0))
	return int(float(buy_price) / 2.0) if buy_price > 0 else 0
