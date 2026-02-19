-- Enable Realtime for announcements and schedule_items so clients can subscribe to new data.
-- Run after 001_full_schema.sql.
-- If ALTER PUBLICATION is not allowed (managed Supabase), add tables
-- in Dashboard: Database > Replication > supabase_realtime > Add table.

ALTER PUBLICATION supabase_realtime ADD TABLE public.announcements;
ALTER PUBLICATION supabase_realtime ADD TABLE public.schedule_items;
