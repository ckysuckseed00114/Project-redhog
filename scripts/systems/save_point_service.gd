class_name SavePointService
extends RefCounted

# save_point_service.gd — บันทึก/โหลดจุดเกิด (Respawn)


static func has_save_point() -> bool:
	return GlobalData.has_save_point and GlobalData.save_point_scene != ""


static func register(player: Player, pos: Vector2, scene_path: String = "") -> bool:
	if player == null:
		return false
	var scene := scene_path
	if scene == "" and player.get_tree() and player.get_tree().current_scene:
		scene = player.get_tree().current_scene.scene_file_path
	scene = WarpHelper.normalize_scene_path(scene)
	if scene == "":
		return false
	GlobalData.save_point_scene = scene
	GlobalData.save_point_x = pos.x
	GlobalData.save_point_y = pos.y
	GlobalData.has_save_point = true
	if OnlineSession.is_online():
		DatabaseManager.save_game_data(player)
	return true


static func get_position() -> Vector2:
	return Vector2(GlobalData.save_point_x, GlobalData.save_point_y)


static func get_scene() -> String:
	return GlobalData.save_point_scene


static func get_display_name() -> String:
	match WarpHelper.normalize_scene_path(GlobalData.save_point_scene):
		ProjectPaths.CAPITAL:
			return "Capital City"
		ProjectPaths.WORLD:
			return "Training Field"
		_:
			return "Save Point"


static func apply_from_cloud(p_data: Dictionary) -> void:
	GlobalData.has_save_point = bool(p_data.get("has_save_point", false))
	GlobalData.save_point_scene = WarpHelper.normalize_scene_path(str(p_data.get("save_point_scene", "")))
	GlobalData.save_point_x = float(p_data.get("save_point_x", 0.0))
	GlobalData.save_point_y = float(p_data.get("save_point_y", 0.0))
	if GlobalData.save_point_scene == "":
		GlobalData.has_save_point = false


static func to_save_fields() -> Dictionary:
	return {
		"has_save_point": GlobalData.has_save_point,
		"save_point_scene": GlobalData.save_point_scene,
		"save_point_x": GlobalData.save_point_x,
		"save_point_y": GlobalData.save_point_y,
	}
