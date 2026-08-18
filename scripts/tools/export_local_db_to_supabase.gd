@tool
extends EditorScript
## One-time exporter: local ItemDatabase / MonsterDB → Supabase seed JSON.
##
## Run in Godot: open this script → Script menu → Run (EditorScript).
##
## Writes:
##   res://data/supabase_seed/item_db_minimal.json
##   res://data/supabase_seed/monster_db_minimal.json
##   res://data/supabase_seed/item_db_full.json
##   res://data/supabase_seed/monster_db_full.json


const OUTPUT_DIR := "res://data/supabase_seed/"


func _run() -> void:
	export_all(OUTPUT_DIR)
	print("Done. Seed files written to ", OUTPUT_DIR)


static func export_all(output_dir: String = "res://data/supabase_seed/") -> void:
	_ensure_dir(output_dir)

	var items_minimal := export_items_minimal()
	var monsters_minimal := export_monsters_minimal()
	var items_full := export_items_full()
	var monsters_full := export_monsters_full()

	_write_json(output_dir.path_join("item_db_minimal.json"), items_minimal)
	_write_json(output_dir.path_join("monster_db_minimal.json"), monsters_minimal)
	_write_json(output_dir.path_join("item_db_full.json"), items_full)
	_write_json(output_dir.path_join("monster_db_full.json"), monsters_full)

	print("=== item_db (minimal) ===")
	print(JSON.stringify(items_minimal, "\t"))
	print("=== monster_db (minimal) ===")
	print(JSON.stringify(monsters_minimal, "\t"))
	print("=== item_db (full) ===")
	print(JSON.stringify(items_full, "\t"))
	print("=== monster_db (full) ===")
	print(JSON.stringify(monsters_full, "\t"))


static func export_items_minimal() -> Array:
	var rows: Array = []
	for item_id in ItemDatabase.ITEMS.keys():
		var def: Dictionary = ItemDatabase.ITEMS[item_id]
		rows.append({
			"item_id": str(def.get("id", item_id)),
			"name": str(def.get("name", "")),
			"type": str(def.get("type", "")),
			"price": int(def.get("buy_price", def.get("price", 0))),
		})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.get("item_id", "")) < str(b.get("item_id", ""))
	)
	return rows


static func export_monsters_minimal() -> Array:
	var rows: Array = []
	for monster_id in MonsterDB.MONSTERS.keys():
		var def: Dictionary = MonsterDB.MONSTERS[monster_id]
		rows.append({
			"monster_id": monster_id,
			"name": str(def.get("name", "")),
			"hp": int(def.get("max_hp", def.get("hp", 0))),
			"atk": _estimate_monster_atk(def),
			"def": int(def.get("def", 0)),
		})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.get("monster_id", "")) < str(b.get("monster_id", ""))
	)
	return rows


static func export_items_full() -> Array:
	var rows: Array = []
	for item_id in ItemDatabase.ITEMS.keys():
		var def: Dictionary = ItemDatabase.ITEMS[item_id].duplicate(true)
		var row: Dictionary = {
			"item_id": str(def.get("id", item_id)),
			"name": str(def.get("name", "")),
			"type": str(def.get("type", "")),
			"price": int(def.get("buy_price", def.get("price", 0))),
		}
		def.erase("id")
		for key in def.keys():
			if not row.has(key):
				row[key] = def[key]
		rows.append(row)
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.get("item_id", "")) < str(b.get("item_id", ""))
	)
	return rows


static func export_monsters_full() -> Array:
	var rows: Array = []
	for monster_id in MonsterDB.MONSTERS.keys():
		var def: Dictionary = MonsterDB.MONSTERS[monster_id].duplicate(true)
		var row: Dictionary = {
			"monster_id": monster_id,
			"name": str(def.get("name", "")),
			"hp": int(def.get("max_hp", def.get("hp", 0))),
			"max_hp": int(def.get("max_hp", def.get("hp", 0))),
			"atk": _estimate_monster_atk(def),
			"def": int(def.get("def", 0)),
		}
		for key in def.keys():
			if key == "max_hp":
				continue
			if not row.has(key):
				row[key] = def[key]
		rows.append(row)
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.get("monster_id", "")) < str(b.get("monster_id", ""))
	)
	return rows


static func _estimate_monster_atk(def: Dictionary) -> int:
	if def.has("atk"):
		return int(def["atk"])
	# monster.gd uses randi_range(5, 9) for normal mobs — seed the midpoint.
	if bool(def.get("is_boss", false)):
		var boss_hp := int(def.get("max_hp", 100))
		return maxi(12, int(round(float(boss_hp) * 0.12)))
	var hp := int(def.get("max_hp", 6))
	return clampi(5 + int(round(float(hp) * 0.15)), 5, 9)


static func _ensure_dir(path: String) -> void:
	var absolute := ProjectSettings.globalize_path(path)
	DirAccess.make_dir_recursive_absolute(absolute)


static func _write_json(path: String, data: Variant) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Cannot write seed file: %s" % path)
		return
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
