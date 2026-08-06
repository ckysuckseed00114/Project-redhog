extends Area2D

@export_file("*.tscn") var target_scene: String
@export var destination_name: String = "Unknown Area"
@export var spawn_position: Vector2 = Vector2.ZERO
@export var warp_color: Color = Color(0.3, 0.7, 1.0, 0.85)

var _warping := false
var _label: Label
var _glow: ColorRect


func _ready() -> void:
	add_to_group("portal")
	collision_layer = 0
	collision_mask = 1
	monitoring = true
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	_build_indicator()


func _build_indicator() -> void:
	_glow = ColorRect.new()
	_glow.custom_minimum_size = Vector2(36, 36)
	_glow.position = Vector2(-18, -18)
	_glow.color = Color(warp_color, 0.25)
	_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_glow)

	_label = Label.new()
	_label.text = "➜ %s" % destination_name
	_label.position = Vector2(-50, -52)
	_label.custom_minimum_size = Vector2(100, 18)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UITheme.style_label(_label, GameConstants.FONT_XS, warp_color, 2)
	add_child(_label)

	var hint := Label.new()
	hint.text = "[Walk in to warp]"
	hint.position = Vector2(-50, -36)
	hint.custom_minimum_size = Vector2(100, 14)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UITheme.style_label(hint, GameConstants.FONT_XS, UITheme.MUTED, 1)
	add_child(hint)


func _on_body_entered(body: Node2D) -> void:
	if _warping or target_scene == "":
		return
		
	if GlobalData.is_warp_grace_active():
		return
		
	if not (body is Player or body.is_in_group("player")):
		return
	if body.get("is_auto_mode"):
		return

	_warping = true
	var player: Player = body as Player if body is Player else null
	
	if player and DatabaseManager != null and DatabaseManager.has_method("save_player_data"):
		await DatabaseManager.save_player_data(player)

	await WarpHelper.execute(get_tree(), target_scene, spawn_position, destination_name, player)
