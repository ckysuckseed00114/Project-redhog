# RH: Redhog — Project Structure

> ดัชนีแก้ไขเร็ว: [`CODE_INDEX.md`](CODE_INDEX.md)

## Scenes (`res://scenes/`)

| Folder | Purpose |
|--------|---------|
| `characters/` | Player, monsters, NPC prefab |
| `maps/` | Playable maps (`world`, `capital_city`) |
| `objects/` | Portals, item drops |
| `ui/` | HUD, login, character screens, pause menu |

## Scripts (`res://scripts/`)

| Folder | Purpose |
|--------|---------|
| `autoload/` | `SupabaseClient` — cloud auth + REST + Realtime |
| `characters/` | Player, monster, NPC, remote player, `npc_role_handlers.gd` |
| `core/` | Paths, warp, UI access helpers |
| `managers/` | Game data, cloud save, boss, online presence, DBs |
| `online/` | Presence, party sync, world sync, broadcast router |
| `quests/` | `quest_db.gd`, `quest_service.gd` |
| `systems/` | Stat registry, shop/consumable/save-point services |
| `ui/` | HUD manager, layout, chat, panels, themes |
| `world/` | Map controllers (`BaseMap`), portals, effects |

## Docs (`res://docs/`)

| ไฟล์ | เนื้อหา |
|------|---------|
| [`CODE_INDEX.md`](CODE_INDEX.md) | ดัชนีไฟล์ + จุดแก้บ่อย |
| [`UI_SYSTEM.md`](UI_SYSTEM.md) | Layout, HUD, panels, Theme, DnD |
| [`QUEST_SYSTEM.md`](QUEST_SYSTEM.md) | รับ/ส่งเควส, persistence, API |

## Assets & Config

| Folder | Purpose |
|--------|---------|
| `animation/` | Sprite sheets (player / monster / NPC) |
| `armor/`, `weapon/` | Item resources |
| `config/` | `supabase.cfg` (optional override สำหรับ desktop export) |
| `html/` | `web_head_include.html` — Godot Web export helper (Supabase fetch) |
| `supabase/` | SQL migrations สำหรับ Supabase (รัน manual ใน SQL Editor) |
| `Build/` | Godot HTML5 export output (generated) |

## Autoloads

| Autoload | หน้าที่ |
|----------|---------|
| `GameConstants` | resolution, map size, UI sizes |
| `GlobalData` | session / character / warp spawn / quest stash |
| `SupabaseClient` | auth, REST (`_dispatch_http`), Realtime WebSocket |
| `DatabaseManager` | save/load แบบ queue + coalesce, quest JSONB |
| `OnlinePresenceManager` | remote players + chat broadcast |
| `BossManager` | scheduled boss spawns + timer sync |
| `WorldSyncManager` | cross-map boss state |
| `PartyManager`, `PauseMenu`, `TextureGenerator` | party, pause, placeholder textures |

## Scene Flow

```
login_screen → character_selection → charactercreation (new)
                      ↓ select slot
              capital_city ↔ world (Training Field)
```

Main scene: `res://scenes/ui/login_screen.tscn`

## Conventions

- **Maps** extend `BaseMap` — spawn player/UI, click-to-move, warp spawn
- **UI** — หา UIManager ผ่าน `UiAccess.get_ui(node)` ไม่เรียก group ตรงๆ
- **UI Layout** — ตำแหน่งทุก panel ผ่าน `UILayout` + `ui_manager._layout_open_windows()` ไม่ hardcode position ใน panel
- **Warp** — Portal/NPC ใช้ `WarpHelper.execute()` + `GlobalData.prepare_warp()` + stash quests
- **Quest** — นิยามใน `QuestDatabase`, logic ใน `QuestService`, NPC ผ่าน `NpcRoleHandlers`
- **Cloud save** — เรียก `DatabaseManager.save_game_data(player)` ได้บ่อย; manager จะ coalesce เป็น snapshot ล่าสุดก่อนยิง Supabase
- **Section comments** — ไฟล์หลักมี `# --- Section ---` สำหรับ jump ใน editor

## Performance Notes

| จุด | แนวทาง |
|-----|--------|
| HUD stats (HP/SP/EXP/zeny) | อัปเดตผ่าน `player.stats_changed` → `_update_player_stats_ui()` ไม่ทำใน `_process` |
| Target HUD | `_process` เฉพาะ HP tween ของมอนสเตอร์ที่เลือก |
| Boss timer UI | `BossManager` refresh ทุก 0.5s + event `boss_state_changed` |
| NPC foot UI | เช็ค interact range ทุก ~0.12s |
| Online presence prune | `OnlinePresenceManager` ทุก 1s |
| Auto flee boss | `world.gd` ใช้ `BossManager.active_boss` แทน loop มอนสเตอร์ทั้งหมด |

## Supabase / Cloud Save

```
Player / Quest / Warp
       ↓
DatabaseManager.save_game_data()
       ↓ coalesce (_queued_payload = snapshot ล่าสุด)
       ↓ queue ทีละ batch
SupabaseClient.update_data / insert_data / delete + upsert
       ↓ error → push_warning + callback(false) — ไม่ crash game loop
```

- Timeout ต่อ save batch: **45s** (`SAVE_TIMEOUT_SEC`)
- HTTP timeout default: **20s** (`SupabaseClient.DEFAULT_HTTP_TIMEOUT`)
- Web fetch timeout: **15s** (browser export)
- Migration: รัน `supabase/player_quests_columns.sql` ก่อนใช้ quest cloud save
