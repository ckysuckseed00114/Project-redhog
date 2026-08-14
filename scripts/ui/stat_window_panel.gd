class_name StatWindowPanel
extends Panel

signal closed
signal stat_confirm_pressed(pending_stats: Dictionary)
signal layout_changed

const WIN_SIZE := Vector2(700, 460)
const COLLAPSED_SIZE := Vector2(700, 50)
const STAT_ORDER: Array[String] = ["str", "agi", "vit", "int", "dex", "luk"]
const GENERAL_COMBAT_STATS: Array[String] = ["atk", "def", "matk", "mdef"]
const ADVANCED_STATS: Array[String] = ["hit", "flee", "aspd"]

const COLOR_PANEL := Color(0.07, 0.07, 0.1, 0.95)
const COLOR_COLUMN := Color(0.05, 0.05, 0.08, 0.88)
const COLOR_GOLD := Color8(0xd4, 0xaf, 0x37)
const COLOR_TEXT := Color8(0xf0, 0xec, 0xe4)
const COLOR_BONUS := Color8(0x5d, 0xe8, 0x8a)
const COLOR_MUTED := Color8(0x88, 0x88, 0x99)
const COLOR_POINTS := Color8(0xff, 0xd7, 0x00)
const COLOR_BTN_SQUARE := Color8(0x1c, 0x1c, 0x28)
const COLOR_BTN_SQUARE_HOVER := Color8(0x2a, 0x2a, 0x3c)
const COLOR_BTN_PLUS := Color8(0x1f, 0x4d, 0x35)
const COLOR_BTN_MINUS := Color8(0x4a, 0x22, 0x22)
const COLOR_CONFIRM := Color8(0x2a, 0x6b, 0x3d)
const COLOR_RESET := Color8(0x2a, 0x2a, 0x34)
const COLOR_SILVER := Color8(0xaa, 0xb0, 0xbc)
const COLOR_ACCORDION_BG := Color8(0x15, 0x15, 0x1e, 0.9)

var _name_label: Label
var _job_label: Label
var _points_label: Label
var _radar_chart: StatHexRadar
var _stat_rows: Dictionary = {}
var _pending_alloc: Dictionary = {}
var _current_player: Player
var _btn_confirm: Button
var _btn_reset: Button
var _confirm_busy: bool = false

var _vital_bars: Dictionary = {}
var _derived_labels: Dictionary = {}
var _accordion_grids: Dictionary = {}
var _accordion_toggles: Dictionary = {}

var _content_split: Control
var _title_bar: HBoxContainer
var _title_label: Label
var _btn_collapse: Button
var _collapsed: bool = false


func _init() -> void:
	for k in StatRegistry.primary_keys():
		_pending_alloc[k] = 0

	custom_minimum_size = WIN_SIZE
	size = WIN_SIZE
	clip_contents = true
	z_index = 80
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_theme_stylebox_override(
		"panel",
		UITheme.make_panel_style(COLOR_PANEL, COLOR_GOLD, 10, 2)
	)
	_build()


func _build() -> void:
	var root := MarginContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("margin_left", 12)
	root.add_theme_constant_override("margin_top", 10)
	root.add_theme_constant_override("margin_right", 12)
	root.add_theme_constant_override("margin_bottom", 10)
	add_child(root)

	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 8)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(body)

	_title_bar = _build_title_bar()
	body.add_child(_title_bar)

	_content_split = HBoxContainer.new()
	_content_split.add_theme_constant_override("separation", 10)
	_content_split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(_content_split)

	_content_split.add_child(_build_left_column())
	_content_split.add_child(_build_right_column())


func _build_title_bar() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 32)

	var title_wrap := PanelContainer.new()
	title_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_wrap.add_theme_stylebox_override("panel", UITheme.make_header_bar(COLOR_GOLD))
	row.add_child(title_wrap)

	_title_label = Label.new()
	_title_label.text = "Character Status"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UITheme.style_label(_title_label, GameConstants.FONT_MD, COLOR_GOLD, 1)
	title_wrap.add_child(_title_label)

	_btn_collapse = _make_square_button("▴", Color8(0x2a, 0x35, 0x48), Vector2(28, 28))
	_btn_collapse.tooltip_text = "ย่อ/ขยายหน้าต่าง"
	_btn_collapse.pressed.connect(_toggle_collapsed)
	row.add_child(_btn_collapse)

	var close_btn := _make_square_button("✕", Color8(0x6b, 0x22, 0x22), Vector2(28, 28))
	close_btn.pressed.connect(func() -> void: closed.emit())
	row.add_child(close_btn)

	return row


func is_collapsed() -> bool:
	return _collapsed


func ensure_expanded() -> void:
	if _collapsed:
		_set_collapsed(false)


func _toggle_collapsed() -> void:
	_set_collapsed(not _collapsed)


func _set_collapsed(collapsed: bool) -> void:
	_collapsed = collapsed
	_content_split.visible = not _collapsed
	if _collapsed:
		custom_minimum_size = COLLAPSED_SIZE
		size = COLLAPSED_SIZE
		_btn_collapse.text = "▾"
	else:
		custom_minimum_size = WIN_SIZE
		size = WIN_SIZE
		_btn_collapse.text = "▴"
	_update_title_summary()
	layout_changed.emit()
	if not _collapsed and is_inside_tree():
		call_deferred("_update_vitals")


func _update_title_summary() -> void:
	if _title_label == null:
		return
	if _collapsed and _current_player:
		var name_text := GlobalData.player_name if GlobalData.player_name != "" else "Adventurer"
		_title_label.text = "%s  ·  Lv.%d  ·  Points %d" % [
			name_text,
			_current_player.level,
			_remaining_points(),
		]
	else:
		_title_label.text = "Character Status"


func _build_left_column() -> Control:
	var wrapper := PanelContainer.new()
	wrapper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrapper.size_flags_vertical = Control.SIZE_EXPAND_FILL
	wrapper.size_flags_stretch_ratio = 0.4
	wrapper.clip_contents = true
	wrapper.add_theme_stylebox_override("panel", UITheme.make_panel_style(COLOR_COLUMN, Color8(0x55, 0x45, 0x22, 0.7), 8, 1))

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	wrapper.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	margin.add_child(vbox)

	var radar_title := Label.new()
	radar_title.text = "Stat Profile"
	radar_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UITheme.style_label(radar_title, GameConstants.FONT_XS, COLOR_MUTED, 0)
	vbox.add_child(radar_title)

	_radar_chart = StatHexRadar.new()
	_radar_chart.custom_minimum_size = Vector2(0, 142)
	_radar_chart.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_radar_chart.wire_color = Color8(0x55, 0xee, 0xff, 0.9)
	_radar_chart.axis_color = Color8(0x33, 0xbb, 0xdd, 0.55)
	_radar_chart.fill_color = Color(0.15, 0.65, 1.0, 0.28)
	_radar_chart.fill_stroke_color = Color8(0x77, 0xdd, 0xff, 0.95)
	_radar_chart.label_color = Color8(0x99, 0xee, 0xff, 0.85)
	_radar_chart.ring_color = Color8(0x22, 0x99, 0xbb, 0.35)
	vbox.add_child(_radar_chart)

	var sep := HSeparator.new()
	sep.modulate = Color(1, 1, 1, 0.15)
	vbox.add_child(sep)

	var vitals_title := Label.new()
	vitals_title.text = "Vitals"
	vitals_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	UITheme.style_label(vitals_title, GameConstants.FONT_XS, COLOR_GOLD, 0)
	vbox.add_child(vitals_title)

	var vitals := VBoxContainer.new()
	vitals.add_theme_constant_override("separation", 5)
	vbox.add_child(vitals)

	for spec in [
		{"key": "base_exp", "label": "Base EXP", "color": Color8(0x2b, 0x82, 0xda), "rtl": false},
		{"key": "job_exp", "label": "Job EXP", "color": Color8(0xe8, 0xb9, 0x2a), "rtl": true},
		{"key": "hp", "label": "HP", "color": Color8(0x5d, 0xc4, 0x5a), "rtl": false},
		{"key": "sp", "label": "SP", "color": Color8(0x44, 0xd4, 0xe8), "rtl": false},
	]:
		vitals.add_child(_make_vital_row(spec.label, spec.color, spec.key, spec.rtl))

	return wrapper


func _make_vital_row(title: String, color: Color, key: String, rtl: bool) -> VBoxContainer:
	var block := VBoxContainer.new()
	block.add_theme_constant_override("separation", 2)

	var label_row := HBoxContainer.new()
	block.add_child(label_row)

	var name_lbl := Label.new()
	name_lbl.text = title
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UITheme.style_label(name_lbl, GameConstants.FONT_XS, COLOR_MUTED, 0)
	label_row.add_child(name_lbl)

	var value_lbl := Label.new()
	value_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	UITheme.style_label(value_lbl, GameConstants.FONT_XS, COLOR_TEXT, 0)
	label_row.add_child(value_lbl)

	var track := Panel.new()
	track.custom_minimum_size = Vector2(0, 8)
	track.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var track_style := StyleBoxFlat.new()
	track_style.bg_color = Color8(0x12, 0x12, 0x1a)
	track_style.corner_radius_top_left = 2
	track_style.corner_radius_bottom_left = 2
	track_style.corner_radius_top_right = 2
	track_style.corner_radius_bottom_right = 2
	track.add_theme_stylebox_override("panel", track_style)
	track.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
	block.add_child(track)

	var fill := ColorRect.new()
	fill.color = color
	fill.custom_minimum_size = Vector2(200, 8)
	if rtl:
		fill.pivot_offset = Vector2(200, 4)
	track.add_child(fill)

	_vital_bars[key] = {"fill": fill, "label": value_lbl, "track": track, "rtl": rtl}
	return block


func _build_right_column() -> Control:
	var wrapper := PanelContainer.new()
	wrapper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrapper.size_flags_vertical = Control.SIZE_EXPAND_FILL
	wrapper.size_flags_stretch_ratio = 0.6
	wrapper.clip_contents = true
	wrapper.add_theme_stylebox_override("panel", UITheme.make_panel_style(COLOR_COLUMN, Color8(0x55, 0x45, 0x22, 0.7), 8, 1))

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.clip_contents = true
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 8)
	wrapper.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_child(vbox)

	vbox.add_child(_build_identity_header())

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.clip_contents = true
	vbox.add_child(scroll)

	var scroll_body := VBoxContainer.new()
	scroll_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_body.add_theme_constant_override("separation", 6)
	scroll.add_child(scroll_body)

	scroll_body.add_child(_build_allocation_section())
	scroll_body.add_child(_make_section_divider())
	scroll_body.add_child(_build_detailed_stats_section())

	vbox.add_child(_build_action_row())
	return wrapper


func _build_allocation_section() -> VBoxContainer:
	var section := VBoxContainer.new()
	section.add_theme_constant_override("separation", 6)
	section.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var title := Label.new()
	title.text = "Stat Allocation"
	UITheme.style_label(title, GameConstants.FONT_XS, COLOR_GOLD, 0)
	section.add_child(title)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	section.add_child(header)

	var col_name := Label.new()
	col_name.text = "Stat"
	col_name.custom_minimum_size = Vector2(42, 0)
	UITheme.style_label(col_name, GameConstants.FONT_XS, COLOR_MUTED, 0)
	header.add_child(col_name)

	var col_base := Label.new()
	col_base.text = "Base"
	col_base.custom_minimum_size = Vector2(36, 0)
	col_base.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UITheme.style_label(col_base, GameConstants.FONT_XS, COLOR_MUTED, 0)
	header.add_child(col_base)

	var col_bonus := Label.new()
	col_bonus.text = "Bonus"
	col_bonus.custom_minimum_size = Vector2(44, 0)
	col_bonus.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UITheme.style_label(col_bonus, GameConstants.FONT_XS, COLOR_MUTED, 0)
	header.add_child(col_bonus)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)

	var col_cost := Label.new()
	col_cost.text = "Cost"
	col_cost.custom_minimum_size = Vector2(40, 0)
	col_cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	UITheme.style_label(col_cost, GameConstants.FONT_XS, COLOR_MUTED, 0)
	header.add_child(col_cost)

	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 4)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	section.add_child(list)

	for key: String in STAT_ORDER:
		list.add_child(_make_stat_row(key))

	return section


func _build_detailed_stats_section() -> VBoxContainer:
	var section := VBoxContainer.new()
	section.add_theme_constant_override("separation", 4)
	section.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var title := Label.new()
	title.text = "Detailed Stats"
	UITheme.style_label(title, GameConstants.FONT_XS, COLOR_GOLD, 0)
	section.add_child(title)

	section.add_child(_make_section_divider())
	section.add_child(_make_accordion_section("general", "General Combat", GENERAL_COMBAT_STATS))
	section.add_child(_make_section_divider())
	section.add_child(_make_accordion_section("advanced", "Advanced Stats", ADVANCED_STATS))
	return section


func _make_section_divider() -> HSeparator:
	var sep := HSeparator.new()
	sep.modulate = Color(1, 1, 1, 0.1)
	return sep


func _make_accordion_section(section_id: String, title: String, stat_keys: Array[String]) -> VBoxContainer:
	var block := VBoxContainer.new()
	block.add_theme_constant_override("separation", 0)
	block.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	block.add_child(_make_accordion_header(section_id, title))

	var grid_wrap := MarginContainer.new()
	grid_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid_wrap.visible = false
	grid_wrap.add_theme_constant_override("margin_left", 8)
	grid_wrap.add_theme_constant_override("margin_top", 4)
	grid_wrap.add_theme_constant_override("margin_right", 2)
	grid_wrap.add_theme_constant_override("margin_bottom", 2)
	block.add_child(grid_wrap)
	_accordion_grids[section_id + "_wrap"] = grid_wrap

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 3)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid_wrap.add_child(grid)
	_accordion_grids[section_id] = grid

	for key: String in stat_keys:
		var name_lbl := Label.new()
		name_lbl.text = StatRegistry.get_label(key)
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		UITheme.style_label(name_lbl, GameConstants.FONT_XS, COLOR_SILVER, 0)
		grid.add_child(name_lbl)

		var value_lbl := Label.new()
		value_lbl.text = "0"
		value_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		value_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		UITheme.style_label(value_lbl, GameConstants.FONT_XS, Color.WHITE, 0)
		grid.add_child(value_lbl)
		_derived_labels[key] = value_lbl

	return block


func _make_accordion_header(section_id: String, title: String) -> PanelContainer:
	var header := PanelContainer.new()
	header.custom_minimum_size = Vector2(0, 26)
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.mouse_filter = Control.MOUSE_FILTER_STOP

	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_ACCORDION_BG
	style.border_color = COLOR_GOLD
	style.border_width_left = 2
	style.corner_radius_top_left = 2
	style.corner_radius_top_right = 2
	style.corner_radius_bottom_left = 2
	style.corner_radius_bottom_right = 2
	style.content_margin_left = 10
	style.content_margin_top = 4
	style.content_margin_right = 8
	style.content_margin_bottom = 4
	header.add_theme_stylebox_override("panel", style)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	header.add_child(row)

	var title_lbl := Label.new()
	title_lbl.text = title
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UITheme.style_label(title_lbl, GameConstants.FONT_XS, COLOR_TEXT, 0)
	row.add_child(title_lbl)

	var indicator := Label.new()
	indicator.text = "[ + ]"
	indicator.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	UITheme.style_label(indicator, GameConstants.FONT_XS, COLOR_SILVER, 0)
	row.add_child(indicator)

	_accordion_toggles[section_id] = indicator
	header.gui_input.connect(_on_accordion_header_input.bind(section_id))
	return header


func _on_accordion_header_input(event: InputEvent, section_id: String) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_on_accordion_toggle(section_id)


func _on_accordion_toggle(section_id: String) -> void:
	var grid: GridContainer = _accordion_grids.get(section_id)
	var grid_wrap: Control = _accordion_grids.get(section_id + "_wrap")
	var indicator: Label = _accordion_toggles.get(section_id)
	if grid == null or indicator == null:
		return
	var expanded := not grid_wrap.visible if grid_wrap else not grid.visible
	if grid_wrap:
		grid_wrap.visible = expanded
	indicator.text = "[ - ]" if expanded else "[ + ]"


func _build_identity_header() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)

	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 2)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)

	_name_label = Label.new()
	UITheme.style_label(_name_label, GameConstants.FONT_MD, COLOR_TEXT, 1)
	info.add_child(_name_label)

	_job_label = Label.new()
	UITheme.style_label(_job_label, GameConstants.FONT_XS, COLOR_MUTED, 0)
	info.add_child(_job_label)

	var points_wrap := PanelContainer.new()
	points_wrap.add_theme_stylebox_override(
		"panel",
		UITheme.make_panel_style(Color8(0x2d, 0x24, 0x0b, 0.95), COLOR_POINTS, 6, 1)
	)
	row.add_child(points_wrap)

	var points_margin := MarginContainer.new()
	points_margin.add_theme_constant_override("margin_left", 10)
	points_margin.add_theme_constant_override("margin_top", 6)
	points_margin.add_theme_constant_override("margin_right", 10)
	points_margin.add_theme_constant_override("margin_bottom", 6)
	points_wrap.add_child(points_margin)

	_points_label = Label.new()
	_points_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	UITheme.style_label(_points_label, GameConstants.FONT_SM, COLOR_POINTS, 1)
	points_margin.add_child(_points_label)

	return row


func _make_stat_row(key: String) -> PanelContainer:
	var row_panel := PanelContainer.new()
	row_panel.add_theme_stylebox_override(
		"panel",
		UITheme.make_panel_style(Color8(0x10, 0x10, 0x16, 0.85), Color8(0x33, 0x33, 0x44, 0.6), 4, 1)
	)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 6)
	margin.add_theme_constant_override("margin_top", 3)
	margin.add_theme_constant_override("margin_right", 6)
	margin.add_theme_constant_override("margin_bottom", 3)
	row_panel.add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	margin.add_child(row)

	var name_lbl := Label.new()
	name_lbl.text = StatRegistry.get_label(key)
	name_lbl.custom_minimum_size = Vector2(42, 0)
	UITheme.style_label(name_lbl, GameConstants.FONT_SM, COLOR_GOLD, 0)
	row.add_child(name_lbl)

	var base_lbl := Label.new()
	base_lbl.text = "0"
	base_lbl.custom_minimum_size = Vector2(36, 0)
	base_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UITheme.style_label(base_lbl, GameConstants.FONT_SM, COLOR_TEXT, 0)
	row.add_child(base_lbl)

	var bonus_lbl := Label.new()
	bonus_lbl.text = "—"
	bonus_lbl.custom_minimum_size = Vector2(44, 0)
	bonus_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UITheme.style_label(bonus_lbl, GameConstants.FONT_SM, COLOR_MUTED, 0)
	row.add_child(bonus_lbl)

	var flex := Control.new()
	flex.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(flex)

	var minus := _make_square_button("◂", COLOR_BTN_MINUS, Vector2(24, 24))
	minus.pressed.connect(_on_minus_pressed.bind(key))
	row.add_child(minus)

	var plus := _make_square_button("▸", COLOR_BTN_PLUS, Vector2(24, 24))
	plus.pressed.connect(_on_plus_pressed.bind(key))
	row.add_child(plus)

	var cost_lbl := Label.new()
	cost_lbl.text = "1"
	cost_lbl.custom_minimum_size = Vector2(40, 0)
	cost_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	UITheme.style_label(cost_lbl, GameConstants.FONT_XS, COLOR_MUTED, 0)
	row.add_child(cost_lbl)

	_stat_rows[key] = {
		"base": base_lbl,
		"bonus": bonus_lbl,
		"minus": minus,
		"plus": plus,
		"cost": cost_lbl,
	}
	return row_panel


func _build_action_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_theme_constant_override("separation", 10)

	_btn_reset = Button.new()
	_btn_reset.text = "Reset Pending"
	_btn_reset.custom_minimum_size = Vector2(130, 32)
	_apply_action_button_style(_btn_reset, COLOR_RESET, COLOR_MUTED)
	_btn_reset.pressed.connect(_on_reset_pressed)
	row.add_child(_btn_reset)

	_btn_confirm = Button.new()
	_btn_confirm.text = "Confirm"
	_btn_confirm.custom_minimum_size = Vector2(120, 32)
	_apply_action_button_style(_btn_confirm, COLOR_CONFIRM, COLOR_GOLD)
	_btn_confirm.pressed.connect(_on_confirm_pressed)
	row.add_child(_btn_confirm)

	_set_buttons_active(false)
	return row


func _make_square_button(text: String, bg: Color, btn_size: Vector2) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = btn_size
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_stylebox_override("normal", UITheme.make_button_style(bg, bg.lightened(0.2)))
	btn.add_theme_stylebox_override("hover", UITheme.make_button_style(bg.lightened(0.12), COLOR_GOLD.darkened(0.2)))
	btn.add_theme_stylebox_override("pressed", UITheme.make_button_style(bg.darkened(0.12), COLOR_GOLD.darkened(0.35)))
	btn.add_theme_stylebox_override("disabled", UITheme.make_button_style(Color8(0x22, 0x22, 0x28), Color8(0x44, 0x44, 0x50)))
	btn.add_theme_color_override("font_color", COLOR_TEXT)
	btn.add_theme_color_override("font_disabled_color", Color8(0x66, 0x66, 0x77))
	btn.add_theme_font_size_override("font_size", GameConstants.FONT_SM)
	return btn


func _apply_action_button_style(btn: Button, bg: Color, accent: Color) -> void:
	btn.add_theme_stylebox_override("normal", UITheme.make_button_style(bg, accent.darkened(0.25)))
	btn.add_theme_stylebox_override("hover", UITheme.make_button_style(bg.lightened(0.08), accent))
	btn.add_theme_stylebox_override("pressed", UITheme.make_button_style(bg.darkened(0.1), accent.darkened(0.2)))
	btn.add_theme_stylebox_override("disabled", UITheme.make_button_style(Color8(0x28, 0x28, 0x30), Color8(0x44, 0x44, 0x50)))
	btn.add_theme_color_override("font_color", accent if accent != COLOR_MUTED else COLOR_TEXT)
	btn.add_theme_color_override("font_disabled_color", Color8(0x66, 0x66, 0x77))
	btn.add_theme_font_size_override("font_size", GameConstants.FONT_SM)


func _set_buttons_active(active: bool) -> void:
	_btn_confirm.disabled = not active or _confirm_busy
	_btn_reset.disabled = not active or _confirm_busy


func _total_pending() -> int:
	var total := 0
	for k in _pending_alloc.keys():
		total += int(_pending_alloc[k])
	return total


func _remaining_points() -> int:
	if _current_player == null:
		return 0
	return _current_player.stat_points - _total_pending()


func _on_plus_pressed(key: String) -> void:
	if _current_player == null or _remaining_points() <= 0:
		return
	_pending_alloc[key] = int(_pending_alloc[key]) + 1
	_refresh_display()


func _on_minus_pressed(key: String) -> void:
	if int(_pending_alloc.get(key, 0)) <= 0:
		return
	_pending_alloc[key] = int(_pending_alloc[key]) - 1
	_refresh_display()


func _on_reset_pressed() -> void:
	for k in _pending_alloc.keys():
		_pending_alloc[k] = 0
	_refresh_display()


func _on_confirm_pressed() -> void:
	if _confirm_busy or _total_pending() <= 0:
		return
	_confirm_busy = true
	_btn_confirm.disabled = true
	_btn_reset.disabled = true
	stat_confirm_pressed.emit(_pending_alloc.duplicate())
	for k in _pending_alloc.keys():
		_pending_alloc[k] = 0
	_refresh_display()


func release_confirm_lock() -> void:
	_confirm_busy = false
	_refresh_display()


func refresh(player: Player) -> void:
	if _current_player != player:
		_current_player = player
		for k in StatRegistry.primary_keys():
			_pending_alloc[k] = 0
	_refresh_display()


func _refresh_display() -> void:
	if _current_player == null:
		return

	var remain := _remaining_points()
	var total_pending := _total_pending()

	_name_label.text = GlobalData.player_name if GlobalData.player_name != "" else "Adventurer"
	_job_label.text = "Lv.%d  %s" % [_current_player.level, ClassDatabase.get_display_name(_current_player.current_job)]
	_points_label.text = "Available: %d" % remain
	_update_title_summary()

	var radar_stats: Dictionary = {}
	for key: String in StatRegistry.primary_keys():
		var base_val: int = _current_player.get_stat(key)
		var pending_val: int = int(_pending_alloc.get(key, 0))
		var row: Dictionary = _stat_rows.get(key, {})
		if row.is_empty():
			continue

		row.base.text = str(base_val)
		if pending_val > 0:
			row.bonus.text = "+%d" % pending_val
			row.bonus.add_theme_color_override("font_color", COLOR_BONUS)
		else:
			row.bonus.text = "—"
			row.bonus.add_theme_color_override("font_color", COLOR_MUTED)

		row.cost.text = "1"
		row.minus.disabled = pending_val <= 0 or _confirm_busy
		row.plus.disabled = remain <= 0 or _current_player.is_dead or _confirm_busy

		radar_stats[key] = base_val + pending_val

	if _radar_chart:
		_radar_chart.set_stats(radar_stats)

	_update_derived_stats()
	_update_vitals()
	_set_buttons_active(total_pending > 0)
	if is_inside_tree():
		call_deferred("_update_vitals")


func _update_derived_stats() -> void:
	if _current_player == null:
		return
	for key: String in _derived_labels.keys():
		var lbl: Label = _derived_labels[key]
		var val: Variant = StatRegistry.get_derived(_current_player, key)
		if key == "aspd":
			lbl.text = "%.2f" % float(val)
		else:
			lbl.text = str(val)


func _update_vitals() -> void:
	if _current_player == null:
		return

	_set_vital_bar(
		"base_exp",
		float(_current_player.current_exp) / maxf(1.0, float(_current_player.max_exp)),
		"%d / %d" % [_current_player.current_exp, _current_player.max_exp]
	)
	_set_vital_bar(
		"job_exp",
		float(_current_player.job_exp) / maxf(1.0, float(_current_player.max_job_exp)),
		"%d / %d" % [_current_player.job_exp, _current_player.max_job_exp]
	)
	_set_vital_bar(
		"hp",
		float(_current_player.hp) / maxf(1.0, float(_current_player.max_hp)),
		"%d / %d" % [_current_player.hp, _current_player.max_hp]
	)
	_set_vital_bar(
		"sp",
		float(_current_player.sp) / maxf(1.0, float(_current_player.max_sp)),
		"%d / %d" % [_current_player.sp, _current_player.max_sp]
	)


func _set_vital_bar(key: String, pct: float, text: String) -> void:
	var data: Dictionary = _vital_bars.get(key, {})
	if data.is_empty():
		return
	var fill: ColorRect = data.fill
	var track: Panel = data.track
	var width := maxf(track.size.x, track.custom_minimum_size.x)
	if width <= 1.0:
		width = 200.0
	fill.custom_minimum_size = Vector2(width, 8)
	if data.get("rtl", false):
		fill.pivot_offset = Vector2(width, 4.0)
	fill.scale.x = clampf(pct, 0.0, 1.0)
	data.label.text = text
