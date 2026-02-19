-- =============================================================================
-- 공지사항 Realtime 알림: anon 구독자도 INSERT 이벤트를 받도록 SELECT 허용
-- =============================================================================
-- Realtime은 RLS를 적용해, 구독자에게 전달할 때 해당 역할이 해당 행을
-- SELECT 할 수 있어야만 이벤트를 보냅니다. 기존에는 TO authenticated 만
-- 있어서, 앱이 anon(세션 없음)이면 백오피스에서 공지를 올려도 알림이 오지 않습니다.
-- anon도 공지사항 SELECT를 허용하면 Realtime 구독 시 INSERT 이벤트를 받을 수 있습니다.

CREATE POLICY "Anon can read announcements"
  ON public.announcements FOR SELECT
  TO anon
  USING (true);
