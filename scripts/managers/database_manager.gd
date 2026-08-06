extends Node

# database_manager.gd — save_game_data | load_game_data | sync_presence

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

# --- Save ---

func save_game_data(player) -> void:
	if not player:
		return
		
	var user_id = SupabaseClient.current_user_id
	if user_id == "":
		print("❌ ไม่สามารถเซฟได้ เนื่องจากยังไม่ได้เข้าสู่ระบบ")
		return
		
	# ถ้าเป็นตัวละครใหม่ที่เพิ่งสร้าง ให้ gen รหัสเฉพาะขึ้นมา
	if GlobalData.character_id == "":
		GlobalData.character_id = user_id + "_" + str(Time.get_ticks_msec())
		
	var char_id = GlobalData.character_id
	print("กำลังเตรียมข้อมูลบันทึกสำหรับ Character ID: ", char_id)
	
	var player_data = {
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
		"active_quests": player.active_quests,
		"finished_quests": player.finished_quests,
		"quick_slots": player.quick_slots,
	}
	player_data.merge(SavePointService.to_save_fields())
	
	var player_ref = weakref(player)
	var query = "character_id=eq." + char_id
	
	# ใช้ update_data เพื่ออัปเดตข้อมูลเดิม (พิกัด, เลเวล, HP ฯลฯ) ไม่ให้ข้อมูลกระโดดหรือทับช่องอื่น
	SupabaseClient.update_data("players", query, player_data, func(success, _res):
		var p = player_ref.get_ref()
		if success:
			print("✅ บันทึกตำแหน่งและสถานะตัวละครสำเร็จ")
			if p:
				_save_equipment(p, char_id)
				_save_inventory(p, char_id)
			
			if is_inside_tree():
				var ui := UiAccess.get_ui(self)
				if ui and ui.has_method("show_notification"):
					ui.show_notification("Game Saved to Cloud!", Color8(0x2e, 0xcc, 0x71))
		else:
			SupabaseClient.insert_data("players", player_data, func(ins_success, _ins_res):
				if ins_success:
					print("✅ สร้างข้อมูลตัวละครใหม่สำเร็จ")
					var p_inner = player_ref.get_ref() 
					if p_inner:
						_save_equipment(p_inner, char_id)
						_save_inventory(p_inner, char_id)
			)
	)


func _save_equipment(player, char_id: String) -> void:
	var user_id = SupabaseClient.current_user_id 
	for slot_key in player.equipment.keys():
		var item = player.equipment[slot_key] 
		if item != null: 
			var eq_record = {
				"user_id": user_id,
				"character_id": char_id,
				"slot_key": slot_key,
				"item_data": item # 🌟 บันทึกข้อมูลไอเทมทั้งหมด เพื่อให้ตรงกับตอนโหลดข้อมูล
			}
			SupabaseClient.insert_data("player_equipment", eq_record)


func _save_inventory(player, char_id: String) -> void:
	var user_id = SupabaseClient.current_user_id # 🌟 ดึง user_id มาใช้ร่วมด้วย
	for i in range(player.inventory.size()):
		var item = player.inventory[i]
		if item != null:
			var inv_record = {
				"user_id": user_id,       # 🌟 ใส่ user_id กลับเข้าไปเพื่อให้ผ่าน RLS Policy
				"character_id": char_id,
				"slot_index": i,
				"item_id": item.get("id", ""),
				"count": int(round(float(item.get("count", 1)))),
				"item_data": item
			}
			SupabaseClient.insert_data("player_inventory", inv_record)

# --- Load ---

func load_game_data(player) -> void:
	if not player:
		return
		
	var char_id = GlobalData.character_id
	if char_id == "":
		print("❌ ไม่สามารถโหลดได้ เนื่องจากยังไม่ได้เลือกตัวละคร")
		if PlayerSaveStash.has_pending():
			PlayerSaveStash.apply_to_player(player)
		else:
			_apply_quests_after_load(player, {})
		if player.has_method("reveal_from_load"):
			player.reveal_from_load()
		else:
			player.visible = true
			player.modulate = Color.WHITE
			player.set_physics_process(true)
		return
		
	print("กำลังโหลดข้อมูลสำหรับ Character ID: ", char_id)
	
	var player_ref = weakref(player)
	var query = "character_id=eq." + char_id
	
	SupabaseClient.fetch_data("players", query, func(success, response):
		var p = player_ref.get_ref()
		if not p:
			return

		if not success:
			print("❌ โหลดข้อมูลจาก Cloud ล้มเหลว (กำลังใช้ค่าเริ่มต้น)")
			if PlayerSaveStash.has_pending():
				PlayerSaveStash.apply_to_player(p)
			else:
				p.apply_job_visuals(p.current_job, GlobalData.player_gender)
				p.stats_changed.emit()
				_apply_quests_after_load(p, {})
				var warp_pos_fail: Variant = GlobalData.take_warp_spawn_position()
				if warp_pos_fail != null:
					p.global_position = warp_pos_fail
			if p.has_method("reveal_from_load"):
				p.reveal_from_load()
			return

		if response is Array and response.size() > 0:
			var p_data = response[0]
			if PlayerSaveStash.has_pending():
				PlayerSaveStash.apply_to_player(p)
			else:
				GlobalData.player_name = p_data.get("name", "Player")
				SavePointService.apply_from_cloud(p_data)
				GlobalData.player_gender = p_data.get("gender", "male")
				p.current_job = p_data.get("current_job", "novice")
				GlobalData.player_class = p.current_job
				p.level = _db_int(p_data.get("level", 1), 1)
				p.current_exp = _db_int(p_data.get("current_exp", 0))
				p.max_exp = _db_int(p_data.get("max_exp", 100), 100)
				p.stat_points = _db_int(p_data.get("stat_points", 0))
				p.job_level = _db_int(p_data.get("job_level", 1), 1)
				p.job_exp = _db_int(p_data.get("job_exp", 0), 0)
				p.max_job_exp = _db_int(p_data.get("max_job_exp", 50), 50)
				p.job_points = _db_int(p_data.get("job_points", 0), 0)
				p.max_hp = _db_int(p_data.get("max_hp", 100), 100)
				p.hp = _db_int(p_data.get("hp", p.max_hp), p.max_hp)
				p.max_sp = _db_int(p_data.get("max_sp", 50), 50)
				p.sp = _db_int(p_data.get("sp", p.max_sp), p.max_sp)
				p.str_stat = _db_int(p_data.get("str_stat", 1), 1)
				p.agi = _db_int(p_data.get("agi", 1), 1)
				p.vit = _db_int(p_data.get("vit", 1), 1)
				p.int_stat = _db_int(p_data.get("int_stat", 1), 1)
				p.dex = _db_int(p_data.get("dex", 1), 1)
				p.luk = _db_int(p_data.get("luk", 1), 1)
				var zeny_raw: Variant = p_data.get("zeny", 500)
				p.zeny = _db_int(zeny_raw, 500)
				p.apply_job_visuals(p.current_job, GlobalData.player_gender)
				p.stats_changed.emit()

				var saved_quick = p_data.get("quick_slots")
				if saved_quick != null and saved_quick is Array and saved_quick.size() == 6:
					p.quick_slots = saved_quick
				else:
					p.quick_slots = [null, null, null, null, null, null]

				var warp_pos: Variant = GlobalData.take_warp_spawn_position()
				if warp_pos != null:
					p.global_position = warp_pos
				elif p_data.has("pos_x") and p_data.has("pos_y"):
					var px = float(p_data.get("pos_x", 0))
					var py = float(p_data.get("pos_y", 0))
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
			if PlayerSaveStash.has_pending():
				PlayerSaveStash.apply_to_player(p)
			else:
				p.apply_job_visuals(p.current_job, GlobalData.player_gender)
				p.stats_changed.emit()
				_apply_quests_after_load(p, {})
				var warp_pos: Variant = GlobalData.take_warp_spawn_position()
				if warp_pos != null:
					p.global_position = warp_pos

		if p.has_method("reveal_from_load"):
			p.reveal_from_load()
		else:
			p.visible = true
			p.modulate = Color.WHITE
			p.set_physics_process(true)
			p.set_process(true)
	)


func _load_equipment(player, char_id: String) -> void:
	var player_ref = weakref(player)
	var query = "character_id=eq." + char_id # 🌟 โหลดอุปกรณ์ตาม character_id
	SupabaseClient.fetch_data("player_equipment", query, func(success, response):
		var p = player_ref.get_ref()
		if not p: return

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
	var query = "character_id=eq." + char_id # 🌟 โหลดกระเป๋าตาม character_id
	SupabaseClient.fetch_data("player_inventory", query, func(success, response):
		var p = player_ref.get_ref()
		if not p: return

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


# --- Presence (legacy delegate) ---

func sync_presence(player) -> void:
	PresenceSync.sync_player(player)

# --- Validation ---

# 🌟 ฟังก์ชันสำหรับเช็คว่าชื่อตัวละครนี้มีคนใช้ไปหรือยัง
func check_name_available(desired_name: String, callback: Callable) -> void:
	if desired_name.strip_edges() == "":
		if callback.is_valid():
			callback.call(false)
		return
		
	# ค้นหาในตาราง players ว่ามีชื่อนี้อยู่หรือไม่
	var query = "name=eq." + desired_name.uri_encode()
	
	# 🌟 แก้ตรงนี้: เติม SupabaseClient. ไว้ข้างหน้าครับ
	SupabaseClient.fetch_data("players", query, func(success, response):
		if success and response is Array:
			# ถ้า response เป็น Array ว่างเปล่า (is_empty) แปลว่าชื่อนี้ยังไม่มีใครใช้
			var is_available = response.is_empty()
			if callback.is_valid():
				callback.call(is_available)
		else:
			# ถ้ามี Error ตีความไปก่อนว่าชื่อนี้ใช้ไม่ได้ เพื่อความปลอดภัย
			if callback.is_valid():
				callback.call(false)
	)
