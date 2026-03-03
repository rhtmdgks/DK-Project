-- =============================================================================
-- timetable_entries: Admin/Council가 다른 사용자(학생) 시간표 INSERT/UPDATE/DELETE 허용
-- 백오피스에서 관리자 로그인 상태로 학생별 시간표 저장 시 RLS 통과하도록 함.
-- =============================================================================

CREATE POLICY "Admin/council can insert timetable entries for any user"
  ON public.timetable_entries FOR INSERT
  WITH CHECK (
    EXISTS (SELECT 1 FROM public.profiles WHERE user_id = auth.uid() AND role IN ('council', 'admin'))
  );

CREATE POLICY "Admin/council can update timetable entries"
  ON public.timetable_entries FOR UPDATE
  USING (
    EXISTS (SELECT 1 FROM public.profiles WHERE user_id = auth.uid() AND role IN ('council', 'admin'))
  )
  WITH CHECK (
    EXISTS (SELECT 1 FROM public.profiles WHERE user_id = auth.uid() AND role IN ('council', 'admin'))
  );

CREATE POLICY "Admin/council can delete timetable entries"
  ON public.timetable_entries FOR DELETE
  USING (
    EXISTS (SELECT 1 FROM public.profiles WHERE user_id = auth.uid() AND role IN ('council', 'admin'))
  );
