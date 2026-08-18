extends Node

const SUPABASE_URL := "https://hfewlpkkflvahpcqoubr.supabase.co"
const SUPABASE_ANON_KEY := "sb_publishable_x5EiaU-iJBPw7JpKF-0gyw_tCVp33lP"

enum LoadState { PENDING, LOADED, FAILED }

var items_cache: Dictionary = {}
var monsters_cache: Dictionary = {}
var items_load_state: LoadState = LoadState.PENDING
var monsters_load_state: LoadState = LoadState.PENDING

signal data_loaded
signal items_cache_ready
signal monsters_cache_ready


func _ready() -> void:
	_fetch_table("item_db")
	_fetch_table("monster_db")


func is_items_ready() -> bool:
	return items_load_state == LoadState.LOADED


func is_monsters_ready() -> bool:
	return monsters_load_state == LoadState.LOADED


func is_offline_or_empty() -> bool:
	return items_load_state == LoadState.FAILED \
		and monsters_load_state == LoadState.FAILED


func get_item_row(item_id: String) -> Dictionary:
	if item_id.is_empty():
		return {}
	var row: Variant = items_cache.get(item_id, {})
	return row if row is Dictionary else {}


func get_monster_row(monster_id: String) -> Dictionary:
	if monster_id.is_empty():
		return {}
	var row: Variant = monsters_cache.get(monster_id, {})
	return row if row is Dictionary else {}


func get_item(item_id: String) -> Dictionary:
	return get_item_row(item_id)


func get_monster(monster_id: String) -> Dictionary:
	return get_monster_row(monster_id)


static func merge_records(
	base: Dictionary,
	cloud: Dictionary,
	overlay_keys: PackedStringArray,
	aliases: Dictionary = {}
) -> Dictionary:
	var merged := base.duplicate(true)
	if cloud.is_empty():
		return merged

	for key in overlay_keys:
		if not cloud.has(key):
			continue
		var value: Variant = cloud[key]
		if is_merge_empty(value):
			continue
		var target_key := str(aliases.get(key, key))
		merged[target_key] = value

	return merged


static func is_merge_empty(value: Variant) -> bool:
	if value == null:
		return true
	if value is String:
		return str(value).strip_edges().is_empty()
	if value is Array:
		return (value as Array).is_empty()
	return false


func _fetch_table(table_name: String) -> void:
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(
		func(result: int, code: int, response_headers: PackedStringArray, body: PackedByteArray) -> void:
			_on_request_completed(result, code, response_headers, body, table_name, http)
	)

	var url := SUPABASE_URL + "/rest/v1/" + table_name + "?select=*"
	var req_headers := PackedStringArray([
		"apikey: " + SUPABASE_ANON_KEY,
		"Authorization: Bearer " + SUPABASE_ANON_KEY,
		"Content-Type: application/json",
	])

	var err := http.request(url, req_headers)
	if err != OK:
		_mark_table_failed(table_name, "HTTPRequest error %s" % err)


func _on_request_completed(
	_result: int,
	response_code: int,
	_headers: PackedStringArray,
	body: PackedByteArray,
	table_name: String,
	http_node: HTTPRequest
) -> void:
	http_node.queue_free()

	if response_code != 200:
		_mark_table_failed(table_name, "Response Code: %s" % response_code)
		return

	var json := JSON.new()
	if json.parse(body.get_string_from_utf8()) != OK:
		_mark_table_failed(table_name, "JSON parse failed")
		return

	var records: Variant = json.get_data()
	if not records is Array:
		_mark_table_failed(table_name, "Expected array payload")
		return

	if table_name == "item_db":
		_populate_items_cache(records as Array)
	elif table_name == "monster_db":
		_populate_monsters_cache(records as Array)
	else:
		return

	data_loaded.emit()


func _populate_items_cache(records: Array) -> void:
	items_cache.clear()
	for row in records:
		if row is Dictionary:
			var item_id := str(row.get("item_id", ""))
			if not item_id.is_empty():
				items_cache[item_id] = row
	items_load_state = LoadState.LOADED
	if OS.is_debug_build():
		print("CloudDB: loaded %d items" % items_cache.size())
	items_cache_ready.emit()


func _populate_monsters_cache(records: Array) -> void:
	monsters_cache.clear()
	for row in records:
		if row is Dictionary:
			var monster_id := str(row.get("monster_id", ""))
			if not monster_id.is_empty():
				monsters_cache[monster_id] = row
	monsters_load_state = LoadState.LOADED
	if OS.is_debug_build():
		print("CloudDB: loaded %d monsters" % monsters_cache.size())
	monsters_cache_ready.emit()


func _mark_table_failed(table_name: String, reason: String) -> void:
	if table_name == "item_db":
		items_load_state = LoadState.FAILED
	elif table_name == "monster_db":
		monsters_load_state = LoadState.FAILED
	push_warning("CloudDB: failed to load %s (%s) — using local fallback data." % [table_name, reason])
