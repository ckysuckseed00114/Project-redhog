class_name BossSpawnPanel
extends Panel

const ROW_H := 68

var _list: VBoxContainer
var _scroll: ScrollContainer


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_stylebox_override("panel", UITheme.make_panel_style(Color(0.08, 0.05, 0.05, 0.94), Color8(0xff, 0x66, 0x22), 8, 2))


func _ready() -> void:
	_build_content()
	if BossManager:
		BossManager.timers_updated.connect(_on_timers_updated)
	if WorldSyncManager:
		WorldSyncManager.boss_state_changed.connect(refresh)
	refresh()


func _build_content() -> void:
	_scroll = ScrollContainer.new()
	_scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	_scroll.offset_left = 8
	_scroll.offset_top = 8
	_scroll.offset_right = -8
	_scroll.offset_bottom = -8
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_scroll)

	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 6)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_list)


func refresh() -> void:
	_on_timers_updated(WorldSyncManager.get_boss_entries())


func _on_timers_updated(entries: Array) -> void:
	for child in _list.get_children():
		child.queue_free()
	if entries.is_empty():
		_list.add_child(_make_empty_row())
		return
	for entry in entries:
		if entry is Dictionary:
			_list.add_child(_make_boss_row(entry))


func _make_empty_row() -> Label:
	var lbl := Label.new()
	lbl.text = "ไม่มี World Boss"
	UITheme.style_label(lbl, GameConstants.FONT_SM, UITheme.MUTED, 1)
	return lbl


func _make_boss_row(entry: Dictionary) -> Panel:
	var row := Panel.new()
	row.custom_minimum_size = Vector2(0, ROW_H - 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_stylebox_override(
		"panel",
		UITheme.make_panel_style(Color(0.05, 0.04, 0.06, 0.96), Color8(0xff, 0x66, 0x22), 6, 1)
	)

	var map_lbl := Label.new()
	map_lbl.text = str(entry.get("map_label", "???"))
	map_lbl.position = Vector2(10, 6)
	UITheme.style_label(map_lbl, GameConstants.FONT_XS, UITheme.GOLD if entry.get("is_current_map", false) else UITheme.MUTED, 1)
	row.add_child(map_lbl)

	var boss_lbl := Label.new()
	boss_lbl.text = str(entry.get("boss_name", "Boss"))
	boss_lbl.position = Vector2(10, 22)
	UITheme.style_label(boss_lbl, GameConstants.FONT_SM, Color.WHITE, 1)
	row.add_child(boss_lbl)

	var timer_lbl := Label.new()
	timer_lbl.position = Vector2(10, 42)
	var alive: bool = entry.get("alive", false)
	if alive:
		timer_lbl.text = "ALIVE!"
		UITheme.style_label(timer_lbl, GameConstants.FONT_MD, Color8(0xff, 0x44, 0x44), 2)
	else:
		var seconds := float(entry.get("seconds_left", 0.0))
		var mins := int(seconds / 60.0)
		var secs := int(seconds) % 60
		timer_lbl.text = "เกิดใน %02d:%02d" % [mins, secs]
		UITheme.style_label(timer_lbl, GameConstants.FONT_SM, Color.WHITE, 1)
	row.add_child(timer_lbl)

	return row
