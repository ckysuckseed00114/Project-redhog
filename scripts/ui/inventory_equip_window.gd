class_name InventoryEquipWindow
extends Panel

signal closed

@warning_ignore("unused_signal")
signal slot_mouse_entered(slot_idx: int)

@warning_ignore("unused_signal")
signal slot_mouse_exited(slot_idx: int)

@warning_ignore("unused_signal")
signal equip_slot_mouse_entered(slot_key: String)

@warning_ignore("unused_signal")
signal equip_slot_mouse_exited(slot_key: String)

const WIN_SIZE := Vector2(820, 520)
const SLOT_SIZE := 44
const SLOT_GAP := 4
const COLS := GameConstants.INVENTORY_COLS

const COLOR_PANEL := Color(0.07, 0.07, 0.1, 0.95)
const COLOR_COLUMN := Color(0.05, 0.05, 0.08, 0.88)
const COLOR_GOLD := Color8(0xd4, 0xaf, 0x37)
const COLOR_TEXT := Color8(0xf0, 0xec, 0xe4)
const COLOR_MUTED := Color8(0x99, 0x9a, 0xa8)
const COLOR_SLOT := Color8(0x15, 0x15, 0x1e, 0.92)
const COLOR_SLOT_HOVER := Color8(0x1c, 0x1c, 0x28, 0.96)
const COLOR_DROP_OK := Color8(0x2a, 0x55, 0x3a, 0.96)

const LEFT_SLOTS: Array[String] = ["helm", "armor", "garment", "boots"]
const RIGHT_SLOTS: Array[String] = ["weapon", "shield", "acc1", "acc2"]

var inv_slots: Array = []
var equip_slots: Dictionary = {}

var _player: Player
var _capacity_label: Label
var _zeny_label: Label
var _preview: TextureRect
var _equip_drag_slots: Dictionary = {}


func _init() -> void:
	custom_minimum_size = WIN_SIZE
	size = WIN_SIZE
	clip_contents = true
	z_index = 80
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_theme_stylebox_override("panel", UITheme.make_panel_style(COLOR_PANEL, COLOR_GOLD, 8, 2))
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
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(body)

	body.add_child(_build_title_bar())

	var split := HBoxContainer.new()
	split.add_theme_constant_override("separation", 10)
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(split)

	split.add_child(_build_equipment_column())
	split.add_child(_build_inventory_column())


func _build_title_bar() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 32)

	var title_wrap := PanelContainer.new()
	title_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_wrap.add_theme_stylebox_override("panel", UITheme.make_header_bar(COLOR_GOLD))
	row.add_child(title_wrap)

	var title := Label.new()
	title.text = "Inventory & Equipment"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UITheme.style_label(title, GameConstants.FONT_MD, COLOR_GOLD, 1)
	title_wrap.add_child(title)

	var close_btn := _make_action_button("✕", Color8(0x6b, 0x22, 0x22), Vector2(28, 28))
	close_btn.pressed.connect(func() -> void: closed.emit())
	row.add_child(close_btn)
	return row


func _build_equipment_column() -> Control:
	var wrapper := PanelContainer.new()
	wrapper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrapper.size_flags_vertical = Control.SIZE_EXPAND_FILL
	wrapper.size_flags_stretch_ratio = 0.4
	wrapper.clip_contents = true
	wrapper.add_theme_stylebox_override("panel", UITheme.make_panel_style(COLOR_COLUMN, Color8(0x55, 0x45, 0x22, 0.65), 6, 1)) # 👈 แก้ wrap เป็น wrapper

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	wrapper.add_child(margin)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(row)

	row.add_child(_build_equip_slot_column(LEFT_SLOTS))
	row.add_child(_build_character_preview())
	row.add_child(_build_equip_slot_column(RIGHT_SLOTS))
	return wrapper


func _build_character_preview() -> Control:
	var center := VBoxContainer.new()
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var frame := PanelContainer.new()
	frame.custom_minimum_size = Vector2(112, 140)
	frame.add_theme_stylebox_override(
		"panel",
		UITheme.make_panel_style(Color8(0x0c, 0x0c, 0x12, 0.85), Color8(0xd4, 0xaf, 0x37, 0.35), 4, 1)
	)
	center.add_child(frame)

	_preview = TextureRect.new()
	_preview.custom_minimum_size = Vector2(96, 120)
	_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	frame.add_child(_preview)
	return center


func _build_equip_slot_column(keys: Array[String]) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	for key: String in keys:
		col.add_child(_make_equip_slot(key))
	return col


func _make_equip_slot(slot_key: String) -> VBoxContainer:
	var block := VBoxContainer.new()
	block.add_theme_constant_override("separation", 2)

	var name_lbl := Label.new()
	name_lbl.text = _equip_label(slot_key)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UITheme.style_label(name_lbl, GameConstants.FONT_XS, COLOR_MUTED, 0)
	block.add_child(name_lbl)

	var slot := _ItemSlot.new()
	slot.kind = _ItemSlot.Kind.EQUIP
	slot.equip_key = slot_key
	slot.window = self
	slot.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
	block.add_child(slot)

	var icon := TextureRect.new()
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon.offset_left = 5
	icon.offset_top = 5
	icon.offset_right = -5
	icon.offset_bottom = -5
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.visible = false
	slot.add_child(icon)
	equip_slots[slot_key] = icon
	_equip_drag_slots[slot_key] = slot
	return block


func _build_inventory_column() -> Control:
	var wrapper := PanelContainer.new()
	wrapper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrapper.size_flags_vertical = Control.SIZE_EXPAND_FILL
	wrapper.size_flags_stretch_ratio = 0.6
	wrapper.clip_contents = true
	wrapper.add_theme_stylebox_override("panel", UITheme.make_panel_style(COLOR_COLUMN, Color8(0x55, 0x45, 0x22, 0.65), 6, 1)) # 👈 แก้ wrap เป็น wrapper

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.clip_contents = true
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

	var header := HBoxContainer.new()
	vbox.add_child(header)

	var bag_title := Label.new()
	bag_title.text = "Bag"
	bag_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UITheme.style_label(bag_title, GameConstants.FONT_XS, COLOR_MUTED, 0)
	header.add_child(bag_title)

	_zeny_label = Label.new()
	_zeny_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	UITheme.style_label(_zeny_label, GameConstants.FONT_SM, COLOR_GOLD, 1)
	header.add_child(_zeny_label)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.clip_contents = true
	vbox.add_child(scroll)

	var grid := GridContainer.new()
	grid.columns = COLS
	grid.add_theme_constant_override("h_separation", SLOT_GAP)
	grid.add_theme_constant_override("v_separation", SLOT_GAP)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(grid)

	for idx in range(GameConstants.INVENTORY_SIZE):
		grid.add_child(_make_inv_slot(idx))

	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 8)
	vbox.add_child(footer)

	_capacity_label = Label.new()
	_capacity_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UITheme.style_label(_capacity_label, GameConstants.FONT_XS, COLOR_MUTED, 0)
	footer.add_child(_capacity_label)

	var sort_btn := _make_action_button("Sort", Color8(0x1c, 0x1c, 0x28), Vector2(72, 28))
	sort_btn.pressed.connect(_on_sort_pressed)
	footer.add_child(sort_btn)

	var close_btn := _make_action_button("Close", Color8(0x2a, 0x2a, 0x34), Vector2(72, 28))
	close_btn.pressed.connect(func() -> void: closed.emit())
	footer.add_child(close_btn)
	return wrapper


func _make_inv_slot(idx: int) -> Control:
	var slot_root := Control.new()
	slot_root.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)

	var slot := _ItemSlot.new()
	slot.kind = _ItemSlot.Kind.INVENTORY
	slot.inv_index = idx
	slot.window = self
	slot.set_anchors_preset(Control.PRESET_FULL_RECT)
	slot_root.add_child(slot)

	var icon := TextureRect.new()
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon.offset_left = 4
	icon.offset_top = 4
	icon.offset_right = -4
	icon.offset_bottom = -4
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.visible = false
	slot_root.add_child(icon)

	var count_bg := Panel.new()
	count_bg.custom_minimum_size = Vector2(16, 13)
	count_bg.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	count_bg.offset_left = -18
	count_bg.offset_top = -14
	count_bg.visible = false
	count_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	count_bg.add_theme_stylebox_override("panel", UITheme.make_panel_style(Color8(0x08, 0x08, 0x0c, 0.95), COLOR_GOLD.darkened(0.4), 2, 1))
	slot_root.add_child(count_bg)

	var count := Label.new()
	count.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	count.offset_left = -18
	count.offset_top = -14
	count.custom_minimum_size = Vector2(16, 13)
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	count.visible = false
	UITheme.style_label(count, GameConstants.FONT_XS, COLOR_TEXT, 0)
	slot_root.add_child(count)

	var equipped_badge := Panel.new()
	equipped_badge.custom_minimum_size = Vector2(12, 12)
	equipped_badge.position = Vector2(2, 2)
	equipped_badge.visible = false
	equipped_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	equipped_badge.add_theme_stylebox_override("panel", UITheme.make_panel_style(COLOR_GOLD.darkened(0.35), COLOR_GOLD, 2, 1))
	slot_root.add_child(equipped_badge)

	inv_slots.append({"icon": icon, "count": count, "count_bg": count_bg, "equipped": equipped_badge, "bg": slot, "slot": slot})
	return slot_root


func _slot_style(hover: bool, drop_ok: bool = false) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	if drop_ok:
		style.bg_color = COLOR_DROP_OK
	elif hover:
		style.bg_color = COLOR_SLOT_HOVER
	else:
		style.bg_color = COLOR_SLOT
	style.border_color = Color(COLOR_GOLD, 0.9 if drop_ok else (0.85 if hover else 0.45))
	style.set_border_width_all(1)
	style.corner_radius_top_left = 2
	style.corner_radius_top_right = 2
	style.corner_radius_bottom_left = 2
	style.corner_radius_bottom_right = 2
	return style


func _make_action_button(text: String, bg: Color, btn_size: Vector2) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = btn_size
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_stylebox_override("normal", UITheme.make_button_style(bg, COLOR_GOLD.darkened(0.35)))
	btn.add_theme_stylebox_override("hover", UITheme.make_button_style(bg.lightened(0.08), COLOR_GOLD))
	btn.add_theme_stylebox_override("pressed", UITheme.make_button_style(bg.darkened(0.1), COLOR_GOLD.darkened(0.2)))
	btn.add_theme_color_override("font_color", COLOR_TEXT)
	btn.add_theme_font_size_override("font_size", GameConstants.FONT_XS)
	return btn


func _equip_label(slot_key: String) -> String:
	match slot_key:
		"helm": return "Helm"
		"armor": return "Armor"
		"garment": return "Garment"
		"boots": return "Boots"
		"weapon": return "Weapon"
		"shield": return "Shield"
		"acc1": return "Acc 1"
		"acc2": return "Acc 2"
	return slot_key.to_upper()


func refresh(player: Player) -> void:
	_player = player
	if _player == null:
		return
	_update_preview()
	_refresh_equipment()
	_refresh_inventory()


func _update_preview() -> void:
	if _preview == null or _player == null:
		return
	var tex := PlayerSpriteLoader.load_preview(_player.current_job, GlobalData.player_gender)
	if tex:
		_preview.texture = tex


func _refresh_equipment() -> void:
	for key in equip_slots:
		var icon: TextureRect = equip_slots[key]
		var equipped_item = _player.equipment.get(key)
		if equipped_item:
			icon.texture = TextureGenerator.get_texture(equipped_item.icon)
			icon.visible = true
		else:
			icon.visible = false


func _refresh_inventory() -> void:
	var used := 0
	for item in _player.inventory:
		if item != null:
			used += 1
	_capacity_label.text = "Capacity: %d / %d" % [used, GameConstants.INVENTORY_SIZE]
	_zeny_label.text = "%s Z" % _format_zeny(_player.zeny)

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
		if item == null:
			continue

		icon.texture = TextureGenerator.get_texture(item.icon)
		icon.visible = true
		var stack := int(item.get("count", 1))
		if stack > 1:
			count_lbl.text = str(stack)
			count_lbl.visible = true
			count_bg.visible = true
		eq_badge.visible = _is_item_equipped(item)


func _is_item_equipped(item: Dictionary) -> bool:
	if _player == null:
		return false
	for key in _player.equipment:
		if _player.equipment[key] != null and _player.equipment[key] == item:
			return true
	return false


func get_slot_global_pos(slot_key: String) -> Vector2:
	var slot: _ItemSlot = _equip_drag_slots.get(slot_key)
	if slot and slot.is_inside_tree():
		return slot.global_position
	return global_position


func get_inv_slot_global_pos(idx: int) -> Vector2:
	if idx >= 0 and idx < inv_slots.size():
		var slot: _ItemSlot = inv_slots[idx].get("slot")
		if slot:
			return slot.global_position
	return global_position


func _get_item_for_slot(slot: _ItemSlot) -> Variant:
	if _player == null:
		return null
	if slot.kind == _ItemSlot.Kind.INVENTORY:
		if slot.inv_index < 0 or slot.inv_index >= _player.inventory.size():
			return null
		return _player.inventory[slot.inv_index]
	if slot.equip_key != "":
		return _player.equipment.get(slot.equip_key)
	return null


func _make_drag_payload(slot: _ItemSlot, item: Dictionary) -> Dictionary:
	if slot.kind == _ItemSlot.Kind.INVENTORY:
		return {"source": "inventory", "index": slot.inv_index, "item": item}
	return {"source": "equip", "key": slot.equip_key, "item": item}


func _make_drag_preview(item: Dictionary) -> Control:
	var preview := Panel.new()
	preview.custom_minimum_size = Vector2(36, 36)
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview.add_theme_stylebox_override("panel", _slot_style(false))
	var icon := TextureRect.new()
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon.offset_left = 4
	icon.offset_top = 4
	icon.offset_right = -4
	icon.offset_bottom = -4
	icon.texture = TextureGenerator.get_texture(str(item.get("icon", "")))
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	preview.add_child(icon)
	return preview


func _item_matches_equip_slot(item: Dictionary, slot_key: String) -> bool:
	return str(item.get("type", "")) == slot_key


func can_accept_drop(target: _ItemSlot, data: Variant) -> bool:
	if _player == null or data == null or typeof(data) != TYPE_DICTIONARY:
		return false
	var item: Dictionary = data.get("item", {})
	if item.is_empty():
		return false
	var source: String = str(data.get("source", ""))

	if target.kind == _ItemSlot.Kind.EQUIP:
		if not _item_matches_equip_slot(item, target.equip_key):
			return false
		if source == "inventory":
			return true
		if source == "equip":
			return str(data.get("key", "")) != target.equip_key
		return false

	if target.kind == _ItemSlot.Kind.INVENTORY:
		if source == "inventory":
			return int(data.get("index", -1)) != target.inv_index
		if source == "equip":
			var slot_key: String = str(data.get("key", ""))
			var inv_item = _player.inventory[target.inv_index]
			return inv_item == null or _item_matches_equip_slot(inv_item, slot_key)
	return false


func apply_drop(target: _ItemSlot, data: Dictionary) -> void:
	if _player == null:
		return
	var source: String = str(data.get("source", ""))
	var ok := false

	if target.kind == _ItemSlot.Kind.EQUIP:
		if source == "inventory":
			ok = _player.equip_inventory_to_slot(int(data.get("index", -1)), target.equip_key)
		elif source == "equip":
			ok = _player.swap_equipment_slots(str(data.get("key", "")), target.equip_key)
	elif target.kind == _ItemSlot.Kind.INVENTORY:
		if source == "inventory":
			ok = _player.swap_inventory_slots(int(data.get("index", -1)), target.inv_index)
		elif source == "equip":
			ok = _player.move_equipment_to_inventory(str(data.get("key", "")), target.inv_index)

	if ok:
		refresh(_player)


func _on_sort_pressed() -> void:
	if _player == null:
		return
	var items: Array = []
	for item in _player.inventory:
		if item != null:
			items.append(item)
	items.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ta := str(a.get("type", ""))
		var tb := str(b.get("type", ""))
		if ta != tb:
			return ta < tb
		return str(a.get("name", "")) < str(b.get("name", ""))
	)
	_player.inventory.fill(null)
	for i in range(items.size()):
		if i < _player.inventory.size():
			_player.inventory[i] = items[i]
	_player.inventory_changed.emit()
	refresh(_player)


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


class _ItemSlot extends Panel:
	enum Kind { INVENTORY, EQUIP }

	var window: InventoryEquipWindow
	var kind: Kind = Kind.INVENTORY
	var inv_index: int = -1
	var equip_key: String = ""
	var _hover := false
	var _drop_hint := false


	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		add_theme_stylebox_override("panel", window._slot_style(false))
		mouse_entered.connect(_on_mouse_entered)
		mouse_exited.connect(_on_mouse_exited)


	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
			if window._player == null:
				return
			if kind == Kind.EQUIP and equip_key != "":
				if window._player.unequip_item(equip_key):
					window.refresh(window._player)
			elif kind == Kind.INVENTORY and inv_index >= 0:
				var item = window._player.inventory[inv_index]
				if item != null and ItemDatabase.is_potion(item):
					window._player.use_item_from_inventory(inv_index)
				elif item != null:
					window._player.equip_item_from_inventory(inv_index)
			get_viewport().set_input_as_handled()


	func _get_drag_data(_at_position: Vector2) -> Variant:
		if window == null:
			return null
		var item = window._get_item_for_slot(self)
		if item == null:
			return null
		var payload := window._make_drag_payload(self, item)
		set_drag_preview(window._make_drag_preview(item))
		return payload


	func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
		if window == null:
			return false
		var ok := window.can_accept_drop(self, data)
		_set_drop_hint(ok)
		return ok


	func _drop_data(_at_position: Vector2, data: Variant) -> void:
		_set_drop_hint(false)
		if window and data is Dictionary:
			window.apply_drop(self, data)


	func _notification(what: int) -> void:
		if what == NOTIFICATION_DRAG_END:
			_set_drop_hint(false)


	func _on_mouse_entered() -> void:
		_hover = true
		_apply_style()
		if window:
			if kind == Kind.INVENTORY:
				window.slot_mouse_entered.emit(inv_index)
			else:
				window.equip_slot_mouse_entered.emit(equip_key)


	func _on_mouse_exited() -> void:
		_hover = false
		_drop_hint = false
		_apply_style()
		if window:
			if kind == Kind.INVENTORY:
				window.slot_mouse_exited.emit(inv_index)
			else:
				window.equip_slot_mouse_exited.emit(equip_key)


	func _set_drop_hint(active: bool) -> void:
		_drop_hint = active
		_apply_style()


	func _apply_style() -> void:
		if window:
			add_theme_stylebox_override("panel", window._slot_style(_hover, _drop_hint))
