class_name QuestLogPanel
extends Panel

signal collapse_changed(is_collapsed: bool)

const EXPANDED_SIZE := Vector2(280, 220)
const COLLAPSED_SIZE := Vector2(280, 36)

var _player: Player
var _collapsed := false
var _visible_panel := false
var _body: Control
var _list: VBoxContainer
var _empty_label: Label
var _count_label: Label
var _collapse_btn: Button


func _init() -> void:
	custom_minimum_size = COLLAPSED_SIZE
	size = COLLAPSED_SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	add_theme_stylebox_override("panel", UITheme.make_cozy_panel(UITheme.COZY_BG, UITheme.COZY_BORDER, 10, 2))
	_build()


func _build() -> void:
	var header := Panel.new()
	header.name = "Header"
	header.position = Vector2(0, 0)
	header.custom_minimum_size = Vector2(EXPANDED_SIZE.x, 36)
	header.mouse_filter = Control.MOUSE_FILTER_STOP
	header.add_theme_stylebox_override("panel", UITheme.make_cozy_panel(UITheme.COZY_HEADER, UITheme.COZY_BORDER, 10, 0))
	header.gui_input.connect(_on_header_gui_input)
	add_child(header)

	var title := Label.new()
	title.text = "📜 เควส"
	title.position = Vector2(10, 8)
	UITheme.style_cozy_label(title, GameConstants.FONT_SM)
	header.add_child(title)

	_count_label = Label.new()
	_count_label.position = Vector2(72, 8)
	_count_label.custom_minimum_size = Vector2(120, 18)
	UITheme.style_cozy_label(_count_label, GameConstants.FONT_XS, UITheme.COZY_TEXT_MUTED, 0)
	header.add_child(_count_label)

	_collapse_btn = Button.new()
	_collapse_btn.text = "−"
	_collapse_btn.position = Vector2(EXPANDED_SIZE.x - 68, 6)
	_collapse_btn.custom_minimum_size = Vector2(24, 24)
	_collapse_btn.add_theme_stylebox_override("normal", UITheme.make_cozy_button())
	_collapse_btn.pressed.connect(_toggle_collapse)
	header.add_child(_collapse_btn)

	var hide_btn := Button.new()
	hide_btn.text = "×"
	hide_btn.position = Vector2(EXPANDED_SIZE.x - 38, 6)
	hide_btn.custom_minimum_size = Vector2(24, 24)
	hide_btn.add_theme_stylebox_override("normal", UITheme.make_cozy_button())
	hide_btn.pressed.connect(hide_panel)
	header.add_child(hide_btn)

	_body = Panel.new()
	_body.position = Vector2(8, 40)
	_body.custom_minimum_size = Vector2(EXPANDED_SIZE.x - 16, EXPANDED_SIZE.y - 48)
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body.add_theme_stylebox_override("panel", UITheme.make_cozy_panel(UITheme.COZY_BODY, UITheme.COZY_BORDER, 8, 1))
	add_child(_body)

	var scroll := ScrollContainer.new()
	scroll.position = Vector2(6, 6)
	scroll.custom_minimum_size = Vector2(EXPANDED_SIZE.x - 28, EXPANDED_SIZE.y - 60)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_body.add_child(scroll)

	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 6)
	scroll.add_child(_list)

	_empty_label = Label.new()
	_empty_label.text = "ยังไม่มีเควสที่กำลังทำ\nไปที่ Quest Board เพื่อรับเควส"
	_empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_empty_label.custom_minimum_size = Vector2(EXPANDED_SIZE.x - 40, 60)
	UITheme.style_cozy_label(_empty_label, GameConstants.FONT_XS, UITheme.COZY_TEXT_MUTED, 0)
	_list.add_child(_empty_label)


func show_panel() -> void:
	_visible_panel = true
	visible = true
	if _collapsed:
		_set_collapsed(false)


func hide_panel() -> void:
	_visible_panel = false
	visible = false


func toggle_panel() -> void:
	if _visible_panel:
		hide_panel()
	else:
		show_panel()


func is_panel_visible() -> bool:
	return _visible_panel and visible


func is_collapsed() -> bool:
	return _collapsed


func refresh(player: Player) -> void:
	_player = player
	for child in _list.get_children():
		child.queue_free()

	if _player == null:
		_count_label.text = "(0)"
		_list.add_child(_empty_label)
		return

	var active_count := _player.active_quests.size()
	_count_label.text = "(%d)" % active_count

	if active_count == 0:
		_empty_label = Label.new()
		_empty_label.text = "ยังไม่มีเควสที่กำลังทำ\nไปที่ Quest Board เพื่อรับเควส"
		_empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_empty_label.custom_minimum_size = Vector2(EXPANDED_SIZE.x - 40, 60)
		UITheme.style_cozy_label(_empty_label, GameConstants.FONT_XS, UITheme.COZY_TEXT_MUTED, 0)
		_list.add_child(_empty_label)
		return

	for qid in _player.active_quests.keys():
		_list.add_child(_make_quest_row(str(qid)))


func _make_quest_row(quest_id: String) -> Control:
	# 💡 ลบตัวแปร def ออกตรงนี้ เพราะไม่ได้ใช้งาน
	var data: Dictionary = _player.active_quests[quest_id]
	var row := Panel.new()
	row.custom_minimum_size = Vector2(EXPANDED_SIZE.x - 40, 56)
	row.add_theme_stylebox_override("panel", UITheme.make_cozy_panel(UITheme.COZY_SLOT, UITheme.COZY_SLOT_BORDER, 6, 1))

	var name_lbl := Label.new()
	name_lbl.text = QuestDatabase.get_display_name(quest_id)
	name_lbl.position = Vector2(8, 4)
	name_lbl.custom_minimum_size = Vector2(220, 16)
	UITheme.style_cozy_label(name_lbl, GameConstants.FONT_SM, UITheme.COZY_ACCENT if data.get("completed") else UITheme.COZY_TEXT, 0)
	row.add_child(name_lbl)

	var prog_lbl := Label.new()
	prog_lbl.text = QuestService.get_progress_text(_player, quest_id)
	prog_lbl.position = Vector2(8, 22)
	prog_lbl.custom_minimum_size = Vector2(220, 14)
	UITheme.style_cozy_label(prog_lbl, GameConstants.FONT_XS, UITheme.COZY_TEXT_MUTED, 0)
	row.add_child(prog_lbl)

	var obj_lbl := Label.new()
	obj_lbl.text = QuestDatabase.get_objective_summary(quest_id)
	obj_lbl.position = Vector2(8, 38)
	obj_lbl.custom_minimum_size = Vector2(220, 14)
	UITheme.style_cozy_label(obj_lbl, GameConstants.FONT_XS, UITheme.COZY_TEXT_MUTED, 0)
	row.add_child(obj_lbl)

	return row


func _toggle_collapse() -> void:
	_set_collapsed(not _collapsed)


func _set_collapsed(collapsed: bool) -> void:
	_collapsed = collapsed
	_body.visible = not collapsed
	_collapse_btn.text = "+" if collapsed else "−"
	var target_size := COLLAPSED_SIZE if collapsed else EXPANDED_SIZE
	custom_minimum_size = target_size
	size = target_size
	collapse_changed.emit(collapsed)


func _on_header_gui_input(event: InputEvent) -> void:
	if _collapsed and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_set_collapsed(false)
