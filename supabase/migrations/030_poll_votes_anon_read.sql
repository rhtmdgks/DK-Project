-- 앱이 anon(세션 토큰 로그인)일 때도 투표 목록에서 옵션별 투표자 아바타를 표시하려면
-- poll_votes SELECT가 anon에게도 허용되어야 함.
CREATE POLICY "Anon can read poll votes for display"
  ON public.poll_votes FOR SELECT
  TO anon
  USING (true);
