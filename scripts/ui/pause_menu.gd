extends CanvasLayer

@onready var main_panel: Panel = $Panel
@onready var settings_panel: Panel = $SettingsPanel
@onready var overlay: ColorRect = $ColorRect

const MAIN_SIZE := Vector2(380, 320)
const SETTINGS_SIZE := Vector2(400, 340)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100
	visible = false
	_apply_hd_theme()
	_center_panels()


func _apply_hd_theme() -> void:
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.anchor_right = 1.0
	overlay.anchor_bottom = 1.0
	overlay.offset_right = 0
	overlay.offset_bottom = 0
	overlay.color = Color(0, 0, 0, 0.72)

	_style_panel(main_panel, MAIN_SIZE)
	_style_panel(settings_panel, SETTINGS_SIZE)

	_style_title(main_panel.get_node_or_null("TitleLabel"))
	_style_title(settings_panel.get_node_or_null("TitleLabel"))

	_style_button_container(main_panel.get_node_or_null("VBoxContainer"), MAIN_SIZE)
	_style_button_container(settings_panel.get_node_or_null("VBoxContainer"), SETTINGS_SIZE)

	var logout_btn = main_panel.get_node_or_null("VBoxContainer/ออกจากระบบ")
	if logout_btn:
		logout_btn.add_theme_stylebox_override("normal", UITheme.make_button_style(Color8(0xc0, 0x39, 0x2b)))


func _style_panel(panel: Panel, panel_size: Vector2) -> void:
	panel.custom_minimum_size = panel_size
	panel.size = panel_size
	panel.add_theme_stylebox_override("panel", UITheme.make_panel_style(Color(0.10, 0.08, 0.16, 0.98), UITheme.GOLD, 10, 2))


func _style_title(label: Label) -> void:
	if label == null:
		return
	UITheme.style_label(label, GameConstants.FONT_LG, UITheme.GOLD, 2)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.custom_minimum_size = Vector2(MAIN_SIZE.x, 28)


func _style_button_container(box: VBoxContainer, panel_size: Vector2) -> void:
	if box == null:
		return
	box.add_theme_constant_override("separation", 10)
	box.offset_left = 24
	box.offset_top = 44
	box.offset_right = panel_size.x - 24
	box.offset_bottom = panel_size.y - 20
	for child in box.get_children():
		if child is Button:
			child.custom_minimum_size = Vector2(0, 44)
			child.add_theme_font_size_override("font_size", GameConstants.FONT_MD)
			child.add_theme_color_override("font_color", Color.WHITE)
			child.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
			child.add_theme_constant_override("outline_size", 1)
			var normal := UITheme.make_button_style(Color8(0x2c, 0x3e, 0x50))
			var hover := normal.duplicate()
			hover.bg_color = Color8(0x3d, 0x5a, 0x73)
			child.add_theme_stylebox_override("normal", normal)
			child.add_theme_stylebox_override("hover", hover)
			child.add_theme_stylebox_override("pressed", hover)


func _center_panels() -> void:
	main_panel.position = Vector2(
		(GameConstants.GAME_WIDTH - MAIN_SIZE.x) / 2.0,
		(GameConstants.GAME_HEIGHT - MAIN_SIZE.y) / 2.0
	)
	settings_panel.position = Vector2(
		(GameConstants.GAME_WIDTH - SETTINGS_SIZE.x) / 2.0,
		(GameConstants.GAME_HEIGHT - SETTINGS_SIZE.y) / 2.0
	)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		var current_scene = get_tree().current_scene.scene_file_path if get_tree().current_scene else ""
		if "login_screen" in current_scene or "character_selection" in current_scene or "character_creation" in current_scene:
			return
		_toggle_pause()


func _toggle_pause() -> void:
	get_tree().paused = not get_tree().paused
	visible = get_tree().paused
	if visible:
		main_panel.visible = true
		settings_panel.visible = false
		_center_panels()


func _on_resume_pressed() -> void:
	get_tree().paused = false
	visible = false


func _on_settings_pressed() -> void:
	main_panel.visible = false
	settings_panel.visible = true


func _on_settings_back_pressed() -> void:
	settings_panel.visible = false
	main_panel.visible = true


func _set_window_resolution(scale_multiplier: int) -> void:
	var target_width = GameConstants.GAME_WIDTH * scale_multiplier
	var target_height = GameConstants.GAME_HEIGHT * scale_multiplier

	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(target_width, target_height))

	var current_screen = DisplayServer.window_get_current_screen()
	var screen_size = DisplayServer.screen_get_size(current_screen)
	var screen_pos = DisplayServer.screen_get_position(current_screen)
	var center_offset = (screen_size - Vector2i(target_width, target_height)) / 2.0
	DisplayServer.window_set_position(screen_pos + Vector2i(center_offset))


func _on_res_960_pressed() -> void:
	_set_window_resolution(1)


func _on_res_1440_pressed() -> void:
	_set_window_resolution(2)


func _on_res_1920_pressed() -> void:
	_set_window_resolution(3)


func _on_fullscreen_pressed() -> void:
	var mode = DisplayServer.window_get_mode()
	if mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		_set_window_resolution(1)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)


func _on_character_selection_pressed() -> void:
	get_tree().paused = false
	visible = false
	get_tree().change_scene_to_file("res://scenes/ui/character_selection.tscn")


func _on_login_pressed() -> void:
	get_tree().paused = false
	visible = false
	get_tree().change_scene_to_file("res://scenes/ui/login_screen.tscn")


func _on_open_log_folder_pressed() -> void:
	var user_path = ProjectSettings.globalize_path("user://")
	OS.shell_open(user_path)
