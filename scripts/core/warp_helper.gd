class_name WarpHelper
extends RefCounted


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
		"res://scenes/maps/west_field.tscn", ProjectPaths.WEST_FIELD:
			return ProjectPaths.WEST_FIELD
	return path


static func execute(tree: SceneTree, target_scene: String, spawn_pos: Vector2, destination_name: String, player: Player = null) -> void:
	var scene_path := normalize_scene_path(target_scene)
	if scene_path == "":
		push_warning("WarpHelper: missing target scene for %s" % destination_name)
		return

	if player:
		player.global_position = spawn_pos
		PlayerSaveStash.stash_for_warp(player, spawn_pos, scene_path)
		if GlobalData.pending_revive_at_save:
			player.hp = player.max_hp
			player.sp = player.max_sp

		if OnlineSession.is_logged_in():
			await SceneTransition.fade_in("Saving to Cloud...")
			var save_id := DatabaseManager.save_game_data(player)
			var saved: bool = await DatabaseManager.wait_for_save_id(save_id)
			if not saved:
				PlayerSaveStash.clear()
				SceneTransition.update_text("Save failed — warp cancelled")
				await SceneTransition.fade_out()
				return
		else:
			await SceneTransition.fade_in("Loading Map...")
	else:
		await SceneTransition.fade_in("Loading Map...")

	SceneTransition.update_text("Loading %s..." % destination_name)
	SceneTransition.prepare_fade_out_on_load()
	tree.change_scene_to_file(scene_path)
