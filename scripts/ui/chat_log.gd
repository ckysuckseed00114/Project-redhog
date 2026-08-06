class_name ChatLog
extends Control

signal message_submitted(text: String)
signal layout_changed()

const CHANNELS := [
	{"id": "all", "label": "ทุกคน"},
	{"id": "map", "label": "แผน"},
	{"id": "party", "label": "ปาร์ตี้"},
	{"id": "guild", "label": "กิลด์"},
	{"id": "whisper", "label": "กระซิบ"},
	{"id": "system", "label": "ระบบ"},
]

const MAX_STORED := 80

const TAB_ACTIVE_BG := Color8(0x4a, 0x2d, 0x72)
const TAB_ACTIVE_BORDER := Color8(0x9b, 0x7b, 0xcc)
const TAB_INACTIVE_BG := Color8(0x22, 0x1e, 0x28)
const TAB_INACTIVE_BORDER := Color8(0x44, 0x3a, 0x55)
const TAB_ACTIVE_TEXT := Color8(0xff, 0xf0, 0xd0)
const TAB_INACTIVE_TEXT := Color8(0xb8, 0xa8, 0xc8)
const BODY_BG := Color(0.06, 0.05, 0.10, 0.88)
const BODY_BORDER := Color8(0x8b, 0x5c, 0xf6)
const TS_COLOR := "#888888"
const NAME_COLOR := "#f1c40f"
const MSG_COLOR := "#ffffff"
const SYS_COLOR := "#aaaaaa"
const PILL_BG := "#2a2535"

var _active_channel := "all"
var _collapsed := false
var _messages: Array[Dictionary] = []
var _tab_buttons: Array[Button] = []
var _tab_bar: HBoxContainer
var _toggle_btn: Button
var _body_panel: PanelContainer
var _message_rt: RichTextLabel
var _input_line: LineEdit
var _root_vbox: VBoxContainer

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP

func _ready() -> void:
	add_to_group("ui")
	_build_ui()
	add_welcome_message()

func _build_ui() -> void:
	_root_vbox = VBoxContainer.new()
	_root_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root_vbox.add_theme_constant_override("separation", 0)
	_root_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root_vbox)

	_tab_bar = HBoxContainer.new()
	_tab_bar.add_theme_constant_override("separation", 2)
	_tab_bar.custom_minimum_size = Vector2(0, GameConstants.CHAT_TAB_HEIGHT)
	for ch in CHANNELS:
		var btn := Button.new()
		btn.text = str(ch.get("label", ""))
		btn.focus_mode = Control.FOCUS_NONE
		btn.custom_minimum_size = Vector2(52, GameConstants.CHAT_TAB_HEIGHT)
		btn.add_theme_font_size_override("font_size", GameConstants.FONT_XS)
		btn.pressed.connect(_on_tab_pressed.bind(str(ch.get("id", ""))))
		_tab_bar.add_child(btn)
		_tab_buttons.append(btn)

	var tab_spacer := Control.new()
	tab_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tab_bar.add_child(tab_spacer)

	_toggle_btn = Button.new()
	_toggle_btn.text = "▼"
	_toggle_btn.focus_mode = Control.FOCUS_NONE
	_toggle_btn.custom_minimum_size = Vector2(28, GameConstants.CHAT_TAB_HEIGHT)
	_toggle_btn.add_theme_font_size_override("font_size", GameConstants.FONT_SM)
	_toggle_btn.add_theme_color_override("font_color", UITheme.GOLD)
	_style_toggle_button(_toggle_btn)
	_toggle_btn.pressed.connect(_on_toggle_pressed)
	_tab_bar.add_child(_toggle_btn)
	_root_vbox.add_child(_tab_bar)

	_body_panel = PanelContainer.new()
	_body_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body_panel.add_theme_stylebox_override("panel", _make_body_style())
	_root_vbox.add_child(_body_panel)

	var body_vbox := VBoxContainer.new()
	body_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	body_vbox.add_theme_constant_override("separation", 0)
	body_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body_panel.add_child(body_vbox)

	_message_rt = RichTextLabel.new()
	_message_rt.bbcode_enabled = true
	_message_rt.fit_content = false
	_message_rt.scroll_active = true
	_message_rt.scroll_following = true
	_message_rt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message_rt.custom_minimum_size = Vector2(0, GameConstants.CHAT_LOG_HEIGHT)
	_message_rt.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_message_rt.add_theme_font_size_override("normal_font_size", GameConstants.FONT_XS)
	_message_rt.add_theme_constant_override("line_separation", 3)
	_message_rt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body_vbox.add_child(_message_rt)

	var input_wrap := MarginContainer.new()
	input_wrap.add_theme_constant_override("margin_left", 6)
	input_wrap.add_theme_constant_override("margin_right", 6)
	input_wrap.add_theme_constant_override("margin_bottom", 4)
	body_vbox.add_child(input_wrap)

	_input_line = LineEdit.new()
	_input_line.custom_minimum_size = Vector2(0, GameConstants.CHAT_INPUT_HEIGHT)
	_input_line.placeholder_text = "Enter เพื่อแชท..."
	_input_line.max_length = 120
	_input_line.add_theme_font_size_override("font_size", GameConstants.FONT_XS)
	_input_line.add_theme_stylebox_override("normal", _make_input_style())
	_input_line.add_theme_stylebox_override("focus", _make_input_style(true))
	_input_line.text_submitted.connect(_on_text_submitted)
	input_wrap.add_child(_input_line)

	_refresh_tab_styles()
	_apply_collapsed_state()

func is_collapsed() -> bool:
	return _collapsed


func apply_layout(rect: Rect2) -> void:
	position = rect.position
	custom_minimum_size = rect.size
	size = rect.size


func add_welcome_message() -> void:
	_append_message("welcome", "[color=%s][i]ยินดีต้อนรับสู่ RH: Redhog! คลิกพื้นเพื่อเดิน กด [F] คุยกับ NPC[/i][/color]" % MSG_COLOR)

func expand_panel() -> void:
	if _collapsed:
		_collapsed = false
		_apply_collapsed_state()
		layout_changed.emit()


func is_input_focused() -> bool:
	return _input_line != null and _input_line.has_focus()

func focus_input() -> void:
	if _input_line and not _collapsed:
		_input_line.grab_focus()

func release_input() -> void:
	if _input_line:
		_input_line.release_focus()

func add_log(new_text: String, color: Color = Color.WHITE) -> void:
	var ts := _format_time()
	var hex := color.to_html(false)
	var escaped := _escape_bbcode(new_text)
	var italic := _is_muted_color(color)
	var line := "[color=%s]%s[/color]  " % [TS_COLOR, ts]
	if italic:
		line += "[color=%s][i]%s[/i][/color]" % [SYS_COLOR, escaped]
	else:
		line += "[color=%s]%s[/color]" % [hex, escaped]
	_append_message("system", line)

func add_chat_message(sender: String, text: String, channel: String = "map") -> void:
	var ts := _format_time()
	var ch_label := _channel_label(channel)
	var line := "[color=%s]%s[/color]  " % [TS_COLOR, ts]
	line += "[bgcolor=%s][color=%s] %s [/color][/bgcolor] " % [PILL_BG, MSG_COLOR, ch_label]
	line += "[color=%s]%s:[/color] [color=%s]%s[/color]" % [
		NAME_COLOR, _escape_bbcode(sender), MSG_COLOR, _escape_bbcode(text)
	]
	_append_message(channel, line)

func _append_message(channel: String, bbcode: String) -> void:
	_messages.append({"channel": channel, "bbcode": bbcode})
	while _messages.size() > MAX_STORED:
		_messages.pop_front()
	_refresh_display()

func _refresh_display() -> void:
	if _message_rt == null:
		return
	var lines: PackedStringArray = []
	for msg in _messages:
		if _should_show(str(msg.get("channel", ""))):
			lines.append(str(msg.get("bbcode", "")))
	_message_rt.text = "\n".join(lines)
	call_deferred("_scroll_chat_to_bottom")

func _scroll_chat_to_bottom() -> void:
	if _message_rt:
		_message_rt.scroll_to_line(maxi(0, _message_rt.get_line_count() - 1))

func _should_show(channel: String) -> bool:
	if _active_channel == "all":
		return true
	if channel == "welcome":
		return false
	return channel == _active_channel

func _on_tab_pressed(channel_id: String) -> void:
	_active_channel = channel_id
	_refresh_tab_styles()
	_refresh_display()

func _on_toggle_pressed() -> void:
	_collapsed = not _collapsed
	_apply_collapsed_state()

func _apply_collapsed_state() -> void:
	_body_panel.visible = not _collapsed
	_toggle_btn.text = "▲" if _collapsed else "▼"
	if _collapsed and _input_line:
		_input_line.release_focus()
	layout_changed.emit()

func _refresh_tab_styles() -> void:
	for i in _tab_buttons.size():
		var btn := _tab_buttons[i]
		var ch_id := str(CHANNELS[i].get("id", ""))
		var active := ch_id == _active_channel
		btn.add_theme_stylebox_override("normal", _make_tab_style(active))
		btn.add_theme_stylebox_override("hover", _make_tab_style(active))
		btn.add_theme_stylebox_override("pressed", _make_tab_style(active))
		btn.add_theme_color_override("font_color", TAB_ACTIVE_TEXT if active else TAB_INACTIVE_TEXT)
		btn.add_theme_color_override("font_hover_color", TAB_ACTIVE_TEXT if active else TAB_INACTIVE_TEXT)

func _make_tab_style(active: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	if active:
		style.bg_color = TAB_ACTIVE_BG
		style.border_color = TAB_ACTIVE_BORDER
		style.set_border_width_all(1)
		style.border_width_top = 2
		style.border_width_bottom = 0
	else:
		style.bg_color = TAB_INACTIVE_BG
		style.border_color = TAB_INACTIVE_BORDER
		style.set_border_width_all(1)
		style.border_width_bottom = 0
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.content_margin_top = 3
	style.content_margin_bottom = 3
	return style

func _make_body_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = BODY_BG
	style.border_color = BODY_BORDER
	style.border_width_top = 2
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 6
	style.content_margin_bottom = 2
	return style

func _make_input_style(focused: bool = false) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color8(0x14, 0x12, 0x1c, 0.95)
	style.border_color = BODY_BORDER if focused else Color8(0x44, 0x3a, 0x55)
	style.set_border_width_all(1)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.content_margin_left = 6
	style.content_margin_right = 6
	return style

func _style_toggle_button(btn: Button) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = TAB_INACTIVE_BG
	style.border_color = TAB_INACTIVE_BORDER
	style.set_border_width_all(1)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_stylebox_override("hover", style)
	btn.add_theme_stylebox_override("pressed", style)

func _format_time() -> String:
	var dt := Time.get_datetime_dict_from_system()
	return "%02d:%02d" % [int(dt.get("hour", 0)), int(dt.get("minute", 0))]

func _channel_label(channel_id: String) -> String:
	for ch in CHANNELS:
		if str(ch.get("id", "")) == channel_id:
			return str(ch.get("label", channel_id))
	return channel_id

func _escape_bbcode(text: String) -> String:
	return text.replace("[", "&#91;")

func _is_muted_color(color: Color) -> bool:
	return color.is_equal_approx(UITheme.MUTED)

func _on_text_submitted(text: String) -> void:
	var msg := text.strip_edges()
	_input_line.clear()
	release_input()
	if msg.is_empty():
		return
	message_submitted.emit(msg)
