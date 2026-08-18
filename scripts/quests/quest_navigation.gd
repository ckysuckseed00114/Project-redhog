class_name QuestNavigation
extends RefCounted

# quest_navigation.gd — คลิกเควส → ข้ามแมพ / ล่า / ส่งเควสอัตโนมัติ

const STATE_TRAVELING := "traveling"
const STATE_HUNTING := "hunting"
const STATE_RETURNING := "returning"
const TURN_IN_NPC_ID := "quest_board"
const TURN_IN_POS := Vector2(634, 407)
const TURN_IN_RANGE_SQ := 25600.0


static func navigate_to_quest(player: Player, quest_id: String, from_node: Node) -> void:
	if player == null or from_node == null or not from_node.is_inside_tree():
		return

	var status := QuestService.get_quest_status(player, quest_id)
	if status == QuestService.QuestStatus.READY:
		start_turn_in(player, from_node, quest_id)
		return
	if status != QuestService.QuestStatus.ACTIVE:
		_notify(from_node, "เควสนี้ไม่ต้องตามหาเป้าหมายแล้ว — กลับไปส่งที่ Quest Board", Color8(0xf1, 0xc4, 0x0f))
		return

	var def := QuestDatabase.get_quest(quest_id)
	if def.is_empty():
		return

	GlobalData.set_auto_quest(quest_id, STATE_HUNTING)

	var target_map := QuestDatabase.get_target_map(quest_id)
	if target_map == "":
		GlobalData.clear_auto_quest()
		_notify(from_node, "ยังไม่ได้ตั้งจุดหมายสำหรับเควสนี้", Color8(0xe7, 0x4c, 0x3c))
		return

	if not _is_on_map(from_node, target_map):
		_navigate_cross_map(player, quest_id, target_map, from_node)
		return

	_continue_quest_on_map(player, quest_id, def, from_node)


static func resume_after_warp(player: Player, from_node: Node) -> void:
	if player == null or from_node == null:
		return
	if GlobalData.is_auto_returning_quest:
		navigate_to_npc(player, TURN_IN_NPC_ID, from_node)
		return
	if not GlobalData.has_active_auto_quest():
		return
	var quest_id := GlobalData.active_auto_quest_id
	match GlobalData.auto_quest_state:
		STATE_RETURNING:
			start_turn_in(player, from_node, quest_id)
		_:
			navigate_to_quest(player, quest_id, from_node)


static func start_turn_in(player: Player, from_node: Node, quest_id: String) -> void:
	if player == null or from_node == null or quest_id == "":
		return
	if QuestService.get_quest_status(player, quest_id) != QuestService.QuestStatus.READY:
		GlobalData.clear_auto_quest_state()
		return
	GlobalData.is_auto_returning_quest = true
	GlobalData.returning_quest_id = quest_id
	navigate_to_npc(player, TURN_IN_NPC_ID, from_node)


static func navigate_to_npc(player: Player, target_npc_id: String, from_node: Node) -> void:
	if player == null or from_node == null or not from_node.is_inside_tree():
		return

	var world := _get_world(from_node)
	if world == null:
		return

	var npc_map := _npc_home_map(target_npc_id)
	if npc_map == "":
		return

	if not _is_on_map(from_node, npc_map):
		var map_name := _map_display_name(npc_map)
		var portal := find_portal_to_map(from_node, npc_map)
		if portal == null:
			_notify(from_node, "ไม่พบ Portal ไป %s" % map_name, Color8(0xe7, 0x4c, 0x3c))
			return
			
		world.move_target = portal.global_position
		world.mark_quest_navigation_active()
		_notify(from_node, "กำลังเดินไป Portal → %s" % map_name, Color8(0x34, 0x98, 0xdb))
		_log(from_node, "🧭 กำลังเดินไป Portal เพื่อส่งเควส")
		return

	var npc := find_npc_by_id(from_node, target_npc_id)
	world.move_target = _npc_walk_target(npc)
	world.mark_quest_navigation_active()

	var title := ""
	if GlobalData.returning_quest_id != "":
		title = QuestDatabase.get_display_name(GlobalData.returning_quest_id)
	var msg := "กำลังเดินไป Quest Board" if title == "" else "กำลังเดินไปส่งเควส [%s]" % title
	_notify(from_node, msg, Color8(0x2e, 0xcc, 0x71))
	_log(from_node, "📋 %s" % msg)


static func _npc_home_map(npc_id: String) -> String:
	match npc_id:
		"quest_board":
			return ProjectPaths.CAPITAL
		_:
			return ""


static func _continue_quest_on_map(player: Player, quest_id: String, def: Dictionary, from_node: Node) -> void:
	var obj_type := str(def.get("objective_type", ""))
	match obj_type:
		"kill":
			_navigate_kill(player, quest_id, str(def.get("target_id", "")), from_node)
		"gather", "visit":
			_navigate_hint(player, quest_id, from_node)
		_:
			GlobalData.clear_auto_quest()
			_notify(from_node, "ประเภทเควสนี้ยังไม่รองรับการนำทางอัตโนมัติ", Color8(0xe7, 0x4c, 0x3c))


static func _navigate_cross_map(
	_player: Player,
	quest_id: String,
	target_map: String,
	from_node: Node,
	message: String = ""
) -> void:
	var world := _get_world(from_node)
	if world == null:
		GlobalData.clear_auto_quest()
		_notify(from_node, "ไม่พบแผนที่ — ลองเข้าโซนทุ่ง/เมืองอีกครั้ง", Color8(0xe7, 0x4c, 0x3c))
		return

	var portal := find_portal_to_map(from_node, target_map)
	if portal == null:
		GlobalData.clear_auto_quest()
		var map_name := _map_display_name(target_map)
		_notify(from_node, "ไม่พบ Portal ไป %s" % map_name, Color8(0xe7, 0x4c, 0x3c))
		return

	var travel_state := STATE_RETURNING if GlobalData.auto_quest_state == STATE_RETURNING else STATE_TRAVELING
	GlobalData.set_auto_quest(quest_id, travel_state)
	world.mark_quest_navigation_active()
	world.move_target = portal.global_position

	var dest_name := _map_display_name(target_map)
	if message == "":
		message = "กำลังเดินไป Portal → %s" % dest_name
	_notify(from_node, message, Color8(0x34, 0x98, 0xdb))
	_log(from_node, "🧭 %s" % message)


static func find_portal_to_map(from_node: Node, target_map: String) -> Node2D:
	var want := WarpHelper.resolve_scene_path(target_map)
	if want == "" or from_node == null or not from_node.is_inside_tree():
		return null

	var world := _get_world(from_node)
	var origin := world.player.global_position if world and world.player else Vector2.ZERO
	var best: Node2D = null
	var best_dist_sq := INF

	for node in from_node.get_tree().get_nodes_in_group("portal"):
		if not node is Node2D:
			continue
		var portal := node as Node2D
		var dest := WarpHelper.resolve_scene_path(str(portal.get("target_scene")))
		if dest != want:
			continue
		var dist_sq := origin.distance_squared_to(portal.global_position)
		if dist_sq < best_dist_sq:
			best = portal
			best_dist_sq = dist_sq
	return best


static func find_npc_by_id(from_node: Node, npc_id: String) -> NPC:
	for node in from_node.get_tree().get_nodes_in_group("npc"):
		if node is NPC and (node as NPC).npc_id == npc_id:
			return node as NPC
	return null


static func try_auto_turn_in(world: BaseMap) -> bool:
	if world == null or not GlobalData.has_active_auto_quest():
		return false
	if GlobalData.auto_quest_state != STATE_RETURNING:
		return false
	if world.player == null:
		return false

	var quest_id := GlobalData.active_auto_quest_id
	if quest_id == "" or QuestService.get_quest_status(world.player, quest_id) != QuestService.QuestStatus.READY:
		GlobalData.clear_auto_quest()
		world.cancel_quest_navigation()
		world.move_target = null
		return false

	var npc := find_npc_by_id(world, TURN_IN_NPC_ID)
	if npc == null:
		return false

	var npc_pos := _npc_walk_target(npc)
	if world.player.global_position.distance_squared_to(npc_pos) > TURN_IN_RANGE_SQ:
		return false

	if not QuestService.turn_in_at_npc(npc, quest_id):
		return false

	GlobalData.clear_auto_quest()
	world.cancel_quest_navigation()
	world.move_target = null

	var title := QuestDatabase.get_display_name(quest_id)
	_notify(world, "ส่งเควส [%s] สำเร็จ!" % title, Color8(0x2e, 0xcc, 0x71))
	_log(world, "✅ ส่งเควส [%s] อัตโนมัติ" % title)
	return true


static func _navigate_kill(_player: Player, quest_id: String, monster_id: String, from_node: Node) -> void:
	if monster_id == "":
		GlobalData.clear_auto_quest()
		return
	var world := _get_world(from_node)
	if world == null:
		GlobalData.clear_auto_quest()
		_notify(from_node, "ไม่พบแผนที่ — ลองเข้าโซนทุ่ง/เมืองอีกครั้ง", Color8(0xe7, 0x4c, 0x3c))
		return
	if not world is World:
		GlobalData.clear_auto_quest()
		_notify(from_node, "แผนที่นี้ไม่มีมอนสเตอร์ให้ตามล่า", Color8(0xe7, 0x4c, 0x3c))
		return
	var result: Dictionary = (world as World).start_quest_hunt(quest_id, monster_id)
	var ok := bool(result.get("ok", false))
	var message := str(result.get("message", ""))
	if message != "":
		_notify(from_node, message, Color8(0x2e, 0xcc, 0x71) if ok else Color8(0xf1, 0xc4, 0x0f))
	if ok:
		GlobalData.set_auto_quest(quest_id, STATE_HUNTING)
		_log(from_node, "🎯 เริ่มล่าเควสจนครบเป้าหมาย")
	else:
		GlobalData.clear_auto_quest()


static func _navigate_hint(_player: Player, quest_id: String, from_node: Node) -> void:
	var hint := QuestDatabase.get_nav_hint_pos(quest_id)
	if hint == Vector2.ZERO:
		GlobalData.clear_auto_quest()
		_notify(from_node, "ยังไม่ได้ตั้งจุดเก็บของสำหรับเควสนี้", Color8(0xe7, 0x4c, 0x3c))
		return
	var world := _get_world(from_node)
	if world == null:
		GlobalData.clear_auto_quest()
		return
	world.cancel_quest_navigation()
	world.move_target = hint
	world.mark_quest_navigation_active()
	GlobalData.set_auto_quest(quest_id, STATE_HUNTING)
	_notify(from_node, "กำลังเดินไปจุดเก็บของ...", Color8(0x2e, 0xcc, 0x71))
	_log(from_node, "🧭 กำลังเดินไปจุดเป้าหมายเควส")


static func _npc_walk_target(npc: NPC) -> Vector2:
	if npc == null or not is_instance_valid(npc):
		return TURN_IN_POS
	if npc.has_method("_get_sprite_metrics"):
		var metrics: Dictionary = npc._get_sprite_metrics()
		return npc.to_global(metrics["center"] as Vector2)
	return npc.global_position


static func _get_world(from_node: Node) -> BaseMap:
	if from_node == null or not from_node.is_inside_tree():
		return null
	return from_node.get_tree().get_first_node_in_group("world") as BaseMap


static func _current_scene_path(from_node: Node) -> String:
	var tree := from_node.get_tree()
	if tree == null or tree.current_scene == null:
		return ""
	return WarpHelper.normalize_scene_path(tree.current_scene.scene_file_path)


static func _is_on_map(from_node: Node, map_path: String) -> bool:
	var want := WarpHelper.resolve_scene_path(map_path)
	var current := WarpHelper.resolve_scene_path(_current_scene_path(from_node))
	return want != "" and current != "" and current == want


static func _map_display_name(map_path: String) -> String:
	match WarpHelper.resolve_scene_path(map_path):
		ProjectPaths.WORLD:
			return "Training Field"
		ProjectPaths.CAPITAL:
			return "Capital City"
		ProjectPaths.WEST_FIELD:
			return "West Field"
		_:
			return map_path.get_file().get_basename()


static func _notify(from_node: Node, text: String, color: Color) -> void:
	var ui := UiAccess.get_ui(from_node)
	if ui and ui.has_method("show_notification"):
		ui.show_notification(text, color)


static func _log(from_node: Node, text: String) -> void:
	var ui := UiAccess.get_ui(from_node)
	if ui and ui.has_method("add_log"):
		ui.add_log(text, Color8(0x34, 0x98, 0xdb))
