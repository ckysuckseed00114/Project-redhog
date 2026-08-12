extends Node

const GAME_WIDTH := 1280
const GAME_HEIGHT := 720

const PLAYER_SPEED := 90.0

const MAP_WORLD_WIDTH := 40 * 32
const MAP_WORLD_HEIGHT := 25 * 32

const INVENTORY_SIZE := 36
const INVENTORY_COLS := 6

# Native 720p UI — no fractional scaling (keeps text crisp)
const FONT_XS := 11
const FONT_SM := 13
const FONT_MD := 15
const FONT_LG := 18

const HUD_MARGIN := 12
const UI_PANEL_GAP := 8
const HUD_WIDTH := 300
const HUD_HEIGHT := 118
const BAR_HEIGHT := 16
const WIN_STAT_SIZE := Vector2(520, 300)
const WIN_EQUIP_SIZE := Vector2(200, 440)
const WIN_INV_SIZE := Vector2(400, 508)
const WIN_SKILL_SIZE := Vector2(520, 320)
const ACTION_BAR_HEIGHT := 54
const MINIMAP_SIZE := 140
const MINIMAP_MARGIN := 12
const MINIMAP_INFO_HEIGHT := 28
const CHAT_TAB_HEIGHT := 26
const CHAT_WIDTH := 520
const CHAT_LOG_HEIGHT := 96
const CHAT_INPUT_HEIGHT := 28
const CHAT_PANEL_HEIGHT := CHAT_TAB_HEIGHT + CHAT_LOG_HEIGHT + CHAT_INPUT_HEIGHT

# Scale factor for modal windows (legacy design → HD)
const UI_WINDOW_SCALE := 2.5

const MONSTER_CLICK_LAYER := 4
const MONSTER_BODY_LAYER := 2
const NPC_CLICK_LAYER := 8
const NPC_INTERACT_RANGE := 30.0
const MELEE_RANGE := 36.0
const PLAYER_MELEE_RANGE := MELEE_RANGE
const PLAYER_MELEE_RANGE_SQ := PLAYER_MELEE_RANGE * PLAYER_MELEE_RANGE
const MELEE_HIT_REACH := 24.0
const MONSTER_MELEE_RANGE_DEFAULT := MELEE_RANGE


func action_bar_y() -> float:
	return float(GAME_HEIGHT - ACTION_BAR_HEIGHT)


func bottom_ui_top_y() -> float:
	return UILayout.bottom_reserved_top_y(false)


func minimap_screen_rect() -> Rect2:
	var size := Vector2(MINIMAP_SIZE, MINIMAP_SIZE)
	var pos := Vector2(
		GAME_WIDTH - MINIMAP_SIZE - MINIMAP_MARGIN,
		MINIMAP_MARGIN
	)
	return Rect2(pos, size)


func minimap_hud_rect() -> Rect2:
	var mini_rect := minimap_screen_rect()
	return Rect2(mini_rect.position, Vector2(mini_rect.size.x, mini_rect.size.y + 4.0 + MINIMAP_INFO_HEIGHT))
