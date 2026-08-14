# RH: Redhog — Code Index (แก้ไข / ตรวจสอบเร็ว)

> UI ละเอียด: [`UI_SYSTEM.md`](UI_SYSTEM.md) · เควส: [`QUEST_SYSTEM.md`](QUEST_SYSTEM.md) · โครงสร้าง: [`PROJECT_STRUCTURE.md`](PROJECT_STRUCTURE.md)

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
| `ui/charactercreation.tscn` | — | `charactercreation.gd` | + `CharacterCreationStats` |
| `ui/ui.tscn` | UI | `ui_manager.gd` | HUD สร้างใน code |
| `ui/pause_menu.tscn` | — | autoload | manual save |
| `maps/world.tscn` | World | `world.gd` | มอนสเตอร์ + combat + quest kill |
| `maps/capital_city.tscn` | CapitalCity | `capital_city.gd` | Hub + NPC |
| `characters/player.tscn` | Player | `player.gd` | ตัวละครรวม male/female |
| `characters/npc.tscn` | npc | `npc.gd` | Prefab NPC (foot UI + click/F) |
| `characters/big_poring.tscn` | — | `big_monster.gd` | Boss |
| `objects/portal.tscn` | Portal | `portal.gd` | ตั้ง target_scene ในแต่ละ map |

## Scripts — แก้ตามระบบ

### Core (`scripts/core/`)
| ไฟล์ | ใช้เมื่อ |
|------|---------|
| `project_paths.gd` | path constant ทุก scene |
| `warp_helper.gd` | Portal + NPC warp + stash + cloud save ก่อน warp |
| `ui_access.gd` | หา UIManager — ใช้แทน `get_first_node_in_group("ui")` |

### Quests (`scripts/quests/`)
| ไฟล์ | ส่วนสำคัญ |
|------|-----------|
| `quest_db.gd` | `QuestDatabase.QUESTS`, rewards, objectives |
| `quest_service.gd` | accept/turn_in, status, save |

### Maps (`scripts/world/`)
| ไฟล์ | ส่วนสำคัญ |
|------|-----------|
| `base_map.gd` | spawn player/UI, คลิกเดิน, `_input` |
| `world.gd` | มอนสเตอร์, combat, auto AI, flee boss via `BossManager.active_boss` |
| `capital_city.gd` | online presence |
| `portal.gd` | walk-in warp |

### Characters (`scripts/characters/`)
| ไฟล์ | ส่วนสำคัญ |
|------|-----------|
| `player.gd` | stats, combat, inventory, equipment, quests, auto-save 180s |
| `player_sprite_loader.gd` | โหลด sprite ตาม job/gender |
| `player_save_stash.gd` | local snapshot หลัง warp |
| `npc.gd` | hover/click/F คุย, foot UI (throttled interact check) |
| `npc_role_handlers.gd` | quest board, shop, warp, job master |
| `monster.gd` / `big_monster.gd` | AI มอนสเตอร์ |

### UI (`scripts/ui/`)
| ไฟล์ | ส่วนสำคัญ |
|------|-----------|
| `ui_manager.gd` | HUD, EXP strip, modals, `_layout_open_windows`, drag preview |
| `ui_layout.gd` | Layout engine — chat, skill bar, exp strip, modal bounds |
| `stat_window_panel.gd` | Stat 700×460, hex radar, accordion, collapse |
| `stat_hex_radar.gd` | Reusable hex radar control |
| `character_creation_stats.gd` | Char create stat pairs + radar |
| `inventory_equip_window.gd` | **Bag 820×520** — inv + equip + Godot DnD |
| `inventory_panel.gd` | ⚠ legacy — ไม่ใช้แล้ว |
| `equipment_panel.gd` | ⚠ legacy — ไม่ใช้แล้ว |
| `skill_book_panel.gd` | Skill Book + drag to quick slot |
| `chat_log.gd` | แท็บช่องแชท, BBCode |
| `quest_log_panel.gd` | Quest Log (Q) |
| `shop_panel.gd` | NPC shop buy/sell |
| `minimap.gd` | minimap + คลิกเดิน (redraw ทุก 0.1s) |
| `map_overview.gd` | World Map UI |

### Managers & Online (`scripts/managers/`, `scripts/online/`, `scripts/autoload/`)
| ไฟล์ | ส่วนสำคัญ |
|------|-----------|
| `global_data.gd` | session, warp spawn, quest stash, typed `Array[String]` finished |
| `database_manager.gd` | save coalesce queue, load, upsert equip/inv, timeout 45s |
| `supabase_client.gd` | `_dispatch_http`, auth, REST, Realtime, web fetch timeout |
| `supabase_config.gd` | credentials จาก `config/supabase.cfg` |
| `boss_manager.gd` | boss spawn, timer refresh 0.5s |
| `presence_manager.gd` | remote players, stale prune 1s |
| `world_sync_manager.gd` | cross-map boss timers |
| `party_manager.gd` | party CRUD, `Array[Dictionary]` members |
| `game_constants.gd` | ขนาดจอ, UI sizes, EXP strip |
| `class_db.gd` | อาชีพ Novice → Lv.15 job change |
| `npc_db.gd` | NPC defs |

### Supabase SQL (`supabase/`)
| ไฟล์ | ใช้เมื่อ |
|------|---------|
| `player_quests_columns.sql` | เพิ่ม `active_quests` / `finished_quests` JSONB |
| `realtime_broadcast_rls.sql` | RLS สำหรับ Realtime broadcast |

## จุดที่มักแก้บ่อย

| ต้องการ | แก้ที่ |
|---------|--------|
| UI ทับกัน / ตำแหน่ง panel | `ui_layout.gd` + `ui_manager._layout_open_windows` |
| EXP bar ล่างจอ (Base/Job) | `ui_manager._build_exp_strip`, `game_constants.EXP_*` |
| Stat window / hex radar | `stat_window_panel.gd`, `stat_hex_radar.gd` |
| กระเป๋า + สวมใส่ DnD | `inventory_equip_window.gd`, `player.equip_*` |
| Char create stats | `character_creation_stats.gd`, `charactercreation.gd` |
| HUD ไม่อัปเดต | เช็ค `player.stats_changed` → `_update_player_stats_ui` |
| Cloud save ถี่เกิน | `database_manager` coalesce — ไม่ต้อง debounce ฝั่ง caller |
| Cloud save ค้าง/ล้มเหลว | `database_manager` timeout + `supabase_client._http_succeeded` |
| Quest หายหลัง warp | `global_data.gd`, `warp_helper.gd`, `player_save_stash.gd` |
| Cloud save quests | รัน `supabase/player_quests_columns.sql` |
| Quick Slot drag | `ui_manager.gd`, `player.assign_quick_slot_entry` |
| Skill drag จาก Skill Book | `skill_book_panel.gd` + `ui_manager._input` |
| Portal ปลายทาง | `scenes/maps/*.tscn` → node Portal |
| Warp logic | `warp_helper.gd` + `GlobalData.prepare_warp()` |
| NPC ชื่อ / role | `npc_db.gd` + instance ใน map |
| Sprite ตัวละคร | `player_sprite_loader.gd` + `animation/player/` |
| เปลี่ยนอาชีพ | `npc_role_handlers`, `class_db.gd` |
| Boss timer UI | `boss_manager.gd`, `boss_spawn_panel.gd` |

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
animation/player/{job}/{gender}/...
```
Jobs: `novice`, `sword`, `mage`, `thief`, `acolyte`, `hunter`

## แนวทางอ่าน/แก้โค้ด

1. เปิด [`CODE_INDEX.md`](CODE_INDEX.md) หรือ [`PROJECT_STRUCTURE.md`](PROJECT_STRUCTURE.md) ก่อน
2. UI/Layout → [`UI_SYSTEM.md`](UI_SYSTEM.md)
3. Quest → [`QUEST_SYSTEM.md`](QUEST_SYSTEM.md)
4. ในไฟล์ script หลัก ใช้ `# --- Section ---` jump ใน Godot editor
5. หา UI: `UiAccess.get_ui(self)` — ไม่เรียก group ตรงๆ
6. Warp ทุกจุด: `WarpHelper.execute()` + `GlobalData.prepare_warp()`
7. อย่า hardcode `position` ใน panel — ใช้ `UILayout` / `_layout_open_windows()`
8. Cloud save: เรียก `save_game_data()` ได้ตาม event — manager coalesce ให้

## ไฟล์ที่มี section comments แล้ว

| ไฟล์ | Sections |
|------|----------|
| `player.gd` | Setup, Visuals, Job, Combat, Inventory, Quest, Movement |
| `base_map.gd` | Lifecycle, Spawn, Input/Movement |
| `world.gd` | Lifecycle, Targeting, Spawn, Combat, Drops, Movement |
| `npc.gd` | Lifecycle, Foot UI, Interaction, Dialog |
| `npc_role_handlers.gd` | Quest Board, Shop, Job Master, Warp |
| `database_manager.gd` | Save, Load, Upsert, Quests |
| `ui_manager.gd` | Setup, Layout, HUD, Windows, NPC Dialog, Drag |
