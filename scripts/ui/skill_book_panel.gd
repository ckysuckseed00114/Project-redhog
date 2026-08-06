class_name SkillBookPanel
extends Panel

signal closed

const WIN_SIZE := Vector2(520, 320)
const CARD_W := 92
const ICON_SIZE := 56

var _player: Player
var _jp_label: Label
var _job_label: Label
var _scroll: ScrollContainer
var _row: HBoxContainer


func _init() -> void:
	custom_minimum_size = WIN_SIZE
	size = WIN_SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_theme_stylebox_override(
		"panel",
		UITheme.make_cozy_panel(UITheme.COZY_BG, UITheme.COZY_BORDER, 14, 2)
	)
	_build()


func _build() -> void:
	var header := Panel.new()
	header.position = Vector2(0, 0)
	header.custom_minimum_size = Vector2(WIN_SIZE.x, 40)
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_theme_stylebox_override(
		"panel",
		UITheme.make_cozy_panel(UITheme.COZY_HEADER, UITheme.COZY_BORDER, 14, 0)
	)
	add_child(header)

	var title := Label.new()
	title.text = "🐾 สมุดสกิล"
	title.position = Vector2(14, 10)
	UITheme.style_cozy_label(title, GameConstants.FONT_MD)
	header.add_child(title)

	var close_btn := Button.new()
	close_btn.text = "ปิด"
	close_btn.position = Vector2(WIN_SIZE.x - 58, 8)
	close_btn.custom_minimum_size = Vector2(44, 26)
	close_btn.add_theme_stylebox_override("normal", UITheme.make_cozy_button())
	close_btn.add_theme_stylebox_override("hover", UITheme.make_cozy_button())
	close_btn.add_theme_stylebox_override("pressed", UITheme.make_cozy_button())
	UITheme.style_cozy_label(close_btn, GameConstants.FONT_SM)
	close_btn.pressed.connect(func(): closed.emit())
	header.add_child(close_btn)

	var toolbar := Panel.new()
	toolbar.position = Vector2(12, 46)
	toolbar.custom_minimum_size = Vector2(WIN_SIZE.x - 24, 28)
	toolbar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toolbar.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	add_child(toolbar)

	_job_label = Label.new()
	_job_label.position = Vector2(4, 4)
	_job_label.text = "สายอาชีพ"
	UITheme.style_cozy_label(_job_label, GameConstants.FONT_SM)
	toolbar.add_child(_job_label)

	_jp_label = Label.new()
	_jp_label.position = Vector2(WIN_SIZE.x - 120, 2)
	_jp_label.custom_minimum_size = Vector2(96, 22)
	_jp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UITheme.style_cozy_label(_jp_label, GameConstants.FONT_SM, UITheme.COZY_ACCENT, 0)
	toolbar.add_child(_jp_label)

	var body := Panel.new()
	body.position = Vector2(12, 78)
	body.custom_minimum_size = Vector2(WIN_SIZE.x - 24, 168)
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_theme_stylebox_override(
		"panel",
		UITheme.make_cozy_panel(UITheme.COZY_BODY, UITheme.COZY_BORDER, 10, 1)
	)
	add_child(body)

	_scroll = ScrollContainer.new()
	_scroll.position = Vector2(8, 8)
	_scroll.custom_minimum_size = Vector2(WIN_SIZE.x - 40, 152)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(_scroll)

	_row = HBoxContainer.new()
	_row.add_theme_constant_override("separation", 10)
	_scroll.add_child(_row)

	var footer := Label.new()
	footer.position = Vector2(14, 252)
	footer.custom_minimum_size = Vector2(WIN_SIZE.x - 28, 56)
	footer.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	footer.text = "● เรียนแล้ว   ○ ปลดได้   ◌ ล็อค\nกด + เพื่ออัปเกรดด้วย Job Points | คลิกค้างแล้วลากสกิลไปแถบสกิล | คลิกขวาช่องเพื่อถอด"
	UITheme.style_cozy_label(footer, GameConstants.FONT_XS, UITheme.COZY_TEXT_MUTED, 0)
	add_child(footer)


func refresh(player: Player) -> void:
	_player = player
	if _player == null:
		return
	_jp_label.text = "%d JP" % _player.job_points
	_job_label.text = "สายอาชีพ — %s" % ClassDatabase.get_display_name(_player.current_job)
	for child in _row.get_children():
		child.queue_free()
	var skill_ids := SkillDatabase.get_job_skill_ids(_player.current_job)
	for i in range(skill_ids.size()):
		var skill_id := skill_ids[i]
		_row.add_child(_make_skill_card(skill_id))
		if i < skill_ids.size() - 1:
			_row.add_child(_make_connector())


func set_scroll_locked(locked: bool) -> void:
	if _scroll == null:
		return
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED if locked else ScrollContainer.SCROLL_MODE_AUTO


func _make_connector() -> Control:
	var line := Control.new()
	line.custom_minimum_size = Vector2(18, ICON_SIZE)
	var dash := Label.new()
	dash.text = "- - -"
	dash.position = Vector2(0, 20)
	UITheme.style_cozy_label(dash, GameConstants.FONT_XS, UITheme.COZY_TEXT_MUTED, 0)
	line.add_child(dash)
	return line


func _make_skill_card(skill_id: String) -> Control:
	var def := SkillDatabase.get_skill(skill_id)
	var card := VBoxContainer.new()
	card.custom_minimum_size = Vector2(CARD_W, 130)
	card.add_theme_constant_override("separation", 4)

	var unlocked := SkillDatabase.is_unlocked(_player, skill_id)
	var level := _player.get_skill_level(skill_id)
	var max_lv := int(def.get("max_level", 5))
	var learned := level > 0

	var icon_wrap := Panel.new()
	icon_wrap.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
	var icon_bg := UITheme.COZY_SKILL_LOCKED if not unlocked else UITheme.COZY_SKILL_ICON
	icon_wrap.add_theme_stylebox_override("panel", UITheme.make_cozy_panel(icon_bg, UITheme.COZY_BORDER, 8, 2))
	
	# 🌟 โค้ดที่เพิ่มเข้ามา: ตรวจจับการลากเมาส์
	icon_wrap.mouse_filter = Control.MOUSE_FILTER_STOP
	icon_wrap.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if learned:
				var ui = get_tree().get_first_node_in_group("ui")
				if ui and ui.has_method("_begin_skill_book_press"):
					ui._begin_skill_book_press(skill_id, event.global_position)
					get_viewport().set_input_as_handled()
	)
	
	card.add_child(icon_wrap)

	var abbr := Label.new()
	abbr.text = str(def.get("icon_label", "?"))
	abbr.position = Vector2(0, 16)
	abbr.custom_minimum_size = Vector2(ICON_SIZE, 24)
	abbr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UITheme.style_cozy_label(abbr, GameConstants.FONT_MD, Color.WHITE if learned else UITheme.COZY_TEXT_MUTED, 0)
	icon_wrap.add_child(abbr)

	var lv_lbl := Label.new()
	lv_lbl.text = "%d/%d" % [level, max_lv]
	lv_lbl.position = Vector2(ICON_SIZE - 34, ICON_SIZE - 16)
	lv_lbl.custom_minimum_size = Vector2(30, 14)
	UITheme.style_cozy_label(lv_lbl, GameConstants.FONT_XS, Color.WHITE, 0)
	icon_wrap.add_child(lv_lbl)

	if not unlocked:
		var lock := Label.new()
		lock.text = "🔒"
		lock.position = Vector2(18, 14)
		lock.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon_wrap.add_child(lock)
	elif level < max_lv: # 🌟 แก้ไข: ลบคำว่า learned ออก ปุ่มจะได้โชว์ตั้งแต่เลเวล 0
		var up_btn := Button.new()
		up_btn.text = "+"
		up_btn.position = Vector2(ICON_SIZE - 18, -4)
		up_btn.custom_minimum_size = Vector2(20, 20)
		up_btn.add_theme_stylebox_override("normal", UITheme.make_cozy_panel(UITheme.COZY_ACCENT, UITheme.COZY_BORDER, 6, 1))
		
		# 🌟 ปรับ UX ใหม่: ถ้าไม่มีแต้ม JP ให้ปุ่มจางลงและกดไม่ได้
		if _player.job_points <= 0:
			up_btn.disabled = true
			up_btn.modulate.a = 0.5
		else:
			# ถ้ามีแต้ม ถึงจะเชื่อมต่อสัญญาณให้กดอัพได้
			up_btn.pressed.connect(_on_upgrade.bind(skill_id))
			
		icon_wrap.add_child(up_btn)

	var name_lbl := Label.new()
	name_lbl.text = str(def.get("name", skill_id))
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.custom_minimum_size = Vector2(CARD_W, 16)
	UITheme.style_cozy_label(name_lbl, GameConstants.FONT_XS, UITheme.COZY_TEXT, 0)
	card.add_child(name_lbl)

	var tag_panel := Panel.new()
	tag_panel.custom_minimum_size = Vector2(CARD_W, 18)
	var type_tag := str(def.get("type_tag", ""))
	var tag_color := SkillDatabase.get_type_color(type_tag)
	tag_panel.add_theme_stylebox_override(
		"panel",
		UITheme.make_cozy_panel(Color(tag_color.r, tag_color.g, tag_color.b, 0.92), tag_color, 6, 1)
	)
	card.add_child(tag_panel)
	var tag := Label.new()
	tag.text = SkillDatabase.get_type_label(type_tag)
	tag.position = Vector2(0, 1)
	tag.custom_minimum_size = Vector2(CARD_W, 16)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UITheme.style_cozy_label(tag, GameConstants.FONT_XS, Color.WHITE, 0)
	tag_panel.add_child(tag)

	return card


func _on_upgrade(skill_id: String) -> void:
	if _player and _player.upgrade_skill(skill_id):
		refresh(_player)
