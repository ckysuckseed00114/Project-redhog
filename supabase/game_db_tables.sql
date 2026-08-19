-- Minimal schema (ตรงกับ SyncDatabase push ปัจจุบัน)
-- รันใน Supabase SQL Editor ถ้ายังไม่มีตาราง

CREATE TABLE IF NOT EXISTS public.item_db (
	item_id text PRIMARY KEY,
	name text NOT NULL DEFAULT '',
	type text NOT NULL DEFAULT '',
	price integer NOT NULL DEFAULT 0
);

CREATE TABLE IF NOT EXISTS public.monster_db (
	monster_id text PRIMARY KEY,
	name text NOT NULL DEFAULT '',
	hp integer NOT NULL DEFAULT 0,
	atk integer NOT NULL DEFAULT 0,
	def integer NOT NULL DEFAULT 0
);

ALTER TABLE public.item_db ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.monster_db ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS item_db_read_anon ON public.item_db;
CREATE POLICY item_db_read_anon ON public.item_db
	FOR SELECT TO anon, authenticated USING (true);

DROP POLICY IF EXISTS monster_db_read_anon ON public.monster_db;
CREATE POLICY monster_db_read_anon ON public.monster_db
	FOR SELECT TO anon, authenticated USING (true);

DROP POLICY IF EXISTS item_db_write_anon ON public.item_db;
CREATE POLICY item_db_write_anon ON public.item_db
	FOR ALL TO anon, authenticated USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS monster_db_write_anon ON public.monster_db;
CREATE POLICY monster_db_write_anon ON public.monster_db
	FOR ALL TO anon, authenticated USING (true) WITH CHECK (true);

-- Optional: เก็บ field เพิ่มจาก local เป็น JSON (ถ้าต้องการ full backup บน cloud)
-- ALTER TABLE public.item_db ADD COLUMN IF NOT EXISTS local_data jsonb DEFAULT '{}'::jsonb;
-- ALTER TABLE public.monster_db ADD COLUMN IF NOT EXISTS local_data jsonb DEFAULT '{}'::jsonb;
