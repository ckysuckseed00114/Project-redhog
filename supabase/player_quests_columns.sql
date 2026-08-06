-- เพิ่มคอลัมน์เก็บเควสในตาราง players (รันใน Supabase SQL Editor)
ALTER TABLE players ADD COLUMN IF NOT EXISTS active_quests jsonb DEFAULT '{}'::jsonb;
ALTER TABLE players ADD COLUMN IF NOT EXISTS finished_quests jsonb DEFAULT '[]'::jsonb;
