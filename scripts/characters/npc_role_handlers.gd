class_name NpcRoleHandlers
extends RefCounted

# npc_role_handlers.gd — จัดการ dialog/action ตาม role (เรียกจาก NPC)

static func dialog_accept_text(npc: NPC) -> String:
	if npc.npc_id != "":
		var def := NpcDatabase.get_definition(npc.npc_id)
		if def.has("accept_text"):
			return str(def.get("accept_text"))
	match npc.npc_role:
		NPC.NpcRole.WARP:
			return "วาร์ป"
		NPC.NpcRole.SHOP:
			return "ซื้อ"
		NPC.NpcRole.UPGRADE:
			return "ตีบวก"
		NPC.NpcRole.JOB_MASTER:
			return "รับเควส"
		NPC.NpcRole.SAVE_POINT:
			return "บันทึกจุดเซฟ"
	return "รับเควส"


static func open_dialog(npc: NPC) -> void:
	match npc.npc_role:
		NPC.NpcRole.JOB_MASTER:
			_open_job_master(npc)
		NPC.NpcRole.SHOP:
			_open_shop_menu(npc)
		NPC.NpcRole.WARP:
			_open_warp(npc)
		NPC.NpcRole.UPGRADE:
			_open_upgrade(npc)
		NPC.NpcRole.SAVE_POINT:
			_open_save_point(npc)
		NPC.NpcRole.QUEST:
			_open_quest_board(npc)
		_:
			_open_generic(npc)


static func on_decline(npc: NPC) -> bool:
	match npc.npc_role:
		NPC.NpcRole.SHOP:
			_open_shop(npc, "sell")
			return false
		NPC.NpcRole.QUEST:
			if npc.has_meta("_pending_quest_id"):
				npc.remove_meta("_pending_quest_id")
			if npc.quest_ids.size() > 1:
				_open_quest_picker(npc)
				return true
			return false
		_:
			return false


static func on_accept(npc: NPC) -> bool:
	match npc.npc_role:
		NPC.NpcRole.WARP:
			if npc.warp_destinations.size() > 1:
				return false
			_do_warp(npc, _first_warp_destination(npc))
			return false
		NPC.NpcRole.SHOP:
			return _open_shop(npc, "buy")
		NPC.NpcRole.JOB_MASTER:
			return _handle_job_master_accept(npc)
		NPC.NpcRole.QUEST:
			if npc.has_meta("_pending_quest_id"):
				var quest_id := str(npc.get_meta("_pending_quest_id"))
				npc.remove_meta("_pending_quest_id")
				if QuestService.accept_at_npc(npc, quest_id):
					_log(npc, "รับเควส: %s" % QuestDatabase.get_display_name(quest_id), UITheme.GOLD)
					if npc.quest_ids.size() > 1:
						_open_quest_picker(npc)
						return true
				else:
					_log(npc, "รับเควสไม่ได้", UITheme.MUTED)
				return false
			return false
		NPC.NpcRole.UPGRADE:
			_log(npc, "[%s] ระบบตีบวกจะเปิดใช้เร็วๆ นี้" % npc.npc_name, UITheme.GOLD)
		NPC.NpcRole.SAVE_POINT:
			return _register_save_point(npc)
	return false


static func on_complete(npc: NPC) -> bool:
	if npc.npc_role != NPC.NpcRole.QUEST:
		_log(npc, "[%s] ส่งเควสสำเร็จ" % npc.npc_name, Color8(0x2e, 0xcc, 0x71))
		return false
	var player := QuestService._resolve_player(npc)
	if player == null:
		return false
	var quest_id := ""
	if npc.has_meta("_pending_quest_id"):
		quest_id = str(npc.get_meta("_pending_quest_id"))
		npc.remove_meta("_pending_quest_id")
	if quest_id == "":
		quest_id = QuestService.find_completable_at_npc(player, npc.quest_ids)
	if quest_id == "":
		_log(npc, "ยังไม่มีเควสที่ส่งได้", UITheme.MUTED)
		return false
	if QuestService.turn_in_at_npc(npc, quest_id):
		var rewards := QuestDatabase.get_reward_summary(quest_id)
		_log(npc, "ส่งเควส: %s สำเร็จ! (%s)" % [QuestDatabase.get_display_name(quest_id), rewards], Color8(0x2e, 0xcc, 0x71))
		if npc.quest_ids.size() > 1:
			_open_quest_picker(npc)
			return true
	return false


static func on_picker_selected(npc: NPC, option_id: String) -> bool:
	match npc.picker_kind:
		"warp":
			_do_warp_by_id(npc, option_id)
			return false
		"quest":
			_open_quest_detail(npc, option_id)
			return true
		"job":
			_apply_job_change(npc, option_id)
			return false
	return false


# --- Quest Board ---

static func _open_quest_board(npc: NPC) -> void:
	var player := QuestService._resolve_player(npc)
	if player == null:
		_log(npc, "ไม่พบตัวละคร", UITheme.MUTED)
		return
	if npc.quest_ids.is_empty():
		_open_generic(npc)
		return
	if npc.quest_ids.size() == 1:
		_open_quest_detail(npc, npc.quest_ids[0])
		return
	_open_quest_picker(npc)


static func _open_quest_picker(npc: NPC) -> void:
	var player := QuestService._resolve_player(npc)
	var options: Array = []
	for qid in npc.quest_ids:
		var sid := str(qid)
		var suffix := QuestService.get_quest_status_label(player, sid) if player else ""
		options.append({"id": sid, "label": "%s%s" % [QuestDatabase.get_display_name(sid), suffix]})
	npc.picker_kind = "quest"
	var msg := npc.dialog_message
	if player and QuestService.has_completable_at_npc(player, npc.quest_ids):
		msg += "\n\n(มีเควสที่ส่งได้ — เลือกเควสแล้วกดส่งเควส)"
	_show_dialog(npc, {
		"name": npc.npc_name,
		"message": msg,
		"picker_options": options,
	})


static func _open_quest_detail(npc: NPC, quest_id: String) -> void:
	var player := QuestService._resolve_player(npc)
	if player == null:
		return
	var def := QuestDatabase.get_quest(quest_id)
	if def.is_empty():
		return
	npc.picker_kind = "quest"
	npc.set_meta("_pending_quest_id", quest_id)
	var status := QuestService.get_quest_status(player, quest_id)
	var can_accept := status == QuestService.QuestStatus.AVAILABLE
	var can_complete := status == QuestService.QuestStatus.READY
	_show_dialog(npc, {
		"name": "%s — %s" % [npc.npc_name, QuestDatabase.get_display_name(quest_id)],
		"message": QuestService.build_quest_detail_message(player, quest_id),
		"accept_text": "รับเควส",
		"decline_text": "กลับ" if npc.quest_ids.size() > 1 else "ปิด",
		"show_decline": true,
		"show_complete": can_complete,
		"hide_accept": not can_accept,
	})


# --- Shop ---

static func _open_shop_menu(npc: NPC) -> void:
	_show_dialog(npc, {
		"name": npc.npc_name,
		"message": npc.dialog_message,
		"accept_text": "ซื้อ",
		"decline_text": "ขาย",
		"show_decline": true,
	})


static func _open_shop(npc: NPC, mode: String = "buy") -> bool:
	var ui := UiAccess.get_ui(npc)
	if ui == null or not ui.has_method("open_shop"):
		return false
	var shop_player: Player = npc._get_player() if npc.has_method("_get_player") else npc.player_ref
	if shop_player == null:
		return false
	npc.is_chatting = false
	shop_player.is_talking = false
	ui.open_shop(shop_player, npc.shop_id, npc.npc_name, mode)
	return false


# --- Job Master ---

static func _open_job_master(npc: NPC) -> void:
	var ui := UiAccess.get_ui(npc)
	if ui == null or not ui.has_method("open_npc_dialog") or npc.player_ref == null:
		return
	npc.is_chatting = true
	npc.player_ref.is_talking = true
	npc.player_ref.apply_velocity(0, 0)
	var player := npc.player_ref
	if player.current_job != "novice":
		_show_dialog(npc, {
			"name": npc.npc_name,
			"message": "คุณเปลี่ยนอาชีพแล้ว — ไม่มีเควสให้ทำ",
			"hide_accept": true,
			"show_decline": false,
		})
	elif not player.can_change_job():
		_show_dialog(npc, {
			"name": npc.npc_name,
			"message": "เควสเปลี่ยนอาชีพต้องการ Novice Lv.%d\n(ปัจจุบัน Lv.%d)" % [
				ClassDatabase.JOB_CHANGE_LEVEL, player.level
			],
			"hide_accept": true,
			"show_decline": false,
		})
	elif npc.is_job_quest_accepted():
		_open_job_picker(npc)
	else:
		_show_dialog(npc, {
			"name": npc.npc_name,
			"message": npc.dialog_message + "\n\nรับเควสเพื่อเลือกอาชีพแรก?",
			"accept_text": "รับเควส",
			"show_decline": true,
			"show_complete": false,
		})


static func _handle_job_master_accept(npc: NPC) -> bool:
	if npc.player_ref == null or not npc.player_ref.can_change_job():
		return false
	if npc.is_job_quest_accepted():
		return false
	npc.mark_job_quest_accepted()
	_log(npc, "[%s] รับเควสเปลี่ยนอาชีพแล้ว!" % npc.npc_name, UITheme.GOLD)
	_open_job_picker(npc)
	return true


static func _open_job_picker(npc: NPC) -> void:
	var options: Array = []
	for job_id in ClassDatabase.get_next_jobs("novice"):
		options.append({"id": job_id, "label": ClassDatabase.get_display_name(job_id)})
	npc.picker_kind = "job"
	_show_dialog(npc, {
		"name": npc.npc_name,
		"message": "เลือกอาชีพแรกของคุณ:",
		"picker_options": options,
	})


static func _apply_job_change(npc: NPC, job_id: String) -> void:
	if npc.player_ref and npc.player_ref.change_job(job_id):
		_log(npc, "เปลี่ยนอาชีพเป็น %s!" % ClassDatabase.get_display_name(job_id), Color8(0x2e, 0xcc, 0x71))


# --- Warp Guide ---

static func _open_warp(npc: NPC) -> void:
	if npc.warp_destinations.size() > 1:
		var options: Array = []
		for dest in npc.warp_destinations:
			if dest is Dictionary:
				options.append({"id": str(dest.get("id", "")), "label": str(dest.get("label", "???"))})
		npc.picker_kind = "warp"
		_show_dialog(npc, {
			"name": npc.npc_name,
			"message": npc.dialog_message,
			"picker_options": options,
		})
		return
	_show_dialog(npc, {
		"name": npc.npc_name,
		"message": npc.dialog_message,
		"accept_text": dialog_accept_text(npc),
		"show_decline": true,
	})


static func _first_warp_destination(npc: NPC) -> Dictionary:
	if npc.warp_destinations.size() > 0 and npc.warp_destinations[0] is Dictionary:
		return npc.warp_destinations[0]
	return {
		"scene": npc.warp_target_scene,
		"label": npc.warp_destination_name,
		"spawn": npc.warp_spawn_position,
	}


static func _do_warp_by_id(npc: NPC, dest_id: String) -> void:
	for dest in npc.warp_destinations:
		if dest is Dictionary and str(dest.get("id", "")) == dest_id:
			_do_warp(npc, dest)
			return


static func _do_warp(npc: NPC, dest: Dictionary) -> void:
	var scene := str(dest.get("scene", npc.warp_target_scene))
	if scene == "":
		return
	var spawn: Variant = dest.get("spawn", npc.warp_spawn_position)
	var spawn_pos: Vector2 = spawn if spawn is Vector2 else npc.warp_spawn_position
	var dest_name := str(dest.get("label", npc.warp_destination_name))
	await WarpHelper.execute(npc.get_tree(), scene, spawn_pos, dest_name, npc.player_ref)


# --- Upgrade / Enchant ---

static func _open_upgrade(npc: NPC) -> void:
	_show_dialog(npc, {
		"name": npc.npc_name,
		"message": npc.dialog_message,
		"accept_text": dialog_accept_text(npc),
		"show_decline": true,
	})


# --- Save Point ---

static func _open_save_point(npc: NPC) -> void:
	# ลบตัวแปร player ออกไปได้เลยเพราะหน้าต่างเซฟไม่ได้ดึงค่าผู้เล่นมาใช้ตรงนี้
	var msg := npc.dialog_message
	if SavePointService.has_save_point():
		msg += "\n\nจุดเซฟปัจจุบัน: %s" % SavePointService.get_display_name()
	_show_dialog(npc, {
		"name": npc.npc_name,
		"message": msg,
		"accept_text": dialog_accept_text(npc),
		"show_decline": true,
	})


static func _register_save_point(npc: NPC) -> bool:
	var player := npc._get_player()
	if player == null:
		_log(npc, "ไม่พบตัวละคร", UITheme.MUTED)
		return false
	if SavePointService.register(player, player.global_position):
		_log(npc, "บันทึกจุดเกิดที่ %s แล้ว" % SavePointService.get_display_name(), Color8(0x2e, 0xcc, 0x71))
		var ui := UiAccess.get_ui(npc)
		if ui and ui.has_method("show_notification"):
			ui.show_notification("Save Point Registered!", Color8(0x2e, 0xcc, 0x71))
	else:
		_log(npc, "บันทึกจุดเซฟไม่สำเร็จ", UITheme.MUTED)
	return false


# --- Shared ---

static func _open_generic(npc: NPC) -> void:
	_show_dialog(npc, {
		"name": npc.npc_name,
		"message": npc.dialog_message,
		"accept_text": dialog_accept_text(npc),
		"show_decline": true,
		"show_complete": npc.npc_role == NPC.NpcRole.QUEST and QuestService.has_completable_at_npc(QuestService._resolve_player(npc), npc.quest_ids),
	})


static func _show_dialog(npc: NPC, config: Dictionary) -> void:
	var ui := UiAccess.get_ui(npc)
	if ui == null or not ui.has_method("open_npc_dialog"):
		return
	npc.is_chatting = true
	if npc.player_ref:
		npc.player_ref.is_talking = true
		npc.player_ref.apply_velocity(0, 0)
	ui.open_npc_dialog(npc, config)


static func _log(npc: NPC, text: String, color: Color) -> void:
	var ui := UiAccess.get_ui(npc)
	if ui and ui.has_method("add_log"):
		ui.add_log(text, color)
