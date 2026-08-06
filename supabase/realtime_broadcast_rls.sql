-- REDHOG: Supabase Realtime (optional — ใช้เมื่อตั้ง private channel)
-- ตอนนี้เกมใช้ public channel (private: false) ไม่จำเป็นต้องรัน SQL นี้
-- ยกเว้น Realtime Settings ปิด "Allow public access" ไว้

-- ลบ policy เก่าชื่อเดียวกัน (ถ้ามี) แล้วสร้างใหม่
DROP POLICY IF EXISTS "redhog_broadcast_select" ON realtime.messages;
DROP POLICY IF EXISTS "redhog_broadcast_insert" ON realtime.messages;

-- อนุญาต user ที่ login แล้ว รับ broadcast ทุก channel
CREATE POLICY "redhog_broadcast_select"
ON realtime.messages FOR SELECT
TO authenticated
USING (extension = 'broadcast');

-- อนุญาต user ที่ login แล้ว ส่ง broadcast ทุก channel
CREATE POLICY "redhog_broadcast_insert"
ON realtime.messages FOR INSERT
TO authenticated
WITH CHECK (extension = 'broadcast');
