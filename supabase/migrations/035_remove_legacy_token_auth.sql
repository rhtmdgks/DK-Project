-- Remove legacy credential/token based auth RPCs.
-- The app now relies on Supabase Auth session only.

DROP FUNCTION IF EXISTS public.login_from_profiles(text, text);
DROP FUNCTION IF EXISTS public.insert_suggestion_by_credentials(text, text, text, text);
DROP FUNCTION IF EXISTS public.insert_suggestion_by_token(uuid, text, text);
DROP FUNCTION IF EXISTS public.insert_poll_vote_by_token(uuid, uuid, int);
DROP FUNCTION IF EXISTS public.get_poll_vote_by_token(uuid, uuid);
DROP FUNCTION IF EXISTS public.get_poll_likes_by_token(uuid);
DROP FUNCTION IF EXISTS public.insert_poll_comment_by_token(uuid, uuid, text);
DROP FUNCTION IF EXISTS public.insert_personal_event_by_token(uuid, text, text, timestamptz, timestamptz, boolean);
DROP FUNCTION IF EXISTS public.get_personal_events_by_token(uuid);

DROP TABLE IF EXISTS public.profile_session_tokens;
