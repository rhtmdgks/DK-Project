-- Reduce public/anon read exposure for production hardening.

-- 1) Announcements should not be globally readable by anon/public.
drop policy if exists "Anon can read announcements" on public.announcements;
drop policy if exists "Allow all to read announcements for Realtime" on public.announcements;

-- Keep authenticated read only.
drop policy if exists "Authenticated users can read announcements" on public.announcements;
create policy "Authenticated users can read announcements"
  on public.announcements for select to authenticated using (true);

-- 2) poll_votes should not be anonymous-readable.
drop policy if exists "Anon can read poll votes for display" on public.poll_votes;

-- 3) Author-enriched poll comments RPC should not be executable by anon.
revoke execute on function public.get_poll_comments_with_authors(uuid) from anon;
grant execute on function public.get_poll_comments_with_authors(uuid) to authenticated;
