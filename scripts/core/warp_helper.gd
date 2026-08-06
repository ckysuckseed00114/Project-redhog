class_name WarpHelper
extends RefCounted

const WARP_DELAY := 0.35


static func normalize_scene_path(path: String) -> String:
	if path == "":
		return ""
	if path.begins_with("uid://"):
		return path
	match path:
		"res://scenes/capital_city.tscn", ProjectPaths.CAPITAL:
			return ProjectPaths.CAPITAL
		"res://scenes/world.tscn", ProjectPaths.WORLD:
			return ProjectPaths.WORLD
	return path


static func notify_ui(tree: SceneTree, destination_name: String) -> void:
	var ui := UiAccess.get_ui(tree.root)
	if ui and ui.has_method("show_notification"):
		ui.show_notification("Warping to %s..." % destination_name, Color8(0x34, 0x98, 0xdb))
	if ui and ui.has_method("add_log"):
		ui.add_log("Warp → %s" % destination_name, Color8(0x34, 0x98, 0xdb))


static func execute(tree: SceneTree, target_scene: String, spawn_pos: Vector2, destination_name: String, player: Player = null) -> void:
	var scene_path := normalize_scene_path(target_scene)
	if scene_path == "":
		push_warning("WarpHelper: missing target scene for %s" % destination_name)
		return

	notify_ui(tree, destination_name)

	if player:
		player.global_position = spawn_pos
		PlayerSaveStash.stash_for_warp(player, spawn_pos, scene_path)
		if OnlineSession.is_logged_in():
			DatabaseManager.save_game_data(player)

	await tree.create_timer(WARP_DELAY).timeout
	tree.call_deferred("change_scene_to_file", scene_path)
