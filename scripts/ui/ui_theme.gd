class_name UITheme
extends RefCounted

const PANEL_BG := Color(0.07, 0.07, 0.11, 0.92)
const PANEL_BORDER := Color8(0x7f, 0x8c, 0x8d)
const GOLD := Color8(0xf1, 0xc4, 0x0f)
const MUTED := Color8(0xbb, 0xbb, 0xcc)
const SLOT_BG := Color8(0x22, 0x22, 0x32)

# Cozy window theme — อิงสีหลอด HP (fill #9be844 / track #1a1a22)
const HP_FILL := Color8(0x9b, 0xe8, 0x44)
const HP_TRACK := Color8(0x1a, 0x1a, 0x22)
const COZY_BG := Color8(0x11, 0x11, 0x11) # ดำสนิท
const COZY_HEADER := Color8(0x1a, 0x1a, 0x1a) # ดำเทา
const COZY_BODY := Color8(0x15, 0x15, 0x15) # ดำล้วน
const COZY_BORDER := Color8(0xd4, 0xaf, 0x37) # ทองคำ
const COZY_TEXT := Color8(0xff, 0xf8, 0xe7)
const COZY_TEXT_MUTED := Color8(0x88, 0x88, 0x88)
const COZY_TAB_ACTIVE := Color8(0x3a, 0x2f, 0x0f) # ดำอมทอง
const COZY_TAB_INACTIVE := Color8(0x22, 0x22, 0x22)
const COZY_SLOT := Color8(0x18, 0x18, 0x18)
const COZY_SLOT_BORDER := Color8(0xa8, 0x89, 0x2b) # ทองหม่น
const COZY_ACCENT := Color8(0xd4, 0xaf, 0x37) # ทองคำ
const COZY_GOLD_BG := Color8(0x2d, 0x24, 0x0b) # ดำอมทอง
const COZY_PILL_BG := Color8(0x1e, 0x1e, 0x1e)
const COZY_COUNT_BADGE := Color8(0x00, 0x00, 0x00) # ดำล้วน
const COZY_BTN := Color8(0x1e, 0x1e, 0x1e)
const COZY_SKILL_ICON := Color8(0x2d, 0x24, 0x0b)
const COZY_SKILL_LOCKED := Color8(0x11, 0x11, 0x11)

static var _game_font: Font


static func game_font() -> Font:
	if _game_font == null:
		_game_font = load("res://Prompt-Light.ttf")
	return _game_font


static func apply_font(control: Control) -> void:
	var font := game_font()
	if font:
		control.add_theme_font_override("font", font)


static func apply_fonts_recursive(root: Node) -> void:
	if root is Control:
		apply_font(root)
	for child in root.get_children():
		apply_fonts_recursive(child)


static func style_label(control: Control, font_size: int, color: Color = Color.WHITE, outline: int = 2) -> void:
	apply_font(control)
	control.add_theme_font_size_override("font_size", font_size)
	control.add_theme_color_override("font_color", color)
	control.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	control.add_theme_constant_override("outline_size", outline)


static func make_panel_style(bg: Color, border: Color, radius: int = 8, border_w: int = 1) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(border_w)
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.shadow_color = Color(0, 0, 0, 0.35)
	style.shadow_size = 4
	return style


static func make_button_style(bg: Color, border: Color = Color8(0x99, 0x99, 0xaa)) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(1)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.content_margin_top = 2
	style.content_margin_bottom = 2
	return style


static func make_header_bar(accent: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(accent.r, accent.g, accent.b, 0.22)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 0
	style.corner_radius_bottom_right = 0
	style.content_margin_left = 10
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	return style


static func make_slot_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = SLOT_BG
	style.border_color = Color8(0x55, 0x55, 0x77)
	style.set_border_width_all(1)
	style.corner_radius_top_left = 3
	style.corner_radius_top_right = 3
	style.corner_radius_bottom_left = 3
	style.corner_radius_bottom_right = 3
	return style


static func make_cozy_panel(bg: Color, border: Color, radius: int = 12, border_w: int = 2) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(border_w)
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	return style


static func make_cozy_slot() -> StyleBoxFlat:
	return make_cozy_panel(COZY_SLOT, COZY_SLOT_BORDER, 8, 2)


static func make_cozy_tab(active: bool) -> StyleBoxFlat:
	var bg := COZY_TAB_ACTIVE if active else COZY_TAB_INACTIVE
	return make_cozy_panel(bg, COZY_BORDER, 8, 2 if active else 1)


static func make_cozy_button() -> StyleBoxFlat:
	return make_cozy_panel(COZY_BTN, COZY_BORDER, 8, 2)


static func make_cozy_pill(bg: Color = COZY_PILL_BG) -> StyleBoxFlat:
	return make_cozy_panel(bg, COZY_BORDER, 10, 1)


static func style_cozy_label(control: Control, font_size: int, color: Color = COZY_TEXT, outline: int = 0) -> void:
	style_label(control, font_size, color, outline)
