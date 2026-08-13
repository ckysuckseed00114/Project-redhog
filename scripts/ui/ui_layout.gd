class_name UILayout
extends RefCounted

# ui_layout.gd — คำนวณตำแหน่ง UI ทั้งหมด (1920×1080)

const SKILL_SLOT_SIZE := 36
const SKILL_SLOT_GAP := 4
const SKILL_SLOT_COUNT := 6
const QUICK_BAR_GAP := 4


static func skill_bar_size() -> Vector2:
	return Vector2(
		SKILL_SLOT_COUNT * SKILL_SLOT_SIZE + (SKILL_SLOT_COUNT - 1) * SKILL_SLOT_GAP,
		SKILL_SLOT_SIZE
	)


static func chat_height(collapsed: bool) -> float:
	return float(GameConstants.CHAT_TAB_HEIGHT if collapsed else GameConstants.CHAT_PANEL_HEIGHT)


static func chat_rect(collapsed: bool = false) -> Rect2:
	var h := chat_height(collapsed)
	# 🌟 เพิ่มระยะห่างจากแถบเมนูด้านล่างขึ้นไปอีก (เช่น + 8 หรือปรับค่าตามต้องการ)
	var y := GameConstants.action_bar_y() - h - float(GameConstants.UI_PANEL_GAP) - 12.0
	return Rect2(float(GameConstants.HUD_MARGIN), y, float(GameConstants.CHAT_WIDTH), h)


static func skill_bar_rect(collapsed: bool = false) -> Rect2:
	var chat := chat_rect(collapsed)
	var sz := skill_bar_size()
	var x := chat.end.x + float(GameConstants.UI_PANEL_GAP)
	var y := GameConstants.action_bar_y() - sz.y - QUICK_BAR_GAP
	return Rect2(x, y, sz.x, sz.y)


static func bottom_reserved_top_y(collapsed: bool = false) -> float:
	var chat := chat_rect(collapsed)
	var skill := skill_bar_rect(collapsed)
	return minf(chat.position.y, skill.position.y) - float(GameConstants.UI_PANEL_GAP)


static func left_column_x() -> float:
	return float(GameConstants.HUD_MARGIN)


static func left_column_start_y() -> float:
	return float(GameConstants.HUD_MARGIN + GameConstants.HUD_HEIGHT + GameConstants.UI_PANEL_GAP)


static func online_label_pos() -> Vector2:
	return Vector2(
		left_column_x() + 10.0,
		float(GameConstants.HUD_MARGIN + GameConstants.HUD_HEIGHT + 2)
	)


static func notification_base_y() -> float:
	return 110.0


static func inventory_block_width() -> float:
	return GameConstants.WIN_EQUIP_SIZE.x + float(GameConstants.UI_PANEL_GAP) + GameConstants.WIN_INV_SIZE.x


static func inventory_block_left() -> float:
	return float(GameConstants.GAME_WIDTH) - float(GameConstants.HUD_MARGIN) - inventory_block_width()


static func left_block_right(stat_open: bool) -> float:
	var right := left_column_x() + GameConstants.WIN_STAT_SIZE.x
	if stat_open:
		right += float(GameConstants.UI_PANEL_GAP) + QuestLogPanel.EXPANDED_SIZE.x
	return right


static func modal_bounds(stat_open: bool, inv_open: bool, chat_collapsed: bool) -> Rect2:
	var left := left_column_x()
	if stat_open:
		left = left_block_right(true)
	else:
		left = left_column_x()
	var right := float(GameConstants.GAME_WIDTH - GameConstants.HUD_MARGIN)
	if inv_open:
		right = inventory_block_left() - float(GameConstants.UI_PANEL_GAP)
	var top := left_column_start_y()
	var bottom := bottom_reserved_top_y(chat_collapsed)
	return Rect2(left, top, maxf(0.0, right - left), maxf(0.0, bottom - top))


static func place_in_rect(panel_size: Vector2, area: Rect2, prefer_bottom: bool = false) -> Vector2:
	if area.size.x <= 0.0 or area.size.y <= 0.0:
		return Vector2(
			(float(GameConstants.GAME_WIDTH) - panel_size.x) * 0.5,
			(float(GameConstants.GAME_HEIGHT) - panel_size.y) * 0.5
		)
	var x := area.position.x + maxf(0.0, (area.size.x - panel_size.x) * 0.5)
	var max_y := maxf(area.position.y, area.end.y - panel_size.y)
	var y := max_y if prefer_bottom else area.position.y + maxf(0.0, (area.size.y - panel_size.y) * 0.5)
	y = clampf(y, area.position.y, max_y)
	return Vector2(x, y)


static func quest_height(collapsed: bool) -> float:
	return QuestLogPanel.COLLAPSED_SIZE.y if collapsed else QuestLogPanel.EXPANDED_SIZE.y


static func layout_quest(
	stat_open: bool,
	quest_visible: bool,
	quest_collapsed: bool,
	chat_collapsed: bool
) -> Vector2:
	if not quest_visible:
		return Vector2(-1.0, -1.0)
	var chat_top := chat_rect(chat_collapsed).position.y
	var h := quest_height(quest_collapsed)
	var y := chat_top - float(GameConstants.UI_PANEL_GAP) - h
	var x := left_column_x()
	if stat_open:
		x = left_column_x() + GameConstants.WIN_STAT_SIZE.x + float(GameConstants.UI_PANEL_GAP)
		y = left_column_start_y()
		var max_y := chat_top - float(GameConstants.UI_PANEL_GAP) - h
		y = minf(y, max_y)
	else:
		y = minf(y, chat_top - float(GameConstants.UI_PANEL_GAP) - h)
	return Vector2(x, maxf(left_column_start_y(), y))


static func layout_stat_y(quest_visible: bool, quest_collapsed: bool, chat_collapsed: bool) -> float:
	var y := left_column_start_y()
	if not quest_visible or quest_collapsed:
		return y
	var quest_pos := layout_quest(false, true, quest_collapsed, chat_collapsed)
	if quest_pos.x < left_column_x() + GameConstants.WIN_STAT_SIZE.x * 0.5:
		return y
	return y


static func boss_window_size(entry_count: int) -> Vector2:
	var rows := maxi(entry_count, 1)
	var row_h := 68.0
	var body_h := 16.0 + rows * row_h + maxf(0, rows - 1) * 6.0
	body_h = clampf(body_h, 96.0, 220.0)
	return Vector2(300.0, 36.0 + body_h)


static func boss_window_rect(entry_count: int, chat_collapsed: bool = false) -> Rect2:
	var size := boss_window_size(entry_count)
	var minimap_rect := GameConstants.minimap_hud_rect()  # 🌟 เปลี่ยนจาก mini เป็น minimap_rect
	var x := float(GameConstants.GAME_WIDTH - GameConstants.HUD_MARGIN) - size.x
	var y := minimap_rect.end.y + float(GameConstants.UI_PANEL_GAP)
	var max_bottom := bottom_reserved_top_y(chat_collapsed) - float(GameConstants.UI_PANEL_GAP)
	if y + size.y > max_bottom:
		y = maxf(left_column_start_y(), max_bottom - size.y)
	return Rect2(x, y, size.x, size.y)


static func layout_inventory_y(chat_collapsed: bool) -> float:
	var inv_h := GameConstants.WIN_INV_SIZE.y
	var top_limit := left_column_start_y()
	var bottom_limit := bottom_reserved_top_y(chat_collapsed) - inv_h
	var center_y := (float(GameConstants.GAME_HEIGHT) - inv_h) * 0.5
	return clampf(center_y, top_limit, bottom_limit)
