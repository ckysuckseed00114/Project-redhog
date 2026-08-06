class_name EquipmentPanel
extends Panel

signal closed
signal slot_gui_input(slot_key: String, event: InputEvent)
signal slot_mouse_entered(slot_key: String)
signal slot_mouse_exited(slot_key: String)

const WIN_SIZE := GameConstants.WIN_EQUIP_SIZE
const SLOT_SIZE := 48

var equip_slots: Dictionary = {}

var _player: Player
var _slot_bgs: Dictionary = {}


func _init() -> void:
	custom_minimum_size = WIN_SIZE
	size = WIN_SIZE
	z_index = 80 # 🌟 บังคับให้สวมใส่อยู่หน้าสุดเสมอ
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
	title.text = "⚔️ สวมใส่"
	title.position = Vector2(14, 12)
	UITheme.style_cozy_label(title, GameConstants.FONT_MD)
	header.add_child(title)

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

	var body := Panel.new()
	body.position = Vector2(12, 58)
	body.custom_minimum_size = Vector2(WIN_SIZE.x - 24, WIN_SIZE.y - 70) # 🌟 ปรับระยะหักลบเพื่อให้กรอบบอดี้กระชับพอดีกับช่องสวมใส่แถวล่างสุด
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_theme_stylebox_override("panel", UITheme.make_cozy_panel(UITheme.COZY_BODY, UITheme.COZY_BORDER, 10, 1))
	add_child(body)

	var slot_defs := [
		{"key": "helm", "label": "หมวก", "pos": Vector2(68, 16)},
		{"key": "weapon", "label": "อาวุธ", "pos": Vector2(8, 84)},
		{"key": "armor", "label": "เกราะ", "pos": Vector2(68, 84)},
		{"key": "shield", "label": "โล่", "pos": Vector2(128, 84)},
		{"key": "garment", "label": "ผ้าคลุม", "pos": Vector2(68, 152)},
		{"key": "acc1", "label": "เครื่อง 1", "pos": Vector2(8, 220)},
		{"key": "boots", "label": "รองเท้า", "pos": Vector2(68, 220)},
		{"key": "acc2", "label": "เครื่อง 2", "pos": Vector2(128, 220)},
	]
	for def in slot_defs:
		_add_equip_slot(body, def.key, def.label, def.pos)

func _add_equip_slot(parent: Control, slot_key: String, label_text: String, pos: Vector2) -> void:
	var name_lbl := Label.new()
	name_lbl.text = label_text
	name_lbl.position = pos + Vector2(0, -16)
	name_lbl.custom_minimum_size = Vector2(SLOT_SIZE, 14)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UITheme.style_cozy_label(name_lbl, GameConstants.FONT_XS, UITheme.COZY_TEXT_MUTED, 0)
	parent.add_child(name_lbl)

	var slot_bg := Panel.new()
	slot_bg.position = pos
	slot_bg.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
	slot_bg.size = Vector2(SLOT_SIZE, SLOT_SIZE)
	slot_bg.add_theme_stylebox_override("panel", UITheme.make_cozy_slot())
	slot_bg.mouse_filter = Control.MOUSE_FILTER_STOP
	slot_bg.gui_input.connect(func(event: InputEvent): slot_gui_input.emit(slot_key, event))
	slot_bg.mouse_entered.connect(func(): slot_mouse_entered.emit(slot_key))
	slot_bg.mouse_exited.connect(func(): slot_mouse_exited.emit(slot_key))
	parent.add_child(slot_bg)
	_slot_bgs[slot_key] = slot_bg

	var icon := TextureRect.new()
	icon.position = pos + Vector2(6, 6)
	icon.custom_minimum_size = Vector2(SLOT_SIZE - 12, SLOT_SIZE - 12)
	icon.size = Vector2(SLOT_SIZE - 12, SLOT_SIZE - 12)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.visible = false
	parent.add_child(icon)
	equip_slots[slot_key] = icon


func refresh(player: Player) -> void:
	_player = player
	if _player == null:
		return
	for key in equip_slots:
		var icon: TextureRect = equip_slots[key]
		var equipped_item = _player.equipment.get(key)
		if equipped_item:
			icon.texture = TextureGenerator.get_texture(equipped_item.icon)
			icon.visible = true
		else:
			icon.visible = false


func get_slot_global_pos(slot_key: String) -> Vector2:
	var bg: Panel = _slot_bgs.get(slot_key)
	if bg and bg.is_inside_tree():
		return bg.global_position
	return global_position
