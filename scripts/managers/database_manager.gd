extends Node

# database_manager.gd — save_game_data | load_game_data (await-friendly)

signal save_completed(success: bool)

var _save_queue: Array[Dictionary] = []
var _save_running: bool = false
var _last_payload: Dictionary = {}
var _next_save_id: int = 0
var _save_results: Dictionary = {}


func _db_int(value: Variant, default_val: int = 0) -> int:
	if value == null:
		return default_val
	match typeof(value):
		TYPE_INT:
			return value
		TYPE_FLOAT:
			return int(value)
		TYPE_STRING:
			if str(value).is_valid_float():
				return int(float(value))
			if str(value).is_valid_int():
				return str(value).to_int()
	return default_val


func _can_cloud_save() -> bool:
	return SupabaseClient.current_user_id != ""


func _emit_save_completed(success: bool) -> void:
	save_completed.emit(success)


# --- Save ---

func save_game_data(player) -> int:
	var payload := _capture_payload(player)
	if payload.is_empty():
		call_deferred("_emit_save_completed", false)
		return -1

	_last_payload = payload

	if not _can_cloud_save():
		call_deferred("_emit_save_completed", true)
		return 0

	_next_save_id += 1
	var save_id := _next_save_id
	payload["save_id"] = save_id
	_save_queue.append(payload)
	if not _save_running:
		_run_next_save()
	return save_id


func wait_for_save_id(save_id: int) -> bool:
	if save_id <= 0:
		return true
	while not _save_results.has(save_id):
		await save_completed
	var ok: bool = bool(_save_results[save_id])
	_save_results.erase(save_id)
	return ok


func _run_next_save() -> void:
	if _save_queue.is_empty():
		_save_running = false
		return

	_save_running = true
	var payload: Dictionary = _save_queue.pop_front()
	var save_id: int = int(payload.get("save_id", 0))
	_persist_payload(payload, func(success: bool) -> void:
		if success:
			print("✅ บันทึกตำแหน่งและสถานะตัวละครสำเร็จ")
			if is_inside_tree():
				var ui := UiAccess.get_ui(self)
				if ui and ui.has_method("show_notification"):
					ui.show_notification("Game Saved to Cloud!", Color8(0x2e, 0xcc, 0x71))
		else:
			push_warning("❌ Cloud save failed")
		if save_id > 0:
			_save_results[save_id] = success
		_emit_save_completed(success)
		_run_next_save()
	)


func _capture_payload(player: Player) -> Dictionary:
	if player == null:
		return {}

	var user_id := SupabaseClient.current_user_id
	if user_id == "":
		return {}

	if GlobalData.character_id == "":
		GlobalData.character_id = user_id + "_" + str(Time.get_ticks_msec())

	var char_id := GlobalData.character_id
	print("กำลังเตรียมข้อมูลบันทึกสำหรับ Character ID: ", char_id)

	var player_row := {
		"user_id": user_id,
		"character_id": char_id,
		"name": GlobalData.player_name,
		"gender": GlobalData.player_gender,
		"current_job": player.current_job,
		"level": player.level,
		"current_exp": player.current_exp,
		"max_exp": player.max_exp,
		"stat_points": player.stat_points,
		"job_level": player.job_level,
		"job_exp": player.job_exp,
		"max_job_exp": player.max_job_exp,
		"job_points": player.job_points,
		"hp": player.hp,
		"max_hp": player.max_hp,
		"sp": player.sp,
		"max_sp": player.max_sp,
		"str_stat": player.str_stat,
		"agi": player.agi,
		"vit": player.vit,
		"int_stat": player.int_stat,
		"dex": player.dex,
		"luk": player.luk,
		"zeny": player.zeny,
		"pos_x": float(player.global_position.x),
		"pos_y": float(player.global_position.y),
		"current_scene": _resolve_save_scene(player),
		"active_quests": player.active_quests.duplicate(true),
		"finished_quests": player.finished_quests.duplicate(),
		"quick_slots": player.quick_slots.duplicate(true),
	}
	player_row.merge(SavePointService.to_save_fields())

	var equipment_records: Array[Dictionary] = []
	for slot_key in player.equipment.keys():
		var item: Variant = player.equipment[slot_key]
		if item != null:
			equipment_records.append({
				"user_id": user_id,
				"character_id": char_id,
				"slot_key": slot_key,
				"item_data": item,
			})

	var inventory_records: Array[Dictionary] = []
	for i in range(player.inventory.size()):
		var item: Variant = player.inventory[i]
		if item != null:
			inventory_records.append({
				"user_id": user_id,
				"character_id": char_id,
				"slot_index": i,
				"item_id": str(item.get("id", "")),
				"count": int(round(float(item.get("count", 1)))),
				"item_data": item,
			})

	return {
		"user_id": user_id,
		"character_id": char_id,
		"player_row": player_row,
		"equipment_records": equipment_records,
		"inventory_records": inventory_records,
	}


func _persist_payload(payload: Dictionary, done: Callable) -> void:
	var char_id: String = str(payload.get("character_id", ""))
	var player_row: Dictionary = payload.get("player_row", {})
	if char_id == "" or player_row.is_empty():
		done.call(false)
		return

	var query := "character_id=eq." + char_id.uri_encode()
	SupabaseClient.update_data("players", query, player_row, func(success: bool, _res: Variant) -> void:
		if success:
			_sync_related_tables(payload, done)
			return
		SupabaseClient.insert_data("players", player_row, func(ins_success: bool, _ins_res: Variant) -> void:
			if ins_success:
				print("✅ สร้างข้อมูลตัวละครใหม่สำเร็จ")
				_sync_related_tables(payload, done)
			else:
				done.call(false)
		)
	)


func _sync_related_tables(payload: Dictionary, done: Callable) -> void:
	var char_id: String = str(payload.get("character_id", ""))
	var eq_query := "character_id=eq." + char_id.uri_encode()
	SupabaseClient.delete_data("player_equipment", eq_query, func(_eq_del_ok: bool) -> void:
		_insert_equipment_records(payload, func(eq_ok: bool) -> void:
			if not eq_ok:
				done.call(false)
				return
			var inv_query := "character_id=eq." + char_id.uri_encode()
			SupabaseClient.delete_data("player_inventory", inv_query, func(_inv_del_ok: bool) -> void:
				_insert_inventory_records(payload, done)
			)
		)
	)


func _insert_equipment_records(payload: Dictionary, done: Callable) -> void:
	var records: Array = payload.get("equipment_records", [])
	if records.is_empty():
		done.call(true)
		return
	_wait_for_inserts(records, "player_equipment", done)


func _insert_inventory_records(payload: Dictionary, done: Callable) -> void:
	var records: Array = payload.get("inventory_records", [])
	if records.is_empty():
		done.call(true)
		return
	_wait_for_inserts(records, "player_inventory", done)


func _wait_for_inserts(records: Array, table: String, done: Callable) -> void:
	var remaining_count: Array[int] = [records.size()]
	var failed_flag: Array[bool] = [false]
	
	for record in records:
		if not record is Dictionary:
			remaining_count[0] -= 1
			if remaining_count[0] <= 0:
				done.call(not failed_flag[0])
			continue
			
		SupabaseClient.insert_data(table, record, func(ok: bool, _res: Variant) -> void:
			if not ok:
				failed_flag[0] = true
			remaining_count[0] -= 1
			if remaining_count[0] <= 0:
				done.call(not failed_flag[0])
		)
# --- Load ---

func _apply_player_stats_from_row(p: Player, row: Dictionary) -> void:
	p.stat_points = _db_int(row.get("stat_points", 0))
	p.str_stat = _db_int(row.get("str_stat", 1), 1)
	p.agi = _db_int(row.get("agi", 1), 1)
	p.vit = _db_int(row.get("vit", 1), 1)
	p.int_stat = _db_int(row.get("int_stat", 1), 1)
	p.dex = _db_int(row.get("dex", 1), 1)
	p.luk = _db_int(row.get("luk", 1), 1)
	p.max_hp = _db_int(row.get("max_hp", p.max_hp), p.max_hp)
	p.hp = _db_int(row.get("hp", p.max_hp), p.max_hp)
	p.max_sp = _db_int(row.get("max_sp", p.max_sp), p.max_sp)
	p.sp = _db_int(row.get("sp", p.max_sp), p.max_sp)
	StatRegistry.recalculate_max_hp(p)
	StatRegistry.recalculate_max_sp(p)


func _apply_player_from_cloud_row(p: Player, p_data: Dictionary) -> void:
	GlobalData.player_name = str(p_data.get("name", "Player"))
	SavePointService.apply_from_cloud(p_data)
	GlobalData.player_gender = str(p_data.get("gender", "male"))
	p.current_job = str(p_data.get("current_job", "novice"))
	GlobalData.player_class = p.current_job
	p.level = _db_int(p_data.get("level", 1), 1)
	p.current_exp = _db_int(p_data.get("current_exp", 0))
	p.max_exp = _db_int(p_data.get("max_exp", 100), 100)
	p.job_level = _db_int(p_data.get("job_level", 1), 1)
	p.job_exp = _db_int(p_data.get("job_exp", 0), 0)
	p.max_job_exp = _db_int(p_data.get("max_job_exp", 50), 50)
	p.job_points = _db_int(p_data.get("job_points", 0), 0)
	p.zeny = _db_int(p_data.get("zeny", 500), 500)
	_apply_player_stats_from_row(p, p_data)
	p.apply_job_visuals(p.current_job, GlobalData.player_gender)
	p.stats_changed.emit()


func _apply_load_fallback(p: Player) -> void:
	if PlayerSaveStash.has_pending():
		PlayerSaveStash.apply_to_player(p)
		return
	if GlobalData.apply_pending_character_to(p):
		p.apply_job_visuals(p.current_job, GlobalData.player_gender)
		p.stats_changed.emit()
		_apply_quests_after_load(p, GlobalData.pending_created_character)
		return
	p.apply_job_visuals(p.current_job, GlobalData.player_gender)
	p.stats_changed.emit()
	_apply_quests_after_load(p, {})


func _clear_pending_created_character(char_id: String) -> void:
	if str(GlobalData.pending_created_character.get("character_id", "")) == char_id:
		GlobalData.pending_created_character = {}


func _finish_player_load(player: Player) -> void:
	if player.has_method("reveal_from_load"):
		player.reveal_from_load()
	else:
		player.visible = true
		player.modulate = Color.WHITE
		player.set_physics_process(true)
		player.set_process(true)
	_apply_pending_save_point_revive(player)


func load_game_data(player) -> void:
	if not player:
		return

	if PlayerSaveStash.has_pending():
		PlayerSaveStash.apply_to_player(player)
		_finish_player_load(player)
		return

	var char_id = GlobalData.character_id
	if char_id == "":
		print("❌ ไม่สามารถโหลดได้ เนื่องจากยังไม่ได้เลือกตัวละคร")
		_apply_load_fallback(player)
		_finish_player_load(player)
		return

	print("กำลังโหลดข้อมูลสำหรับ Character ID: ", char_id)

	var player_ref = weakref(player)
	var query = "character_id=eq." + char_id.uri_encode()

	SupabaseClient.fetch_data("players", query, func(success, response):
		var p = player_ref.get_ref()
		if not p:
			return

		if PlayerSaveStash.has_pending():
			PlayerSaveStash.apply_to_player(p)
			_finish_player_load(p)
			return

		if not success:
			print("❌ โหลดข้อมูลจาก Cloud ล้มเหลว (กำลังใช้ค่าเริ่มต้น)")
			_apply_load_fallback(p)
			var warp_pos_fail: Variant = GlobalData.take_warp_spawn_position()
			if warp_pos_fail != null:
				p.global_position = warp_pos_fail
			_finish_player_load(p)
			return

		if response is Array and response.size() > 0:
			var p_data: Dictionary = response[0]
			_apply_player_from_cloud_row(p, p_data)
			_clear_pending_created_character(char_id)

			var saved_quick: Variant = p_data.get("quick_slots")
			if saved_quick is Array and saved_quick.size() == 6:
				p.quick_slots = saved_quick
			else:
				p.quick_slots = [null, null, null, null, null, null]

			var warp_pos: Variant = GlobalData.take_warp_spawn_position()
			if warp_pos != null:
				p.global_position = warp_pos
			elif p_data.has("pos_x") and p_data.has("pos_y"):
				var px := float(p_data.get("pos_x", 0))
				var py := float(p_data.get("pos_y", 0))
				if px == 0.0 and py == 0.0:
					p.global_position = Vector2(GameConstants.MAP_WORLD_WIDTH / 2.0, GameConstants.MAP_WORLD_HEIGHT / 2.0)
				else:
					p.global_position = Vector2(px, py)

			_load_equipment(p, char_id)
			_load_inventory(p, char_id)
			_apply_quests_after_load(p, p_data)

			if is_inside_tree():
				var ui := UiAccess.get_ui(self)
				if ui and ui.has_method("show_notification"):
					ui.show_notification("Game Loaded from Cloud!", Color8(0x34, 0x98, 0xdb))
		else:
			print("❌ ไม่พบข้อมูลเซฟของตัวละครนี้บน Cloud (กำลังใช้งานค่าเริ่มต้น)")
			_apply_load_fallback(p)
			var warp_pos: Variant = GlobalData.take_warp_spawn_position()
			if warp_pos != null:
				p.global_position = warp_pos

		_finish_player_load(p)
	)


func _apply_pending_save_point_revive(player: Player) -> void:
	if player == null or not GlobalData.pending_revive_at_save:
		return
	GlobalData.pending_revive_at_save = false
	if player.has_method("restore_after_save_point_revive"):
		player.restore_after_save_point_revive()


func _load_equipment(player, char_id: String) -> void:
	var player_ref = weakref(player)
	var query = "character_id=eq." + char_id.uri_encode()
	SupabaseClient.fetch_data("player_equipment", query, func(success, response):
		var p = player_ref.get_ref()
		if not p:
			return

		if success and response is Array:
			for row in response:
				var slot_key = row.get("slot_key")
				var item_data = row.get("item_data")
				if p and slot_key in p.equipment:
					p.equipment[slot_key] = item_data
			print("✅ โหลดข้อมูลอุปกรณ์สวมใส่สำเร็จ")
			p.equipment_changed.emit()
	)


func _load_inventory(player, char_id: String) -> void:
	var player_ref = weakref(player)
	var query = "character_id=eq." + char_id.uri_encode()
	SupabaseClient.fetch_data("player_inventory", query, func(success, response):
		var p = player_ref.get_ref()
		if not p:
			return

		if success and response is Array:
			for row in response:
				var slot_index = row.get("slot_index", 0)
				var item_data = row.get("item_data")
				var saved_id := str(row.get("item_id", ""))
				if item_data is Dictionary:
					item_data = item_data.duplicate(true)
					if saved_id != "":
						item_data["id"] = saved_id
					elif str(item_data.get("id", "")) == "":
						item_data["id"] = ItemDatabase.resolve_item_id(item_data)
				elif saved_id != "":
					item_data = ItemDatabase.get_item(saved_id)
				if p and slot_index >= 0 and slot_index < p.inventory.size():
					p.inventory[slot_index] = item_data
			print("✅ โหลดข้อมูลกระเป๋าสำเร็จ")
			p.inventory_changed.emit()
	)


func _resolve_save_scene(player) -> String:
	return SceneContext.from_player(player)


func _apply_quests_after_load(player: Player, p_data: Dictionary) -> void:
	if player == null:
		return
	if GlobalData.has_pending_quest_state:
		GlobalData.apply_quest_state(player)
	elif p_data.get("active_quests") is Dictionary:
		player.active_quests = _normalize_active_quests(p_data.get("active_quests", {}))
		player.finished_quests = _normalize_finished_quests(p_data.get("finished_quests", []))
	player.quests_changed.emit()
	var ui := UiAccess.get_ui(player)
	if ui and ui.has_method("refresh_quest_log"):
		ui.refresh_quest_log()


func _normalize_active_quests(raw: Variant) -> Dictionary:
	var result: Dictionary = {}
	if raw is Dictionary:
		for qid in raw.keys():
			var entry: Variant = raw[qid]
			if entry is Dictionary:
				result[str(qid)] = {
					"progress": int(entry.get("progress", 0)),
					"completed": bool(entry.get("completed", false)),
				}
	return result


func _normalize_finished_quests(raw: Variant) -> Array[String]:
	var result: Array[String] = []
	if raw is Array:
		for qid in raw:
			result.append(str(qid))
	return result


# --- Validation ---

func check_name_available(desired_name: String, callback: Callable) -> void:
	if desired_name.strip_edges() == "":
		if callback.is_valid():
			callback.call(false)
		return

	var query = "name=eq." + desired_name.uri_encode()

	SupabaseClient.fetch_data("players", query, func(success, response):
		if success and response is Array:
			var is_available = response.is_empty()
			if callback.is_valid():
				callback.call(is_available)
		else:
			if callback.is_valid():
				callback.call(false)
	)


func delete_character(character_id: String, callback: Callable) -> void:
	var user_id := SupabaseClient.current_user_id
	var cid := character_id.strip_edges()
	if user_id == "" or cid == "":
		if callback.is_valid():
			callback.call(false)
		return

	var query := "character_id=eq.%s&user_id=eq.%s" % [cid.uri_encode(), user_id.uri_encode()]
	SupabaseClient.delete_data("players", query, callback)
