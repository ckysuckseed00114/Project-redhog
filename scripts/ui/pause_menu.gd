extends CanvasLayer

@onready var main_panel: Panel = $Panel
@onready var settings_panel: Panel = $SettingsPanel
@onready var overlay: ColorRect = $ColorRect
@onready var _main_vbox: VBoxContainer = $Panel/VBoxContainer

const MAIN_SIZE := Vector2(380, 320)
const MAIN_SIZE_DEBUG := Vector2(380, 360)
const SETTINGS_SIZE := Vector2(400, 340)
const ADMIN_SIZE := Vector2(400, 340)

var _admin_panel: Panel
var _transition_busy: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100
	visible = false
	_transition_busy = false
	_apply_hd_theme()
	_center_panels()
	if AdminCheats.is_enabled():
		_setup_admin_panel()


func _apply_hd_theme() -> void:
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.anchor_right = 1.0
	overlay.anchor_bottom = 1.0
	overlay.offset_right = 0
	overlay.offset_bottom = 0
	overlay.color = Color(0, 0, 0, 0.72)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP # 🌟 ป้องกันการคลิกเมาส์ทะลุจางๆ

	var main_size := MAIN_SIZE_DEBUG if AdminCheats.is_enabled() else MAIN_SIZE
	_style_panel(main_panel, main_size)
	_style_panel(settings_panel, SETTINGS_SIZE)

	_style_title(main_panel.get_node_or_null("TitleLabel"))
	_style_title(settings_panel.get_node_or_null("TitleLabel"))

	_style_button_container(main_panel.get_node_or_null("VBoxContainer"), main_size)
	_style_button_container(settings_panel.get_node_or_null("VBoxContainer"), SETTINGS_SIZE)

	var logout_btn = main_panel.get_node_or_null("VBoxContainer/ออกจากระบบ")
	if logout_btn:
		logout_btn.add_theme_stylebox_override("normal", UITheme.make_button_style(Color8(0xc0, 0x39, 0x2b)))

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		var current_scene = get_tree().current_scene.scene_file_path if get_tree().current_scene else ""
		if "login_screen" in current_scene or "character_selection" in current_scene or "character_creation" in current_scene:
			return
		_toggle_pause()
		get_viewport().set_input_as_handled() # 🌟 ยืนยันการจัดการปุ่ม ESC
		return
		
	# 🌟 ถ้าหน้าต่าง Pause เปิดอยู่ ให้ดักจับคีย์บอร์ดทั้งหมด (ป้องกันกด Hotkey พื้นหลัง)
	if visible:
		get_viewport().set_input_as_handled()

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
	var main_size := MAIN_SIZE_DEBUG if AdminCheats.is_enabled() else MAIN_SIZE
	main_panel.position = Vector2(
		(float(GameConstants.GAME_WIDTH) - main_size.x) / 2.0,
		(float(GameConstants.GAME_HEIGHT) - main_size.y) / 2.0
	)
	settings_panel.position = Vector2(
		(float(GameConstants.GAME_WIDTH) - SETTINGS_SIZE.x) / 2.0,
		(float(GameConstants.GAME_HEIGHT) - SETTINGS_SIZE.y) / 2.0
	)
	if _admin_panel:
		_admin_panel.position = Vector2(
			(float(GameConstants.GAME_WIDTH) - ADMIN_SIZE.x) / 2.0,
			(float(GameConstants.GAME_HEIGHT) - ADMIN_SIZE.y) / 2.0
		)
		
func _setup_admin_panel() -> void:
	var admin_btn := Button.new()
	admin_btn.text = "Admin Test (Debug)"
	admin_btn.pressed.connect(_on_admin_pressed)
	var logout_idx := _main_vbox.get_node("ออกจากระบบ").get_index()
	_main_vbox.add_child(admin_btn)
	_main_vbox.move_child(admin_btn, logout_idx)
	_style_admin_button(admin_btn)

	_admin_panel = Panel.new()
	_admin_panel.visible = false
	_admin_panel.custom_minimum_size = ADMIN_SIZE
	_admin_panel.size = ADMIN_SIZE
	_admin_panel.add_theme_stylebox_override(
		"panel",
		UITheme.make_panel_style(Color(0.10, 0.08, 0.16, 0.98), Color8(0x9b, 0x59, 0xb6), 10, 2)
	)
	add_child(_admin_panel)

	var title := Label.new()
	title.text = "- ADMIN TEST -"
	title.position = Vector2(0, 8)
	title.size = Vector2(ADMIN_SIZE.x, 28)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UITheme.style_label(title, GameConstants.FONT_LG, Color8(0x9b, 0x59, 0xb6), 2)
	_admin_panel.add_child(title)

	var vbox := VBoxContainer.new()
	vbox.offset_left = 24
	vbox.offset_top = 44
	vbox.offset_right = ADMIN_SIZE.x - 24
	vbox.offset_bottom = ADMIN_SIZE.y - 20
	vbox.add_theme_constant_override("separation", 10)
	_admin_panel.add_child(vbox)

	_add_admin_action(vbox, "+1 Level", _admin_grant_levels.bind(1))
	_add_admin_action(vbox, "+5 Levels", _admin_grant_levels.bind(5))
	_add_admin_action(vbox, "+5 Stat Points", _admin_grant_stat_points.bind(5))
	_add_admin_action(vbox, "+1 All Primary Stats", _admin_grant_primary_stats.bind(1))

	var back_btn := Button.new()
	back_btn.text = "ย้อนกลับ (Back)"
	back_btn.custom_minimum_size = Vector2(0, 44)
	back_btn.pressed.connect(_on_admin_back_pressed)
	vbox.add_child(back_btn)
	_style_admin_button(back_btn)


func _add_admin_action(vbox: VBoxContainer, label: String, callback: Callable) -> void:
	var btn := Button.new()
	btn.text = label
	btn.custom_minimum_size = Vector2(0, 44)
	btn.pressed.connect(callback)
	vbox.add_child(btn)
	_style_admin_button(btn)


func _style_admin_button(btn: Button) -> void:
	btn.add_theme_font_size_override("font_size", GameConstants.FONT_MD)
	btn.add_theme_color_override("font_color", Color.WHITE)
	var normal := UITheme.make_button_style(Color8(0x5b, 0x2c, 0x6f))
	var hover := normal.duplicate()
	hover.bg_color = Color8(0x7d, 0x3c, 0x98)
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", hover)


func _get_player() -> Player:
	var world := get_tree().get_first_node_in_group("world")
	if world and world.has_method("get_player"):
		return world.get_player()
	return null


func _admin_grant_levels(count: int) -> void:
	var p := _get_player()
	if p:
		AdminCheats.grant_levels(p, count)


func _admin_grant_stat_points(amount: int) -> void:
	var p := _get_player()
	if p:
		AdminCheats.grant_stat_points(p, amount)


func _admin_grant_primary_stats(amount: int) -> void:
	var p := _get_player()
	if p:
		AdminCheats.grant_primary_stats(p, amount)


func _on_admin_pressed() -> void:
	main_panel.visible = false
	settings_panel.visible = false
	if _admin_panel:
		_admin_panel.visible = true


func _on_admin_back_pressed() -> void:
	if _admin_panel:
		_admin_panel.visible = false
	main_panel.visible = true

func _toggle_pause() -> void:
	visible = not visible
	if visible:
		_transition_busy = false
		_set_main_buttons_enabled(true)
		main_panel.visible = true
		settings_panel.visible = false
		if _admin_panel:
			_admin_panel.visible = false
		_center_panels()

func _on_resume_pressed() -> void:
	visible = false


func _on_settings_pressed() -> void:
	main_panel.visible = false
	settings_panel.visible = true


func _on_settings_back_pressed() -> void:
	settings_panel.visible = false
	main_panel.visible = true


func _set_window_size(target_size: Vector2i) -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(target_size)

	var current_screen := DisplayServer.window_get_current_screen()
	var screen_size := DisplayServer.screen_get_size(current_screen)
	var screen_pos := DisplayServer.screen_get_position(current_screen)
	var center_offset := (Vector2(screen_size) - Vector2(target_size)) / 2.0
	DisplayServer.window_set_position(screen_pos + Vector2i(center_offset))

func _on_res_1080_pressed() -> void:
	_set_window_size(Vector2i(1920, 1080))


func _on_res_1440_pressed() -> void:
	_set_window_size(Vector2i(2560, 1440))


func _on_fullscreen_pressed() -> void:
	var mode := DisplayServer.window_get_mode()
	if mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		_set_window_size(Vector2i(1920, 1080))
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)


func _set_main_buttons_enabled(enabled: bool) -> void:
	for child in _main_vbox.get_children():
		if child is Button:
			child.disabled = not enabled


func _is_gameplay_scene() -> bool:
	var current_scene := get_tree().current_scene.scene_file_path if get_tree().current_scene else ""
	return not (
		"login_screen" in current_scene
		or "character_selection" in current_scene
		or "character_creation" in current_scene
	)


func _save_before_scene_change() -> bool:
	if not _is_gameplay_scene():
		return true

	var p := _get_player()
	if p == null or not OnlineSession.is_logged_in():
		return true

	var save_id := DatabaseManager.save_game_data(p)
	return await DatabaseManager.wait_for_save_id(save_id)


func _leave_to_scene(scene_path: String) -> void:
	if _transition_busy:
		return
	_transition_busy = true
	_set_main_buttons_enabled(false)
	visible = false

	await SceneTransition.fade_in("Saving & Exiting...")

	var saved := await _save_before_scene_change()
	if not saved:
		SceneTransition.update_text("Save failed — please try again")
		await SceneTransition.fade_out()
		_transition_busy = false
		visible = true
		main_panel.visible = true
		_set_main_buttons_enabled(true)
		return

	SceneTransition.update_text("Loading...")
	SceneTransition.prepare_fade_out_on_load()
	get_tree().change_scene_to_file(scene_path)


func _on_character_selection_pressed() -> void:
	await _leave_to_scene("res://scenes/ui/character_selection.tscn")


func _on_login_pressed() -> void:
	await _leave_to_scene("res://scenes/ui/login_screen.tscn")


func _on_open_log_folder_pressed() -> void:
	var user_path = ProjectSettings.globalize_path("user://")
	OS.shell_open(user_path)
