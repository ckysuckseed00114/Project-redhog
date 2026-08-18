class_name BaseMap
extends Node2D

const ARRIVAL_DIST_SQ := 16.0
const NPC_TALK_DIST_SQ := 10000.0
const NPC_TALK_FALLBACK_DIST_SQ := 25600.0
const NPC_CLICK_RADIUS_MIN := 80.0
const PORTAL_AUTO_WARP_RANGE_SQ := 1225.0

var player: Player
var move_target: Variant = null
var pending_npc_talk: Node = null
var _quest_nav_active: bool = false
var _is_dragging_map: bool = false
var _ui: Node
var _quest_board_npc: NPC
var _portals: Array[Node2D] = []
var _npcs: Array[NPC] = []

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
	call_deferred("_cache_map_nodes")
	call_deferred("_resume_auto_quest_after_warp")


func _cache_map_nodes() -> void:
	_portals.clear()
	_npcs.clear()
	_quest_board_npc = null
	for node in get_tree().get_nodes_in_group("portal"):
		if node is Node2D:
			_portals.append(node as Node2D)
	for node in get_tree().get_nodes_in_group("npc"):
		if node is NPC:
			var npc := node as NPC
			_npcs.append(npc)
			if npc.npc_id == "quest_board":
				_quest_board_npc = npc


func _resume_auto_quest_after_warp() -> void:
	if player == null:
		return
	QuestNavigation.resume_after_warp(player, self)


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
	_ui = UiAccess.get_ui(self)
	if _ui:
		return
	var ui_scene: PackedScene = load(ProjectPaths.UI) as PackedScene
	if ui_scene == null:
		return
	var ui_instance: Node = ui_scene.instantiate()
	add_child(ui_instance)
	_ui = ui_instance


func _spawn_player() -> void:
	var player_scene := load(ProjectPaths.PLAYER)
	if not player_scene:
		return

	var instance: Node = player_scene.instantiate()
	if not (instance is Player):
		return

	player = instance as Player
	player.z_index = 10
	if GlobalData.warp_spawn_pending or GlobalData.has_saved_position:
		player.global_position = Vector2(GlobalData.spawn_x, GlobalData.spawn_y)
		if GlobalData.has_saved_position:
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


func _get_ui() -> Node:
	if _ui == null or not is_instance_valid(_ui):
		_ui = UiAccess.get_ui(self)
	return _ui


func blocks_player_movement() -> bool:
	var ui := _get_ui()
	return ui != null and ui.has_method("blocks_player_movement") and ui.blocks_player_movement()


func is_modal_open() -> bool:
	var ui := _get_ui()
	return ui != null and ui.has_method("is_modal_open") and ui.is_modal_open()


func _get_flash_overlay() -> Node:
	if player == null or player.camera == null:
		return null
	return player.camera.get_node_or_null("FlashOverlay")


func flash_damage() -> void:
	var flash := _get_flash_overlay()
	if flash and flash.has_method("do_flash"):
		flash.do_flash(Color(1, 0, 0, 0.4), 0.075)


func flash_hit() -> void:
	var flash := _get_flash_overlay()
	if flash and flash.has_method("do_flash"):
		flash.do_flash(Color(1, 1, 1, 0.5), 0.06)

func _get_world_mouse_pos() -> Vector2:
	var vp := get_viewport()
	if player and player.camera and player.camera.is_inside_tree():
		return vp.get_canvas_transform().affine_inverse() * vp.get_mouse_position()
	return vp.get_global_mouse_position()


func _should_keep_auto_quest_nav() -> bool:
	if GlobalData.is_auto_returning_quest:
		return true
	return GlobalData.has_active_auto_quest() \
		and GlobalData.auto_quest_state in [QuestNavigation.STATE_TRAVELING, QuestNavigation.STATE_RETURNING]


func _interrupt_manual_move() -> void:
	GlobalData.clear_auto_quest_state()
	GlobalData.clear_auto_quest()
	cancel_quest_navigation()
	pending_npc_talk = null


func _process_auto_return_turn_in() -> void:
	if player == null or _quest_board_npc == null:
		return

	var range_sq := GameConstants.NPC_INTERACT_RANGE * GameConstants.NPC_INTERACT_RANGE
	if player.global_position.distance_squared_to(_quest_board_npc.global_position) > range_sq:
		return

	move_target = null
	player.apply_velocity(0, 0)
	cancel_quest_navigation()

	var quest_id := GlobalData.returning_quest_id
	if quest_id != "" and player.turn_in_quest(quest_id):
		QuestService.save_quests(player)
		QuestService.refresh_quest_ui(self)

	GlobalData.clear_auto_quest_state()


func _try_auto_portal_warp() -> void:
	if player == null:
		return
	var p_pos := player.global_position
	for portal in _portals:
		if not is_instance_valid(portal) or not portal.has_method("try_auto_warp"):
			continue
		if p_pos.distance_squared_to(portal.global_position) > PORTAL_AUTO_WARP_RANGE_SQ:
			continue
		portal.call("try_auto_warp", player)
		return

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

	# ถ้ากดปุ่ม WASD ให้ยกเลิกเป้าหมายคลิกเมาส์ทันที
	if vx != 0.0 or vy != 0.0:
		_is_dragging_map = false
		_interrupt_manual_move()
		move_target = null
		player.apply_velocity(vx, vy)
		return

	var p_pos := player.global_position

	# ถ้ามีเป้าหมายจากการคลิกเมาส์ ให้เดินไปจนถึงเป้าหมาย
	if move_target != null:
		var target: Vector2 = move_target
		if p_pos.distance_squared_to(target) > ARRIVAL_DIST_SQ:
			var dir := (target - p_pos).normalized()
			var pos_before := player.global_position
			player.apply_velocity(dir.x, dir.y)
			
			if player.global_position.distance_squared_to(pos_before) < 0.01:
				move_target = null
				_is_dragging_map = false
				if not _should_keep_auto_quest_nav():
					cancel_quest_navigation()
				player.apply_velocity(0, 0)
		else:
			move_target = null
			_is_dragging_map = false
			if not _should_keep_auto_quest_nav():
				cancel_quest_navigation()
			player.apply_velocity(0, 0)
		return

	player.apply_velocity(0, 0)

func _allow_click_move_to(_world_pos: Vector2) -> bool:
	return true


func _on_map_click(world_pos: Vector2) -> bool:
	for npc in _npcs:
		if not is_instance_valid(npc):
			continue
		var click_rad := maxf(npc.click_area_radius, NPC_CLICK_RADIUS_MIN)
		var center_pos := _get_npc_center(npc)
		if center_pos.distance_squared_to(world_pos) <= click_rad * click_rad:
			_apply_manual_click_move(center_pos)
			pending_npc_talk = npc
			return true
	return false


func _get_npc_center(npc: Node) -> Vector2:
	if not npc.has_method("_get_sprite_metrics"):
		return npc.global_position
	var metrics: Dictionary = npc._get_sprite_metrics()
	return npc.to_global(metrics["center"] as Vector2)


func _process_pending_npc_talk() -> void:
	if pending_npc_talk == null or not is_instance_valid(pending_npc_talk) or player == null:
		return
	var npc_pos := _get_npc_center(pending_npc_talk)
	var dist_sq := player.global_position.distance_squared_to(npc_pos)
	if dist_sq <= NPC_TALK_DIST_SQ:
		if pending_npc_talk.has_method("try_interact_at"):
			pending_npc_talk.try_interact_at(npc_pos)
		move_target = null
		player.apply_velocity(0, 0)
		pending_npc_talk = null
	elif move_target == null:
		if dist_sq <= NPC_TALK_FALLBACK_DIST_SQ and pending_npc_talk.has_method("try_interact_at"):
			pending_npc_talk.try_interact_at(npc_pos)
		pending_npc_talk = null


func set_move_target_from_minimap(local_x: float, local_y: float, map_w: float, map_h: float) -> void:
	var target_x := (local_x / map_w) * GameConstants.MAP_WORLD_WIDTH
	var target_y := (local_y / map_h) * GameConstants.MAP_WORLD_HEIGHT
	target_x = clampf(target_x, 8, GameConstants.MAP_WORLD_WIDTH - 8)
	target_y = clampf(target_y, 8, GameConstants.MAP_WORLD_HEIGHT - 8)
	_interrupt_manual_move()
	move_target = Vector2(target_x, target_y)


func _apply_manual_click_move(world_pos: Vector2) -> bool:
	if not _allow_click_move_to(world_pos):
		return false
	world_pos = MapClickInput.clamp_map_pos(world_pos)
	_interrupt_manual_move()
	move_target = world_pos
	return true


func _set_move_target_from_click(world_pos: Vector2) -> bool:
	return _apply_manual_click_move(world_pos)


func _process_map_click_input(event: InputEvent) -> void:
	if not player or player.is_talking or player.is_dead or _is_item_drag_active():
		if event is InputEventMouseButton:
			_is_dragging_map = false
		return
	if not event is InputEventMouseButton or event.button_index != MOUSE_BUTTON_LEFT:
		return
	var screen_pos := get_viewport().get_mouse_position()
	if MapClickInput.is_ui_blocking(self, screen_pos):
		return
	var world_pos := _get_world_mouse_pos()
	
	if event.pressed:
		if _on_map_click(world_pos):
			_is_dragging_map = false
			return
		if _set_move_target_from_click(world_pos):
			_is_dragging_map = true
	else:
		_is_dragging_map = false

func mark_quest_navigation_active() -> void:
	_quest_nav_active = true


func cancel_quest_navigation() -> void:
	_quest_nav_active = false


func is_quest_navigation_active() -> bool:
	return _quest_nav_active


func _is_map_click_move_active() -> bool:
	var ui := _get_ui()
	if ui == null:
		return false
	if ui.has_method("is_item_drag_active") and ui.is_item_drag_active():
		return false
	return ui.has_method("is_map_click_move_allowed") and ui.is_map_click_move_allowed()


func _is_item_drag_active() -> bool:
	var ui := _get_ui()
	return ui != null and ui.has_method("is_item_drag_active") and ui.is_item_drag_active()


func _physics_process(_delta: float) -> void:
	if not player:
		return
	_update_click_move_target()
	_handle_movement(_delta)
	if pending_npc_talk != null:
		_process_pending_npc_talk()
	if GlobalData.is_auto_returning_quest:
		_process_auto_return_turn_in()
	if _should_keep_auto_quest_nav():
		_try_auto_portal_warp()

func _input(event: InputEvent) -> void:
	_process_map_click_input(event)


func _update_click_move_target() -> void:
	if not _is_dragging_map:
		return
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_is_dragging_map = false
		return
	if not player or player.is_talking or player.is_dead or _is_item_drag_active():
		_is_dragging_map = false
		return
	if MapClickInput.is_ui_blocking(self, get_viewport().get_mouse_position()):
		_is_dragging_map = false
		return
	var world_pos := _get_world_mouse_pos()
	if not _allow_click_move_to(world_pos):
		return
	move_target = MapClickInput.clamp_map_pos(world_pos)
