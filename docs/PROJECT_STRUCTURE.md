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
| `autoload/` | Supabase client (registered in project settings) |
| `characters/` | Player, monster, NPC, remote player, `npc_role_handlers.gd` |
| `core/` | Paths, warp, UI access helpers |
| `managers/` | Game data, cloud save, boss, online presence, `npc_db.gd` |
| `quests/` | `quest_db.gd`, `quest_service.gd` |
| `ui/` | HUD manager, layout, chat, panels, themes |
| `world/` | Map controllers (`BaseMap`), portals, effects |

## Docs (`res://docs/`)

| ไฟล์ | เนื้อหา |
|------|---------|
| [`CODE_INDEX.md`](CODE_INDEX.md) | ดัชนีไฟล์ + จุดแก้บ่อย |
| [`UI_SYSTEM.md`](UI_SYSTEM.md) | Layout, Chat, Quick Slot, Theme |
| [`QUEST_SYSTEM.md`](QUEST_SYSTEM.md) | รับ/ส่งเควส, persistence, API |

## Assets

| Folder | Purpose |
|--------|---------|
| `animation/` | Sprite sheets (player / monster) |
| `armor/`, `weapon/` | Item resources |

## Autoloads

- `GameConstants` — resolution, map size, UI sizes
- `GlobalData` — session / selected character / warp spawn / quest stash
- `SupabaseClient` — cloud auth + REST
- `DatabaseManager` — save/load + presence sync + quests
- `OnlinePresenceManager` — other players + chat broadcast
- `BossManager` — scheduled boss spawns
- `PartyManager`, `PauseMenu`, `TextureGenerator`

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
- **Section comments** — ไฟล์หลักมี `# --- Section ---` สำหรับ jump ใน editor

## Legacy (safe to ignore)

- `legacy_phaser/` — old web prototype
