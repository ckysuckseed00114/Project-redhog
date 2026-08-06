class_name InventoryPanel
extends Panel

signal closed
signal slot_gui_input(slot_idx: int, event: InputEvent)
signal slot_mouse_entered(slot_idx: int)
signal slot_mouse_exited(slot_idx: int)

enum Tab { ALL, EQUIP, CONSUMABLE, OTHER }

const WIN_SIZE := GameConstants.WIN_INV_SIZE
const SLOT_SIZE := 48
const SLOT_GAP := 6
const COLS := GameConstants.INVENTORY_COLS

var inv_slots: Array = []

var _player: Player
var _capacity_label: Label
var _zeny_label: Label
var _tab_buttons: Array[Button] = []
var _active_tab: Tab = Tab.ALL
var _grid_root: Control


func _init() -> void:
	custom_minimum_size = WIN_SIZE
	size = WIN_SIZE
	z_index = 80 # 🌟 บังคับให้กระเป๋าอยู่หน้าสุดเสมอ
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_theme_stylebox_override("panel", UITheme.make_cozy_panel(UITheme.COZY_BG, UITheme.COZY_BORDER, 14, 2))
	_build()


func _build() -> void:
	var header := Panel.new()
	header.position = Vector2(0, 0)
	header.custom_minimum_size = Vector2(WIN_SIZE.x, 46)
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_theme_stylebox_override("panel", UITheme.make_cozy_panel(UITheme.COZY_HEADER, UITheme.COZY_BORDER, 14, 0))
	add_child(header)

	var title := Label.new()
	title.text = "🎒 กระเป๋า"
	title.position = Vector2(14, 12)
	UITheme.style_cozy_label(title, GameConstants.FONT_MD)
	header.add_child(title)

	var cap_pill := Panel.new()
	cap_pill.position = Vector2(148, 10)
	cap_pill.custom_minimum_size = Vector2(72, 26)
	cap_pill.add_theme_stylebox_override("panel", UITheme.make_cozy_pill())
	header.add_child(cap_pill)
	_capacity_label = Label.new()
	_capacity_label.position = Vector2(0, 4)
	_capacity_label.custom_minimum_size = Vector2(72, 18)
	_capacity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UITheme.style_cozy_label(_capacity_label, GameConstants.FONT_SM)
	cap_pill.add_child(_capacity_label)

	var zeny_pill := Panel.new()
	zeny_pill.position = Vector2(228, 10)
	zeny_pill.custom_minimum_size = Vector2(108, 26)
	zeny_pill.add_theme_stylebox_override("panel", UITheme.make_cozy_pill(UITheme.COZY_GOLD_BG))
	header.add_child(zeny_pill)
	_zeny_label = Label.new()
	_zeny_label.position = Vector2(0, 4)
	_zeny_label.custom_minimum_size = Vector2(108, 18)
	_zeny_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UITheme.style_cozy_label(_zeny_label, GameConstants.FONT_SM, UITheme.COZY_TEXT)
	zeny_pill.add_child(_zeny_label)

	var close_btn := Button.new()
	close_btn.text = "ปิด"
	close_btn.position = Vector2(WIN_SIZE.x - 58, 10)
	close_btn.custom_minimum_size = Vector2(44, 26)
	close_btn.add_theme_stylebox_override("normal", UITheme.make_cozy_button())
	close_btn.add_theme_stylebox_override("hover", UITheme.make_cozy_button())
	close_btn.add_theme_stylebox_override("pressed", UITheme.make_cozy_button())
	UITheme.style_cozy_label(close_btn, GameConstants.FONT_SM)
	close_btn.pressed.connect(func(): closed.emit())
	header.add_child(close_btn)

	var divider := Panel.new()
	divider.position = Vector2(12, 46)
	divider.custom_minimum_size = Vector2(WIN_SIZE.x - 24, 2)
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	divider.add_theme_stylebox_override("panel", UITheme.make_cozy_panel(UITheme.COZY_ACCENT, UITheme.COZY_ACCENT, 0, 0))
	add_child(divider)

	_build_tabs(54)
	_build_filter_bar(92)
	_build_grid(132)

func _build_tabs(y: float) -> void:
	var tabs := [
		[Tab.ALL, "ทั้งหมด"],
		[Tab.EQUIP, "สวมใส่"],
		[Tab.CONSUMABLE, "ใช้ได้"],
		[Tab.OTHER, "อื่นๆ"],
	]
	var x := 12.0
	for entry in tabs:
		var tab_id: Tab = entry[0]
		var tab_text: String = entry[1]
		var btn := Button.new()
		btn.text = tab_text
		btn.position = Vector2(x, y)
		btn.custom_minimum_size = Vector2(88, 28)
		btn.toggle_mode = true
		btn.button_pressed = tab_id == Tab.ALL
		btn.add_theme_stylebox_override("normal", UITheme.make_cozy_tab(false))
		btn.add_theme_stylebox_override("hover", UITheme.make_cozy_tab(false))
		btn.add_theme_stylebox_override("pressed", UITheme.make_cozy_tab(true))
		UITheme.style_cozy_label(btn, GameConstants.FONT_SM)
		btn.pressed.connect(_on_tab_pressed.bind(tab_id, btn))
		add_child(btn)
		_tab_buttons.append(btn)
		x += 94.0


func _build_filter_bar(y: float) -> void:
	var bar := Panel.new()
	bar.position = Vector2(12, y)
	bar.custom_minimum_size = Vector2(WIN_SIZE.x - 24, 30)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_theme_stylebox_override("panel", UITheme.make_cozy_panel(UITheme.COZY_BODY, UITheme.COZY_ACCENT, 8, 1))
	add_child(bar)
	var filter_lbl := Label.new()
	filter_lbl.text = "🔽 ตัวกรอง"
	filter_lbl.position = Vector2(10, 6)
	UITheme.style_cozy_label(filter_lbl, GameConstants.FONT_SM, UITheme.COZY_TEXT_MUTED, 0)
	bar.add_child(filter_lbl)


func _build_grid(y: float) -> void:
	_grid_root = Control.new()
	_grid_root.position = Vector2(12, y)
	var grid_w := COLS * SLOT_SIZE + (COLS - 1) * SLOT_GAP
	var rows := int(ceil(float(GameConstants.INVENTORY_SIZE) / float(COLS)))
	var grid_h := rows * SLOT_SIZE + (rows - 1) * SLOT_GAP
	_grid_root.custom_minimum_size = Vector2(grid_w, grid_h)
	add_child(_grid_root)

	for idx in range(GameConstants.INVENTORY_SIZE):
		var row := int(float(idx) / COLS)
		var col := idx % COLS
		var sx := col * (SLOT_SIZE + SLOT_GAP)
		var sy := row * (SLOT_SIZE + SLOT_GAP)

		var slot_bg := Panel.new()
		slot_bg.position = Vector2(sx, sy)
		slot_bg.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
		slot_bg.size = Vector2(SLOT_SIZE, SLOT_SIZE)
		slot_bg.add_theme_stylebox_override("panel", UITheme.make_cozy_slot())
		slot_bg.mouse_filter = Control.MOUSE_FILTER_STOP
		slot_bg.gui_input.connect(func(event: InputEvent): slot_gui_input.emit(idx, event))
		slot_bg.mouse_entered.connect(func(): slot_mouse_entered.emit(idx))
		slot_bg.mouse_exited.connect(func(): slot_mouse_exited.emit(idx))
		_grid_root.add_child(slot_bg)

		var equipped_badge := Panel.new()
		equipped_badge.position = Vector2(sx + 2, sy + 2)
		equipped_badge.custom_minimum_size = Vector2(14, 14)
		equipped_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		equipped_badge.visible = false
		equipped_badge.add_theme_stylebox_override(
			"panel",
			UITheme.make_cozy_panel(UITheme.COZY_ACCENT, UITheme.COZY_BORDER, 3, 1)
		)
		_grid_root.add_child(equipped_badge)
		var eq_lbl := Label.new()
		eq_lbl.text = "E"
		eq_lbl.custom_minimum_size = Vector2(14, 14)
		eq_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		eq_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		UITheme.style_cozy_label(eq_lbl, GameConstants.FONT_XS, Color.WHITE, 0)
		equipped_badge.add_child(eq_lbl)

		var icon := TextureRect.new()
		icon.position = Vector2(sx + 6, sy + 6)
		icon.custom_minimum_size = Vector2(SLOT_SIZE - 12, SLOT_SIZE - 12)
		icon.size = Vector2(SLOT_SIZE - 12, SLOT_SIZE - 12)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.visible = false
		_grid_root.add_child(icon)

		var count_bg := Panel.new()
		count_bg.position = Vector2(sx + SLOT_SIZE - 18, sy + SLOT_SIZE - 16)
		count_bg.custom_minimum_size = Vector2(16, 14)
		count_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		count_bg.visible = false
		count_bg.add_theme_stylebox_override(
			"panel",
			UITheme.make_cozy_panel(UITheme.COZY_COUNT_BADGE, UITheme.COZY_COUNT_BADGE, 7, 0)
		)
		_grid_root.add_child(count_bg)

		var count := Label.new()
		count.position = Vector2(sx + SLOT_SIZE - 18, sy + SLOT_SIZE - 16)
		count.custom_minimum_size = Vector2(16, 14)
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		UITheme.style_cozy_label(count, GameConstants.FONT_XS, Color.WHITE, 0)
		count.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_grid_root.add_child(count)

		inv_slots.append({"icon": icon, "count": count, "count_bg": count_bg, "equipped": equipped_badge, "bg": slot_bg})


func _on_tab_pressed(tab_id: Tab, btn: Button) -> void:
	_active_tab = tab_id
	for b in _tab_buttons:
		b.button_pressed = b == btn
		b.add_theme_stylebox_override("normal", UITheme.make_cozy_tab(b == btn))
	if _player:
		refresh(_player)


func refresh(player: Player) -> void:
	_player = player
	if _player == null:
		return

	var used := 0
	for item in _player.inventory:
		if item != null:
			used += 1
	_capacity_label.text = "%d/%d" % [used, GameConstants.INVENTORY_SIZE]
	_zeny_label.text = "G %s" % _format_zeny(_player.zeny)

	for i in range(inv_slots.size()):
		var slot: Dictionary = inv_slots[i]
		var icon: TextureRect = slot.icon
		var count_lbl: Label = slot.count
		var count_bg: Panel = slot.count_bg
		var eq_badge: Panel = slot.equipped

		icon.visible = false
		count_lbl.visible = false
		count_bg.visible = false
		eq_badge.visible = false

		if i >= _player.inventory.size():
			continue
		var item: Variant = _player.inventory[i]
		if item == null or not _item_matches_tab(item):
			continue

		icon.texture = TextureGenerator.get_texture(item.icon)
		icon.visible = true
		var stack := int(item.get("count", 1))
		if stack > 1:
			count_lbl.text = str(stack)
			count_lbl.visible = true
			count_bg.visible = true
		eq_badge.visible = _is_item_equipped(item)


func _item_matches_tab(item: Dictionary) -> bool:
	var item_type := str(item.get("type", ""))
	match _active_tab:
		Tab.ALL:
			return true
		Tab.EQUIP:
			return item_type in ["weapon", "helm", "armor", "garment", "shield", "boots", "acc1", "acc2"]
		Tab.CONSUMABLE:
			return item_type == "consumable" or ItemDatabase.is_potion(item)
		Tab.OTHER:
			return item_type not in ["weapon", "helm", "armor", "garment", "shield", "boots", "acc1", "acc2", "consumable"]
	return true


func _is_item_equipped(item: Dictionary) -> bool:
	if _player == null:
		return false
	for key in _player.equipment:
		var eq: Variant = _player.equipment[key]
		# 🌟 เช็คว่าไอเทมชิ้นนี้ในกระเป๋า คือชิ้นเดียวกับที่อยู่ในช่องสวมใส่จริงๆ หรือไม่
		if eq != null and eq == item:
			return true
	return false


static func _format_zeny(amount: int) -> String:
	var s := str(amount)
	if s.length() <= 3:
		return s
	var parts: PackedStringArray = []
	while s.length() > 3:
		parts.insert(0, s.substr(s.length() - 3, 3))
		s = s.substr(0, s.length() - 3)
	parts.insert(0, s)
	return ",".join(parts)
