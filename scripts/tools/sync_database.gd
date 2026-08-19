class_name SyncDatabase
extends RefCounted

## Push local ItemDatabase / MonsterDB dictionaries to Supabase (item_db, monster_db).
## Run from editor: open sync_database_push.gd → Script → Run.

const TABLE_ITEMS := "item_db"
const TABLE_MONSTERS := "monster_db"
const HTTP_TIMEOUT_SEC := 30.0

var _host: Node
var _on_complete: Callable
var _summary: Dictionary = {}


static func run_from_editor(editor_root: Node) -> void:
	var host := Node.new()
	host.name = "SyncDatabaseHost"
	editor_root.add_child(host)
	var sync := SyncDatabase.new()
	sync.start_push(host, func(summary: Dictionary) -> void:
		_print_summary(summary)
		host.queue_free()
	)


func start_push(host: Node, on_complete: Callable = Callable()) -> void:
	if host == null or not is_instance_valid(host):
		push_error("SyncDatabase: invalid HTTP host node")
		if on_complete.is_valid():
			on_complete.call(_empty_summary())
		return

	SupabaseConfig.ensure_loaded()
	_host = host
	_on_complete = on_complete
	_summary = {
		"items_ok": [],
		"items_fail": [],
		"monsters_ok": [],
		"monsters_fail": [],
	}

	var item_rows: Array[Dictionary] = _collect_item_rows()
	var monster_rows: Array[Dictionary] = _collect_monster_rows()
	print("SyncDatabase: pushing %d items, %d monsters..." % [item_rows.size(), monster_rows.size()])

	_push_rows_sequential(TABLE_ITEMS, "item_id", item_rows, "items_ok", "items_fail", func() -> void:
		_push_rows_sequential(TABLE_MONSTERS, "monster_id", monster_rows, "monsters_ok", "monsters_fail", func() -> void:
			if _on_complete.is_valid():
				_on_complete.call(_summary)
		)
	)


static func map_item_row(item_id: String, def: Dictionary) -> Dictionary:
	# ส่งเฉพาะคอลัมน์ที่ Supabase item_db มีจริง (minimal schema)
	return {
		"item_id": str(def.get("id", item_id)),
		"name": str(def.get("name", "")),
		"type": str(def.get("type", "")),
		"price": int(def.get("buy_price", def.get("price", 0))),
	}


static func map_monster_row(monster_id: String, def: Dictionary) -> Dictionary:
	var max_hp := int(def.get("max_hp", def.get("hp", 0)))
	# ส่งเฉพาะคอลัมน์ที่ Supabase monster_db มีจริง (minimal schema)
	return {
		"monster_id": monster_id,
		"name": str(def.get("name", "")),
		"hp": max_hp,
		"atk": _estimate_monster_atk(def),
		"def": int(def.get("def", def.get("defense", 0))),
	}


static func _estimate_monster_atk(def: Dictionary) -> int:
	if def.has("atk"):
		return int(def["atk"])
	if def.has("attack"):
		return int(def["attack"])
	if bool(def.get("is_boss", false)):
		var boss_hp := int(def.get("max_hp", 100))
		return maxi(12, int(round(float(boss_hp) * 0.12)))
	var hp := int(def.get("max_hp", 6))
	return clampi(5 + int(round(float(hp) * 0.15)), 5, 9)


func _collect_item_rows() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for item_id in ItemDatabase.ITEMS.keys():
		var def: Dictionary = ItemDatabase.ITEMS[item_id]
		rows.append(map_item_row(str(item_id), def))
	return rows


func _collect_monster_rows() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for monster_id in MonsterDB.MONSTERS.keys():
		var def: Dictionary = MonsterDB.MONSTERS[monster_id]
		rows.append(map_monster_row(str(monster_id), def))
	return rows


func _push_rows_sequential(
	table: String,
	conflict_key: String,
	rows: Array[Dictionary],
	ok_key: String,
	fail_key: String,
	done: Callable
) -> void:
	if rows.is_empty():
		if done.is_valid():
			done.call()
		return
	_push_row_at_index(table, conflict_key, rows, ok_key, fail_key, 0, done)


func _push_row_at_index(
	table: String,
	conflict_key: String,
	rows: Array[Dictionary],
	ok_key: String,
	fail_key: String,
	index: int,
	done: Callable
) -> void:
	if index >= rows.size():
		if done.is_valid():
			done.call()
		return

	var row: Dictionary = rows[index]
	var record_id := str(row.get(conflict_key, "?"))
	_upsert_row(table, conflict_key, row, func(ok: bool, response_code: int, body_text: String) -> void:
		if ok:
			_summary[ok_key].append(record_id)
			print("  ✅ %s/%s" % [table, record_id])
		else:
			_summary[fail_key].append({"id": record_id, "code": response_code, "body": body_text.left(200)})
			push_warning("  ❌ %s/%s HTTP %d — %s" % [table, record_id, response_code, body_text.left(200)])
		_push_row_at_index(table, conflict_key, rows, ok_key, fail_key, index + 1, done)
	)


func _upsert_row(table: String, conflict_key: String, row: Dictionary, done: Callable) -> void:
	var http := HTTPRequest.new()
	_host.add_child(http)
	http.timeout = HTTP_TIMEOUT_SEC

	var url := SupabaseConfig.url + table + "?on_conflict=" + conflict_key.uri_encode()
	var headers := PackedStringArray([
		"apikey: " + SupabaseConfig.anon_key,
		"Authorization: Bearer " + SupabaseConfig.anon_key,
		"Content-Type: application/json",
		"Prefer: resolution=merge-duplicates, return=minimal",
		"Accept-Encoding: identity",
	])

	http.request_completed.connect(func(result: int, response_code: int, _h: PackedStringArray, body: PackedByteArray) -> void:
		http.queue_free()
		var body_text := body.get_string_from_utf8() if not body.is_empty() else ""
		var ok := result == HTTPRequest.RESULT_SUCCESS and response_code >= 200 and response_code < 300
		if done.is_valid():
			done.call(ok, response_code, body_text)
	, CONNECT_ONE_SHOT)

	var err := http.request(url, headers, HTTPClient.METHOD_POST, JSON.stringify(row))
	if err != OK:
		http.queue_free()
		if done.is_valid():
			done.call(false, 0, "HTTPRequest failed to start: %s" % error_string(err))


static func _empty_summary() -> Dictionary:
	return {
		"items_ok": [],
		"items_fail": [],
		"monsters_ok": [],
		"monsters_fail": [],
	}


static func _print_summary(summary: Dictionary) -> void:
	var items_ok: Array = summary.get("items_ok", [])
	var items_fail: Array = summary.get("items_fail", [])
	var monsters_ok: Array = summary.get("monsters_ok", [])
	var monsters_fail: Array = summary.get("monsters_fail", [])
	print("")
	print("=== SyncDatabase Summary ===")
	print("Items:   %d OK, %d failed" % [items_ok.size(), items_fail.size()])
	print("Monsters: %d OK, %d failed" % [monsters_ok.size(), monsters_fail.size()])
	if not items_fail.is_empty() or not monsters_fail.is_empty():
		print("Check warnings above. If HTTP 401/403 → RLS policy. If HTTP 400 → missing columns (run supabase/game_db_tables.sql).")
	else:
		print("All records pushed successfully.")
		print("Restart the game (or re-run) so CloudDB reloads from Supabase.")
	print("============================")
