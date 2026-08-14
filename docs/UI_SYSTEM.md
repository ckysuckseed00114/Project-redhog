# RH: Redhog — UI System

> ดัชนีโค้ด: [`CODE_INDEX.md`](CODE_INDEX.md) · โครงโปรเจกต์: [`PROJECT_STRUCTURE.md`](PROJECT_STRUCTURE.md)

Native resolution **1280×720** — UI สร้างใน code ผ่าน `UIManager` (`ui_manager.gd`)

## Layout Engine

ตำแหน่ง UI ทั้งหมดคำนวณผ่าน **`scripts/ui/ui_layout.gd`** (`UILayout`)

| ฟังก์ชัน | ใช้เมื่อ |
|---------|---------|
| `chat_rect(collapsed)` | กล่องแชท (ซ้ายล่าง) |
| `skill_bar_rect(collapsed)` | Quick Slot 6 ช่อง (ถัดจากแชท) |
| `exp_strip_y()` | แถบ Base/Job EXP ชิดล่าง (RO-style) |
| `bottom_reserved_top_y(collapsed)` | ขอบบนของโซนล่าง — modal ต้องไม่ล้น |
| `modal_bounds(stat, inv, chat_collapsed)` | พื้นที่กลางจอสำหรับ popup |
| `inventory_block_width()` / `inventory_block_left()` | กว้าง/ตำแหน่งหน้าต่างกระเป๋า (820px) |
| `layout_quest(...)` | Quest Log — ขวา Stat หรือเหนือ Chat |

`ui_manager.gd` เรียก `_layout_open_windows()` เมื่อเปิด/ปิดหน้าต่าง, ย่อแชท, หรือย่อ Quest Log

### โซนหน้าจอ (ไม่ทับกัน)

```
┌─────────────────────────────────────────────────────────┐
│ HUD (ซ้ายบน)              Target HUD (กลางบน)  Minimap │
│ Stat (ซ้าย)    Quest (ขวา Stat / เหนือ Chat)            │
│              Modal กลาง (Skill/Shop/Map/Party/NPC)      │
│                                    Bag 820×520 (ขวา)    │
│ Chat (600px) │ Quick Slots │        Action Bar (เต็ม)  │
│ ═════ Base EXP (L→R) ═════ Job EXP (R→L) ══════════════ │
└─────────────────────────────────────────────────────────┘
```

## ค่าคงที่ (`game_constants.gd`)

| Constant | ค่า | หมายเหตุ |
|----------|-----|----------|
| `HUD_WIDTH` × `HUD_HEIGHT` | 450 × 108 | แถบ HP/SP (ไม่มี EXP ใน HUD แล้ว) |
| `EXP_STRIP_HEIGHT` | 32 | แถบ Base/Job EXP ชิดล่าง |
| `WIN_STAT_SIZE` | 700 × 460 | Character Stats (hex radar + accordion) |
| `WIN_BAG_SIZE` | 820 × 520 | Inventory + Equipment รวม |
| `WIN_SKILL_SIZE` | 520 × 320 | Skill Book |
| `CHAT_WIDTH` | 600 | กว้างแชท |
| `CHAT_PANEL_HEIGHT` | tab + log + input | รวม ~150px |
| `ACTION_BAR_HEIGHT` | 54 | แถบปุ่มล่าง |

## HUD & EXP Strip

| องค์ประกอบ | ไฟล์ | หมายเหตุ |
|-----------|------|----------|
| HP / SP / Job label / Zeny | `ui_manager._build_hud()` | อัปเดตผ่าน `stats_changed` |
| Base EXP bar | `_build_exp_strip()` | เติม **ซ้าย → ขวา** |
| Job EXP bar | `_refresh_exp_strip()` | เติม **ขวา → ซ้าย** (`pivot_offset`) |
| Minimap coords | `_update_minimap_info()` | throttle เมื่อ tile ไม่เปลี่ยน |
| Target monster HP | `_update_target_hud()` | tween ใน `_process` |

## Stat Window (`stat_window_panel.gd`)

- ขนาด **700×460**, dark-fantasy 2-pane
- ซ้าย: vitals + **`stat_hex_radar.gd`** (hex radar 6 สtat)
- ขวา: stat allocation + accordion **Detailed Stats** (ScrollContainer)
- ปุ่ม collapse → **700×50**
- Refresh เมื่อ `stats_changed` (ไม่ refresh ทุก frame)

## Character Creation (`character_creation_stats.gd`)

- Classic RO stat allocation: STR↔INT, AGI↔LUK, VIT↔DEX
- Hex radar + 6 vertex buttons + side list
- Max stat **9**, ไม่มี free points — ใช้คู่ตรงข้าม

## Inventory + Equipment (`inventory_equip_window.gd`)

- หน้าต่างรวม **820×520** แทน panel แยก
- Godot built-in DnD: `_get_drag_data` / `_can_drop_data` / `_drop_data`
- Validation: `item.type == slot_key` (strict type)
- Player API: `equip_inventory_to_slot()`, `move_equipment_to_inventory()`, `swap_*()`

> `inventory_panel.gd` / `equipment_panel.gd` — legacy, ไม่ถูก `ui_manager` ใช้แล้ว

## Theme (`ui_theme.gd`)

- **Cozy panels** — Bag, Skill Book, Quest Log (สีอิง HP bar: `#9be844` / `#1a1a22`)
- **Chat tabs** — ม่วง active / เทา inactive (กำหนดใน `chat_log.gd`)

## Chat (`chat_log.gd`)

- แท็บช่อง: ทุกคน · แผน · ปาร์ตี้ · กิลด์ · กระซิบ · ระบบ
- ปุ่ม **▼/▲** ย่อ/ขยาย → `layout_changed` → re-layout
- `add_chat_message(sender, text, channel)` — ข้อความผู้เล่น
- `add_log(text, color)` — ข้อความระบบ
- Hotkey: **Enter** เปิด input แชท

## Quest Log (`quest_log_panel.gd`)

- Hotkey: **Q** toggle
- Collapse/expand header — ส่ง `collapse_changed` → re-layout

## Quick Slot & Drag

| การกระทำ | ไฟล์ |
|---------|------|
| ลาก Skill จาก Skill Book | `skill_book_panel.gd` + `ui_manager.gd` |
| ลาก Item ในกระเป๋า / สวมใส่ | `inventory_equip_window.gd` (Godot DnD) |
| ลาก Item/Skill ออกจาก Quick Slot | `ui_manager.gd` (threshold 10px) |
| Passive skill | ใส่ Quick Slot ไม่ได้ |
| swap / dedupe slot | `player.assign_quick_slot_entry()` |

## หน้าต่าง Modal

| หน้าต่าง | Toggle | ขนาด |
|---------|--------|------|
| Stat | C | 700×460 |
| Inventory + Equipment | I | 820×520 |
| Skill Book | K | 520×320 |
| Party | P | 420×360 |
| Map | M | 360×348 |
| Boss | ปุ่ม BOSS | 320×168 |
| Auto | ปุ่ม AUTO | — |
| Shop | NPC Shop | 460×360 |
| NPC Dialog | F / คลิก NPC | 520×220 |

## API ที่ UI อื่นเรียก

```gdscript
var ui := UiAccess.get_ui(self)
ui.add_log("ข้อความ", Color.WHITE)
ui.show_notification("...", Color.GOLD)
ui.refresh_quest_log()
ui.open_shop(player, shop_id, name, "buy")
ui.open_npc_dialog(npc, config)
ui.blocks_player_movement()   # world ใช้เช็ค input lock
```
