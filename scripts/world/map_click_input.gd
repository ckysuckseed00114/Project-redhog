class_name MapClickInput
extends RefCounted

# map_click_input.gd — ตรวจ UI / clamp ตำแหน่งคลิกแมพ


static func clamp_map_pos(world_pos: Vector2) -> Vector2:
	world_pos.x = clampf(world_pos.x, 8, GameConstants.MAP_WORLD_WIDTH - 8)
	world_pos.y = clampf(world_pos.y, 8, GameConstants.MAP_WORLD_HEIGHT - 8)
	return world_pos


static func is_ui_blocking(map: BaseMap, screen_pos: Vector2) -> bool:
	if map == null:
		return false
	var ui := UiAccess.get_ui(map)
	if ui and ui.has_method("blocks_world_click_at"):
		return ui.blocks_world_click_at(screen_pos)
	if ui and ui.has_method("is_point_over_ui"):
		return ui.is_point_over_ui(screen_pos)
	return false
