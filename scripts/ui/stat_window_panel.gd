class_name StatWindowPanel
extends Panel

signal closed
signal stat_confirm_pressed(pending_stats: Dictionary)

const WIN_SIZE := Vector2(520, 380) # 🌟 เพิ่มความสูงเพื่อล็อกพื้นที่ให้ปุ่มยืนยันด้านล่าง

var _header_label: Label
var _stat_labels: Dictionary = {}
var _derived_labels: Dictionary = {}
var _plus_buttons: Dictionary = {}
var _radar_chart: StatRadarChart

var _pending_alloc: Dictionary = {}
var _current_player: Player
var _btn_confirm: Button
var _btn_cancel: Button
var _confirm_busy: bool = false

func _init() -> void:
	for k in StatRegistry.primary_keys():
		_pending_alloc[k] = 0
		
	custom_minimum_size = WIN_SIZE
	size = WIN_SIZE
	z_index = 80
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_theme_stylebox_override(
		"panel",
		UITheme.make_panel_style(Color8(0x10, 0x0e, 0x14, 0.97), UITheme.COZY_BORDER, 12, 2)
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
	body.add_theme_constant_override("separation", 6)
	root.add_child(body)

	body.add_child(_build_header_row())

	_header_label = Label.new()
	_header_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UITheme.style_label(_header_label, GameConstants.FONT_SM, UITheme.MUTED, 0)
	body.add_child(_header_label)

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 10)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(columns)

	columns.add_child(_build_primary_column())
	columns.add_child(_build_derived_column())
	
	# 🌟 แถบปุ่มยืนยันด้านล่าง ล็อกพื้นที่ไว้เสมอ
	var bottom_row := HBoxContainer.new()
	bottom_row.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom_row.add_theme_constant_override("separation", 16)
	body.add_child(bottom_row)
	
	_btn_cancel = Button.new()
	_btn_cancel.text = "ยกเลิก"
	_btn_cancel.custom_minimum_size = Vector2(100, 30)
	_btn_cancel.add_theme_stylebox_override("normal", UITheme.make_button_style(Color8(0xc0, 0x39, 0x2b)))
	_btn_cancel.pressed.connect(_on_cancel_pressed)
	bottom_row.add_child(_btn_cancel)
	
	_btn_confirm = Button.new()
	_btn_confirm.text = "ยืนยัน (Apply)"
	_btn_confirm.custom_minimum_size = Vector2(140, 30)
	_btn_confirm.add_theme_stylebox_override("normal", UITheme.make_button_style(Color8(0x27, 0xae, 0x60)))
	_btn_confirm.pressed.connect(_on_confirm_pressed)
	bottom_row.add_child(_btn_confirm)
	
	_set_buttons_active(false)


func _build_header_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 32)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var title_bar := PanelContainer.new()
	title_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_bar.add_theme_stylebox_override("panel", UITheme.make_header_bar(UITheme.GOLD))
	row.add_child(title_bar)

	var title := Label.new()
	title.text = "⚔️ Character Stats"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UITheme.style_label(title, GameConstants.FONT_MD, UITheme.GOLD, 1)
	title_bar.add_child(title)

	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.custom_minimum_size = Vector2(32, 32)
	close_btn.add_theme_stylebox_override("normal", UITheme.make_button_style(Color8(0xe7, 0x4c, 0x3c)))
	close_btn.add_theme_color_override("font_color", Color.WHITE)
	close_btn.pressed.connect(func() -> void: closed.emit())
	row.add_child(close_btn)

	return row


func _build_primary_column() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override(
		"panel",
		UITheme.make_panel_style(Color8(0x14, 0x12, 0x1a, 0.95), UITheme.COZY_BORDER, 8, 1)
	)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 6)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	margin.add_child(vbox)

	var section_title := Label.new()
	section_title.text = "Primary Stats"
	section_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UITheme.style_label(section_title, GameConstants.FONT_XS, UITheme.GOLD, 0)
	vbox.add_child(section_title)

	# 🌟 ใส่กราฟเรดาร์โดยตรง พร้อมล็อกขนาดชัดเจน
	_radar_chart = StatRadarChart.new()
	_radar_chart.custom_minimum_size = Vector2(110, 110)
	_radar_chart.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(_radar_chart)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 2)
	vbox.add_child(grid)

	var display_order = ["str", "int", "agi", "dex", "vit", "luk"]
	for key in display_order:
		grid.add_child(_make_stat_row(key))

	return panel


func _make_stat_row(key: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var name_lbl := Label.new()
	name_lbl.text = StatRegistry.get_label(key)
	name_lbl.custom_minimum_size = Vector2(26, 0)
	UITheme.style_label(name_lbl, GameConstants.FONT_XS, UITheme.GOLD, 0)
	row.add_child(name_lbl)

	var value_lbl := Label.new()
	value_lbl.text = "1"
	value_lbl.custom_minimum_size = Vector2(30, 0)
	value_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UITheme.style_label(value_lbl, GameConstants.FONT_XS, UITheme.GOLD, 1)
	row.add_child(value_lbl)
	_stat_labels[key] = value_lbl

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)

	var plus := Button.new()
	plus.text = "+"
	plus.custom_minimum_size = Vector2(20, 20)
	plus.add_theme_stylebox_override("normal", UITheme.make_button_style(Color8(0x27, 0xae, 0x60)))
	plus.add_theme_stylebox_override("disabled", UITheme.make_button_style(Color8(0x33, 0x33, 0x3a)))
	plus.add_theme_color_override("font_color", Color.WHITE)
	
	# 🌟 แก้บัคเชื่อมปุ่ม: ใช้ .bind(key) ส่งตัวแปรเข้าไปตรงๆ แทน lambda เพื่อไม่ให้บัคทับซ้อน
	plus.pressed.connect(_on_plus_pressed.bind(key))
	
	row.add_child(plus)
	_plus_buttons[key] = plus

	return row


func _build_derived_column() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(200, 0)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override(
		"panel",
		UITheme.make_panel_style(Color8(0x14, 0x12, 0x1a, 0.95), UITheme.COZY_BORDER, 8, 1)
	)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 6)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	margin.add_child(vbox)

	var section_title := Label.new()
	section_title.text = "Combat Stats"
	section_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UITheme.style_label(section_title, GameConstants.FONT_XS, UITheme.GOLD, 0)
	vbox.add_child(section_title)

	for key: String in StatRegistry.derived_keys():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var name_lbl := Label.new()
		name_lbl.text = StatRegistry.get_label(key)
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		UITheme.style_label(name_lbl, GameConstants.FONT_XS, UITheme.MUTED, 0)
		row.add_child(name_lbl)

		var val_lbl := Label.new()
		val_lbl.text = "0"
		val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		val_lbl.custom_minimum_size = Vector2(64, 0)
		UITheme.style_label(val_lbl, GameConstants.FONT_XS, Color8(0xff, 0xf8, 0xe7), 0)
		row.add_child(val_lbl)
		_derived_labels[key] = val_lbl

		vbox.add_child(row)

	return panel

# 🌟 ซ่อนโชว์ปุ่มยืนยันโดยใช้ Modulate (ไม่หดกรอบ UI)
func _set_buttons_active(active: bool) -> void:
	var alpha := 1.0 if active else 0.0
	var filter := Control.MOUSE_FILTER_STOP if active else Control.MOUSE_FILTER_IGNORE
	
	_btn_confirm.modulate.a = alpha
	_btn_confirm.mouse_filter = filter
	_btn_cancel.modulate.a = alpha
	_btn_cancel.mouse_filter = filter

# 🌟 ฟังก์ชันจัดการกดบวกสเตตัสชั่วคราว (ยังไม่เซฟ)
func _on_plus_pressed(key: String) -> void:
	if _current_player == null: return
	
	var total_pending: int = 0
	for k in _pending_alloc.keys():
		total_pending += int(_pending_alloc[k])
		
	if _current_player.stat_points - total_pending > 0:
		_pending_alloc[key] = int(_pending_alloc[key]) + 1
		_refresh_display()

# 🌟 เมื่อกดกากบาทยกเลิก
func _on_cancel_pressed() -> void:
	for k in _pending_alloc.keys():
		_pending_alloc[k] = 0
	_refresh_display()

func _on_confirm_pressed() -> void:
	if _confirm_busy:
		return
	_confirm_busy = true
	_btn_confirm.disabled = true
	_btn_cancel.disabled = true
	stat_confirm_pressed.emit(_pending_alloc.duplicate())
	for k in _pending_alloc.keys():
		_pending_alloc[k] = 0
	_refresh_display()


func release_confirm_lock() -> void:
	_confirm_busy = false
	_btn_confirm.disabled = false
	_btn_cancel.disabled = false
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

	var total_pending: int = 0
	for k in _pending_alloc.keys():
		total_pending += int(_pending_alloc[k])
		
	var remain_pts: int = _current_player.stat_points - total_pending
	_header_label.text = "Points: %d  |  Zeny: %d" % [remain_pts, _current_player.zeny]

	var radar_stats: Dictionary = {}
	for key: String in StatRegistry.primary_keys():
		var base_val: int = _current_player.get_stat(key)
		var pending_val: int = _pending_alloc.get(key, 0)
		var display_val: int = base_val + pending_val
		
		if pending_val > 0:
			_stat_labels[key].text = "%d (+%d)" % [base_val, pending_val]
			_stat_labels[key].add_theme_color_override("font_color", Color8(0x2e, 0xcc, 0x71))
		else:
			_stat_labels[key].text = str(base_val)
			_stat_labels[key].add_theme_color_override("font_color", UITheme.GOLD)
			
		radar_stats[key] = display_val

	if _radar_chart:
		_radar_chart.set_stats(radar_stats)

	var can_spend: bool = (remain_pts > 0) and not _current_player.is_dead
	
	for key: String in _plus_buttons:
		_plus_buttons[key].disabled = not can_spend

	for key: String in StatRegistry.derived_keys():
		var val: Variant = StatRegistry.get_derived(_current_player, key)
		var lbl: Label = _derived_labels[key]
		match key:
			"aspd":
				lbl.text = "%.2f" % float(val)
			"mspd":
				lbl.text = "%.1f" % float(val)
			"hp":
				lbl.text = "%d / %d" % [_current_player.hp, _current_player.max_hp]
			_:
				lbl.text = str(val)
				
	_set_buttons_active(total_pending > 0)
