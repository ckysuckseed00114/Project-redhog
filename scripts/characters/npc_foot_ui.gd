class_name NpcFootUi
extends RefCounted

const MIN_BOX_W := 116.0
const BOX_H := 34.0
const NAME_H := 16.0
const PAD := 8.0


static func get_box_size(display_name: String, hint_text: String, show_hint: bool) -> Vector2:
	var font := ThemeDB.fallback_font
	var font_size := GameConstants.FONT_XS
	var name_w := font.get_string_size(display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var content_w := name_w
	var box_h := NAME_H + PAD
	if show_hint:
		var hint_w := font.get_string_size(hint_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		content_w = maxf(content_w, hint_w)
		box_h = BOX_H
	return Vector2(maxf(MIN_BOX_W, content_w + PAD), box_h)


static func draw_at(
	canvas: CanvasItem,
	pos: Vector2,
	scale: Vector2,
	display_name: String,
	hint_text: String,
	show_hint: bool
) -> void:
	var box := get_box_size(display_name, hint_text, show_hint)
	var half_w := box.x * 0.5
	var rect := Rect2(-half_w, 0.0, box.x, box.y)

	canvas.draw_set_transform(pos, 0.0, scale)
	canvas.draw_rect(rect, Color(0.05, 0.05, 0.08, 0.88))
	canvas.draw_rect(rect, UITheme.GOLD, false, 1.0)

	var font := ThemeDB.fallback_font
	var font_size := GameConstants.FONT_XS
	canvas.draw_string(
		font,
		Vector2(-half_w, 14),
		display_name,
		HORIZONTAL_ALIGNMENT_CENTER,
		int(box.x),
		font_size,
		UITheme.GOLD
	)
	if show_hint:
		canvas.draw_string(
			font,
			Vector2(-half_w, 30),
			hint_text,
			HORIZONTAL_ALIGNMENT_CENTER,
			int(box.x),
			font_size,
			Color8(0x66, 0xcc, 0xff)
		)
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
