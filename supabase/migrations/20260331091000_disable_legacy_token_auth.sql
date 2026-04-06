-- Security hardening: disable legacy password/token RPC auth paths.
-- Student ID + password login remains, but must go through Supabase Auth signInWithPassword only.

revoke execute on function public.login_from_profiles(text, text) from anon, authenticated;
revoke execute on function public.insert_suggestion_by_token(uuid, text, text) from anon, authenticated;
revoke execute on function public.insert_suggestion_by_credentials(text, text, text, text) from anon, authenticated;
revoke execute on function public.insert_poll_vote_by_token(uuid, uuid, int) from anon, authenticated;
revoke execute on function public.get_poll_vote_by_token(uuid, uuid) from anon, authenticated;
revoke execute on function public.insert_poll_comment_by_token(uuid, uuid, text) from anon, authenticated;
revoke execute on function public.get_poll_likes_by_token(uuid) from anon, authenticated;

-- Force like toggle RPC to authenticated sessions only.
revoke execute on function public.toggle_poll_like(uuid, uuid) from anon;
grant execute on function public.toggle_poll_like(uuid, uuid) to authenticated;

-- Remove anonymous poll comment read policy introduced for session-token mode.
drop policy if exists "Anon can read poll comments" on public.poll_comments;
