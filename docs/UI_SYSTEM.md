# RH: Redhog — UI System

> ดัชนีโค้ด: [`CODE_INDEX.md`](CODE_INDEX.md) · โครงโปรเจกต์: [`PROJECT_STRUCTURE.md`](PROJECT_STRUCTURE.md)

Native resolution **1280×720** — UI สร้างใน code ผ่าน `UIManager` (`ui_manager.gd`)

## Layout Engine

ตำแหน่ง UI ทั้งหมดคำนวณผ่าน **`scripts/ui/ui_layout.gd`** (`UILayout`)

| ฟังก์ชัน | ใช้เมื่อ |
|---------|---------|
| `chat_rect(collapsed)` | กล่องแชท (ซ้ายล่าง) |
| `skill_bar_rect(collapsed)` | Quick Slot 6 ช่อง (ถัดจากแชท) |
| `bottom_reserved_top_y(collapsed)` | ขอบบนของโซนล่าง — modal ต้องไม่ล้น |
| `modal_bounds(stat, inv, chat_collapsed)` | พื้นที่กลางจอสำหรับ popup |
| `place_in_rect(size, area)` | จัด modal กึ่งกลางใน band |
| `layout_quest(...)` | Quest Log — ขวา Stat หรือเหนือ Chat |
| `layout_inventory_y(...)` | Inv/Equip — clamp แนวตั้ง |

`ui_manager.gd` เรียก `_layout_open_windows()` เมื่อเปิด/ปิดหน้าต่าง, ย่อแชท, หรือย่อ Quest Log

### โซนหน้าจอ (ไม่ทับกัน)

```
┌─────────────────────────────────────────────────────────┐
│ HUD (ซ้ายบน)              Target HUD (กลางบน)  Minimap │
│ Stat (ซ้าย)    Quest (ขวา Stat / เหนือ Chat)            │
│              Modal กลาง (Skill/Shop/Map/Party/NPC)      │
│                                    Inv + Equip (ขวา)    │
│ Chat (520px) │ Quick Slots │        Action Bar (เต็ม)  │
└─────────────────────────────────────────────────────────┘
```

## ค่าคงที่ (`game_constants.gd`)

| Constant | ค่า | หมายเหตุ |
|----------|-----|----------|
| `HUD_WIDTH` × `HUD_HEIGHT` | 300 × 118 | แถบ HP/SP/EXP |
| `WIN_STAT_SIZE` | 300 × 360 | Character Stats |
| `WIN_SKILL_SIZE` | 520 × 320 | Skill Book |
| `WIN_INV_SIZE` | 400 × 508 | Inventory |
| `WIN_EQUIP_SIZE` | 200 × 508 | Equipment |
| `CHAT_WIDTH` | 520 | กว้างตาม reference LumiPaws |
| `CHAT_PANEL_HEIGHT` | tab + log + input | รวม ~150px |
| `ACTION_BAR_HEIGHT` | 54 | แถบปุ่มล่าง |

## Theme (`ui_theme.gd`)

- **Cozy panels** — Inventory, Equipment, Skill Book, Quest Log (สีอิง HP bar: `#9be844` / `#1a1a22`)
- **Chat tabs** — ม่วง active / เทา inactive (กำหนดใน `chat_log.gd`)

## Chat (`chat_log.gd`)

- แท็บช่อง: ทุกคน · แผน · ปาร์ตี้ · กิลด์ · กระซิบ · ระบบ
- ปุ่ม **▼/▲** ย่อ/ขยาย → `layout_changed` → re-layout
- `add_chat_message(sender, text, channel)` — ข้อความผู้เล่น (เวลา + pill ช่อง + ชื่อทอง)
- `add_log(text, color)` — ข้อความระบบ (quest, combat, warp ฯลฯ)
- Hotkey: **Enter** เปิด input แชท (ใน `ui_manager.gd`)

## Quest Log (`quest_log_panel.gd`)

- Hotkey: **Q** toggle
- Collapse/expand header — ส่ง `collapse_changed` → re-layout
- วางตำแหน่งโดย `UILayout.layout_quest()`

## Quick Slot & Drag

| การกระทำ | ไฟล์ |
|---------|------|
| ลาก Skill จาก Skill Book | `skill_book_panel.gd` + `ui_manager.gd` |
| ลาก Item/Skill ออกจาก Quick Slot | `ui_manager.gd` (threshold 10px) |
| Passive skill | ใส่ Quick Slot ไม่ได้ |
| สwap / dedupe slot | `player.assign_quick_slot_entry()` |

## หน้าต่าง Modal

| หน้าต่าง | Toggle | ขนาด |
|---------|--------|------|
| Stat | C | 300×360 |
| Inventory + Equipment | I | 600×508 รวม |
| Skill Book | K | 520×320 |
| Party | P | 420×360 |
| Map | M | 360×348 |
| Boss | ปุ่ม BOSS | 320×168 |
| Shop | NPC Shop | 460×360 |
| NPC Dialog | F / คลิก NPC | 520×220 |

## API ที่ UI อื่นเรียก

```gdscript
# จาก player, world, npc ฯลฯ
var ui := UiAccess.get_ui(self)
ui.add_log("ข้อความ", Color.WHITE)           # ระบบ → แท็บ ระบบ
ui.show_notification("...", Color.GOLD)     # toast กลางบน
ui.refresh_quest_log()                        # อัปเดต Quest Log
ui.open_shop(player, shop_id, name, "buy")   # ร้านค้า
ui.open_npc_dialog(npc, config)              # dialog / quest picker
```
