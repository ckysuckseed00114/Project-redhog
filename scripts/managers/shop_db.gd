class_name ShopDatabase
extends RefCounted

const SHOPS := {
	"general_store": {
		"name": "General Store",
		"items": ["sword01", "armor01", "red_potion"],
	},
	"potion_shop": {
		"name": "Potion Shop",
		"items": ["red_potion", "blue_potion", "white_potion"],
	},
	"weapon_shop": {
		"name": "Weapon Shop",
		"items": ["sword01"],
	},
}


static func get_shop(shop_id: String) -> Dictionary:
	if SHOPS.has(shop_id):
		return SHOPS[shop_id].duplicate()
	return {}


static func get_shop_items(shop_id: String) -> Array[String]:
	var shop := get_shop(shop_id)
	var out: Array[String] = []
	for item_id in shop.get("items", []):
		out.append(String(item_id))
	return out
