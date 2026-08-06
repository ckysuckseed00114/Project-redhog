class_name itemfactory
extends Node

static func create_loot_item(item_id: String) -> Dictionary:
	var item_data := ItemDatabase.get_item(item_id)
	if item_data.is_empty():
		return {}

	item_data["id"] = item_id
	if not item_data.has("count"):
		item_data["count"] = 1
	return item_data
