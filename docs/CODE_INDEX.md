# RH: Redhog — Code Index (แก้ไข / ตรวจสอบเร็ว)

> UI ละเอียด: [`UI_SYSTEM.md`](UI_SYSTEM.md) · เควส: [`QUEST_SYSTEM.md`](QUEST_SYSTEM.md)

## Scene Flow
```
login_screen → character_selection → charactercreation (ใหม่)
                ↓ เลือกตัว
         capital_city ↔ world (Training Field)
```

## Scenes (`res://scenes/`)

| ไฟล์ | Root Node | Script | หมายเหตุ |
|------|-----------|--------|----------|
| `ui/login_screen.tscn` | — | `login_screen.gd` | Main scene |
| `ui/character_selection.tscn` | — | `character_selection.gd` | สร้าง slot ตอน runtime |
| `ui/charactercreation.tscn` | — | `charactercreation.gd` | |
| `ui/ui.tscn` | UI | `ui_manager.gd` | HUD สร้างใน code |
| `ui/pause_menu.tscn` | — | autoload | |
| `maps/world.tscn` | World | `world.gd` | มอนสเตอร์ + combat + quest kill progress |
| `maps/capital_city.tscn` | CapitalCity | `capital_city.gd` | Hub + NPC |
| `characters/player.tscn` | Player | `player.gd` | ตัวละครรวม male/female |
| `characters/npc.tscn` | npc | `npc.gd` | Prefab NPC (foot UI + click/F) |
| `characters/job_master.tscn` | JobMaster | `npc.gd` | Job Master + idle animation |
| `characters/poring.tscn` | — | `monster.gd` | |
| `characters/fabre.tscn` | — | `monster.gd` | |
| `characters/big_poring.tscn` | — | `big_monster.gd` | Boss |
| `objects/portal.tscn` | Portal | `portal.gd` | ตั้ง target_scene ในแต่ละ map |
| `objects/itemdrop.tscn` | — | *(logic ใน world.gd)* | |

## Scripts — แก้ตามระบบ

### Core (`scripts/core/`)
| ไฟล์ | ใช้เมื่อ |
|------|---------|
| `project_paths.gd` | path constant ทุก scene |
| `warp_helper.gd` | Portal + NPC warp + stash quests |
| `ui_access.gd` | หา UIManager |

### Quests (`scripts/quests/`)
| ไฟล์ | ส่วนสำคัญ |
|------|-----------|
| `quest_db.gd` | `QuestDatabase.QUESTS`, rewards, objectives |
| `quest_service.gd` | accept/turn_in, status, save, `_resolve_player` |

### Maps (`scripts/world/`)
| ไฟล์ | ส่วนสำคัญ |
|------|-----------|
| `base_map.gd` | spawn player/UI, คลิกเดิน, `_input` |
| `world.gd` | มอนสเตอร์, combat, drop, `update_quest_progress("kill", ...)` |
| `capital_city.gd` | online presence |
| `portal.gd` | walk-in warp |
| `map_overview.gd` | **World Map UI** — `MAP_REGIONS`, `_draw` |

### Characters (`scripts/characters/`)
| ไฟล์ | ส่วนสำคัญ |
|------|-----------|
| `player.gd` | stats, combat, inventory, quests, quick slots |
| `player_sprite_loader.gd` | โหลด sprite ตาม job/gender |
| `npc.gd` | hover/click/F คุย, foot UI, dialog callbacks |
| `npc_role_handlers.gd` | quest board, shop, warp, job master |
| `monster.gd` / `big_monster.gd` | AI มอนสเตอร์ |

### UI (`scripts/ui/`)
| ไฟล์ | ส่วนสำคัญ |
|------|-----------|
| `ui_manager.gd` | HUD ทั้งหมด, `_layout_open_windows`, drag quick slot |
| `ui_layout.gd` | **Layout engine** — chat, skill bar, modal bounds |
| `ui_theme.gd` | Cozy theme + HP bar colors |
| `chat_log.gd` | แท็บช่องแชท, BBCode, ย่อ/ขยาย |
| `quest_log_panel.gd` | Quest Log (Q), collapse |
| `inventory_panel.gd` | Inventory grid + filter |
| `equipment_panel.gd` | Equipment slots |
| `skill_book_panel.gd` | Skill Book + drag to quick slot |
| `shop_panel.gd` | NPC shop buy/sell |
| `minimap.gd` | minimap + คลิกเดิน |
| `map_overview.gd` | กล่อง Capital / South Capital |

### Managers (`scripts/managers/`)
| ไฟล์ | ส่วนสำคัญ |
|------|-----------|
| `global_data.gd` | session, warp spawn, `stash_quest_state` |
| `database_manager.gd` | save/load Supabase + quests JSONB |
| `npc_db.gd` | NPC defs รวม `quest_board` |
| `class_db.gd` | อาชีพ Novice → Lv.15 job change |
| `game_constants.gd` | ขนาดจอ, UI sizes, CHAT_WIDTH, WIN_* |

## จุดที่มักแก้บ่อย

| ต้องการ | แก้ที่ |
|---------|--------|
| UI ทับกัน / ตำแหน่ง panel | `ui_layout.gd` + `ui_manager._layout_open_windows` |
| สี UI Cozy / HP bar | `ui_theme.gd` → `COZY_*`, `HP_FILL` |
| Chat ช่อง / สไตล์ | `chat_log.gd` |
| Quest Log | `quest_log_panel.gd`, hotkey Q ใน `ui_manager.gd` |
| เพิ่มเควสใหม่ | `quest_db.gd` → `npc_db.gd` quest_ids |
| Flow รับ/ส่งเควส | `npc_role_handlers.gd`, `quest_service.gd` |
| Quest หายหลัง warp | `global_data.gd`, `warp_helper.gd`, `database_manager.gd` |
| Cloud save quests | รัน `supabase/player_quests_columns.sql` |
| Quick Slot drag | `ui_manager.gd`, `player.assign_quick_slot_entry` |
| Skill drag จาก Skill Book | `skill_book_panel.gd` + `ui_manager._input` |
| World Map layout | `map_overview.gd` → `MAP_REGIONS` |
| Portal ปลายทาง | `scenes/maps/*.tscn` → node Portal |
| Warp logic | `warp_helper.gd` + `global_data.gd` |
| NPC ชื่อ / role | `npc_db.gd` + instance ใน map |
| Sprite ตัวละคร | `player_sprite_loader.gd` + `animation/player/` |
| เปลี่ยนอาชีพ | `npc_role_handlers` (Job Master), `class_db.gd` |

## Hotkeys (in-game HUD)

| Key | หน้าที่ |
|-----|--------|
| C | Stat |
| I | Inventory + Equipment |
| K | Skill Book |
| P | Party |
| M | Map |
| Q | Quest Log |
| Enter | เปิดแชท |
| F | คุย NPC (ใกล้) |

## โฟลเดอร์ Animation ตัวละคร
```
animation/player/{job}/{gender}/PNG/PNG Sequences/{Idle,Walking,...}/
```
Jobs: `novice`, `sword`, `mage`, `thief`, `acolyte`, `hunter`

## แนวทางอ่าน/แก้โค้ด

1. เปิด [`CODE_INDEX.md`](CODE_INDEX.md) หรือ [`PROJECT_STRUCTURE.md`](PROJECT_STRUCTURE.md) ก่อน
2. UI/Layout → [`UI_SYSTEM.md`](UI_SYSTEM.md)
3. Quest → [`QUEST_SYSTEM.md`](QUEST_SYSTEM.md)
4. ในไฟล์ script หลัก ใช้ `# --- Section ---` jump ใน Godot editor
5. หา UI: `UiAccess.get_ui(self)` — ไม่เรียก `get_first_node_in_group("ui")` ตรงๆ
6. Warp ทุกจุด: `WarpHelper.execute()` + `GlobalData.prepare_warp()`
7. อย่า hardcode `position` ใน panel — ใช้ `UILayout` / `_layout_open_windows()`

## ไฟล์ที่มี section comments แล้ว

| ไฟล์ | Sections |
|------|----------|
| `player.gd` | Setup, Visuals, Job, Combat, Inventory, Quest, Movement |
| `base_map.gd` | Lifecycle, Spawn, Input/Movement |
| `world.gd` | Lifecycle, Targeting, Spawn, Combat, Drops, Movement |
| `npc.gd` | Lifecycle, Foot UI, Interaction, Dialog |
| `npc_role_handlers.gd` | Quest Board, Shop, Job Master, Warp |
| `database_manager.gd` | Save, Load, Presence, Quests |
| `ui_manager.gd` | Setup, Layout, HUD, Windows, NPC Dialog, Drag |
