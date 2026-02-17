-- Enable Realtime for chat_messages so clients can subscribe to new messages.
-- Run after 001_full_schema.sql.
-- If ALTER PUBLICATION is not allowed (managed Supabase), add public.chat_messages
-- in Dashboard: Database > Replication > supabase_realtime > Add table.

ALTER PUBLICATION supabase_realtime ADD TABLE public.chat_messages;
