-- =============================================================================
-- 멀티스쿨 1단계 (8/8): role 참조 정책 헬퍼화 + RESTRICTIVE 테넌트 격리
-- =============================================================================
-- ① 가드: school_id backfill 누락 행이 있으면 트랜잭션 전체 실패 (행 증발 사고 방지)
-- ② 라이브 pg_policy 덤프(2026-07-18) 기준으로 role 문자열 정책을 동일 의미의
--    헬퍼 함수 기반으로 재작성 — 레거시('admin','council')와 신규 role 값 모두 허용.
--    * 'admin' → is_school_admin()  (school_admin/super_admin 포섭)
--    * 'council','admin' → has_council() OR is_school_admin()
--    * 'council','admin','teacher' → is_council_or_staff()
--    * class_photo_shares 3개 정책은 의도적으로 유보 (학번 파싱 로직 얽힘 — 2단계)
-- ③ tenant_isolation_<table> RESTRICTIVE 정책 (AND 결합, TO authenticated 한정).
--    anon 에는 걸지 않음: current_school_id() 가 NULL 이라 전면 차단되어
--    구앱의 로그인 전 조회(announcements/poll_votes anon 정책)가 깨지기 때문.
--    profiles·모더레이션 로그류·자식 테이블(부모 경유 격리)도 유보 — 계획 문서 참조.

-- ---------------------------------------------------------------------------
-- ① backfill 가드
-- ---------------------------------------------------------------------------
DO $$
DECLARE
  t text;
  v_cnt bigint;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'announcements','polls','suggestions','schedule_items','class_events',
    'class_photo_shares','opinion_campaigns','greeting_messages',
    'class_timetable','timetable_master','timetable_entries','subjects',
    'subject_divisions','assignments','student_enrollments',
    'timetable_swap_requests','timetable_makeup_requests',
    'chat_rooms','personal_events','bug_reports','fcm_tokens',
    'meal_departure_schedules'
  ] LOOP
    EXECUTE format('SELECT count(*) FROM public.%I WHERE school_id IS NULL', t) INTO v_cnt;
    IF v_cnt > 0 THEN
      RAISE EXCEPTION 'school_id backfill incomplete: %.% rows NULL', t, v_cnt;
    END IF;
  END LOOP;
  IF (SELECT count(*) FROM public.profiles WHERE school_id IS NULL) > 0 THEN
    RAISE EXCEPTION 'school_id backfill incomplete: profiles';
  END IF;
END $$;

-- ---------------------------------------------------------------------------
-- ② permissive 정책 헬퍼화 (이름/커맨드/대상 role 동일, 표현식만 교체)
-- ---------------------------------------------------------------------------

-- announcements (TO authenticated)
DROP POLICY IF EXISTS "Council or admin can delete announcements" ON public.announcements;
CREATE POLICY "Council or admin can delete announcements" ON public.announcements
  FOR DELETE TO authenticated
  USING ((SELECT public.has_council()) OR (SELECT public.is_school_admin()));

DROP POLICY IF EXISTS "Council or admin can insert announcements" ON public.announcements;
CREATE POLICY "Council or admin can insert announcements" ON public.announcements
  FOR INSERT TO authenticated
  WITH CHECK ((SELECT public.has_council()) OR (SELECT public.is_school_admin()));

DROP POLICY IF EXISTS "Council or admin can update announcements" ON public.announcements;
CREATE POLICY "Council or admin can update announcements" ON public.announcements
  FOR UPDATE TO authenticated
  USING ((SELECT public.has_council()) OR (SELECT public.is_school_admin()));

-- polls (TO authenticated)
DROP POLICY IF EXISTS "Council or admin can delete polls" ON public.polls;
CREATE POLICY "Council or admin can delete polls" ON public.polls
  FOR DELETE TO authenticated
  USING ((SELECT public.has_council()) OR (SELECT public.is_school_admin()));

DROP POLICY IF EXISTS "Council or admin can insert polls" ON public.polls;
CREATE POLICY "Council or admin can insert polls" ON public.polls
  FOR INSERT TO authenticated
  WITH CHECK ((SELECT public.has_council()) OR (SELECT public.is_school_admin()));

DROP POLICY IF EXISTS "Council or admin can update polls" ON public.polls;
CREATE POLICY "Council or admin can update polls" ON public.polls
  FOR UPDATE TO authenticated
  USING ((SELECT public.has_council()) OR (SELECT public.is_school_admin()));

-- assignments (PUBLIC — 라이브와 동일하게 TO 절 없음)
DROP POLICY IF EXISTS "Admin can delete assignments" ON public.assignments;
CREATE POLICY "Admin can delete assignments" ON public.assignments
  FOR DELETE USING ((SELECT public.is_school_admin()));

DROP POLICY IF EXISTS "Admin can insert assignments" ON public.assignments;
CREATE POLICY "Admin can insert assignments" ON public.assignments
  FOR INSERT WITH CHECK ((SELECT public.is_school_admin()));

DROP POLICY IF EXISTS "Admin can update assignments" ON public.assignments;
CREATE POLICY "Admin can update assignments" ON public.assignments
  FOR UPDATE USING ((SELECT public.is_school_admin()));

DROP POLICY IF EXISTS "Enrolled students can read assignments" ON public.assignments;
CREATE POLICY "Enrolled students can read assignments" ON public.assignments
  FOR SELECT USING (
    (EXISTS ( SELECT 1
       FROM student_enrollments se
      WHERE ((se.division_id = assignments.division_id) AND (se.profile_id IN ( SELECT profiles.id
               FROM profiles
              WHERE (profiles.user_id = auth.uid()))))))
    OR (SELECT public.is_school_admin())
  );

-- bug_reports (TO authenticated)
DROP POLICY IF EXISTS "Admins can update all bug reports" ON public.bug_reports;
CREATE POLICY "Admins can update all bug reports" ON public.bug_reports
  FOR UPDATE TO authenticated
  USING ((SELECT public.is_school_admin()));

DROP POLICY IF EXISTS "Admins can view all bug reports" ON public.bug_reports;
CREATE POLICY "Admins can view all bug reports" ON public.bug_reports
  FOR SELECT TO authenticated
  USING ((SELECT public.is_school_admin()));

-- chat_rooms / chat_room_members (TO authenticated)
DROP POLICY IF EXISTS "Council or admin can insert chat rooms" ON public.chat_rooms;
CREATE POLICY "Council or admin can insert chat rooms" ON public.chat_rooms
  FOR INSERT TO authenticated
  WITH CHECK ((SELECT public.has_council()) OR (SELECT public.is_school_admin()));

DROP POLICY IF EXISTS "Council or admin can insert chat room members" ON public.chat_room_members;
CREATE POLICY "Council or admin can insert chat room members" ON public.chat_room_members
  FOR INSERT TO authenticated
  WITH CHECK ((SELECT public.has_council()) OR (SELECT public.is_school_admin()));

-- class_events (TO authenticated)
DROP POLICY IF EXISTS "Creators or admins can delete class events" ON public.class_events;
CREATE POLICY "Creators or admins can delete class events" ON public.class_events
  FOR DELETE TO authenticated
  USING ((auth.uid() = created_by_user_id) OR (SELECT public.is_school_admin()));

DROP POLICY IF EXISTS "Creators or admins can update class events" ON public.class_events;
CREATE POLICY "Creators or admins can update class events" ON public.class_events
  FOR UPDATE TO authenticated
  USING ((auth.uid() = created_by_user_id) OR (SELECT public.is_school_admin()))
  WITH CHECK ((auth.uid() = created_by_user_id) OR (SELECT public.is_school_admin()));

-- moderation_keywords (TO authenticated)
DROP POLICY IF EXISTS "Council admin manage moderation keywords" ON public.moderation_keywords;
CREATE POLICY "Council admin manage moderation keywords" ON public.moderation_keywords
  FOR ALL TO authenticated
  USING ((SELECT public.has_council()) OR (SELECT public.is_school_admin()))
  WITH CHECK ((SELECT public.has_council()) OR (SELECT public.is_school_admin()));

-- opinion_campaigns / opinion_submissions (TO authenticated)
DROP POLICY IF EXISTS "Council admin manage campaigns" ON public.opinion_campaigns;
CREATE POLICY "Council admin manage campaigns" ON public.opinion_campaigns
  FOR ALL TO authenticated
  USING ((SELECT public.has_council()) OR (SELECT public.is_school_admin()))
  WITH CHECK ((SELECT public.has_council()) OR (SELECT public.is_school_admin()));

DROP POLICY IF EXISTS "Students read open campaigns" ON public.opinion_campaigns;
CREATE POLICY "Students read open campaigns" ON public.opinion_campaigns
  FOR SELECT TO authenticated
  USING ((status = 'open'::text)
         OR (SELECT public.has_council()) OR (SELECT public.is_school_admin()));

DROP POLICY IF EXISTS "Read own submissions or staff" ON public.opinion_submissions;
CREATE POLICY "Read own submissions or staff" ON public.opinion_submissions
  FOR SELECT TO authenticated
  USING (
    (author_id IN ( SELECT profiles.id FROM profiles WHERE (profiles.user_id = auth.uid())))
    OR (SELECT public.has_council()) OR (SELECT public.is_school_admin())
  );

-- schedule_items (TO authenticated)
DROP POLICY IF EXISTS "Council admin teacher can delete schedule" ON public.schedule_items;
CREATE POLICY "Council admin teacher can delete schedule" ON public.schedule_items
  FOR DELETE TO authenticated
  USING ((SELECT public.is_council_or_staff()));

DROP POLICY IF EXISTS "Council admin teacher can insert schedule" ON public.schedule_items;
CREATE POLICY "Council admin teacher can insert schedule" ON public.schedule_items
  FOR INSERT TO authenticated
  WITH CHECK ((SELECT public.is_council_or_staff()));

DROP POLICY IF EXISTS "Council admin teacher can update schedule" ON public.schedule_items;
CREATE POLICY "Council admin teacher can update schedule" ON public.schedule_items
  FOR UPDATE TO authenticated
  USING ((SELECT public.is_council_or_staff()));

-- student_enrollments / subject_divisions / subjects (PUBLIC)
DROP POLICY IF EXISTS "Admin can manage enrollments" ON public.student_enrollments;
CREATE POLICY "Admin can manage enrollments" ON public.student_enrollments
  FOR ALL USING ((SELECT public.is_school_admin()));

DROP POLICY IF EXISTS "Users can read own enrollments" ON public.student_enrollments;
CREATE POLICY "Users can read own enrollments" ON public.student_enrollments
  FOR SELECT USING (
    (profile_id IN ( SELECT profiles.id FROM profiles WHERE (profiles.user_id = auth.uid())))
    OR (SELECT public.is_school_admin())
  );

DROP POLICY IF EXISTS "Admin can manage divisions" ON public.subject_divisions;
CREATE POLICY "Admin can manage divisions" ON public.subject_divisions
  FOR ALL USING ((SELECT public.is_school_admin()));

DROP POLICY IF EXISTS "Admin can manage subjects" ON public.subjects;
CREATE POLICY "Admin can manage subjects" ON public.subjects
  FOR ALL USING ((SELECT public.is_school_admin()));

-- suggestion_comments (PUBLIC)
DROP POLICY IF EXISTS "Users can read suggestion comments" ON public.suggestion_comments;
CREATE POLICY "Users can read suggestion comments" ON public.suggestion_comments
  FOR SELECT USING (
    EXISTS ( SELECT 1
       FROM suggestions s
      WHERE ((s.id = suggestion_comments.suggestion_id)
        AND ((s.author_id IN ( SELECT profiles.id FROM profiles WHERE (profiles.user_id = auth.uid())))
             OR (SELECT public.has_council()) OR (SELECT public.is_school_admin()))))
  );

-- timetable_entries (PUBLIC)
DROP POLICY IF EXISTS "Admin/council can delete timetable entries" ON public.timetable_entries;
CREATE POLICY "Admin/council can delete timetable entries" ON public.timetable_entries
  FOR DELETE USING ((SELECT public.has_council()) OR (SELECT public.is_school_admin()));

DROP POLICY IF EXISTS "Admin/council can insert timetable entries for any user" ON public.timetable_entries;
CREATE POLICY "Admin/council can insert timetable entries for any user" ON public.timetable_entries
  FOR INSERT WITH CHECK ((SELECT public.has_council()) OR (SELECT public.is_school_admin()));

DROP POLICY IF EXISTS "Admin/council can update timetable entries" ON public.timetable_entries;
CREATE POLICY "Admin/council can update timetable entries" ON public.timetable_entries
  FOR UPDATE
  USING ((SELECT public.has_council()) OR (SELECT public.is_school_admin()))
  WITH CHECK ((SELECT public.has_council()) OR (SELECT public.is_school_admin()));

-- ---------------------------------------------------------------------------
-- ③ RESTRICTIVE 테넌트 격리 (TO authenticated, 기존 permissive 와 AND 결합)
-- ---------------------------------------------------------------------------
DO $$
DECLARE
  t text;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'announcements','polls','suggestions','schedule_items','class_events',
    'class_photo_shares','opinion_campaigns','greeting_messages',
    'class_timetable','timetable_master','timetable_entries','subjects',
    'subject_divisions','assignments','student_enrollments',
    'timetable_swap_requests','timetable_makeup_requests',
    'chat_rooms','personal_events','bug_reports','fcm_tokens',
    'meal_departure_schedules'
  ] LOOP
    EXECUTE format('DROP POLICY IF EXISTS tenant_isolation_%I ON public.%I', t, t);
    EXECUTE format(
      'CREATE POLICY tenant_isolation_%I ON public.%I
         AS RESTRICTIVE FOR ALL TO authenticated
         USING ((SELECT public.same_school(school_id)))
         WITH CHECK ((SELECT public.same_school(school_id)))', t, t
    );
  END LOOP;
END $$;

-- moderation_keywords: NULL = 전역 금칙어 허용 변형
DROP POLICY IF EXISTS tenant_isolation_moderation_keywords ON public.moderation_keywords;
CREATE POLICY tenant_isolation_moderation_keywords ON public.moderation_keywords
  AS RESTRICTIVE FOR ALL TO authenticated
  USING (school_id IS NULL OR (SELECT public.same_school(school_id)))
  WITH CHECK (school_id IS NULL OR (SELECT public.same_school(school_id)));
