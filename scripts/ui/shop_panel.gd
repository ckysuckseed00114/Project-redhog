class_name ShopPanel
extends Panel

signal closed

var _player: Player
var _shop_id: String = ""
var _mode: String = "buy"
var _zeny_label: Label
var _title_label: Label
var _list: VBoxContainer
var _mode_buy: Button
var _mode_sell: Button
var _ui: UIManager


func setup(ui: UIManager, player: Player, shop_id: String, shop_name: String, mode: String = "buy") -> void:
	_ui = ui
	_player = player
	_shop_id = shop_id
	custom_minimum_size = Vector2(460, 360)
	add_theme_stylebox_override("panel", UITheme.make_panel_style(Color(0.08, 0.08, 0.12, 0.97), Color8(0xff, 0xd7, 0x00), 10, 2))
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_if_needed()
	_title_label.text = shop_name
	_set_mode(mode)


func _build_if_needed() -> void:
	if _list != null:
		return
	var header := Panel.new()
	header.position = Vector2(0, 0)
	header.custom_minimum_size = Vector2(460, 36)
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_theme_stylebox_override("panel", UITheme.make_header_bar(Color8(0xff, 0xd7, 0x00)))
	add_child(header)

	_title_label = Label.new()
	_title_label.position = Vector2(14, 8)
	_title_label.add_theme_font_size_override("font_size", GameConstants.FONT_LG)
	_title_label.add_theme_color_override("font_color", Color8(0xff, 0xd7, 0x00))
	add_child(_title_label)

	_zeny_label = Label.new()
	_zeny_label.position = Vector2(14, 44)
	UITheme.style_label(_zeny_label, GameConstants.FONT_SM, Color8(0xff, 0xd7, 0x00), 2)
	add_child(_zeny_label)

	_mode_buy = _make_tab_button("ซื้อ", Vector2(14, 68), true)
	_mode_buy.pressed.connect(func(): _set_mode("buy"))
	add_child(_mode_buy)

	_mode_sell = _make_tab_button("ขาย", Vector2(96, 68), false)
	_mode_sell.pressed.connect(func(): _set_mode("sell"))
	add_child(_mode_sell)

	var close_btn := Button.new()
	close_btn.text = "X"
	close_btn.position = Vector2(418, 6)
	close_btn.custom_minimum_size = Vector2(32, 26)
	close_btn.add_theme_stylebox_override("normal", UITheme.make_button_style(Color8(0xe7, 0x4c, 0x3c)))
	close_btn.pressed.connect(_on_close)
	add_child(close_btn)

	var scroll := ScrollContainer.new()
	scroll.position = Vector2(12, 104)
	scroll.custom_minimum_size = Vector2(436, 244)
	add_child(scroll)

	_list = VBoxContainer.new()
	_list.custom_minimum_size = Vector2(420, 0)
	_list.add_theme_constant_override("separation", 8)
	scroll.add_child(_list)


func _make_tab_button(text: String, pos: Vector2, active: bool) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.position = pos
	btn.custom_minimum_size = Vector2(76, 28)
	btn.add_theme_font_size_override("font_size", GameConstants.FONT_SM)
	var bg := Color8(0x27, 0xae, 0x60) if active else Color8(0x44, 0x44, 0x66)
	btn.add_theme_stylebox_override("normal", UITheme.make_button_style(bg))
	return btn


func _set_mode(mode: String) -> void:
	_mode = mode
	_mode_buy.add_theme_stylebox_override("normal", UITheme.make_button_style(
		Color8(0x27, 0xae, 0x60) if mode == "buy" else Color8(0x44, 0x44, 0x66)))
	_mode_sell.add_theme_stylebox_override("normal", UITheme.make_button_style(
		Color8(0x27, 0xae, 0x60) if mode == "sell" else Color8(0x44, 0x44, 0x66)))
	_refresh()


func _refresh() -> void:
	if _player == null or _list == null:
		return
	_zeny_label.text = "Zeny: %d" % _player.zeny
	_clear_list()
	if _mode == "buy":
		for item_id in ShopDatabase.get_shop_items(_shop_id):
			_add_buy_row(item_id)
		if _list.get_child_count() == 0:
			_list.add_child(_make_hint("ร้านนี้ไม่มีสินค้า"))
	else:
		var found := false
		for i in range(_player.inventory.size()):
			var item: Variant = _player.inventory[i]
			if item == null or not item is Dictionary:
				continue
			var item_id := ItemDatabase.resolve_item_id(item)
			if item_id == "":
				continue
			if ItemDatabase.get_sell_price(item_id) <= 0:
				continue
			found = true
			_add_sell_row(i, item, item_id)
		if not found:
			_list.add_child(_make_hint("ไม่มีไอเทมที่ขายได้ในกระเป๋า"))


func _clear_list() -> void:
	for child in _list.get_children():
		child.queue_free()


func _after_transaction(result: Dictionary) -> void:
	if _ui:
		_ui.add_log(result.get("message", ""), Color8(0xcc, 0xe5, 0xff) if result.get("ok") else Color8(0xff, 0x66, 0x66))
		if _ui.has_method("refresh_inventory_and_equipment_ui"):
			_ui.refresh_inventory_and_equipment_ui()
	_refresh()


func _make_hint(text: String) -> Label:
	var lbl := Label.new()
	UITheme.style_label(lbl, GameConstants.FONT_SM, UITheme.MUTED, 0)
	lbl.text = text
	return lbl


func _add_buy_row(item_id: String) -> void:
	var def := ItemDatabase.get_item(item_id)
	if def.is_empty():
		return
	var row := _make_row("%s  —  %d z" % [def.get("name", item_id), int(def.get("buy_price", 0))])
	var btn := Button.new()
	btn.name = "BuyBtn"
	btn.text = "ซื้อ"
	btn.custom_minimum_size = Vector2(72, 28)
	btn.add_theme_font_size_override("font_size", GameConstants.FONT_XS)
	btn.add_theme_stylebox_override("normal", UITheme.make_button_style(Color8(0x27, 0xae, 0x60)))
	btn.pressed.connect(func(): _try_buy(item_id))
	row.add_child(btn)
	_list.add_child(row)


func _add_sell_row(inv_index: int, item: Dictionary, item_id: String) -> void:
	var def := ItemDatabase.get_item(item_id)
	var sell_price: int = ItemDatabase.get_sell_price(item_id)
	var count: int = int(item.get("count", 1))
	var row := _make_row(
		"%s x%d  —  %d z" % [item.get("name", def.get("name", item_id)), count, sell_price]
	)
	var btn := Button.new()
	btn.name = "SellBtn"
	btn.text = "ขาย"
	btn.custom_minimum_size = Vector2(72, 28)
	btn.add_theme_font_size_override("font_size", GameConstants.FONT_XS)
	btn.add_theme_stylebox_override("normal", UITheme.make_button_style(Color8(0xc0, 0x39, 0x2b)))
	btn.pressed.connect(_try_sell.bind(inv_index))
	row.add_child(btn)
	_list.add_child(row)


func _make_row(label_text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(420, 32)
	var lbl := Label.new()
	lbl.text = label_text
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UITheme.style_label(lbl, GameConstants.FONT_SM, Color.WHITE, 0)
	row.add_child(lbl)
	return row


func _try_buy(item_id: String) -> void:
	var result := ShopService.buy(_player, item_id, 1)
	_after_transaction(result)


func _try_sell(inv_index: int) -> void:
	var result := ShopService.sell(_player, inv_index, 1)
	_after_transaction(result)


func _on_close() -> void:
	closed.emit()
