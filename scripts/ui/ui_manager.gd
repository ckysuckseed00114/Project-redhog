class_name UIManager
extends CanvasLayer

const HUD_PANEL := Color(0.08, 0.08, 0.12, 0.85)
const BORDER := Color8(0x7f, 0x8c, 0x8d)
const GW := GameConstants.GAME_WIDTH
const GH := GameConstants.GAME_HEIGHT

# ui_manager.gd — สารบัญ
# [Setup] _ready, _connect_world, _build_ui
# [HUD] _build_hud, _build_minimap, _build_buttons, _build_skill_bar, _process
# [Windows] stat/inv/equip/skill/party/boss/map — _build_*_window, _toggle_*
# [NPC Dialog] open_npc_dialog, _close_npc_dialog
# [Helpers] _make_*, _animate_window, tooltip, notifications

var _action_bar: Panel

var world: Node2D
var player: Player
var chat_log_instance: ChatLog
var _shop_panel: ShopPanel
var is_stat_open: bool = false
var is_inventory_open: bool = false
var is_skill_open: bool = false
var is_party_open: bool = false
var is_boss_open: bool = false
var is_map_open: bool = false
var is_auto_window_open: bool = false
var is_death_dialog_open: bool = false
var _auto_root: Panel
var _auto_switch_btn: CheckButton
var _auto_flee_boss_btn: CheckButton
var _auto_potion_btn: CheckButton
var _auto_potion_hp_slider: HSlider
var _auto_potion_sp_slider: HSlider
var _auto_potion_hp_lbl: Label
var _auto_potion_sp_lbl: Label
var _syncing_auto_ui: bool = false
var _death_root: Panel
var _death_blocker: ColorRect
var _death_message: Label
var _death_at_spot_btn: Button
var _death_at_save_btn: Button
var is_npc_dialog_open: bool = false
var is_shop_open: bool = false
var ui_root: Control
var _skill_root: Panel
var _skill_book: SkillBookPanel
var _quest_log: QuestLogPanel
var _title_label: Label
var _job_hud_label: Label
var _zeny_hud_label: Label
var _hp_bar: ColorRect
var _hp_text: Label
var _sp_bar: ColorRect
var _sp_text: Label
var _xp_bar: ColorRect
var _xp_text: Label
var _target_hud_root: Panel
var _target_name_label: Label
var _target_hp_bar: ColorRect
var _target_hp_text: Label
var _stat_panel: StatWindowPanel
var _inv_root: Panel
var _inventory_panel: InventoryPanel
var _inv_slots: Array = []
var _equip_root: Panel
var _equipment_panel: EquipmentPanel
var _equip_slots: Dictionary = {}
var _skill_slots: Array = []
var _tooltip_panel: Panel
var _tooltip_hbox: HBoxContainer
var _left_box: Panel
var _left_icon: TextureRect
var _left_label: Label
var _right_box: Panel
var _right_icon: TextureRect
var _right_label: Label
var _party_root: Panel
var _party_list_container: VBoxContainer
var _minimap: Control
var _minimap_info: Panel
var _minimap_name_label: Label
var _boss_root: Panel
var _boss_panel: BossSpawnPanel
var _map_root: Panel
var _map_title_label: Label
var _map_subtitle_label: Label
var _map_frame: Panel
var _map_hint_label: Label
var _current_map_panel: Minimap
var _map_overview: MapOverview
var _world_map_btn: Button
var _current_map_btn: Button
var _map_showing_world: bool = false
var _npc_dialog_root: Panel
var _npc_dialog_name: Label
var _npc_dialog_message: Label
var _npc_dialog_accept: Button
var _npc_dialog_decline: Button
var _npc_dialog_complete: Button
var _npc_dialog_close: Button
var _npc_job_grid: GridContainer
var _npc_active: NPC = null
var _skill_bar_root: Control
var _party_status_label: Label
var _party_id_label: Label
var _online_label: Label
var _active_notifications: Array[Panel] = []
var _drag_inv_index: int = -1
var _drag_skill_id: String = ""
var _drag_item_id: String = ""
var _drag_from_slot_idx: int = -1
var _slot_press_idx: int = -1
var _slot_press_pos: Vector2 = Vector2.ZERO
var _skill_book_press_id: String = ""
var _skill_book_press_pos: Vector2 = Vector2.ZERO
const SLOT_DRAG_THRESHOLD := 10.0
var _drag_preview: Control = null

# --- Setup ---

func _ready() -> void:
	add_to_group("ui")
	layer = 10
	ui_root = Control.new()
	ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	super.add_child(ui_root)

	call_deferred("_connect_world")

func _update_player_stats_ui() -> void:
	if not player: return

	_title_label.text = GlobalData.player_name if GlobalData.player_name != "" else "Adventurer"
	if _job_hud_label:
		_job_hud_label.text = "Lv.%d | %s J.Lv.%d" % [player.level, ClassDatabase.get_display_name(player.current_job), player.job_level]
	if _zeny_hud_label:
		_zeny_hud_label.text = "%d Z" % player.zeny

	var hp_pct := clampf(float(player.hp) / player.max_hp, 0.0, 1.0)
	_hp_bar.scale.x = hp_pct
	_hp_text.text = "%d/%d" % [player.hp, player.max_hp]

	var sp_pct := clampf(float(player.sp) / player.max_sp, 0.0, 1.0)
	_sp_bar.scale.x = sp_pct
	_sp_text.text = "%d/%d" % [player.sp, player.max_sp]

	var xp_pct := clampf(float(player.current_exp) / player.max_exp, 0.0, 1.0)
	_xp_bar.scale.x = xp_pct
	_xp_text.text = "%d/%d" % [player.current_exp, player.max_exp]
	
	if is_stat_open and _stat_panel:
		_stat_panel.refresh(player)


func _connect_world() -> void:
	world = get_tree().get_first_node_in_group("world")
	if world:
		player = world.get_player()
		if player:
			if player.has_signal("inventory_changed"):
				player.inventory_changed.connect(_on_inventory_changed)
			if player.has_signal("equipment_changed"):
				player.equipment_changed.connect(_update_equipment_ui)
			if player.has_signal("stats_changed"):
				player.stats_changed.connect(_update_player_stats_ui)
			if player.has_signal("quests_changed"):
				player.quests_changed.connect(refresh_quest_log)
		_build_ui()


func blocks_player_movement() -> bool:
	if is_death_dialog_open:
		return true
		
	# 🌟 เพิ่มการเช็กหน้าต่าง Pause Menu กลางเกม
	var pause_menu = get_tree().root.get_node_or_null("PauseMenu")
	if pause_menu and pause_menu.visible:
		return true
		
	var chat_open := chat_log_instance != null and chat_log_instance.is_input_focused()
	if is_npc_dialog_open or chat_open:
		return true
	if player != null and player.is_talking:
		return true
	return is_stat_open or is_inventory_open or is_skill_open or is_party_open \
		or is_shop_open or is_boss_open or is_map_open or is_auto_window_open

func is_death_input_locked() -> bool:
	return is_death_dialog_open


func _block_if_death_modal() -> bool:
	if is_death_dialog_open:
		_layout_death_layers()
		return true
	return false


func _set_action_bar_buttons_disabled(disabled: bool) -> void:
	if _action_bar == null:
		return
	for child in _action_bar.get_children():
		if child is BaseButton:
			child.disabled = disabled


func is_modal_open() -> bool:
	return blocks_player_movement()


func is_point_over_ui(pos: Vector2) -> bool:
	return _rect_blocks_click(pos)


func _panel_screen_rect(panel: Control) -> Rect2:
	if panel == null or not panel.visible:
		return Rect2()
	if panel.is_inside_tree():
		return panel.get_global_rect()
	var sz := panel.size
	if sz.x <= 1.0 or sz.y <= 1.0:
		sz = panel.custom_minimum_size
	return Rect2(panel.position, sz)


func _rect_blocks_click(pos: Vector2) -> bool:
	if is_death_dialog_open:
		return true
		
	# 🌟 เพิ่มการเช็กคลิกเมาส์บนหน้าต่าง Pause Menu กลางเกม
	var pause_menu = get_tree().root.get_node_or_null("PauseMenu")
	if pause_menu and pause_menu.visible:
		return true
		
	var hud_rect := Rect2(GameConstants.HUD_MARGIN, GameConstants.HUD_MARGIN, GameConstants.HUD_WIDTH, GameConstants.HUD_HEIGHT)
	if hud_rect.has_point(pos):
		return true
	if GameConstants.minimap_hud_rect().has_point(pos):
		return true
	if _target_hud_root and _target_hud_root.visible and _panel_screen_rect(_target_hud_root).has_point(pos):
		return true
	for panel in _open_window_panels():
		if _panel_screen_rect(panel).has_point(pos):
			return true
	if _tooltip_panel and _tooltip_panel.visible and _panel_screen_rect(_tooltip_panel).has_point(pos):
		return true
	if _action_bar and _panel_screen_rect(_action_bar).has_point(pos):
		return true
	if _skill_bar_root and _skill_bar_root.visible and _panel_screen_rect(_skill_bar_root).has_point(pos):
		return true
	if chat_log_instance and _panel_screen_rect(chat_log_instance).has_point(pos):
		return true
	if _quest_log and _quest_log.is_panel_visible() and _panel_screen_rect(_quest_log).has_point(pos):
		return true
	if pos.y >= GameConstants.action_bar_y():
		return true
	return false

func _open_window_panels() -> Array[Control]:
	var panels: Array[Control] = []
	if is_stat_open and _stat_panel:
		panels.append(_stat_panel)
	if is_inventory_open:
		if _inv_root:
			panels.append(_inv_root)
		if _equip_root:
			panels.append(_equip_root)
	if is_skill_open and _skill_root:
		panels.append(_skill_root)
	if is_party_open and _party_root:
		panels.append(_party_root)
	if is_boss_open and _boss_root:
		panels.append(_boss_root)
	if is_map_open and _map_root:
		panels.append(_map_root)
	if is_shop_open and is_instance_valid(_shop_panel):
		panels.append(_shop_panel)
	if is_death_dialog_open and _death_root:
		panels.append(_death_root)
	if is_npc_dialog_open and _npc_dialog_root:
		panels.append(_npc_dialog_root)
	if is_auto_window_open and _auto_root:
		panels.append(_auto_root)
	return panels


func _left_column_start_y() -> float:
	return UILayout.left_column_start_y()


func _chat_collapsed() -> bool:
	return chat_log_instance != null and chat_log_instance.is_collapsed()


func _layout_open_windows() -> void:
	_layout_bottom_hud()
	_layout_online_label()
	_layout_left_column()
	_layout_right_column()
	_layout_center_modals()
	_layout_quest_log()
	if is_death_dialog_open:
		_layout_death_layers()


func _layout_bottom_hud() -> void:
	var collapsed := _chat_collapsed()
	if chat_log_instance:
		chat_log_instance.apply_layout(UILayout.chat_rect(collapsed))
	if _skill_bar_root:
		var skill_rect := UILayout.skill_bar_rect(collapsed)
		_skill_bar_root.position = skill_rect.position
		_skill_bar_root.custom_minimum_size = skill_rect.size


func _layout_online_label() -> void:
	if _online_label:
		_online_label.position = UILayout.online_label_pos()


func _layout_left_column() -> void:
	var x := UILayout.left_column_x()
	var y := UILayout.layout_stat_y(
		_quest_log != null and _quest_log.is_panel_visible(),
		_quest_log.is_collapsed() if _quest_log else true,
		_chat_collapsed()
	)
	if is_stat_open and _stat_panel:
		_stat_panel.position = Vector2(x, y)


func _layout_quest_log() -> void:
	if _quest_log == null:
		return
	var pos := UILayout.layout_quest(
		is_stat_open,
		_quest_log.is_panel_visible(),
		_quest_log.is_collapsed(),
		_chat_collapsed()
	)
	if pos.x >= 0.0:
		_quest_log.position = pos


func _layout_right_column() -> void:
	if not is_inventory_open:
		return
	var equip_size := GameConstants.WIN_EQUIP_SIZE
	var spacing := float(GameConstants.UI_PANEL_GAP)
	var start_x := UILayout.inventory_block_left()
	var start_y := UILayout.layout_inventory_y(_chat_collapsed())
	if _equip_root:
		_equip_root.position = Vector2(start_x, start_y)
	if _inv_root:
		_inv_root.position = Vector2(start_x + equip_size.x + spacing, start_y)


func _layout_center_modals() -> void:
	var area := UILayout.modal_bounds(is_stat_open, is_inventory_open, _chat_collapsed())
	if is_skill_open and _skill_root:
		_skill_root.position = UILayout.place_in_rect(GameConstants.WIN_SKILL_SIZE, area)
	if is_party_open and _party_root:
		_party_root.position = UILayout.place_in_rect(Vector2(420, 360), area)
	if is_map_open and _map_root:
		_map_root.position = UILayout.place_in_rect(Vector2(360, 348), area)
	if is_shop_open and is_instance_valid(_shop_panel):
		_shop_panel.position = UILayout.place_in_rect(Vector2(460, 360), area)
	if is_npc_dialog_open and _npc_dialog_root:
		_npc_dialog_root.position = UILayout.place_in_rect(Vector2(520, 220), area)
	if is_auto_window_open and _auto_root:
		_auto_root.position = UILayout.place_in_rect(Vector2(340, 300), area)
	_layout_boss_window()


func _layout_boss_window() -> void:
	if not is_boss_open or not _boss_root:
		return
	var area := UILayout.modal_bounds(is_stat_open, is_inventory_open, _chat_collapsed())
	var count := WorldSyncManager.WORLD_BOSSES.size()
	var rect := UILayout.boss_window_rect(count, _chat_collapsed())
	_boss_root.position = rect.position
	_boss_root.custom_minimum_size = rect.size
	_boss_root.size = rect.size
	if _boss_panel:
		_boss_panel.position = Vector2(8, 32)
		_boss_panel.custom_minimum_size = Vector2(rect.size.x - 16, rect.size.y - 40)
		_boss_panel.size = _boss_panel.custom_minimum_size
		_map_root.position = UILayout.place_in_rect(Vector2(360, 348), area)
	if is_shop_open and is_instance_valid(_shop_panel):
		_shop_panel.position = UILayout.place_in_rect(Vector2(460, 360), area)
	if is_npc_dialog_open and _npc_dialog_root:
		_npc_dialog_root.position = UILayout.place_in_rect(Vector2(520, 220), area)


func _update_bottom_hud_input_block() -> void:
	var death_locked := is_death_dialog_open
	var block := is_npc_dialog_open or is_shop_open
	var filter := Control.MOUSE_FILTER_STOP if death_locked else (Control.MOUSE_FILTER_IGNORE if block else Control.MOUSE_FILTER_STOP)
	if _action_bar:
		_action_bar.mouse_filter = filter
		_set_action_bar_buttons_disabled(death_locked)
	if _skill_bar_root:
		_skill_bar_root.mouse_filter = Control.MOUSE_FILTER_IGNORE if (block or death_locked) else Control.MOUSE_FILTER_STOP
	if chat_log_instance:
		if death_locked:
			chat_log_instance.mouse_filter = Control.MOUSE_FILTER_STOP
		else:
			chat_log_instance.mouse_filter = filter


func _raise_modal_panel(panel: Control) -> void:
	if panel == null or panel.get_parent() != ui_root:
		return
	ui_root.move_child(panel, ui_root.get_child_count() - 1)
	panel.z_index = 80


# --- HUD build ---

func _build_ui() -> void:
	_build_hud()
	_build_minimap()
	_build_boss_window()
	_build_map_window()
	_build_npc_dialog()
	_build_death_dialog()
	_build_target_hud()
	_build_buttons()
	_build_skill_bar()
	_update_quick_slot_ui()
	_build_stat_window()
	_build_equipment_window()
	_build_inventory_window()
	_build_skill_window()
	_build_quest_log()
	_build_party_window()
	_build_auto_window()
	_build_tooltip()

	chat_log_instance = ChatLog.new()
	chat_log_instance.message_submitted.connect(_on_chat_message_submitted)
	chat_log_instance.layout_changed.connect(_layout_open_windows)
	ui_root.add_child(chat_log_instance)

	_online_label = _make_label("", Vector2(0, 0), GameConstants.FONT_XS, false, Color8(0x66, 0xcc, 0xff))
	ui_root.add_child(_online_label)
	if OnlinePresenceManager:
		OnlinePresenceManager.presence_updated.connect(_on_presence_updated)
		OnlinePresenceManager.chat_received.connect(_on_chat_received)

	if PartyManager:
		PartyManager.party_updated.connect(_update_party_ui)

	_layout_open_windows()


func _build_hud() -> void:
	var hud_panel := Panel.new()
	hud_panel.position = Vector2(GameConstants.HUD_MARGIN, GameConstants.HUD_MARGIN)
	hud_panel.custom_minimum_size = Vector2(GameConstants.HUD_WIDTH, GameConstants.HUD_HEIGHT)
	hud_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_panel.add_theme_stylebox_override("panel", UITheme.make_panel_style(Color(0.06, 0.06, 0.1, 0.94), UITheme.GOLD, 10, 2))
	ui_root.add_child(hud_panel)

	var pad := 12
	var bar_w := GameConstants.HUD_WIDTH - pad * 2

	_title_label = _make_label("Adventurer", Vector2(pad, 8), GameConstants.FONT_MD, true, UITheme.GOLD)
	hud_panel.add_child(_title_label)

	_job_hud_label = _make_label("Novice", Vector2(pad, 28), GameConstants.FONT_XS, false, Color8(0xbb, 0xdd, 0xff))
	hud_panel.add_child(_job_hud_label)

	_zeny_hud_label = _make_label("Z 500", Vector2(pad + 168, 28), GameConstants.FONT_XS, true, Color8(0xff, 0xd7, 0x00))
	_zeny_hud_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_zeny_hud_label.custom_minimum_size = Vector2(bar_w - 168, 14)
	hud_panel.add_child(_zeny_hud_label)

	_add_hud_bar(hud_panel, "HP", Vector2(pad, 48), bar_w, Color8(0x9b, 0xe8, 0x44))
	_add_hud_bar(hud_panel, "SP", Vector2(pad, 68), bar_w, Color8(0x44, 0xd4, 0xe8))
	_add_hud_bar(hud_panel, "EXP", Vector2(pad, 88), bar_w, Color8(0xf1, 0xc4, 0x0f))


func _add_hud_bar(parent: Control, tag: String, pos: Vector2, width: float, color: Color) -> void:
	parent.add_child(_make_label(tag, pos, GameConstants.FONT_XS, true, UITheme.MUTED))
	var bg := _create_bar_bg(pos + Vector2(28, 0), Vector2(width - 28, GameConstants.BAR_HEIGHT), Color8(0x1a, 0x1a, 0x22))
	parent.add_child(bg)
	var bar := ColorRect.new()
	bar.color = color
	bar.custom_minimum_size = Vector2(width - 28, GameConstants.BAR_HEIGHT)
	bg.add_child(bar)
	var text := _make_label("0/0", Vector2(0, 0), GameConstants.FONT_XS, true)
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	text.custom_minimum_size = Vector2(width - 28, GameConstants.BAR_HEIGHT)
	bg.add_child(text)
	match tag:
		"HP":
			_hp_bar = bar
			_hp_text = text
		"SP":
			_sp_bar = bar
			_sp_text = text
		"EXP":
			_xp_bar = bar
			_xp_text = text


func _create_bar_bg(pos: Vector2, size: Vector2, color: Color) -> Panel:
	var panel := Panel.new()
	panel.position = pos
	panel.custom_minimum_size = size
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_right = 4
	panel.add_theme_stylebox_override("panel", style)
	panel.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
	return panel


func _build_target_hud() -> void:
	var panel_w := 280
	var panel_h := 52
	var start_x := int((GW - panel_w) / 2.0)
	
	_target_hud_root = Panel.new()
	_target_hud_root.position = Vector2(start_x, 14)
	_target_hud_root.custom_minimum_size = Vector2(panel_w, panel_h)
	_target_hud_root.visible = false
	_target_hud_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_target_hud_root.add_theme_stylebox_override("panel", UITheme.make_panel_style(HUD_PANEL, BORDER, 8))
	ui_root.add_child(_target_hud_root)

	_target_name_label = _make_label("Monster Name", Vector2(12, 6), GameConstants.FONT_MD, true, UITheme.GOLD)
	_target_hud_root.add_child(_target_name_label)

	_target_hud_root.add_child(_make_label("HP", Vector2(12, 28), GameConstants.FONT_XS, true, Color8(0x2e, 0xcc, 0x71)))
	_add_bar_bg(_target_hud_root, Vector2(36, 30), Color8(0x33, 0x33, 0x33))
	_target_hp_bar = _add_bar_fill(_target_hud_root, Vector2(36, 30), Color8(0x2e, 0xcc, 0x71))
	_target_hp_bar.custom_minimum_size = Vector2(180, 10)
	_target_hp_text = _make_label("100/100", Vector2(220, 26), GameConstants.FONT_XS)
	_target_hud_root.add_child(_target_hp_text)


func _build_minimap() -> void:
	var mini_size := float(GameConstants.MINIMAP_SIZE)
	_minimap = Minimap.new()
	_minimap.configure(true, false, Vector2(mini_size, mini_size), true)
	add_child(_minimap)
	_minimap.setup(world, player)

	_minimap_info = Panel.new()
	_minimap_info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_minimap_info.add_theme_stylebox_override(
		"panel",
		UITheme.make_panel_style(Color(0.05, 0.05, 0.1, 0.92), UITheme.GOLD, 4, 1)
	)
	add_child(_minimap_info)

	_minimap_name_label = _make_label("Capital", Vector2(4, 6), GameConstants.FONT_XS, false, UITheme.GOLD)
	_minimap_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_minimap_name_label.custom_minimum_size = Vector2(mini_size - 8, 16)
	_minimap_info.add_child(_minimap_name_label)

	_position_minimap()


func _build_boss_window() -> void:
	var count := WorldSyncManager.WORLD_BOSSES.size()
	var win_size := UILayout.boss_window_size(count)
	_boss_root = _make_window_root(Vector2.ZERO, win_size, Color8(0xff, 0x66, 0x22))
	_boss_root.visible = false
	ui_root.add_child(_boss_root)

	_add_window_title(_boss_root, "- WORLD BOSS -", win_size)
	_add_close_button(_boss_root, win_size, _toggle_boss)

	_boss_panel = BossSpawnPanel.new()
	_boss_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_boss_panel.offset_left = 8
	_boss_panel.offset_top = 32
	_boss_panel.offset_right = -8
	_boss_panel.offset_bottom = -8
	_boss_root.add_child(_boss_panel)


func is_map_click_move_allowed() -> bool:
	if is_drag_active():
		return false
	return is_map_open and not _map_showing_world and is_instance_valid(_current_map_panel) and _current_map_panel.visible


func is_drag_active() -> bool:
	return _drag_inv_index >= 0 or _drag_skill_id != "" or _drag_item_id != ""


func is_item_drag_active() -> bool:
	return is_drag_active()


func _build_map_window() -> void:
	var win_size := Vector2(360, 348)
	var win_pos := Vector2(
		int(float(GW) / 2.0 - win_size.x / 2.0),
		int(float(GH) / 2.0 - win_size.y / 2.0)
	)
	_map_root = _make_window_root(win_pos, win_size, Color8(0x34, 0x98, 0xdb))
	_map_root.visible = false
	ui_root.add_child(_map_root)

	_add_window_title(_map_root, "CURRENT MAP", win_size)
	_map_title_label = _map_root.get_child(_map_root.get_child_count() - 1) as Label
	_add_close_button(_map_root, win_size, _toggle_map)

	_map_subtitle_label = _make_label("Capital  X:0  Y:0", Vector2(0, 34), GameConstants.FONT_XS, false, Color8(0xbd, 0xc3, 0xc7))
	_map_subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_map_subtitle_label.custom_minimum_size = Vector2(win_size.x, 16)
	_map_root.add_child(_map_subtitle_label)

	_map_frame = Panel.new()
	_map_frame.position = Vector2(16, 56)
	_map_frame.custom_minimum_size = Vector2(328, 216)
	_map_frame.add_theme_stylebox_override(
		"panel",
		UITheme.make_panel_style(Color(0.03, 0.04, 0.07, 0.98), UITheme.GOLD, 6, 1)
	)
	_map_root.add_child(_map_frame)

	_current_map_panel = Minimap.new()
	_current_map_panel.configure(false, true, Vector2(312, 200), false)
	_current_map_panel.position = Vector2(8, 8)
	_map_frame.add_child(_current_map_panel)

	_map_overview = MapOverview.new()
	_map_overview.position = Vector2(8, 8)
	_map_overview.custom_minimum_size = Vector2(312, 200)
	_map_overview.size = Vector2(312, 200)
	_map_overview.visible = false
	_map_frame.add_child(_map_overview)

	_map_hint_label = _make_label("คลิกบนแผนที่เพื่อเดิน", Vector2(0, 278), GameConstants.FONT_XS, false, Color8(0x66, 0xcc, 0xff))
	_map_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_map_hint_label.custom_minimum_size = Vector2(win_size.x, 14)
	_map_root.add_child(_map_hint_label)

	var btn_w := 152.0
	var btn_y := 298.0
	var btn_gap := 8.0
	var btn_x := (win_size.x - btn_w * 2.0 - btn_gap) * 0.5

	_world_map_btn = _make_dialog_button("World Map", Vector2(btn_x, btn_y), Color8(0x16, 0xa0, 0x85))
	_world_map_btn.custom_minimum_size = Vector2(btn_w, 36)
	_world_map_btn.pressed.connect(_show_world_map_view)
	_map_root.add_child(_world_map_btn)

	_current_map_btn = _make_dialog_button("Current Map", Vector2(btn_x, btn_y), Color8(0x34, 0x98, 0xdb))
	_current_map_btn.custom_minimum_size = Vector2(btn_w, 36)
	_current_map_btn.visible = false
	_current_map_btn.pressed.connect(_show_current_map_view)
	_map_root.add_child(_current_map_btn)


func _build_npc_dialog() -> void:
	var win_size := Vector2(520, 220)
	var win_pos := Vector2(
		int(float(GW) / 2.0 - win_size.x / 2.0),
		int(GameConstants.bottom_ui_top_y() - win_size.y - GameConstants.UI_PANEL_GAP)
	)
	_npc_dialog_root = _make_window_root(win_pos, win_size, UITheme.GOLD)
	_npc_dialog_root.visible = false
	_npc_dialog_root.z_index = 80
	ui_root.add_child(_npc_dialog_root)

	_npc_dialog_name = _make_label("NPC Name", Vector2(16, 12), GameConstants.FONT_LG, true, UITheme.GOLD)
	_npc_dialog_root.add_child(_npc_dialog_name)

	var sep := ColorRect.new()
	sep.position = Vector2(16, 40)
	sep.custom_minimum_size = Vector2(win_size.x - 32, 1)
	sep.color = Color8(0x55, 0x55, 0x77)
	_npc_dialog_root.add_child(sep)

	_npc_dialog_message = _make_label("...", Vector2(16, 50), GameConstants.FONT_MD, false, Color.WHITE)
	_npc_dialog_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_npc_dialog_message.custom_minimum_size = Vector2(win_size.x - 32, 100)
	_npc_dialog_root.add_child(_npc_dialog_message)

	_npc_dialog_accept = _make_dialog_button("รับเควส", Vector2(16, 168), Color8(0x27, 0xae, 0x60))
	_npc_dialog_accept.pressed.connect(_on_npc_accept)
	_npc_dialog_root.add_child(_npc_dialog_accept)

	_npc_dialog_decline = _make_dialog_button("ปฏิเสธ", Vector2(140, 168), Color8(0x7f, 0x8c, 0x8d))
	_npc_dialog_decline.pressed.connect(_on_npc_decline)
	_npc_dialog_root.add_child(_npc_dialog_decline)

	_npc_dialog_complete = _make_dialog_button("ส่งเควส", Vector2(264, 168), Color8(0x29, 0x80, 0xb9))
	_npc_dialog_complete.pressed.connect(_on_npc_complete)
	_npc_dialog_root.add_child(_npc_dialog_complete)

	_npc_dialog_close = _make_dialog_button("ปิด", Vector2(388, 168), Color8(0xc0, 0x39, 0x2b))
	_npc_dialog_close.pressed.connect(_close_npc_dialog)
	_npc_dialog_root.add_child(_npc_dialog_close)

	_npc_job_grid = GridContainer.new()
	_npc_job_grid.columns = 3
	_npc_job_grid.position = Vector2(16, 120)
	_npc_job_grid.add_theme_constant_override("h_separation", 8)
	_npc_job_grid.add_theme_constant_override("v_separation", 8)
	_npc_job_grid.visible = false
	_npc_dialog_root.add_child(_npc_job_grid)


func _build_death_dialog() -> void:
	_death_blocker = ColorRect.new()
	_death_blocker.set_anchors_preset(Control.PRESET_FULL_RECT)
	_death_blocker.anchor_right = 1.0
	_death_blocker.anchor_bottom = 1.0
	_death_blocker.offset_right = 0.0
	_death_blocker.offset_bottom = 0.0
	_death_blocker.color = Color(0.0, 0.0, 0.0, 0.62)
	_death_blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	_death_blocker.visible = false
	_death_blocker.z_index = 119
	ui_root.add_child(_death_blocker)

	var win_size := Vector2(420, 200)
	var win_pos := Vector2(
		int(float(GW) / 2.0 - win_size.x / 2.0),
		int(float(GH) / 2.0 - win_size.y / 2.0)
	)
	_death_root = _make_window_root(win_pos, win_size, Color8(0xc0, 0x39, 0x2b))
	_death_root.visible = false
	_death_root.z_index = 120
	_death_root.mouse_filter = Control.MOUSE_FILTER_STOP
	ui_root.add_child(_death_root)

	var title := _make_label("คุณเสียชีวิต", Vector2(16, 12), GameConstants.FONT_LG, true, Color8(0xe7, 0x4c, 0x3c))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.custom_minimum_size = Vector2(win_size.x - 32, 24)
	_death_root.add_child(title)

	_death_message = _make_label("เลือกวิธีฟื้นชีพ", Vector2(16, 44), GameConstants.FONT_MD, false, Color.WHITE)
	_death_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_death_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_death_message.custom_minimum_size = Vector2(win_size.x - 32, 48)
	_death_root.add_child(_death_message)

	_death_at_spot_btn = _make_dialog_button("ฟื้นที่จุดตาย", Vector2(24, 118), Color8(0x27, 0xae, 0x60))
	_death_at_spot_btn.custom_minimum_size = Vector2(176, 40)
	_death_at_spot_btn.pressed.connect(_on_revive_at_death_spot)
	_death_root.add_child(_death_at_spot_btn)

	_death_at_save_btn = _make_dialog_button("ฟื้นที่จุดเซฟ", Vector2(220, 118), Color8(0x29, 0x80, 0xb9))
	_death_at_save_btn.custom_minimum_size = Vector2(176, 40)
	_death_at_save_btn.pressed.connect(_on_revive_at_save_point)
	_death_root.add_child(_death_at_save_btn)


func _is_point_over_chat(global_pos: Vector2) -> bool:
	return chat_log_instance != null and _panel_screen_rect(chat_log_instance).has_point(global_pos)


func _layout_death_layers() -> void:
	if not is_death_dialog_open or _death_blocker == null or _death_root == null:
		return
	ui_root.move_child(_death_blocker, ui_root.get_child_count() - 1)
	if chat_log_instance:
		chat_log_instance.z_index = 119
		chat_log_instance.mouse_filter = Control.MOUSE_FILTER_STOP
		ui_root.move_child(chat_log_instance, ui_root.get_child_count() - 1)
	ui_root.move_child(_death_root, ui_root.get_child_count() - 1)


func _reset_death_chat_layer() -> void:
	if chat_log_instance:
		chat_log_instance.z_index = 0
	_layout_open_windows()


func open_death_dialog(dead_player: Player) -> void:
	if dead_player == null:
		return
	player = dead_player
	is_death_dialog_open = true
	if chat_log_instance and chat_log_instance.has_method("expand_panel"):
		chat_log_instance.expand_panel()
	_close_other_modals_except("death")
	_cancel_item_drag()
	_drag_skill_id = ""
	_skill_book_press_id = ""
	_slot_press_idx = -1
	if _death_blocker:
		_death_blocker.visible = true
	_death_root.visible = true
	var save_hint := ""
	if SavePointService.has_save_point():
		save_hint = "\nจุดเซฟ: %s" % SavePointService.get_display_name()
		_death_at_save_btn.disabled = false
		_death_at_save_btn.modulate = Color.WHITE
	else:
		save_hint = "\n(ยังไม่มีจุดเซฟ — คุยกับ Save Point ในเมือง)"
		_death_at_save_btn.disabled = true
		_death_at_save_btn.modulate = Color(1, 1, 1, 0.45)
	_death_message.text = "เลือกวิธีฟื้นชีพ%s" % save_hint
	_layout_death_layers()
	_update_bottom_hud_input_block()
	_layout_open_windows()
	_layout_death_layers()


func close_death_dialog() -> void:
	is_death_dialog_open = false
	if _death_blocker:
		_death_blocker.visible = false
	if _death_root:
		_death_root.visible = false
	_update_bottom_hud_input_block()
	_reset_death_chat_layer()


func _on_revive_at_death_spot() -> void:
	if player and player.has_method("revive_at_death_spot"):
		player.revive_at_death_spot()


func _on_revive_at_save_point() -> void:
	if player and player.has_method("revive_at_save_point"):
		player.revive_at_save_point()


func _make_dialog_button(text: String, pos: Vector2, bg: Color) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.position = pos
	btn.custom_minimum_size = Vector2(116, 36)
	btn.add_theme_font_size_override("font_size", GameConstants.FONT_SM)
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_stylebox_override("normal", UITheme.make_button_style(bg))
	var hover := UITheme.make_button_style(bg.lightened(0.12))
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", hover)
	return btn


func open_npc_dialog(npc: NPC, config: Dictionary) -> void:
	_npc_active = npc
	is_npc_dialog_open = true
	_npc_dialog_root.visible = true
	_npc_dialog_name.text = config.get("name", "NPC")
	_npc_dialog_message.text = config.get("message", "...")
	_npc_dialog_accept.text = config.get("accept_text", "ตกลง")
	if config.has("decline_text"):
		_npc_dialog_decline.text = config.get("decline_text", "ปฏิเสธ")
	else:
		_npc_dialog_decline.text = "ปฏิเสธ"
	_clear_npc_job_buttons()
	var picker_options: Array = config.get("picker_options", [])
	var job_options: Array = config.get("job_options", [])
	if picker_options.size() > 0:
		_npc_job_grid.visible = true
		_npc_dialog_accept.visible = false
		_npc_dialog_decline.visible = false
		_npc_dialog_complete.visible = false
		for opt in picker_options:
			if not opt is Dictionary:
				continue
			var opt_id := str(opt.get("id", ""))
			var label := str(opt.get("label", opt_id))
			var btn := _make_dialog_button(label, Vector2.ZERO, Color8(0xf1, 0xc4, 0x0f))
			btn.custom_minimum_size = Vector2(150, 32)
			btn.pressed.connect(_on_npc_picker_selected.bind(opt_id))
			_npc_job_grid.add_child(btn)
	elif job_options.size() > 0:
		_npc_job_grid.visible = true
		_npc_dialog_accept.visible = false
		_npc_dialog_decline.visible = false
		_npc_dialog_complete.visible = false
		for job_id in job_options:
			var btn := _make_dialog_button(ClassDatabase.get_display_name(job_id), Vector2.ZERO, Color8(0xf1, 0xc4, 0x0f))
			btn.custom_minimum_size = Vector2(150, 32)
			btn.pressed.connect(_on_npc_job_picked.bind(job_id))
			_npc_job_grid.add_child(btn)
	else:
		_npc_job_grid.visible = false
		_npc_dialog_accept.visible = not config.get("hide_accept", false)
		_npc_dialog_decline.visible = config.get("show_decline", true)
		_npc_dialog_complete.visible = config.get("show_complete", false)
	_layout_open_windows()
	_raise_modal_panel(_npc_dialog_root)
	_update_bottom_hud_input_block()


func _clear_npc_job_buttons() -> void:
	if not _npc_job_grid:
		return
	for child in _npc_job_grid.get_children():
		child.queue_free()


func _on_npc_job_picked(job_id: String) -> void:
	if player and player.change_job(job_id):
		add_log("Job changed to %s!" % ClassDatabase.get_display_name(job_id), Color8(0x2e, 0xcc, 0x71))
	_close_npc_dialog()


func _on_npc_picker_selected(option_id: String) -> void:
	var keep_open := false
	if is_instance_valid(_npc_active):
		keep_open = _npc_active.on_picker_selected(option_id)
	if not keep_open:
		_close_npc_dialog()


func _close_npc_dialog() -> void:
	is_npc_dialog_open = false
	_npc_dialog_root.visible = false
	_clear_npc_job_buttons()
	if _npc_job_grid:
		_npc_job_grid.visible = false
	if is_instance_valid(_npc_active):
		_npc_active.on_dialog_closed()
	_npc_active = null
	_layout_open_windows()
	_update_bottom_hud_input_block()


func open_shop(p: Player, shop_id: String, shop_name: String = "Shop", mode: String = "buy") -> void:
	var shop_player := p if p != null else player
	if shop_player == null:
		return
	_close_npc_dialog()
	_close_shop()
	is_shop_open = true
	_shop_panel = ShopPanel.new()
	_shop_panel.z_index = 80
	_shop_panel.closed.connect(_close_shop)
	ui_root.add_child(_shop_panel)
	var catalog := ShopDatabase.get_shop(shop_id)
	var title: String = str(catalog.get("name", shop_name))
	_shop_panel.setup(self, shop_player, shop_id, title, mode)
	_close_other_modals_except("shop")
	_layout_open_windows()
	_raise_modal_panel(_shop_panel)
	_update_bottom_hud_input_block()


func _close_shop() -> void:
	is_shop_open = false
	if is_instance_valid(_shop_panel):
		_shop_panel.queue_free()
	_shop_panel = null
	_layout_open_windows()
	_update_bottom_hud_input_block()


func _on_npc_accept() -> void:
	var keep_open := false
	if is_instance_valid(_npc_active):
		keep_open = _npc_active.on_dialog_accept()
	if not keep_open:
		_close_npc_dialog()


func _on_npc_decline() -> void:
	var keep_open := false
	if is_instance_valid(_npc_active):
		keep_open = _npc_active.on_dialog_decline()
	if not keep_open:
		_close_npc_dialog()


func _on_npc_complete() -> void:
	var keep_open := false
	if is_instance_valid(_npc_active):
		keep_open = _npc_active.on_dialog_complete()
	if not keep_open:
		_close_npc_dialog()


func _refresh_map_window() -> void:
	if is_instance_valid(_current_map_panel) and is_instance_valid(world):
		_current_map_panel.setup(world, player)
	if is_instance_valid(_map_overview) and is_instance_valid(world):
		_map_overview.setup(world, player)


func _show_current_map_view() -> void:
	_map_showing_world = false
	if _current_map_panel:
		_current_map_panel.visible = true
		_refresh_map_window()
	if _map_overview:
		_map_overview.visible = false
	if _world_map_btn:
		_world_map_btn.visible = true
		_world_map_btn.position.x = (_map_root.size.x - _world_map_btn.size.x) * 0.5
	if _current_map_btn:
		_current_map_btn.visible = false
	if _map_hint_label:
		_map_hint_label.visible = true
	_set_map_window_title("CURRENT MAP")
	_update_map_window_subtitle()


func _show_world_map_view() -> void:
	_map_showing_world = true
	if _current_map_panel:
		_current_map_panel.visible = false
	if _map_overview:
		_map_overview.visible = true
		_refresh_map_window()
	if _world_map_btn:
		_world_map_btn.visible = false
	if _current_map_btn:
		_current_map_btn.visible = true
		_current_map_btn.position.x = (_map_root.size.x - _current_map_btn.size.x) * 0.5
	if _map_hint_label:
		_map_hint_label.visible = false
	_set_map_window_title("WORLD MAP")
	_update_map_window_subtitle()


func _update_map_window_subtitle() -> void:
	if not _map_subtitle_label or not is_instance_valid(world):
		return
	if _map_showing_world:
		_map_subtitle_label.text = "Capital (North)  ·  Training Field (South)"
	elif is_instance_valid(player):
		var pos := player.global_position
		_map_subtitle_label.text = "%s  X:%d  Y:%d" % [
			ProjectPaths.get_map_display_name(world),
			int(pos.x),
			int(pos.y)
		]
	else:
		_map_subtitle_label.text = ProjectPaths.get_map_display_name(world)


func _set_map_window_title(title: String) -> void:
	if _map_title_label:
		_map_title_label.text = title

func _on_presence_updated(remote_count: int) -> void:
	if not _online_label:
		return
	if not OnlineSession.is_logged_in():
		_online_label.text = "Offline Mode"
	elif remote_count <= 0:
		_online_label.text = "Online — exploring alone"
	else:
		_online_label.text = "Online — %d player(s) nearby" % remote_count


func _position_minimap() -> void:
	if not _minimap:
		return
	var rect := GameConstants.minimap_screen_rect()
	_minimap.position = rect.position
	_minimap.size = rect.size
	_minimap.custom_minimum_size = rect.size
	if _minimap_info:
		_minimap_info.position = Vector2(rect.position.x, rect.end.y + 4.0)
		_minimap_info.custom_minimum_size = Vector2(rect.size.x, GameConstants.MINIMAP_INFO_HEIGHT)
		_minimap_info.size = _minimap_info.custom_minimum_size


func _update_minimap_info() -> void:
	if not is_instance_valid(player) or not is_instance_valid(world):
		return
	if _minimap_name_label:
		var pos := player.global_position
		_minimap_name_label.text = "%s  X:%d  Y:%d" % [
			ProjectPaths.get_map_display_name(world),
			int(pos.x),
			int(pos.y)
		]


# Unified bottom action bar
func _build_buttons() -> void:
	_action_bar = Panel.new()
	_action_bar.position = Vector2(0, GameConstants.action_bar_y())
	_action_bar.custom_minimum_size = Vector2(GW, GameConstants.ACTION_BAR_HEIGHT)
	_action_bar.mouse_filter = Control.MOUSE_FILTER_STOP
	_action_bar.add_theme_stylebox_override("panel", UITheme.make_panel_style(Color(0.06, 0.06, 0.1, 0.94), UITheme.PANEL_BORDER, 0, 1))
	ui_root.add_child(_action_bar)

	var btn_w := 108
	var btn_h := 34
	var y_pos := 10
	var gap := 8
	var x_pos := 14

	var stat_btn := _make_menu_button("STAT [C]", Vector2(x_pos, y_pos), Color8(0x2c, 0x3e, 0x50))
	stat_btn.custom_minimum_size = Vector2(btn_w, btn_h)
	stat_btn.pressed.connect(_toggle_stat)
	_action_bar.add_child(stat_btn)
	x_pos += btn_w + gap

	var inv_btn := _make_menu_button("INV [I]", Vector2(x_pos, y_pos), Color8(0x8e, 0x44, 0xad))
	inv_btn.custom_minimum_size = Vector2(btn_w, btn_h)
	inv_btn.pressed.connect(_toggle_inventory)
	_action_bar.add_child(inv_btn)
	x_pos += btn_w + gap

	var skill_btn := _make_menu_button("SKILL [K]", Vector2(x_pos, y_pos), Color8(0xe6, 0x7e, 0x22))
	skill_btn.custom_minimum_size = Vector2(btn_w, btn_h)
	skill_btn.pressed.connect(_toggle_skill)
	_action_bar.add_child(skill_btn)
	x_pos += btn_w + gap

	var party_btn := _make_menu_button("PARTY [P]", Vector2(x_pos, y_pos), Color8(0x16, 0xa0, 0x85))
	party_btn.custom_minimum_size = Vector2(btn_w, btn_h)
	party_btn.pressed.connect(_toggle_party)
	_action_bar.add_child(party_btn)
	x_pos += btn_w + gap

	var boss_btn := _make_menu_button("BOSS [B]", Vector2(x_pos, y_pos), Color8(0xc0, 0x39, 0x2b))
	boss_btn.custom_minimum_size = Vector2(btn_w, btn_h)
	boss_btn.pressed.connect(_toggle_boss)
	_action_bar.add_child(boss_btn)
	x_pos += btn_w + gap

	var map_btn := _make_menu_button("MAP [M]", Vector2(x_pos, y_pos), Color8(0x34, 0x98, 0xdb))
	map_btn.custom_minimum_size = Vector2(btn_w, btn_h)
	map_btn.pressed.connect(_toggle_map)
	_action_bar.add_child(map_btn)
	x_pos += btn_w + gap
	
	var auto_btn := _make_menu_button("AUTO [O]", Vector2(x_pos, y_pos), Color8(0x9b, 0x59, 0xb6))
	auto_btn.custom_minimum_size = Vector2(btn_w, btn_h)
	auto_btn.pressed.connect(_toggle_auto_window) # 👈 แก้บรรทัดนี้
	_action_bar.add_child(auto_btn)


func _build_skill_bar() -> void:
	var skill_rect := UILayout.skill_bar_rect(false)
	_skill_bar_root = Control.new()
	_skill_bar_root.position = skill_rect.position
	_skill_bar_root.custom_minimum_size = skill_rect.size
	_skill_bar_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.add_child(_skill_bar_root)

	var slot_size := UILayout.SKILL_SLOT_SIZE
	var gap := UILayout.SKILL_SLOT_GAP

	for i in range(6):
		var sx := i * (slot_size + gap)
		var sy := 0

		var slot_bg := Panel.new()
		slot_bg.position = Vector2(sx, sy)
		slot_bg.custom_minimum_size = Vector2(slot_size, slot_size)
		slot_bg.add_theme_stylebox_override("panel", UITheme.make_panel_style(UITheme.SLOT_BG, Color8(0x55, 0x55, 0x77), 4))
		slot_bg.mouse_filter = Control.MOUSE_FILTER_STOP
		var slot_idx := i
		
		slot_bg.gui_input.connect(func(event):
			if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
				if event.pressed:
					if is_drag_active():
						get_viewport().set_input_as_handled()
						return
					if player and _quick_slot_can_drag(slot_idx):
						_slot_press_idx = slot_idx
						_slot_press_pos = get_viewport().get_mouse_position()
						get_viewport().set_input_as_handled()
						return
					_use_skill_slot(slot_idx)
					get_viewport().set_input_as_handled()
				else:
					if _drag_skill_id != "":
						_handle_skill_drop()
						get_viewport().set_input_as_handled()
					elif _drag_item_id != "":
						_handle_item_drop()
						get_viewport().set_input_as_handled()
					elif _drag_inv_index >= 0:
						var quick_idx := _quick_slot_index_at(get_viewport().get_mouse_position())
						if quick_idx >= 0:
							_assign_quick_slot(quick_idx, _drag_inv_index)
						else:
							_cancel_item_drag()
						get_viewport().set_input_as_handled()
					elif _slot_press_idx == slot_idx:
						_use_skill_slot(slot_idx)
						_slot_press_idx = -1
						get_viewport().set_input_as_handled()
			elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
				if player:
					player.clear_quick_slot(slot_idx)
					_update_quick_slot_ui()
				get_viewport().set_input_as_handled()
		)
		_skill_bar_root.add_child(slot_bg)

		var num_lbl := Label.new()
		num_lbl.position = Vector2(sx + 3, sy + 2)
		num_lbl.text = str(i + 1)
		UITheme.style_label(num_lbl, GameConstants.FONT_XS, UITheme.MUTED, 1)
		num_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_skill_bar_root.add_child(num_lbl)

		var icon := TextureRect.new()
		icon.position = Vector2(sx + 4, sy + 4)
		icon.custom_minimum_size = Vector2(slot_size - 8, slot_size - 8)
		icon.size = Vector2(slot_size - 8, slot_size - 8)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.visible = false
		_skill_bar_root.add_child(icon)
		
		# 🌟 เพิ่มป้ายตัวหนังสือโชว์สกิล
		var skill_lbl := Label.new()
		skill_lbl.position = Vector2(sx, sy)
		skill_lbl.custom_minimum_size = Vector2(slot_size, slot_size)
		skill_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		skill_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		UITheme.style_label(skill_lbl, GameConstants.FONT_MD, Color.WHITE, 1)
		skill_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		skill_lbl.visible = false
		_skill_bar_root.add_child(skill_lbl)

		_skill_slots.append({"icon": icon, "bg": slot_bg, "count": num_lbl, "skill_abbr": skill_lbl})

func _on_inventory_changed() -> void:
	_update_inventory_ui()
	_update_quick_slot_ui()


func _start_item_drag(inv_index: int) -> void:
	if not player:
		return
	var item: Variant = player.inventory[inv_index] if inv_index < player.inventory.size() else null
	if item == null:
		return
	if not player.can_assign_quick_slot(item):
		add_log("Quick Slot ใส่ได้เฉพาะยา", UITheme.MUTED)
		return
	_cancel_item_drag()
	_drag_inv_index = inv_index
	if world:
		world.move_target = null
	_create_item_drag_preview(str(item.get("icon", "")))


func _start_item_drag_from_slot(slot_idx: int) -> void:
	if not _quick_slot_has_item(slot_idx):
		return
	var entry: Dictionary = player.quick_slots[slot_idx]
	var item_id := str(entry.get("item_id", ""))
	if item_id == "" or player.get_quick_slot_item_count(slot_idx) <= 0:
		return
	var def := ItemDatabase.get_item(item_id)
	if def.is_empty():
		return

	_slot_press_idx = -1
	_skill_book_press_id = ""
	_cancel_item_drag()
	_drag_from_slot_idx = slot_idx
	_drag_item_id = item_id
	if world:
		world.move_target = null
	_create_item_drag_preview(str(def.get("icon", "")))


func _create_item_drag_preview(icon_name: String) -> void:
	_drag_preview = Panel.new()
	_drag_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_drag_preview.z_index = 200
	_drag_preview.custom_minimum_size = Vector2(32, 32)
	var preview_icon := TextureRect.new()
	preview_icon.custom_minimum_size = Vector2(32, 32)
	preview_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview_icon.texture = TextureGenerator.get_texture(icon_name)
	preview_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_drag_preview.add_child(preview_icon)
	ui_root.add_child(_drag_preview)
	_update_drag_preview_pos()


func _update_drag_preview_pos() -> void:
	if _drag_preview:
		_drag_preview.global_position = get_viewport().get_mouse_position() - Vector2(16, 16)


func _cancel_item_drag() -> void:
	_drag_inv_index = -1
	_drag_skill_id = ""
	_drag_item_id = ""
	_drag_from_slot_idx = -1
	_slot_press_idx = -1
	_skill_book_press_id = ""
	if _drag_preview:
		_drag_preview.queue_free()
		_drag_preview = null
	_update_skill_book_scroll_lock()


func _begin_skill_book_press(skill_id: String, press_pos: Vector2) -> void:
	if not player:
		return
	if SkillDatabase.is_passive(skill_id):
		add_log("สกิล Passive ไม่สามารถใส่ Quick Slot ได้", UITheme.MUTED)
		return
	if not SkillDatabase.can_assign_to_quick_slot(player, skill_id):
		return
	_skill_book_press_id = skill_id
	_skill_book_press_pos = press_pos
	_slot_press_idx = -1
	_update_skill_book_scroll_lock()


func _cancel_skill_book_press() -> void:
	_skill_book_press_id = ""
	_update_skill_book_scroll_lock()


func _update_skill_book_scroll_lock() -> void:
	if _skill_book and _skill_book.has_method("set_scroll_locked"):
		_skill_book.set_scroll_locked(_skill_book_press_id != "" or _drag_skill_id != "")


func _try_start_pending_skill_drags(mouse_pos: Vector2) -> void:
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		return
	if _skill_book_press_id != "" and not is_drag_active():
		if mouse_pos.distance_to(_skill_book_press_pos) >= SLOT_DRAG_THRESHOLD:
			var skill_id := _skill_book_press_id
			_skill_book_press_id = ""
			_start_skill_drag(skill_id)
	elif _slot_press_idx >= 0 and not is_drag_active():
		if mouse_pos.distance_to(_slot_press_pos) >= SLOT_DRAG_THRESHOLD:
			var slot_idx := _slot_press_idx
			_slot_press_idx = -1
			if _quick_slot_has_skill(slot_idx):
				_start_skill_drag_from_slot(slot_idx)
			elif _quick_slot_has_item(slot_idx):
				_start_item_drag_from_slot(slot_idx)


func _quick_slot_has_skill(slot_idx: int) -> bool:
	if not player or slot_idx < 0 or slot_idx >= player.quick_slots.size():
		return false
	var entry: Variant = player.quick_slots[slot_idx]
	return entry is Dictionary and str(entry.get("kind", "")) == "skill"


func _quick_slot_has_item(slot_idx: int) -> bool:
	if not player or slot_idx < 0 or slot_idx >= player.quick_slots.size():
		return false
	var entry: Variant = player.quick_slots[slot_idx]
	if not entry is Dictionary or str(entry.get("kind", "")) != "item":
		return false
	return player.get_quick_slot_item_count(slot_idx) > 0


func _quick_slot_can_drag(slot_idx: int) -> bool:
	return _quick_slot_has_skill(slot_idx) or _quick_slot_has_item(slot_idx)


func _create_skill_drag_preview(def: Dictionary) -> void:
	_drag_preview = Panel.new()
	_drag_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_drag_preview.z_index = 200
	_drag_preview.custom_minimum_size = Vector2(32, 32)

	var style := StyleBoxFlat.new()
	style.bg_color = UITheme.COZY_SKILL_ICON
	style.border_color = UITheme.COZY_BORDER
	style.set_border_width_all(1)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	_drag_preview.add_theme_stylebox_override("panel", style)

	var lbl := Label.new()
	lbl.text = str(def.get("icon_label", "?"))
	lbl.custom_minimum_size = Vector2(32, 32)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UITheme.style_label(lbl, GameConstants.FONT_MD, Color.WHITE, 1)
	_drag_preview.add_child(lbl)

	ui_root.add_child(_drag_preview)
	_update_drag_preview_pos()


func _start_skill_drag_from_slot(slot_idx: int) -> void:
	if not _quick_slot_has_skill(slot_idx):
		return
	var entry: Dictionary = player.quick_slots[slot_idx]
	var skill_id := str(entry.get("skill_id", ""))
	if skill_id == "":
		return
	var def := SkillDatabase.get_skill(skill_id)
	if def.is_empty():
		return

	_slot_press_idx = -1
	_skill_book_press_id = ""
	_cancel_item_drag()
	_drag_from_slot_idx = slot_idx
	_drag_skill_id = skill_id
	if world:
		world.move_target = null
	_create_skill_drag_preview(def)
	_update_skill_book_scroll_lock()


# 🌟 ฟังก์ชันเริ่มลากสกิล
func _start_skill_drag(skill_id: String) -> void:
	if not player:
		return
	if SkillDatabase.is_passive(skill_id):
		add_log("สกิล Passive ไม่สามารถใส่ Quick Slot ได้", UITheme.MUTED)
		return
	if not SkillDatabase.can_assign_to_quick_slot(player, skill_id):
		return
	var def := SkillDatabase.get_skill(skill_id)
	if def.is_empty():
		return

	_slot_press_idx = -1
	_skill_book_press_id = ""
	_cancel_item_drag()
	_drag_skill_id = skill_id

	if world:
		world.move_target = null
	_create_skill_drag_preview(def)
	_update_skill_book_scroll_lock()

# 🌟 ฟังก์ชันปล่อยเมาส์ใส่ช่อง
func _handle_skill_drop() -> void:
	if _drag_skill_id == "":
		return
	var quick_idx := _quick_slot_index_at(get_viewport().get_mouse_position())
	var from_slot := _drag_from_slot_idx

	if quick_idx >= 0:
		if from_slot == quick_idx:
			_cancel_item_drag()
			return
		if not SkillDatabase.can_assign_to_quick_slot(player, _drag_skill_id):
			add_log("สกิล Passive ไม่สามารถใส่ Quick Slot ได้", UITheme.MUTED)
			_cancel_item_drag()
			return
		player.assign_quick_slot_entry(quick_idx, {"kind": "skill", "skill_id": _drag_skill_id}, from_slot)
		_update_quick_slot_ui()
	elif from_slot >= 0:
		player.clear_quick_slot(from_slot)
		_update_quick_slot_ui()
	_cancel_item_drag()


func _handle_item_drop() -> void:
	if _drag_item_id == "":
		return
	var quick_idx := _quick_slot_index_at(get_viewport().get_mouse_position())
	var from_slot := _drag_from_slot_idx

	if quick_idx >= 0:
		if from_slot == quick_idx:
			_cancel_item_drag()
			return
		player.assign_quick_slot_entry(quick_idx, {"kind": "item", "item_id": _drag_item_id}, from_slot)
		_update_quick_slot_ui()
	elif from_slot >= 0:
		player.clear_quick_slot(from_slot)
		_update_quick_slot_ui()
	_cancel_item_drag()

# 🌟 ฟังก์ชันติดตั้งสกิล
func _assign_skill_quick_slot(quick_idx: int, skill_id: String) -> void:
	if not player:
		return
	if not SkillDatabase.can_assign_to_quick_slot(player, skill_id):
		add_log("สกิล Passive ไม่สามารถใส่ Quick Slot ได้", UITheme.MUTED)
		_cancel_item_drag()
		return
	player.assign_quick_slot_entry(quick_idx, {"kind": "skill", "skill_id": skill_id}, -1)
	_update_quick_slot_ui()
	_cancel_item_drag()


func _assign_quick_slot(quick_idx: int, inv_index: int) -> void:
	if not player:
		return
	var item: Variant = player.inventory[inv_index] if inv_index < player.inventory.size() else null
	if item == null or not player.can_assign_quick_slot(item):
		add_log("Quick Slot ใส่ได้เฉพาะยา", UITheme.MUTED)
		_cancel_item_drag()
		return
	player.assign_quick_slot_entry(quick_idx, {"kind": "item", "item_id": str(item.get("id", ""))}, -1)
	_update_quick_slot_ui()
	_cancel_item_drag()


func _update_quick_slot_ui() -> void:
	if not player:
		return
	for i in range(_skill_slots.size()):
		var slot: Dictionary = _skill_slots[i]
		var icon: TextureRect = slot.icon
		var count_lbl: Label = slot.get("count")
		var skill_lbl: Label = slot.get("skill_abbr")
		
		icon.visible = false
		if skill_lbl: skill_lbl.visible = false
		if count_lbl: count_lbl.text = str(i + 1)
		
		if i >= player.quick_slots.size():
			continue
			
		var entry: Variant = player.quick_slots[i]
		if entry == null or not entry is Dictionary:
			continue
			
		var kind = str(entry.get("kind", ""))
		if kind == "item":
			var def := ItemDatabase.get_item(str(entry.get("item_id", "")))
			if not def.is_empty():
				icon.texture = TextureGenerator.get_texture(def.get("icon", ""))
				icon.visible = true
			var stack := player.get_quick_slot_item_count(i)
			if count_lbl:
				count_lbl.text = str(stack) if stack > 1 else str(i + 1)
			if stack <= 0:
				player.clear_quick_slot(i)
				icon.visible = false
				if count_lbl: count_lbl.text = str(i + 1)
				
		elif kind == "skill":
			var skill_id = str(entry.get("skill_id", ""))
			var def = SkillDatabase.get_skill(skill_id)
			if not def.is_empty():
				if skill_lbl:
					skill_lbl.text = def.get("icon_label", "?")
					skill_lbl.visible = true
				if count_lbl:
					count_lbl.text = "" # ซ่อนเลขช่อง 1-6 ทิ้งไปเลยเพื่อความสวยงาม
			else:
				player.clear_quick_slot(i)


func _use_skill_slot(slot_idx: int) -> void:
	if not player:
		return
	var result: Dictionary = player.use_quick_slot(slot_idx)
	var msg := str(result.get("message", ""))
	if result.get("ok", false):
		if msg != "":
			add_log(msg, Color8(0x2e, 0xcc, 0x71))
	elif msg != "":
		add_log(msg, UITheme.MUTED)
	_update_quick_slot_ui()


func _build_stat_window() -> void:
	_stat_panel = StatWindowPanel.new()
	_stat_panel.visible = false
	_stat_panel.closed.connect(_toggle_stat)
	# 🌟 เชื่อมสัญญาณปุ่ม Confirm แทนปุ่ม Plus
	_stat_panel.stat_confirm_pressed.connect(_on_stat_confirm)
	ui_root.add_child(_stat_panel)


func _build_equipment_window() -> void:
	var equip_size := GameConstants.WIN_EQUIP_SIZE
	var inv_size := GameConstants.WIN_INV_SIZE
	var spacing := 8
	var total_width := equip_size.x + spacing + inv_size.x
	var start_x := int(GW - total_width - GameConstants.HUD_MARGIN)
	var start_y := int((GH - inv_size.y) / 2.0)

	_equipment_panel = EquipmentPanel.new()
	_equipment_panel.position = Vector2(start_x, start_y)
	_equipment_panel.visible = false
	_equipment_panel.closed.connect(_toggle_inventory)
	_equipment_panel.slot_gui_input.connect(_on_equipment_slot_gui_input)
	_equipment_panel.slot_mouse_entered.connect(_on_equipment_slot_mouse_entered)
	_equipment_panel.slot_mouse_exited.connect(_on_equipment_slot_mouse_exited)
	ui_root.add_child(_equipment_panel)
	_equip_root = _equipment_panel
	_equip_slots = _equipment_panel.equip_slots


func _on_equipment_slot_gui_input(slot_key: String, event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		if player:
			player.unequip_item(slot_key)
			_hide_item_tooltip()
		get_viewport().set_input_as_handled()


func _on_equipment_slot_mouse_entered(slot_key: String) -> void:
	if player and player.equipment.has(slot_key):
		var item = player.equipment[slot_key]
		if item and _equipment_panel:
			_show_item_tooltip(item, _equipment_panel.get_slot_global_pos(slot_key), false)


func _on_equipment_slot_mouse_exited(_slot_key: String) -> void:
	_hide_item_tooltip()


func _build_inventory_window() -> void:
	var equip_size := GameConstants.WIN_EQUIP_SIZE
	var inv_size := GameConstants.WIN_INV_SIZE
	var spacing := 8
	var total_width := equip_size.x + spacing + inv_size.x
	var start_x := int(GW - total_width - GameConstants.HUD_MARGIN) + equip_size.x + spacing
	var start_y := int((GH - inv_size.y) / 2.0)

	_inventory_panel = InventoryPanel.new()
	_inventory_panel.position = Vector2(start_x, start_y)
	_inventory_panel.visible = false
	_inventory_panel.closed.connect(_toggle_inventory)
	_inventory_panel.slot_gui_input.connect(_on_inventory_slot_gui_input)
	_inventory_panel.slot_mouse_entered.connect(_on_inventory_slot_mouse_entered)
	_inventory_panel.slot_mouse_exited.connect(_on_inventory_slot_mouse_exited)
	ui_root.add_child(_inventory_panel)
	_inv_root = _inventory_panel
	_inv_slots = _inventory_panel.inv_slots


func _on_inventory_slot_gui_input(idx: int, event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if player and idx < player.inventory.size() and player.inventory[idx]:
				if player.can_assign_quick_slot(player.inventory[idx]):
					_start_item_drag(idx)
		elif _drag_inv_index >= 0:
			var quick_idx := _quick_slot_index_at(get_viewport().get_mouse_position())
			if quick_idx >= 0:
				_assign_quick_slot(quick_idx, _drag_inv_index)
			else:
				_cancel_item_drag()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		if player and idx < player.inventory.size():
			var item: Variant = player.inventory[idx]
			if item != null and ItemDatabase.is_potion(item):
				var use_result: Dictionary = player.use_item_from_inventory_verbose(idx)
				var msg := str(use_result.get("message", ""))
				if use_result.get("ok", false) and msg != "":
					add_log(msg, Color8(0x2e, 0xcc, 0x71))
				elif msg != "":
					add_log(msg, UITheme.MUTED)
			else:
				player.equip_item_from_inventory(idx)
			_hide_item_tooltip()
		get_viewport().set_input_as_handled()


func _on_inventory_slot_mouse_entered(idx: int) -> void:
	if player and idx < player.inventory.size():
		var item = player.inventory[idx]
		if item and _inventory_panel and _inventory_panel.inv_slots[idx].bg:
			_show_item_tooltip(item, _inventory_panel.inv_slots[idx].bg.global_position, true)


func _on_inventory_slot_mouse_exited(_idx: int) -> void:
	_hide_item_tooltip()


func _build_party_window() -> void:
	var win_size := Vector2(420, 360)
	var win_pos := Vector2(
		int(float(GW) / 2.0 - win_size.x / 2.0),
		int(float(GH) / 2.0 - win_size.y / 2.0)
	)

	_party_root = _make_window_root(win_pos, win_size, Color8(0x16, 0xa0, 0x85))
	_party_root.visible = false
	ui_root.add_child(_party_root)

	_add_window_title(_party_root, "- PARTY -", win_size)
	_add_close_button(_party_root, win_size, _toggle_party)

	_party_status_label = _make_label("No active party", Vector2(16, 36), GameConstants.FONT_SM, true, UITheme.MUTED)
	_party_root.add_child(_party_status_label)

	_party_id_label = _make_label("", Vector2(16, 56), GameConstants.FONT_XS, false, UITheme.MUTED)
	_party_root.add_child(_party_id_label)

	_party_list_container = VBoxContainer.new()
	_party_list_container.position = Vector2(16, 78)
	_party_list_container.custom_minimum_size = Vector2(388, 210)
	_party_list_container.add_theme_constant_override("separation", 8)
	_party_root.add_child(_party_list_container)

	var create_btn := Button.new()
	create_btn.text = "Create Party"
	create_btn.position = Vector2(16, 300)
	create_btn.custom_minimum_size = Vector2(120, 38)
	create_btn.add_theme_font_size_override("font_size", GameConstants.FONT_SM)
	create_btn.add_theme_stylebox_override("normal", UITheme.make_button_style(Color8(0x27, 0xae, 0x60)))
	create_btn.pressed.connect(func():
		PartyManager.create_party()
		_update_party_ui(PartyManager.party_members)
	)
	_party_root.add_child(create_btn)

	var refresh_btn := Button.new()
	refresh_btn.text = "Refresh"
	refresh_btn.position = Vector2(148, 300)
	refresh_btn.custom_minimum_size = Vector2(100, 38)
	refresh_btn.add_theme_font_size_override("font_size", GameConstants.FONT_SM)
	refresh_btn.add_theme_stylebox_override("normal", UITheme.make_button_style(Color8(0x29, 0x80, 0xb9)))
	refresh_btn.pressed.connect(func():
		PartyManager.refresh_local_member_stats()
		if PartyManager.is_in_party():
			PartyManager.fetch_party_data()
	)
	_party_root.add_child(refresh_btn)

	var leave_btn := Button.new()
	leave_btn.text = "Leave Party"
	leave_btn.position = Vector2(260, 300)
	leave_btn.custom_minimum_size = Vector2(144, 38)
	leave_btn.add_theme_font_size_override("font_size", GameConstants.FONT_SM)
	leave_btn.add_theme_stylebox_override("normal", UITheme.make_button_style(Color8(0xc0, 0x39, 0x2b)))
	leave_btn.pressed.connect(func():
		PartyManager.leave_party()
	)
	_party_root.add_child(leave_btn)


func _build_tooltip() -> void:
	_tooltip_panel = Panel.new()
	_tooltip_panel.z_index = 100
	_tooltip_panel.visible = false
	_tooltip_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.12, 0.95)
	style.border_color = Color8(0x7f, 0x8c, 0x8d)
	style.set_border_width_all(1)
	style.corner_radius_top_left = 2
	style.corner_radius_top_right = 2
	style.corner_radius_bottom_left = 2
	style.corner_radius_bottom_right = 2
	_tooltip_panel.add_theme_stylebox_override("panel", style)
	
	_tooltip_hbox = HBoxContainer.new()
	_tooltip_hbox.position = Vector2(4, 4)
	_tooltip_hbox.add_theme_constant_override("separation", 4)
	_tooltip_panel.add_child(_tooltip_hbox)
	
	_left_box = Panel.new()
	_left_box.custom_minimum_size = Vector2(50, 50)
	var left_style := StyleBoxFlat.new()
	left_style.bg_color = Color(0.12, 0.12, 0.18, 0.9)
	left_style.border_color = Color8(0x55, 0x55, 0x77)
	left_style.set_border_width_all(1)
	_left_box.add_theme_stylebox_override("panel", left_style)
	
	_left_icon = TextureRect.new()
	_left_icon.position = Vector2(4, 4)
	_left_icon.custom_minimum_size = Vector2(16, 16)
	_left_icon.size = Vector2(16, 16)
	_left_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_left_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_left_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_left_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_left_box.add_child(_left_icon)

	_left_label = Label.new()
	_left_label.position = Vector2(4, 4)
	_left_label.add_theme_font_size_override("font_size", GameConstants.FONT_XS)
	_left_label.add_theme_color_override("font_color", Color.WHITE)
	_left_box.add_child(_left_label)
	_tooltip_hbox.add_child(_left_box)
	
	_right_box = Panel.new()
	_right_box.custom_minimum_size = Vector2(50, 50)
	var right_style := StyleBoxFlat.new()
	right_style.bg_color = Color(0.12, 0.12, 0.18, 0.9)
	right_style.border_color = Color8(0x55, 0x55, 0x77)
	right_style.set_border_width_all(1)
	_right_box.add_theme_stylebox_override("panel", right_style)
	
	_right_icon = TextureRect.new()
	_right_icon.position = Vector2(4, 4)
	_right_icon.custom_minimum_size = Vector2(16, 16)
	_right_icon.size = Vector2(16, 16)
	_right_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_right_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_right_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_right_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_right_box.add_child(_right_icon)

	_right_label = Label.new()
	_right_label.position = Vector2(4, 4)
	_right_label.add_theme_font_size_override("font_size", GameConstants.FONT_XS)
	_right_label.add_theme_color_override("font_color", Color.WHITE)
	_right_box.add_child(_right_label)
	_tooltip_hbox.add_child(_right_box)
	
	ui_root.add_child(_tooltip_panel)


func _show_item_tooltip(item: Dictionary, slot_global_pos: Vector2, is_inventory: bool = true) -> void:
	if not item:
		return
		
	var item_type = item.get("type", "")
	var equipped_item = null
	if player and player.equipment.has(item_type):
		equipped_item = player.equipment[item_type]

	if item.has("icon") and TextureGenerator.get_texture(item.icon):
		_left_icon.texture = TextureGenerator.get_texture(item.icon)
		_left_icon.visible = true
	else:
		_left_icon.visible = false

	if not is_inventory or not equipped_item:
		var text = "\n\n[ Selected ]\n" + item.get("name", "Unknown")
		var item_atk = item.get("attack", 0)
		var item_def = item.get("defense", 0)
		if item_atk > 0: text += "\nATK: %d" % item_atk
		if item_def > 0: text += "\nDEF: %d" % item_def
		if item.has("type"): text += "\nType: %s" % str(item.type).capitalize()
			
		_left_label.text = text
		_right_box.visible = false
		
		var lbl_size = _left_label.get_minimum_size()
		var box_w = maxf(lbl_size.x + 12, 50)
		var box_h = lbl_size.y + 8
		
		_left_icon.position = Vector2((box_w - 16) / 2, 4)
		_left_box.custom_minimum_size = Vector2(box_w, box_h)
		_tooltip_hbox.size = Vector2(box_w, box_h)
		_tooltip_panel.size = _tooltip_hbox.size + Vector2(8, 8)
	else:
		var left_text = "\n\n[ Selected ]\n" + item.get("name", "Unknown")
		var item_atk = item.get("attack", 0)
		var item_def = item.get("defense", 0)
		if item_atk > 0: left_text += "\nATK: %d" % item_atk
		if item_def > 0: left_text += "\nDEF: %d" % item_def
		if item.has("type"): left_text += "\nType: %s" % str(item.type).capitalize()
		_left_label.text = left_text

		if equipped_item.has("icon") and TextureGenerator.get_texture(equipped_item.icon):
			_right_icon.texture = TextureGenerator.get_texture(equipped_item.icon)
			_right_icon.visible = true
		else:
			_right_icon.visible = false

		var right_text = "\n\n[ Equipped ]\n" + equipped_item.get("name", "Unknown")
		var eq_atk = equipped_item.get("attack", 0)
		var eq_def = equipped_item.get("defense", 0)
		if eq_atk > 0: right_text += "\nATK: %d" % eq_atk
		if eq_def > 0: right_text += "\nDEF: %d" % eq_def
		if equipped_item.has("type"): right_text += "\nType: %s" % str(equipped_item.type).capitalize()
		_right_label.text = right_text
		
		_right_box.visible = true

		var left_size = _left_label.get_minimum_size()
		var right_size = _right_label.get_minimum_size()
		var box_w = maxf(maxf(left_size.x, right_size.x) + 12, 50)
		var box_h = maxf(left_size.y, right_size.y) + 8
		
		_left_icon.position = Vector2((box_w - 16) / 2, 4)
		_right_icon.position = Vector2((box_w - 16) / 2, 4)
		
		_left_box.custom_minimum_size = Vector2(box_w, box_h)
		_right_box.custom_minimum_size = Vector2(box_w, box_h)
		
		_tooltip_hbox.size = Vector2(box_w * 2 + 4, box_h)
		_tooltip_panel.size = _tooltip_hbox.size + Vector2(8, 8)

	_tooltip_panel.global_position = slot_global_pos + Vector2(18, 0)
	_tooltip_panel.visible = true


func _hide_item_tooltip() -> void:
	if _tooltip_panel:
		_tooltip_panel.visible = false


func _make_window_root(pos: Vector2, size: Vector2, border_color: Color) -> Panel:
	var panel := Panel.new()
	panel.position = pos
	panel.custom_minimum_size = size
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed:
			get_viewport().set_input_as_handled()
	)
	var style := UITheme.make_panel_style(Color(0.1, 0.09, 0.14, 0.97), border_color, 10, 2)
	panel.add_theme_stylebox_override("panel", style)
	return panel


func _add_window_title(parent: Control, text: String, win_size: Vector2, accent: Color = UITheme.GOLD) -> void:
	var header := Panel.new()
	header.position = Vector2(0, 0)
	header.custom_minimum_size = Vector2(win_size.x, 36)
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_theme_stylebox_override("panel", UITheme.make_header_bar(accent))
	parent.add_child(header)
	var title := _make_label(text, Vector2(12, 8), GameConstants.FONT_MD, true, accent)
	title.custom_minimum_size = Vector2(win_size.x - 24, 20)
	parent.add_child(title)


func _add_close_button(parent: Control, win_size: Vector2, callback: Callable) -> void:
	var btn := Button.new()
	btn.text = "X"
	btn.position = Vector2(win_size.x - 36, 6)
	btn.custom_minimum_size = Vector2(28, 24)
	btn.add_theme_font_size_override("font_size", GameConstants.FONT_SM)
	btn.add_theme_stylebox_override("normal", UITheme.make_button_style(Color8(0xe7, 0x4c, 0x3c)))
	btn.pressed.connect(callback)
	parent.add_child(btn)


func _make_menu_button(text: String, pos: Vector2, bg: Color) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.position = pos
	btn.custom_minimum_size = Vector2(108, 34)
	btn.add_theme_font_size_override("font_size", GameConstants.FONT_SM)
	var style := UITheme.make_button_style(Color(bg, 0.92))
	btn.add_theme_stylebox_override("normal", style)
	var hover := style.duplicate()
	hover.bg_color = bg.lightened(0.15)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", hover)
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	btn.add_theme_constant_override("outline_size", 1)
	return btn


func _make_label(text: String, pos: Vector2, size: int, _bold: bool = false, color: Color = Color.WHITE) -> Label:
	var label := Label.new()
	label.text = text
	label.position = pos
	UITheme.style_label(label, size, color)
	return label


func _add_bar_bg(parent: Control, pos: Vector2, color: Color = Color8(0x44, 0x44, 0x44)) -> void:
	var bg := ColorRect.new()
	bg.position = pos
	bg.custom_minimum_size = Vector2(180, 10)
	bg.color = color
	parent.add_child(bg)


func _add_bar_fill(parent: Control, pos: Vector2, color: Color) -> ColorRect:
	var bar := ColorRect.new()
	bar.position = pos
	bar.custom_minimum_size = Vector2(180, 10)
	bar.color = color
	parent.add_child(bar)
	return bar


# --- Modal toggles ---

func _toggle_boss() -> void:
	if _block_if_death_modal():
		return
	is_boss_open = not is_boss_open
	if is_boss_open:
		_close_other_modals_except("boss")
		_layout_boss_window()
		if _boss_panel:
			_boss_panel.refresh()
	_animate_window(_boss_root, is_boss_open)
	_hide_item_tooltip()
	_layout_open_windows()


func _toggle_map() -> void:
	if _block_if_death_modal():
		return
	is_map_open = not is_map_open
	if is_map_open:
		_map_showing_world = false
		_show_current_map_view()
		_close_other_modals_except("map")
	_animate_window(_map_root, is_map_open)
	_hide_item_tooltip()
	_layout_open_windows()


func _close_other_modals_except(keep: String) -> void:
	if keep != "stat" and is_stat_open:
		is_stat_open = false
		_animate_window(_stat_panel, false)
	if keep != "inventory" and is_inventory_open:
		is_inventory_open = false
		_animate_window(_inv_root, false)
		if _equip_root:
			_animate_window(_equip_root, false)
	if keep != "skill" and is_skill_open:
		is_skill_open = false
		if _skill_root:
			_animate_window(_skill_root, false)
	if keep != "party" and is_party_open:
		is_party_open = false
		if _party_root:
			_animate_window(_party_root, false)
	if keep != "boss" and is_boss_open:
		is_boss_open = false
		if _boss_root:
			_animate_window(_boss_root, false)
	if keep != "map" and is_map_open:
		is_map_open = false
		if _map_root:
			_animate_window(_map_root, false)
	if keep != "npc" and is_npc_dialog_open:
		_close_npc_dialog()
	if keep != "shop" and is_shop_open:
		_close_shop()
	_layout_open_windows()
	if keep != "auto" and is_auto_window_open:
		is_auto_window_open = false
		if _auto_root:
			_animate_window(_auto_root, false)


func _release_modal_focus() -> void:
	var vp := get_viewport()
	if vp:
		vp.gui_release_focus()


func _toggle_stat() -> void:
	if _block_if_death_modal():
		return
	is_stat_open = not is_stat_open
	_animate_window(_stat_panel, is_stat_open)
	if is_stat_open:
		_close_other_modals_except("stat")
		_raise_modal_panel(_stat_panel)
		_update_player_stats_ui()
	else:
		_release_modal_focus()
	_hide_item_tooltip()
	_layout_open_windows()


func _toggle_inventory() -> void:
	if _block_if_death_modal():
		return
	is_inventory_open = not is_inventory_open
	_animate_window(_inv_root, is_inventory_open)
	if _equip_root: _animate_window(_equip_root, is_inventory_open)
	if is_inventory_open:
		_close_other_modals_except("inventory")
		_update_inventory_ui()
		_update_equipment_ui()
		# 🌟 ดันหน้าต่างกระเป๋าและสวมใส่ขึ้นมาด้านหน้าสุดตอนถูกเปิด
		if _equip_root: _raise_modal_panel(_equip_root)
		_raise_modal_panel(_inv_root)
	else:
		_hide_item_tooltip()
	_layout_open_windows()


func _toggle_skill() -> void:
	if _block_if_death_modal():
		return
	is_skill_open = not is_skill_open
	_animate_window(_skill_root, is_skill_open)
	if is_skill_open:
		_close_other_modals_except("skill")
		if _skill_book and player:
			_skill_book.refresh(player)
		# 🌟 ดันสมุดสกิลขึ้นหน้าสุด
		_raise_modal_panel(_skill_root)
	_hide_item_tooltip()
	_layout_open_windows()


func _toggle_party() -> void:
	if _block_if_death_modal():
		return
	is_party_open = not is_party_open
	if is_party_open:
		PartyManager.refresh_local_member_stats()
		_update_party_ui(PartyManager.party_members)
	_animate_window(_party_root, is_party_open)
	if is_party_open:
		_close_other_modals_except("party")
	_hide_item_tooltip()
	_layout_open_windows()

func _update_party_ui(members: Array) -> void:
	if not _party_list_container:
		return
	for child in _party_list_container.get_children():
		child.queue_free()

	if PartyManager.is_in_party():
		_party_status_label.text = "%d member(s) in party" % members.size()
		_party_id_label.text = "Party ID: %s" % PartyManager.current_party_id
	else:
		_party_status_label.text = "No active party — create one to adventure together"
		_party_id_label.text = ""

	if members.is_empty():
		var empty_panel := Panel.new()
		empty_panel.custom_minimum_size = Vector2(388, 80)
		empty_panel.add_theme_stylebox_override("panel", UITheme.make_panel_style(Color(0.08, 0.08, 0.12, 0.8), UITheme.PANEL_BORDER, 8))
		var empty_lbl := _make_label("No members yet.\nPress Create Party to start.", Vector2(12, 16), GameConstants.FONT_SM, false, UITheme.MUTED)
		empty_panel.add_child(empty_lbl)
		_party_list_container.add_child(empty_panel)
		return

	for mem in members:
		var p_name = mem.get("name", mem.get("player_name", "Unknown"))
		var p_lv = mem.get("level", 1)
		var p_hp = mem.get("hp", 0)
		var p_mhp = mem.get("max_hp", 100)
		var is_leader: bool = mem.get("is_leader", false)

		var card := Panel.new()
		card.custom_minimum_size = Vector2(388, 58)
		card.add_theme_stylebox_override("panel", UITheme.make_panel_style(Color(0.08, 0.10, 0.12, 0.92), Color8(0x16, 0xa0, 0x85), 8))

		var leader_mark := " ★" if is_leader else ""
		var name_lbl := _make_label("Lv.%d  %s%s" % [p_lv, p_name, leader_mark], Vector2(12, 8), GameConstants.FONT_MD, true, UITheme.GOLD if is_leader else Color.WHITE)
		card.add_child(name_lbl)

		var role_lbl := _make_label("Leader" if is_leader else "Member", Vector2(300, 10), GameConstants.FONT_XS, false, UITheme.MUTED)
		card.add_child(role_lbl)

		var hp_bg := ColorRect.new()
		hp_bg.position = Vector2(12, 34)
		hp_bg.custom_minimum_size = Vector2(300, 12)
		hp_bg.color = Color8(0x22, 0x22, 0x28)

		var hp_fill := ColorRect.new()
		hp_fill.color = Color8(0x2e, 0xcc, 0x71)
		var pct := clampf(float(p_hp) / float(maxi(p_mhp, 1)), 0.0, 1.0)
		hp_fill.custom_minimum_size = Vector2(300 * pct, 12)
		hp_bg.add_child(hp_fill)
		card.add_child(hp_bg)

		var hp_text := _make_label("%d / %d" % [p_hp, p_mhp], Vector2(320, 30), GameConstants.FONT_XS, false, UITheme.MUTED)
		card.add_child(hp_text)

		_party_list_container.add_child(card)

func _on_stat_confirm(pending_stats: Dictionary) -> void:
	if not player or not player.has_method("confirm_stat_allocation"):
		if _stat_panel and _stat_panel.has_method("release_confirm_lock"):
			_stat_panel.release_confirm_lock()
		return

	var save_id: int = player.confirm_stat_allocation(pending_stats)
	if save_id > 0:
		await DatabaseManager.wait_for_save_id(save_id)
	if _stat_panel:
		if _stat_panel.has_method("release_confirm_lock"):
			_stat_panel.release_confirm_lock()
		_stat_panel.refresh(player)


func _quick_slot_index_at(screen_pos: Vector2) -> int:
	for i in range(_skill_slots.size()):
		var bg: Panel = _skill_slots[i].bg
		if _panel_screen_rect(bg).has_point(screen_pos):
			return i
	return -1


func _update_inventory_ui() -> void:
	if _inventory_panel and player:
		_inventory_panel.refresh(player)
		return
	if not player:
		return
	for i in GameConstants.INVENTORY_SIZE:
		if i >= _inv_slots.size():
			break
		var item = player.inventory[i]
		var slot = _inv_slots[i]
		if item:
			slot.icon.texture = TextureGenerator.get_texture(item.icon)
			slot.icon.visible = true
			slot.count.text = str(item.count) if item.count > 1 else ""
		else:
			slot.icon.visible = false
			slot.count.text = ""


func _update_equipment_ui() -> void:
	if _equipment_panel and player:
		_equipment_panel.refresh(player)
		return
	if not player:
		return
	for key in _equip_slots:
		var icon: TextureRect = _equip_slots[key]
		var equipped_item = player.equipment.get(key)
		if equipped_item:
			icon.texture = TextureGenerator.get_texture(equipped_item.icon)
			icon.visible = true
		else:
			icon.visible = false


func _input(event: InputEvent) -> void:
	if not is_death_input_locked():
		if event is InputEventMouseMotion:
			_try_start_pending_skill_drags(event.global_position)
		elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			if _drag_skill_id != "":
				_handle_skill_drop()
			elif _drag_item_id != "":
				_handle_item_drop()
			elif _drag_inv_index >= 0:
				var quick_idx := _quick_slot_index_at(get_viewport().get_mouse_position())
				if quick_idx >= 0:
					_assign_quick_slot(quick_idx, _drag_inv_index)
				else:
					_cancel_item_drag()
			elif _skill_book_press_id != "":
				_cancel_skill_book_press()


func _unhandled_input(event: InputEvent) -> void:
	if is_death_input_locked():
		if chat_log_instance and chat_log_instance.is_input_focused():
			if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE:
				chat_log_instance.release_input()
				get_viewport().set_input_as_handled()
			return
		if event is InputEventKey and event.pressed and not event.echo:
			if event.physical_keycode == KEY_ENTER or event.physical_keycode == KEY_KP_ENTER:
				if chat_log_instance:
					chat_log_instance.focus_input()
				get_viewport().set_input_as_handled()
				return
			get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _slot_press_idx >= 0:
			_slot_press_idx = -1
			get_viewport().set_input_as_handled()
			return

	if chat_log_instance and chat_log_instance.is_input_focused():
		if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE:
			chat_log_instance.release_input()
			get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("toggle_stat"):
		_toggle_stat()
		get_viewport().set_input_as_handled()
		return
	elif event.is_action_pressed("toggle_inventory"):
		_toggle_inventory()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_ENTER or event.physical_keycode == KEY_KP_ENTER:
			if chat_log_instance and not chat_log_instance.is_input_focused() and not is_npc_dialog_open:
				chat_log_instance.focus_input()
				get_viewport().set_input_as_handled()
				return
		if event.physical_keycode == KEY_M:
			_toggle_map()
			get_viewport().set_input_as_handled()
		elif event.physical_keycode == KEY_B:
			_toggle_boss()
			get_viewport().set_input_as_handled()
		elif event.physical_keycode == KEY_K:
			_toggle_skill()
			get_viewport().set_input_as_handled()
		elif event.physical_keycode == KEY_P:
			_toggle_party()
			get_viewport().set_input_as_handled()
		elif event.physical_keycode == KEY_Q:
			_toggle_quest_log()
			get_viewport().set_input_as_handled()
		elif event.physical_keycode == KEY_O:
			_toggle_auto_window() # 👈 แก้บรรทัดนี้
			get_viewport().set_input_as_handled()

		var key_map = {KEY_1: 0, KEY_2: 1, KEY_3: 2, KEY_4: 3, KEY_5: 4, KEY_6: 5}
		if key_map.has(event.physical_keycode):
			_use_skill_slot(key_map[event.physical_keycode])
			get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if is_drag_active():
		_update_drag_preview_pos()

	if not player or not world:
		return

	_update_minimap_info()
	_update_map_window_subtitle()

	_title_label.text = GlobalData.player_name if GlobalData.player_name != "" else "Adventurer"
	if _job_hud_label:
		_job_hud_label.text = "Lv.%d | %s J.Lv.%d" % [player.level, ClassDatabase.get_display_name(player.current_job), player.job_level]
	if _zeny_hud_label:
		_zeny_hud_label.text = "%d Z" % player.zeny

	var hp_pct := clampf(float(player.hp) / player.max_hp, 0.0, 1.0)
	_hp_bar.scale.x = hp_pct
	_hp_text.text = "%d/%d" % [player.hp, player.max_hp]

	var sp_pct := clampf(float(player.sp) / player.max_sp, 0.0, 1.0)
	_sp_bar.scale.x = sp_pct
	_sp_text.text = "%d/%d" % [player.sp, player.max_sp]

	var xp_pct := clampf(float(player.current_exp) / player.max_exp, 0.0, 1.0)
	_xp_bar.scale.x = xp_pct
	_xp_text.text = "%d/%d" % [player.current_exp, player.max_exp]

	if world and is_instance_valid(world.get("selected_target")) and world.selected_target.get("is_active_monster"):
		var target = world.selected_target
		_target_hud_root.visible = true
		var m_id = target.get("monster_id") if target.get("monster_id") != null else "poring"
		var m_data = MonsterDB.get_monster(m_id)
		var m_name = m_data.get("name", "Monster")
		var hp = target.get("hp") if target.get("hp") != null else 0
		var max_hp = target.get("max_hp") if target.get("max_hp") != null else 100
		
		_target_name_label.text = m_name
		var target_hp_pct := clampf(float(hp) / float(max_hp), 0.0, 1.0)
		
		var current_scale_x = _target_hp_bar.scale.x
		if absf(current_scale_x - target_hp_pct) > 0.001:
			var tween_name = "hp_tween"
			if _target_hp_bar.has_meta(tween_name) and _target_hp_bar.get_meta(tween_name):
				_target_hp_bar.get_meta(tween_name).kill()
			var hp_tween = create_tween()
			_target_hp_bar.set_meta(tween_name, hp_tween)
			hp_tween.tween_property(_target_hp_bar, "scale:x", target_hp_pct, 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		_target_hp_text.text = "%d/%d" % [hp, max_hp]
	else:
		if _target_hud_root:
			_target_hud_root.visible = false

	if is_stat_open and _stat_panel and player:
		_stat_panel.refresh(player)


# --- Public API ---

func add_log(text: String, color: Color = Color.WHITE) -> void:
	if chat_log_instance:
		chat_log_instance.add_log(text, color)

func _on_chat_message_submitted(text: String) -> void:
	if text.strip_edges() == "": 
		return
		
	var player_name := GlobalData.player_name if GlobalData.player_name != "" else "Player"
	
	if chat_log_instance:
		chat_log_instance.add_chat_message(player_name, text, "map")
	
	if player and player.has_method("show_chat_balloon"):
		player.show_chat_balloon(text)
	
	if OnlinePresenceManager and OnlineSession.is_logged_in():
		OnlinePresenceManager.broadcast_chat(text)
		
func _on_chat_received(sender_name: String, text: String) -> void:
	var my_name = GlobalData.player_name if GlobalData.player_name != "" else "Player"
	
	if sender_name == my_name:
		return
		
	if chat_log_instance:
		chat_log_instance.add_chat_message(sender_name, text, "map")

func show_notification(message: String, banner_color: Color = Color8(0xf1, 0xc4, 0x0f)) -> void:
	_active_notifications = _active_notifications.filter(func(t): return is_instance_valid(t))
	var toast_w := GameConstants.TOAST_WIDTH
	var toast := Panel.new()
	toast.custom_minimum_size = Vector2(toast_w, 40)
	toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast.z_index = 200 
	
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.14, 0.92)
	style.border_color = banner_color
	style.set_border_width_all(2)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	toast.add_theme_stylebox_override("panel", style)
	
	var lbl := Label.new()
	lbl.text = message
	lbl.add_theme_font_size_override("font_size", GameConstants.FONT_MD)
	lbl.add_theme_color_override("font_color", Color.WHITE)
	lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	lbl.add_theme_constant_override("outline_size", 2)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.custom_minimum_size = Vector2(toast_w, 40)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast.add_child(lbl)
	
	var start_x = int((GW - toast_w) / 2.0)
	var base_y = UILayout.notification_base_y()
	var offset_y = _active_notifications.size() * 44.0
	toast.position = Vector2(start_x, base_y + offset_y)
	toast.pivot_offset = Vector2(180, 20) 
	
	ui_root.add_child(toast)
	_active_notifications.append(toast)
	
	toast.scale = Vector2(0.5, 0.5)
	toast.modulate.a = 0.0
	
	var tween = create_tween().set_parallel(true)
	tween.tween_property(toast, "scale", Vector2(1.0, 1.0), 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(toast, "modulate:a", 1.0, 0.15)
	tween.chain().tween_property(toast, "position:y", toast.position.y - 10.0, 1.2).set_trans(Tween.TRANS_SINE)
	
	var fade_tween = create_tween()
	fade_tween.tween_property(toast, "modulate:a", 0.0, 0.3).set_delay(1.1)
	fade_tween.tween_callback(func():
		_active_notifications.erase(toast)
		toast.queue_free()
	)


func _toggle_quest_log() -> void:
	if _block_if_death_modal():
		return
	if _quest_log == null:
		return
	_quest_log.toggle_panel()
	_layout_open_windows()
	if _quest_log.is_panel_visible():
		refresh_quest_log()


func refresh_quest_log() -> void:
	if _quest_log and player:
		_quest_log.refresh(player)


func _build_quest_log() -> void:
	_quest_log = QuestLogPanel.new()
	_quest_log.collapse_changed.connect(func(_c): _layout_open_windows())
	ui_root.add_child(_quest_log)


func _build_skill_window() -> void:
	_skill_book = SkillBookPanel.new()
	_skill_book.visible = false
	_skill_book.closed.connect(_toggle_skill)
	ui_root.add_child(_skill_book)
	_skill_root = _skill_book


func _animate_window(window: Control, is_opening: bool) -> void:
	if not window: return
	if window.has_meta("tween") and window.get_meta("tween"):
		window.get_meta("tween").kill()
		
	var tween = create_tween().set_parallel(true)
	window.set_meta("tween", tween)
	
	if is_opening:
		window.visible = true
		window.scale = Vector2(0.8, 0.8)
		window.modulate.a = 0.0
		tween.tween_property(window, "scale", Vector2(1.0, 1.0), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(window, "modulate:a", 1.0, 0.15)
	else:
		tween.tween_property(window, "scale", Vector2(0.9, 0.9), 0.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		tween.tween_property(window, "modulate:a", 0.0, 0.1)
		tween.chain().tween_callback(func(): window.visible = false)


func refresh_inventory_and_equipment_ui() -> void:
	_update_inventory_ui()
	_update_equipment_ui()
	_update_quick_slot_ui()

func _build_auto_window() -> void:
	var win_size := Vector2(340, 300)
	var win_pos := Vector2.ZERO 
	
	_auto_root = _make_window_root(win_pos, win_size, Color8(0x9b, 0x59, 0xb6))
	_auto_root.visible = false
	ui_root.add_child(_auto_root)

	_add_window_title(_auto_root, "- AUTO SETTINGS -", win_size, Color8(0x9b, 0x59, 0xb6))
	_add_close_button(_auto_root, win_size, _toggle_auto_window)

	_auto_switch_btn = CheckButton.new()
	_auto_switch_btn.text = " เปิดใช้งานบอท (Auto-Battle)"
	_auto_switch_btn.position = Vector2(20, 50)
	_auto_switch_btn.custom_minimum_size = Vector2(300, 36)
	_auto_switch_btn.add_theme_font_size_override("font_size", GameConstants.FONT_MD)
	_auto_switch_btn.toggled.connect(_on_auto_switch_toggled)
	_auto_root.add_child(_auto_switch_btn)
	
	_auto_flee_boss_btn = CheckButton.new()
	_auto_flee_boss_btn.text = " ระบบวิ่งหนีบอส (Flee Boss)"
	_auto_flee_boss_btn.position = Vector2(20, 88)
	_auto_flee_boss_btn.custom_minimum_size = Vector2(300, 36)
	_auto_flee_boss_btn.add_theme_font_size_override("font_size", GameConstants.FONT_MD)
	_auto_flee_boss_btn.toggled.connect(_on_auto_flee_boss_toggled)
	_auto_root.add_child(_auto_flee_boss_btn)

	_auto_potion_btn = CheckButton.new()
	_auto_potion_btn.text = " ใช้ยาอัตโนมัติ (Auto Potion)"
	_auto_potion_btn.position = Vector2(20, 126)
	_auto_potion_btn.custom_minimum_size = Vector2(300, 36)
	_auto_potion_btn.add_theme_font_size_override("font_size", GameConstants.FONT_MD)
	_auto_potion_btn.toggled.connect(_on_auto_potion_toggled)
	_auto_root.add_child(_auto_potion_btn)

	var potion_panel := Panel.new()
	potion_panel.position = Vector2(20, 168)
	potion_panel.custom_minimum_size = Vector2(300, 112)
	potion_panel.add_theme_stylebox_override("panel", UITheme.make_panel_style(Color(0.0, 0.0, 0.0, 0.3), Color8(0x55, 0x55, 0x77), 4))
	_auto_root.add_child(potion_panel)

	var hp_title := _make_label("HP ต่ำกว่า", Vector2(10, 8), GameConstants.FONT_XS, false, UITheme.MUTED)
	potion_panel.add_child(hp_title)
	_auto_potion_hp_lbl = _make_label("50%", Vector2(250, 8), GameConstants.FONT_XS, false, Color8(0x2e, 0xcc, 0x71))
	_auto_potion_hp_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_auto_potion_hp_lbl.custom_minimum_size = Vector2(40, 18)
	potion_panel.add_child(_auto_potion_hp_lbl)

	_auto_potion_hp_slider = HSlider.new()
	_auto_potion_hp_slider.position = Vector2(10, 28)
	_auto_potion_hp_slider.custom_minimum_size = Vector2(280, 20)
	_auto_potion_hp_slider.min_value = 5
	_auto_potion_hp_slider.max_value = 95
	_auto_potion_hp_slider.step = 5
	_auto_potion_hp_slider.value = 50
	_auto_potion_hp_slider.tick_count = 0
	_auto_potion_hp_slider.value_changed.connect(_on_auto_potion_hp_changed)
	potion_panel.add_child(_auto_potion_hp_slider)

	var sp_title := _make_label("SP ต่ำกว่า", Vector2(10, 58), GameConstants.FONT_XS, false, UITheme.MUTED)
	potion_panel.add_child(sp_title)
	_auto_potion_sp_lbl = _make_label("30%", Vector2(250, 58), GameConstants.FONT_XS, false, Color8(0x34, 0x98, 0xdb))
	_auto_potion_sp_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_auto_potion_sp_lbl.custom_minimum_size = Vector2(40, 18)
	potion_panel.add_child(_auto_potion_sp_lbl)

	_auto_potion_sp_slider = HSlider.new()
	_auto_potion_sp_slider.position = Vector2(10, 78)
	_auto_potion_sp_slider.custom_minimum_size = Vector2(280, 20)
	_auto_potion_sp_slider.min_value = 5
	_auto_potion_sp_slider.max_value = 95
	_auto_potion_sp_slider.step = 5
	_auto_potion_sp_slider.value = 30
	_auto_potion_sp_slider.tick_count = 0
	_auto_potion_sp_slider.value_changed.connect(_on_auto_potion_sp_changed)
	potion_panel.add_child(_auto_potion_sp_slider)

func _toggle_auto_window() -> void:
	if _block_if_death_modal():
		return
	is_auto_window_open = not is_auto_window_open
	_animate_window(_auto_root, is_auto_window_open)
	if is_auto_window_open:
		_close_other_modals_except("auto")
		if player:
			_sync_auto_settings_from_player()
		_raise_modal_panel(_auto_root)
	_hide_item_tooltip()
	_layout_open_windows()

func _on_auto_switch_toggled(button_pressed: bool) -> void:
	if player and player.has_method("set_auto_mode"):
		player.set_auto_mode(button_pressed)

# 🌟 อีเวนต์เวลากดปุ่มหนีบอส
func _on_auto_flee_boss_toggled(button_pressed: bool) -> void:
	if player and player.has_method("set_auto_flee_boss"):
		player.set_auto_flee_boss(button_pressed)


func _sync_auto_settings_from_player() -> void:
	if player == null:
		return
	_syncing_auto_ui = true
	_auto_switch_btn.button_pressed = player.get("is_auto_mode")
	_auto_flee_boss_btn.button_pressed = player.get("auto_flee_boss")
	_auto_potion_btn.button_pressed = player.get("auto_potion_enabled")
	_auto_potion_hp_slider.value = int(round(float(player.get("auto_potion_hp_pct")) * 100.0))
	_auto_potion_sp_slider.value = int(round(float(player.get("auto_potion_sp_pct")) * 100.0))
	_auto_potion_hp_lbl.text = "%d%%" % int(_auto_potion_hp_slider.value)
	_auto_potion_sp_lbl.text = "%d%%" % int(_auto_potion_sp_slider.value)
	_update_auto_potion_sliders_enabled()
	_syncing_auto_ui = false


func _update_auto_potion_sliders_enabled() -> void:
	var enabled := _auto_potion_btn.button_pressed
	_auto_potion_hp_slider.editable = enabled
	_auto_potion_sp_slider.editable = enabled
	var alpha := 1.0 if enabled else 0.45
	_auto_potion_hp_slider.modulate.a = alpha
	_auto_potion_sp_slider.modulate.a = alpha
	_auto_potion_hp_lbl.modulate.a = alpha
	_auto_potion_sp_lbl.modulate.a = alpha


func _on_auto_potion_toggled(button_pressed: bool) -> void:
	if _syncing_auto_ui:
		return
	if player and player.has_method("set_auto_potion_enabled"):
		player.set_auto_potion_enabled(button_pressed)
	_update_auto_potion_sliders_enabled()


func _on_auto_potion_hp_changed(value: float) -> void:
	_auto_potion_hp_lbl.text = "%d%%" % int(value)
	if _syncing_auto_ui:
		return
	if player and player.has_method("set_auto_potion_hp_pct"):
		player.set_auto_potion_hp_pct(value / 100.0)


func _on_auto_potion_sp_changed(value: float) -> void:
	_auto_potion_sp_lbl.text = "%d%%" % int(value)
	if _syncing_auto_ui:
		return
	if player and player.has_method("set_auto_potion_sp_pct"):
		player.set_auto_potion_sp_pct(value / 100.0)
