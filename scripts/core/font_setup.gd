extends Node
## บังคับใช้ Prompt-Light เป็น default/fallback font — จำเป็นบน Web (WASM ไม่มี system font ไทย)

const GAME_FONT: FontFile = preload("res://Prompt-Light.ttf")


func _enter_tree() -> void:
	_apply()


func _apply() -> void:
	if GAME_FONT == null:
		push_warning("FontSetup: Prompt-Light.ttf not found")
		return

	ThemeDB.fallback_font = GAME_FONT
	ThemeDB.fallback_font_size = 16

	var root := get_tree().root
	var theme := root.theme
	if theme == null:
		theme = Theme.new()
		root.theme = theme
	if theme.default_font == null:
		theme.default_font = GAME_FONT
