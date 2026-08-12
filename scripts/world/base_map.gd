class_name BaseMap
extends Node2D

var player: Player
var move_target: Variant = null

@onready var ground: Sprite2D = $Ground if has_node("Ground") else null
@onready var backdrop: Sprite2D = $Backdrop if has_node("Backdrop") else null

var _scenery: MapScenery

# base_map.gd — สารบัญ: Lifecycle | Spawn | Input/Movement | FX

# --- Lifecycle ---

func _ready() -> void:
	add_to_group("world")
	_setup_backdrop()
	_setup_ground()
	_setup_scenery()
	_spawn_player()
	_spawn_ui()
	_on_map_ready()


func get_map_theme() -> String:
	return "field"


func get_scenery_exclusions() -> Array[Vector2]:
	return []


func _setup_backdrop() -> void:
	var spr := backdrop
	if spr == null:
		spr = Sprite2D.new()
		spr.name = "Backdrop"
		spr.z_index = -10
		add_child(spr)
		move_child(spr, 0)
		backdrop = spr
	spr.texture = TextureGenerator.get_backdrop_texture(get_map_theme())
	spr.position = Vector2.ZERO
	spr.centered = false
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func _setup_scenery() -> void:
	if _scenery and is_instance_valid(_scenery):
		_scenery.queue_free()
	_scenery = MapScenery.new()
	_scenery.name = "Scenery"
	_scenery.z_index = 1
	add_child(_scenery)
	if ground:
		move_child(_scenery, ground.get_index() + 1)
	var map_size := Vector2(GameConstants.MAP_WORLD_WIDTH, GameConstants.MAP_WORLD_HEIGHT)
	_scenery.setup(get_map_theme(), map_size, get_scenery_exclusions())


func _on_map_ready() -> void:
	MapOnlineBridge.register_map(self)


func _exit_tree() -> void:
	_on_map_exit()
	MapOnlineBridge.unregister_map(self)


func _on_map_exit() -> void:
	pass


# --- Online sync hooks (World overrides) ---

func notify_mob_hp(_sync_id: String, _hp: int) -> void:
	pass


func notify_mob_died(_sync_id: String) -> void:
	pass


func notify_boss_hp(_hp: float) -> void:
	pass


# --- Spawn ---

func _spawn_ui() -> void:
	var existing_ui := UiAccess.get_ui(self)
	if existing_ui:
		return
	var ui_scene := load(ProjectPaths.UI)
	if ui_scene:
		var ui_instance = ui_scene.instantiate()
		add_child(ui_instance)


func _spawn_player() -> void:
	var player_scene := load(ProjectPaths.PLAYER)
	if not player_scene:
		return

	var instance = player_scene.instantiate()
	if not (instance is Player):
		return

	player = instance as Player
	player.z_index = 10
	if GlobalData.warp_spawn_pending:
		player.global_position = Vector2(GlobalData.spawn_x, GlobalData.spawn_y)
	elif GlobalData.has_saved_position:
		player.global_position = Vector2(GlobalData.spawn_x, GlobalData.spawn_y)
		GlobalData.has_saved_position = false
	else:
		player.global_position = Vector2(
			GameConstants.MAP_WORLD_WIDTH / 2.0,
			GameConstants.MAP_WORLD_HEIGHT / 2.0
		)
	add_child(player)

	if player.camera:
		player.camera.make_current()

func _setup_ground() -> void:
	if not ground:
		return
	ground.texture = TextureGenerator.get_ground_map_texture(get_map_theme())
	ground.position = Vector2.ZERO
	ground.centered = false
	ground.z_index = 0
	ground.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func get_player() -> Player:
	return player


func blocks_player_movement() -> bool:
	var ui := UiAccess.get_ui(self)
	return ui != null and ui.has_method("blocks_player_movement") and ui.blocks_player_movement()

func is_modal_open() -> bool:
	var ui := UiAccess.get_ui(self)
	if ui != null and ui.has_method("is_modal_open"):
		return ui.is_modal_open()
	return false


func flash_damage() -> void:
	if player and player.camera:
		player.camera.get_node("FlashOverlay").do_flash(Color(1, 0, 0, 0.4), 0.075)


func flash_hit() -> void:
	if player and player.camera:
		player.camera.get_node("FlashOverlay").do_flash(Color(1, 1, 1, 0.5), 0.06)


func _is_ui_zone(pos: Vector2) -> bool:
	var ui := UiAccess.get_ui(self)
	if ui and ui.has_method("is_point_over_ui"):
		return ui.is_point_over_ui(pos)
	return false


func _get_world_mouse_pos() -> Vector2:
	var vp := get_viewport()
	if player and player.camera and player.camera.is_inside_tree():
		return vp.get_canvas_transform().affine_inverse() * vp.get_mouse_position()
	return vp.get_global_mouse_position()


# --- Input & movement ---

func _handle_movement(_delta: float) -> void:
	if not player or player.is_sitting or player.is_talking or player.is_dead:
		move_target = null
		if player:
			player.apply_velocity(0, 0)
		return

	var ui_blocks := blocks_player_movement() and not _is_map_click_move_active()

	var vx := 0.0
	var vy := 0.0
	if not ui_blocks:
		vx = Input.get_axis("move_left", "move_right")
		vy = Input.get_axis("move_up", "move_down")

	if vx != 0.0 or vy != 0.0:
		move_target = null
		player.apply_velocity(vx, vy)
		return

	var p_pos := player.global_position

	if move_target != null:
		var target: Vector2 = move_target
		if p_pos.distance_squared_to(target) > 16.0:
			var dir := (target - p_pos).normalized()
			
			var pos_before := player.global_position
			player.apply_velocity(dir.x, dir.y)
			
			if player.global_position.distance_squared_to(pos_before) < 0.01:
				move_target = null
				player.apply_velocity(0, 0)
		else:
			move_target = null
			player.apply_velocity(0, 0)
		return

	player.apply_velocity(0, 0)

func _update_click_move_target() -> void:
	if not player or player.is_talking or player.is_dead or _is_item_drag_active():
		return
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		return
	var screen_pos := get_viewport().get_mouse_position()
	if _is_ui_zone(screen_pos):
		return
	var world_pos := _get_world_mouse_pos()
	if _allow_click_move_to(world_pos):
		world_pos.x = clampf(world_pos.x, 8, GameConstants.MAP_WORLD_WIDTH - 8)
		world_pos.y = clampf(world_pos.y, 8, GameConstants.MAP_WORLD_HEIGHT - 8)
		move_target = world_pos

func _allow_click_move_to(_world_pos: Vector2) -> bool:
	return true


func _on_map_click(world_pos: Vector2) -> bool:
	for node in get_tree().get_nodes_in_group("npc"):
		if node is NPC and node.try_interact_at(world_pos):
			return true
	return false


func set_move_target_from_minimap(local_x: float, local_y: float, map_w: float, map_h: float) -> void:
	var target_x := (local_x / map_w) * GameConstants.MAP_WORLD_WIDTH
	var target_y := (local_y / map_h) * GameConstants.MAP_WORLD_HEIGHT
	target_x = clampf(target_x, 8, GameConstants.MAP_WORLD_WIDTH - 8)
	target_y = clampf(target_y, 8, GameConstants.MAP_WORLD_HEIGHT - 8)
	move_target = Vector2(target_x, target_y)


func _is_map_click_move_active() -> bool:
	var ui := UiAccess.get_ui(self)
	if ui and ui.has_method("is_item_drag_active") and ui.is_item_drag_active():
		return false
	if ui and ui.has_method("is_map_click_move_allowed"):
		return ui.is_map_click_move_allowed()
	return false


func _is_item_drag_active() -> bool:
	var ui := UiAccess.get_ui(self)
	return ui != null and ui.has_method("is_item_drag_active") and ui.is_item_drag_active()


func _physics_process(delta: float) -> void:
	if not player:
		return
	_update_click_move_target()
	_handle_movement(delta)


func _input(event: InputEvent) -> void:
	if not player or player.is_talking or player.is_dead or _is_item_drag_active():
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var screen_pos := get_viewport().get_mouse_position()
		if _is_ui_zone(screen_pos):
			return
		var world_pos := _get_world_mouse_pos()
		if _on_map_click(world_pos):
			get_viewport().set_input_as_handled()
			return
		if _allow_click_move_to(world_pos):
			world_pos.x = clampf(world_pos.x, 8, GameConstants.MAP_WORLD_WIDTH - 8)
			world_pos.y = clampf(world_pos.y, 8, GameConstants.MAP_WORLD_HEIGHT - 8)
			move_target = world_pos
		get_viewport().set_input_as_handled()
