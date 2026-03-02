-- =============================================================================
-- 시간표 변경 로그 테이블 + RLS: profiles.class_number 사용
-- =============================================================================
-- 1) 테이블이 없으면 생성 (백오피스 등 다른 마이그레이션과 중복 가능).
-- 2) RLS 정책이 profiles.class_num을 참조하면 42703 오류가 나므로,
--    기존 정책을 제거하고 profiles.class_number 기준으로 재생성.

-- 1. 테이블 (없을 때만 생성)
CREATE TABLE IF NOT EXISTS public.class_timetable_change_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  grade smallint NOT NULL,
  class_number smallint NOT NULL,
  week_offset smallint NOT NULL DEFAULT 0,
  day_of_week smallint NOT NULL,
  period smallint NOT NULL,
  previous_subject text,
  previous_teacher text,
  new_subject text NOT NULL,
  new_teacher text,
  reason text,
  changed_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.class_timetable_change_logs ENABLE ROW LEVEL SECURITY;

-- 2. 기존 정책 제거 후 해당 반 학생만 조회 가능하도록 정책 생성 (profiles.class_number 사용)
DROP POLICY IF EXISTS "Students can read own class timetable change logs" ON public.class_timetable_change_logs;
DROP POLICY IF EXISTS "Allow students to read own class timetable change logs" ON public.class_timetable_change_logs;
DROP POLICY IF EXISTS "Students can read class timetable change logs for own class" ON public.class_timetable_change_logs;

CREATE POLICY "Students can read own class timetable change logs"
  ON public.class_timetable_change_logs FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE profiles.user_id = auth.uid()
        AND profiles.grade = class_timetable_change_logs.grade
        AND profiles.class_number = class_timetable_change_logs.class_number
    )
  );
