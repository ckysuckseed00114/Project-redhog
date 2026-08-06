class_name QuestService
extends RefCounted

# quests/quest_service.gd — ช่วยเชื่อม NPC / UI / Player

enum QuestStatus { AVAILABLE, ACTIVE, READY, FINISHED }


static func refresh_quest_ui(from_node: Node) -> void:
	var ui := UiAccess.get_ui(from_node)
	if ui and ui.has_method("refresh_quest_log"):
		ui.refresh_quest_log()


static func save_quests(player: Player) -> void:
	if player == null or not OnlineSession.is_logged_in():
		return
	DatabaseManager.save_game_data(player)


static func get_quest_status(player: Player, quest_id: String) -> QuestStatus:
	if player == null:
		return QuestStatus.AVAILABLE
	if quest_id in player.finished_quests:
		return QuestStatus.FINISHED
	if not player.active_quests.has(quest_id):
		return QuestStatus.AVAILABLE
	var data: Dictionary = player.active_quests[quest_id]
	if data.get("completed", false):
		return QuestStatus.READY
	return QuestStatus.ACTIVE


static func get_quest_status_label(player: Player, quest_id: String) -> String:
	match get_quest_status(player, quest_id):
		QuestStatus.ACTIVE:
			return " [กำลังทำ]"
		QuestStatus.READY:
			return " [ส่งได้]"
		QuestStatus.FINISHED:
			return " [เสร็จแล้ว]"
		_:
			return ""


static func build_quest_detail_message(player: Player, quest_id: String) -> String:
	var def := QuestDatabase.get_quest(quest_id)
	if def.is_empty():
		return ""
	var lines: PackedStringArray = []
	lines.append(str(def.get("description", "")))
	lines.append("")
	lines.append("เป้าหมาย: %s" % QuestDatabase.get_objective_summary(quest_id))
	var rewards := QuestDatabase.get_reward_summary(quest_id)
	if rewards != "":
		lines.append("รางวัล: %s" % rewards)
	var status := get_quest_status(player, quest_id)
	if status == QuestStatus.ACTIVE or status == QuestStatus.READY:
		lines.append("ความคืบหน้า: %s" % get_progress_text(player, quest_id))
	elif status == QuestStatus.FINISHED:
		lines.append("สถานะ: ส่งเควสแล้ว")
	return "\n".join(lines)


static func has_completable_at_npc(player: Player, quest_ids: Array) -> bool:
	return find_completable_at_npc(player, quest_ids) != ""


static func find_completable_at_npc(player: Player, quest_ids: Array) -> String:
	if player == null:
		return ""
	for qid in quest_ids:
		var sid := str(qid)
		if get_quest_status(player, sid) == QuestStatus.READY:
			return sid
	return ""


static func can_accept(player: Player, quest_id: String) -> bool:
	return get_quest_status(player, quest_id) == QuestStatus.AVAILABLE and not QuestDatabase.get_quest(quest_id).is_empty()


static func can_turn_in(player: Player, quest_id: String) -> bool:
	return get_quest_status(player, quest_id) == QuestStatus.READY


static func accept_at_npc(npc: NPC, quest_id: String) -> bool:
	var player := _resolve_player(npc)
	if player == null:
		return false
	if not can_accept(player, quest_id):
		return false
	if not player.accept_quest(quest_id):
		return false
	save_quests(player)
	refresh_quest_ui(npc)
	return true


static func turn_in_at_npc(npc: NPC, quest_id: String) -> bool:
	var player := _resolve_player(npc)
	if player == null:
		return false
	if not can_turn_in(player, quest_id):
		return false
	if not player.turn_in_quest(quest_id):
		return false
	save_quests(player)
	refresh_quest_ui(npc)
	return true


static func get_progress_text(player: Player, quest_id: String) -> String:
	if player == null or not player.active_quests.has(quest_id):
		return "0/0"
	var data: Dictionary = player.active_quests[quest_id]
	var current := int(data.get("progress", 0))
	var target := QuestDatabase.get_target_count(quest_id)
	if data.get("completed", false):
		return "สำเร็จ — กลับไปส่งเควส"
	return "%d/%d" % [current, target]


static func _resolve_player(npc: NPC) -> Player:
	if npc == null:
		return null
	if npc.player_ref and is_instance_valid(npc.player_ref):
		return npc.player_ref
	if npc.has_method("_get_player"):
		var p: Player = npc._get_player()
		if p:
			npc.player_ref = p
			return p
	return null
