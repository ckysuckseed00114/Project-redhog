extends CanvasLayer

const FADE_DURATION := 0.35

var _overlay: ColorRect
var _label: Label
var _tween: Tween
var _auto_fade_out: bool = false


func _ready() -> void:
	layer = 150
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

	_overlay = ColorRect.new()
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.color = Color(0, 0, 0, 0)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_overlay)

	_label = Label.new()
	_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", GameConstants.FONT_LG)
	_label.add_theme_color_override("font_color", Color.WHITE)
	_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_label.add_theme_constant_override("outline_size", 2)
	_label.text = ""
	add_child(_label)

	if not get_tree().scene_changed.is_connected(_on_scene_changed):
		get_tree().scene_changed.connect(_on_scene_changed)


func update_text(new_text: String) -> void:
	if _label:
		_label.text = new_text


func fade_in(loading_text: String = "Loading...") -> void:
	update_text(loading_text)
	visible = true
	_kill_tween()
	_tween = create_tween()
	_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_tween.tween_property(_overlay, "color:a", 1.0, FADE_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await _tween.finished


func fade_out() -> void:
	_kill_tween()
	_tween = create_tween()
	_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_tween.tween_property(_overlay, "color:a", 0.0, FADE_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await _tween.finished
	visible = false
	update_text("")


func prepare_fade_out_on_load() -> void:
	_auto_fade_out = true


func cancel_pending_fade_out() -> void:
	_auto_fade_out = false


func _on_scene_changed() -> void:
	if not _auto_fade_out:
		return
	_auto_fade_out = false
	call_deferred("_fade_out_after_scene_ready")


func _fade_out_after_scene_ready() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await fade_out()


func _kill_tween() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = null
