-- =============================================================================
-- 멀티스쿨 1단계 (4/8): 학교 스코프 테이블에 school_id 추가 + backfill
-- =============================================================================
-- 패턴: 컬럼 추가(NULL 허용, DEFAULT 없음 → 테이블 rewrite 없음) → 기본 학교로 backfill
--       → 인덱스. 모두 additive.
-- 대상 제외:
--  * 자식 테이블(poll_votes/poll_likes/poll_comments, suggestion_comments,
--    chat_room_members/chat_messages, personal_event_attachments, opinion_submissions,
--    timetable_*_reason_logs): 부모 FK 경유로 격리 전이 — 컬럼 불필요
--  * public_holidays: 대한민국 공휴일 전역 공통
--  * moderation_keywords: 컬럼은 추가하되 NULL=전역 금칙어 의미론 (backfill 하지 않음)
-- 주의: class_timetable 의 기존 unique 제약은 절대 교체하지 않는다
--       (sync_timetable_entries_from_class_fn 의 ON CONFLICT 가 제약 컬럼에 바인딩됨. 2단계에서 처리)

-- ---- 콘텐츠 루트 ----
ALTER TABLE public.announcements       ADD COLUMN IF NOT EXISTS school_id uuid REFERENCES public.schools(id);
ALTER TABLE public.polls               ADD COLUMN IF NOT EXISTS school_id uuid REFERENCES public.schools(id);
ALTER TABLE public.suggestions         ADD COLUMN IF NOT EXISTS school_id uuid REFERENCES public.schools(id);
ALTER TABLE public.schedule_items      ADD COLUMN IF NOT EXISTS school_id uuid REFERENCES public.schools(id);
ALTER TABLE public.class_events        ADD COLUMN IF NOT EXISTS school_id uuid REFERENCES public.schools(id);
ALTER TABLE public.class_photo_shares  ADD COLUMN IF NOT EXISTS school_id uuid REFERENCES public.schools(id);
ALTER TABLE public.opinion_campaigns   ADD COLUMN IF NOT EXISTS school_id uuid REFERENCES public.schools(id);
ALTER TABLE public.greeting_messages   ADD COLUMN IF NOT EXISTS school_id uuid REFERENCES public.schools(id);

-- ---- 시간표 / 학사 ----
ALTER TABLE public.class_timetable            ADD COLUMN IF NOT EXISTS school_id uuid REFERENCES public.schools(id);
ALTER TABLE public.timetable_master           ADD COLUMN IF NOT EXISTS school_id uuid REFERENCES public.schools(id);
ALTER TABLE public.timetable_entries          ADD COLUMN IF NOT EXISTS school_id uuid REFERENCES public.schools(id);
ALTER TABLE public.subjects                   ADD COLUMN IF NOT EXISTS school_id uuid REFERENCES public.schools(id);
ALTER TABLE public.subject_divisions          ADD COLUMN IF NOT EXISTS school_id uuid REFERENCES public.schools(id);
ALTER TABLE public.assignments                ADD COLUMN IF NOT EXISTS school_id uuid REFERENCES public.schools(id);
ALTER TABLE public.student_enrollments        ADD COLUMN IF NOT EXISTS school_id uuid REFERENCES public.schools(id);
ALTER TABLE public.timetable_swap_requests    ADD COLUMN IF NOT EXISTS school_id uuid REFERENCES public.schools(id);
ALTER TABLE public.timetable_makeup_requests  ADD COLUMN IF NOT EXISTS school_id uuid REFERENCES public.schools(id);

-- ---- 채팅 루트 / 개인 / 운영 ----
ALTER TABLE public.chat_rooms               ADD COLUMN IF NOT EXISTS school_id uuid REFERENCES public.schools(id);
ALTER TABLE public.personal_events          ADD COLUMN IF NOT EXISTS school_id uuid REFERENCES public.schools(id);
ALTER TABLE public.bug_reports              ADD COLUMN IF NOT EXISTS school_id uuid REFERENCES public.schools(id);
ALTER TABLE public.backoffice_accounts      ADD COLUMN IF NOT EXISTS school_id uuid REFERENCES public.schools(id);
ALTER TABLE public.fcm_tokens               ADD COLUMN IF NOT EXISTS school_id uuid REFERENCES public.schools(id);
ALTER TABLE public.meal_departure_schedules ADD COLUMN IF NOT EXISTS school_id uuid REFERENCES public.schools(id);
ALTER TABLE public.meal_departure_logs      ADD COLUMN IF NOT EXISTS school_id uuid REFERENCES public.schools(id);

-- ---- 모더레이션 ----
ALTER TABLE public.content_reports       ADD COLUMN IF NOT EXISTS school_id uuid REFERENCES public.schools(id);
ALTER TABLE public.moderation_actions    ADD COLUMN IF NOT EXISTS school_id uuid REFERENCES public.schools(id);
ALTER TABLE public.banned_users          ADD COLUMN IF NOT EXISTS school_id uuid REFERENCES public.schools(id);
ALTER TABLE public.content_tombstones    ADD COLUMN IF NOT EXISTS school_id uuid REFERENCES public.schools(id);
ALTER TABLE public.account_deletion_logs ADD COLUMN IF NOT EXISTS school_id uuid REFERENCES public.schools(id);
ALTER TABLE public.moderation_keywords   ADD COLUMN IF NOT EXISTS school_id uuid REFERENCES public.schools(id);
COMMENT ON COLUMN public.moderation_keywords.school_id IS 'NULL = 전역 금칙어(모든 학교 적용)';

-- ---- backfill (moderation_keywords 제외) ----
DO $$
DECLARE
  v_default uuid;
  t text;
BEGIN
  SELECT id INTO v_default FROM public.schools WHERE is_default LIMIT 1;
  IF v_default IS NULL THEN
    RAISE EXCEPTION 'default school missing: run 20260718100000 first';
  END IF;

  FOREACH t IN ARRAY ARRAY[
    'announcements','polls','suggestions','schedule_items','class_events',
    'class_photo_shares','opinion_campaigns','greeting_messages',
    'class_timetable','timetable_master','timetable_entries','subjects',
    'subject_divisions','assignments','student_enrollments',
    'timetable_swap_requests','timetable_makeup_requests',
    'chat_rooms','personal_events','bug_reports','backoffice_accounts',
    'fcm_tokens','meal_departure_schedules','meal_departure_logs',
    'content_reports','moderation_actions','banned_users',
    'content_tombstones','account_deletion_logs'
  ] LOOP
    EXECUTE format(
      'UPDATE public.%I SET school_id = $1 WHERE school_id IS NULL', t
    ) USING v_default;
  END LOOP;
END $$;

-- ---- 인덱스 ----
CREATE INDEX IF NOT EXISTS announcements_school_id_idx       ON public.announcements (school_id);
CREATE INDEX IF NOT EXISTS polls_school_id_idx               ON public.polls (school_id);
CREATE INDEX IF NOT EXISTS suggestions_school_id_idx         ON public.suggestions (school_id);
CREATE INDEX IF NOT EXISTS schedule_items_school_id_idx      ON public.schedule_items (school_id);
CREATE INDEX IF NOT EXISTS class_events_school_id_idx        ON public.class_events (school_id);
CREATE INDEX IF NOT EXISTS class_photo_shares_school_id_idx  ON public.class_photo_shares (school_id);
CREATE INDEX IF NOT EXISTS opinion_campaigns_school_id_idx   ON public.opinion_campaigns (school_id);
CREATE INDEX IF NOT EXISTS greeting_messages_school_id_idx   ON public.greeting_messages (school_id);
CREATE INDEX IF NOT EXISTS timetable_master_school_id_idx    ON public.timetable_master (school_id);
CREATE INDEX IF NOT EXISTS subjects_school_id_idx            ON public.subjects (school_id);
CREATE INDEX IF NOT EXISTS subject_divisions_school_id_idx   ON public.subject_divisions (school_id);
CREATE INDEX IF NOT EXISTS assignments_school_id_idx         ON public.assignments (school_id);
CREATE INDEX IF NOT EXISTS student_enrollments_school_id_idx ON public.student_enrollments (school_id);
CREATE INDEX IF NOT EXISTS timetable_swap_requests_school_id_idx   ON public.timetable_swap_requests (school_id);
CREATE INDEX IF NOT EXISTS timetable_makeup_requests_school_id_idx ON public.timetable_makeup_requests (school_id);
CREATE INDEX IF NOT EXISTS chat_rooms_school_id_idx          ON public.chat_rooms (school_id);
CREATE INDEX IF NOT EXISTS personal_events_school_id_idx     ON public.personal_events (school_id);
CREATE INDEX IF NOT EXISTS bug_reports_school_id_idx         ON public.bug_reports (school_id);
CREATE INDEX IF NOT EXISTS backoffice_accounts_school_id_idx ON public.backoffice_accounts (school_id);
CREATE INDEX IF NOT EXISTS meal_departure_schedules_school_id_idx ON public.meal_departure_schedules (school_id);
CREATE INDEX IF NOT EXISTS meal_departure_logs_school_id_idx ON public.meal_departure_logs (school_id);
CREATE INDEX IF NOT EXISTS content_reports_school_id_idx     ON public.content_reports (school_id);
CREATE INDEX IF NOT EXISTS moderation_actions_school_id_idx  ON public.moderation_actions (school_id);
CREATE INDEX IF NOT EXISTS banned_users_school_id_idx        ON public.banned_users (school_id);
CREATE INDEX IF NOT EXISTS content_tombstones_school_id_idx  ON public.content_tombstones (school_id);
CREATE INDEX IF NOT EXISTS account_deletion_logs_school_id_idx ON public.account_deletion_logs (school_id);
CREATE INDEX IF NOT EXISTS moderation_keywords_school_id_idx ON public.moderation_keywords (school_id);

-- 핫패스 복합 인덱스
CREATE INDEX IF NOT EXISTS class_timetable_school_lookup_idx
  ON public.class_timetable (school_id, grade, class_number, week_offset);
CREATE INDEX IF NOT EXISTS fcm_tokens_school_class_idx
  ON public.fcm_tokens (school_id, grade, class_number);
CREATE INDEX IF NOT EXISTS announcements_school_target_idx
  ON public.announcements (school_id, target_grade, target_class_number);
CREATE INDEX IF NOT EXISTS timetable_entries_school_user_idx
  ON public.timetable_entries (school_id, user_id);
