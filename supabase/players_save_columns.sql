-- คอลัมน์ที่เกมใช้ตอน Cloud Save (รันใน Supabase SQL Editor ถ้ายังไม่มี)
ALTER TABLE public.players ADD COLUMN IF NOT EXISTS active_quests jsonb DEFAULT '{}'::jsonb;
ALTER TABLE public.players ADD COLUMN IF NOT EXISTS finished_quests jsonb DEFAULT '[]'::jsonb;
ALTER TABLE public.players ADD COLUMN IF NOT EXISTS quick_slots jsonb DEFAULT '[]'::jsonb;
ALTER TABLE public.players ADD COLUMN IF NOT EXISTS has_save_point boolean DEFAULT false;
ALTER TABLE public.players ADD COLUMN IF NOT EXISTS save_point_scene text DEFAULT '';
ALTER TABLE public.players ADD COLUMN IF NOT EXISTS save_point_x double precision DEFAULT 0;
ALTER TABLE public.players ADD COLUMN IF NOT EXISTS save_point_y double precision DEFAULT 0;

-- Upsert ต้องมี unique constraint (ถ้ายังไม่มี)
DO $$
BEGIN
	IF NOT EXISTS (
		SELECT 1 FROM pg_constraint
		WHERE conname = 'players_character_id_key'
	) THEN
		ALTER TABLE public.players ADD CONSTRAINT players_character_id_key UNIQUE (character_id);
	END IF;
END $$;

DO $$
BEGIN
	IF NOT EXISTS (
		SELECT 1 FROM pg_constraint
		WHERE conname = 'player_equipment_character_slot_key'
	) THEN
		ALTER TABLE public.player_equipment
		ADD CONSTRAINT player_equipment_character_slot_key UNIQUE (character_id, slot_key);
	END IF;
END $$;

DO $$
BEGIN
	IF NOT EXISTS (
		SELECT 1 FROM pg_constraint
		WHERE conname = 'player_inventory_character_slot_key'
	) THEN
		ALTER TABLE public.player_inventory
		ADD CONSTRAINT player_inventory_character_slot_key UNIQUE (character_id, slot_index);
	END IF;
END $$;
