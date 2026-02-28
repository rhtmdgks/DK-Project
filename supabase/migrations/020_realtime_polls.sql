-- Enable Realtime for polls so Flutter 앱 can refresh when 백오피스 creates/updates/deletes.
-- Idempotent: skip if polls is already in the publication (e.g. added via Dashboard).
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND tablename = 'polls'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.polls;
  END IF;
END $$;
