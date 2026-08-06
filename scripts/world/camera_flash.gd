extends ColorRect

var _tween: Tween


func do_flash(flash_color: Color, duration: float) -> void:
	color = flash_color
	visible = true
	modulate = Color(1, 1, 1, flash_color.a)
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 0.0, duration)
	_tween.tween_callback(func(): visible = false)
