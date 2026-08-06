class_name SceneContext
extends RefCounted

# scene_context.gd — resolve scene path สำหรับ online sync / save


static func normalize(path: String) -> String:
	return WarpHelper.normalize_scene_path(path)


static func from_tree(tree: SceneTree) -> String:
	if tree == null or tree.current_scene == null:
		return ""
	return normalize(tree.current_scene.scene_file_path)


static func from_node(node: Node) -> String:
	if node == null or not node.is_inside_tree():
		return ""
	return from_tree(node.get_tree())


static func from_player(player: Player) -> String:
	if player == null:
		return ""
	if GlobalData.pending_warp_scene != "":
		return normalize(GlobalData.pending_warp_scene)
	return from_node(player)


static func is_same_scene(a: String, b: String) -> bool:
	if a == "" or b == "":
		return false
	return normalize(a) == normalize(b)


static func is_local_character(payload: Dictionary) -> bool:
	var char_id := str(payload.get(RealtimeEvents.KEY_CHARACTER_ID, ""))
	return char_id != "" and char_id == GlobalData.character_id


static func is_for_local_scene(payload: Dictionary, local_scene: String) -> bool:
	var scene := str(payload.get(RealtimeEvents.KEY_CURRENT_SCENE, ""))
	if scene == "":
		scene = str(payload.get(RealtimeEvents.KEY_MAP_SCENE, ""))
	return is_same_scene(scene, local_scene)
