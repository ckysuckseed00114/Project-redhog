# RH: Redhog — Quest System

> ดัชนีโค้ด: [`CODE_INDEX.md`](CODE_INDEX.md)

## โครงสร้างไฟล์

```
scripts/quests/
  quest_db.gd       — นิยามเควสทั้งหมด (QuestDatabase)
  quest_service.gd  — helper รับ/ส่ง/สถานะ/save (QuestService)

scripts/characters/
  npc_role_handlers.gd — Quest Board flow, shop, warp, job master
  player.gd            — active_quests, accept/turn_in/progress

scripts/ui/
  quest_log_panel.gd   — UI รายการเควส (Q)

scripts/managers/
  global_data.gd       — stash/apply quest state ตอน warp
  database_manager.gd  — save/load active + finished quests
  npc_db.gd            — quest_board NPC definition

supabase/
  player_quests_columns.sql — JSONB columns (รันใน Supabase ก่อนใช้ cloud save)
```

## เควสที่มีอยู่

| ID | ชื่อ | เป้าหมาย | รางวัล |
|----|------|----------|--------|
| `hunt_porings` | กำจัด Poring มือใหม่ | kill poring ×3 | EXP 150, Job EXP 100, 100 Z |
| `gather_herbs` | เก็บสมุนไพร | gather herb ×3 | EXP 80, Job EXP 50, 50 Z |

> `gather_herbs` — ยังไม่มี hook `gather` ใน world (แสดงใน board ได้ แต่ progress ยังไม่เพิ่ม)

## Flow รับ / ส่งเควส

```
NPC Quest Board (F)
  → รายการเควส [กำลังทำ] / [ส่งได้] / [เสร็จแล้ว]
  → เลือกเควส → หน้ารายละเอียด
      → "รับเควส"     (QuestService.accept_at_npc)
      → "ส่งเควส"     (QuestService.turn_in_at_npc)
      → "กลับ"        (หลายเควส → กลับรายการ)
```

### Progress

- **Kill:** `world.gd` → `player.update_quest_progress("kill", "poring", 1)`
- ครบเป้าหมาย → `completed: true` → แจ้งเตือนให้กลับไปส่ง

### Persistence

| เหตุการณ์ | การบันทึก |
|----------|-----------|
| รับ / ส่งเควส | `QuestService.save_quests()` → `DatabaseManager.save_game_data()` |
| Warp แมพ | `WarpHelper` → `GlobalData.stash_quest_state()` + save ถ้า login |
| Load ตัวละคร | `DatabaseManager._apply_quests_after_load()` |

## QuestService API

```gdscript
QuestService.get_quest_status(player, quest_id)      # AVAILABLE | ACTIVE | READY | FINISHED
QuestService.get_quest_status_label(player, id)    # " [ส่งได้]" ฯลฯ
QuestService.build_quest_detail_message(player, id)
QuestService.can_accept / can_turn_in
QuestService.accept_at_npc(npc, quest_id)
QuestService.turn_in_at_npc(npc, quest_id)
QuestService.refresh_quest_ui(from_node)
```

## Player API

```gdscript
player.accept_quest(quest_id) -> bool
player.update_quest_progress(type, target_id, amount)
player.turn_in_quest(quest_id) -> bool
player.quests_changed  # signal → refresh Quest Log
```

## NPC ตั้งค่า

ใน `npc_db.gd`:

```gdscript
"quest_board": {
    "role": "quest",
    "quest_ids": ["hunt_porings", "gather_herbs"],
    ...
}
```

Place instance ใน map + ตั้ง `npc_id = "quest_board"`

## Supabase Migration

รัน `supabase/player_quests_columns.sql` เพื่อเพิ่ม:

- `active_quests` (JSONB)
- `finished_quests` (JSONB)
