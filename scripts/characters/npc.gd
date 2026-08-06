class_name NPC
extends Area2D

enum NpcRole { QUEST, SHOP, WARP, UPGRADE, JOB_MASTER, SAVE_POINT }

@export var npc_id: String = ""
@export var npc_name: String = "พนักงานร้านค้า"
@export var npc_role: NpcRole = NpcRole.QUEST
@export_multiline var dialog_message: String = "ยินดีต้อนรับสู่ร้านค้าของเรา ต้องการใช้บริการด้านไหนดีคะ?"
@export var npc_texture: Texture2D
@export var shop_id: String = "general_store"
@export_file("*.tscn") var warp_target_scene: String = ""
@export var warp_destination_name: String = ""
@export var warp_spawn_position: Vector2 = Vector2.ZERO
@export var foot_ui_extra_offset: Vector2 = Vector2.ZERO
@export var foot_y_adjust: float = 0.0
@export var click_area_offset: Vector2 = Vector2(8, 12)
@export var click_area_radius: float = 22.0
@export var use_auto_foot_ui: bool = true

var quest_ids: Array[String] = []
var warp_destinations: Array = []
var picker_kind: String = ""

var player_ref: Player = null
var is_chatting: bool = false
var _mouse_over: bool = false
var _job_quest_accepted: bool = false

func is_job_quest_accepted() -> bool:
	return _job_quest_accepted

func mark_job_quest_accepted() -> void:
	_job_quest_accepted = true

var _click_area: Area2D
var _foot_pos: Vector2 = Vector2.ZERO
var _foot_ui_visible: bool = false
var _foot_ui_show_hint: bool = false
var _foot_hint_text: String = "กด [F] เพื่อคุย"
var _in_interact_range: bool = false

# --- Lifecycle ---

func _ready() -> void:
	add_to_group("npc")
	if npc_id != "":
		NpcDatabase.apply_to_npc(self, npc_id)
	if npc_texture and has_node("Sprite2D"):
		$Sprite2D.texture = npc_texture
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_build_foot_ui()
	_setup_proximity_area()
	_setup_click_area()
	_setup_animation()

func _setup_animation() -> void:
	var anim_player := get_node_or_null("AnimationPlayer") as AnimationPlayer
	if anim_player == null:
		return
	if anim_player.autoplay != "":
		anim_player.play(anim_player.autoplay)

# --- Foot UI ---

func _build_foot_ui() -> void:
	call_deferred("_refresh_foot_position")

func _refresh_foot_position() -> void:
	_foot_pos = _resolve_foot_ui_position()

func _setup_proximity_area() -> void:
	var area := Area2D.new()
	area.name = "ProximityArea"
	area.collision_layer = 0
	area.collision_mask = 1
	area.monitoring = true
	area.monitorable = false
	var metrics := _get_sprite_metrics()
	area.position = metrics["center"] as Vector2
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = GameConstants.NPC_INTERACT_RANGE
	shape.shape = circle
	area.add_child(shape)
	add_child(area)
	area.body_entered.connect(_on_proximity_entered)
	area.body_exited.connect(_on_proximity_exited)

func _on_proximity_entered(body: Node2D) -> void:
	if body is Player:
		player_ref = body as Player

func _on_proximity_exited(body: Node2D) -> void:
	if body == player_ref:
		_close_chat()
		player_ref = null
		_in_interact_range = false

func _setup_click_area() -> void:
	_click_area = Area2D.new()
	_click_area.name = "ClickArea"
	_click_area.collision_layer = GameConstants.NPC_CLICK_LAYER
	_click_area.collision_mask = 0
	_click_area.input_pickable = true
	var circle := CircleShape2D.new()
	if use_auto_foot_ui:
		var metrics := _get_sprite_metrics()
		_click_area.position = metrics["center"] as Vector2
		circle.radius = maxf(click_area_radius, metrics["radius"] as float)
	else:
		_click_area.position = click_area_offset
		circle.radius = click_area_radius
	var shape := CollisionShape2D.new()
	shape.shape = circle
	_click_area.add_child(shape)
	add_child(_click_area)
	_click_area.input_event.connect(_on_click_area_input)
	_click_area.mouse_entered.connect(_on_mouse_entered)
	_click_area.mouse_exited.connect(_on_mouse_exited)

func _get_sprite_metrics() -> Dictionary:
	var center := Vector2(8, 12)
	var feet_y := 22.0
	var radius := 22.0
	if not has_node("Sprite2D"):
		return {"center": center, "feet_y": feet_y, "radius": radius}
	var spr: Sprite2D = $Sprite2D
	if spr.texture == null:
		return {"center": center, "feet_y": feet_y, "radius": radius}
	var cols := maxi(spr.hframes, 1)
	var rows := maxi(spr.vframes, 1)
	var frame_w := spr.texture.get_width() / float(cols)
	var frame_h := spr.texture.get_height() / float(rows)
	var scaled := Vector2(frame_w * absf(spr.scale.x), frame_h * absf(spr.scale.y))
	if spr.centered:
		center = spr.position
		feet_y = spr.position.y + scaled.y * 0.5
	else:
		center = spr.position + Vector2(scaled.x * 0.5, scaled.y * 0.5)
		feet_y = spr.position.y + scaled.y
	radius = maxf(scaled.x, scaled.y) * 0.45
	return {"center": center, "feet_y": feet_y, "radius": radius}

func _resolve_foot_ui_position() -> Vector2:
	var metrics := _get_sprite_metrics()
	var center: Vector2 = metrics["center"]
	var feet_y: float = metrics["feet_y"] + foot_y_adjust
	if not use_auto_foot_ui:
		return click_area_offset + Vector2(0, 10.0) + foot_ui_extra_offset
	return Vector2(center.x, feet_y + 4.0) + foot_ui_extra_offset

# --- Interaction ---

func _process(_delta: float) -> void:
	_update_foot_ui()
	queue_redraw()

func _draw() -> void:
	if not _foot_ui_visible:
		return
	var cam := get_viewport().get_camera_2d()
	var inv := Vector2.ONE / cam.zoom if cam else Vector2.ONE
	NpcFootUi.draw_at(self, _foot_pos, inv, npc_name, _foot_hint_text, _foot_ui_show_hint)

func _update_foot_ui() -> void:
	_update_interact_range()
	_foot_ui_visible = _in_interact_range and not is_chatting
	_foot_ui_show_hint = _in_interact_range
	_foot_hint_text = "กด [F] เพื่อคุย"

func _update_interact_range() -> void:
	var player := _get_player()
	if player == null:
		_in_interact_range = false
		return
	var metrics := _get_sprite_metrics()
	var center_global := to_global(metrics["center"] as Vector2)
	_in_interact_range = center_global.distance_to(player.global_position) <= GameConstants.NPC_INTERACT_RANGE
	if _in_interact_range:
		player_ref = player

func _get_player() -> Player:
	if player_ref and is_instance_valid(player_ref):
		return player_ref
	var world := get_tree().get_first_node_in_group("world")
	if world and world.has_method("get_player"):
		var p = world.get_player()
		if p is Player:
			return p
	return null

func _is_player_in_range() -> bool:
	return _in_interact_range

func _is_closest_interact_npc() -> bool:
	var player := _get_player()
	if player == null or not _in_interact_range:
		return false
	var closest: NPC = null
	var best_dist_sq := INF
	for node in get_tree().get_nodes_in_group("npc"):
		if not (node is NPC):
			continue
		var npc := node as NPC
		if not npc._in_interact_range:
			continue
		var metrics := npc._get_sprite_metrics()
		var center_global := npc.to_global(metrics["center"] as Vector2)
		var dist_sq := center_global.distance_squared_to(player.global_position)
		if dist_sq < best_dist_sq:
			best_dist_sq = dist_sq
			closest = npc
	return closest == self

func try_interact_at(world_pos: Vector2) -> bool:
	var metrics := _get_sprite_metrics()
	var center_global := to_global(metrics["center"] as Vector2)
	if center_global.distance_to(world_pos) > GameConstants.NPC_INTERACT_RANGE:
		return false
	return _try_interact()

func _try_interact() -> bool:
	if is_chatting:
		return false
	if not _is_player_in_range():
		var ui := UiAccess.get_ui(self)
		if ui and ui.has_method("add_log"):
			ui.add_log("เข้าใกล้ %s ก่อน" % npc_name, UITheme.MUTED)
		return false
	_open_chat()
	return true

func _on_click_area_input(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _try_interact():
			get_viewport().set_input_as_handled()

func _on_mouse_entered() -> void:
	_mouse_over = true

func _on_mouse_exited() -> void:
	_mouse_over = false

func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		player_ref = body

func _on_body_exited(body: Node2D) -> void:
	if body == player_ref:
		_close_chat()
		player_ref = null

func _unhandled_input(event: InputEvent) -> void:
	if is_chatting or not _in_interact_range:
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_F:
		if not _is_closest_interact_npc():
			return
		_open_chat()
		get_viewport().set_input_as_handled()

# --- Dialog (delegates to role handlers) ---

func _open_chat() -> void:
	NpcRoleHandlers.open_dialog(self)

func _close_chat() -> void:
	is_chatting = false
	if player_ref:
		player_ref.is_talking = false

func on_dialog_closed() -> void:
	is_chatting = false
	if player_ref:
		player_ref.is_talking = false

func on_dialog_accept() -> bool:
	return NpcRoleHandlers.on_accept(self)

func on_dialog_decline() -> bool:
	return NpcRoleHandlers.on_decline(self)

func on_dialog_complete() -> bool:
	return NpcRoleHandlers.on_complete(self)


func on_picker_selected(option_id: String) -> bool:
	return NpcRoleHandlers.on_picker_selected(self, option_id)
