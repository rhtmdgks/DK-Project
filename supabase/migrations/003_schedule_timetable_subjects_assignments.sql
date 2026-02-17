-- =============================================================================
-- UTILITY: set_updated_at trigger function
-- =============================================================================
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

-- =============================================================================
-- TIMETABLE ENTRIES (개인별 주간 시간표 — 고교학점제 대응)
-- =============================================================================
CREATE TABLE public.timetable_entries (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  day_of_week smallint NOT NULL CHECK (day_of_week >= 0 AND day_of_week <= 6),
  period smallint NOT NULL CHECK (period >= 1 AND period <= 20),
  subject text NOT NULL,
  room text,
  teacher text,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(user_id, day_of_week, period)
);

CREATE INDEX idx_timetable_entries_user_id ON public.timetable_entries(user_id);
CREATE INDEX idx_timetable_entries_user_day ON public.timetable_entries(user_id, day_of_week);

ALTER TABLE public.timetable_entries ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can read own timetable"
  ON public.timetable_entries FOR SELECT
  USING (
    auth.uid() = user_id
    OR EXISTS (SELECT 1 FROM public.profiles WHERE user_id = auth.uid() AND role IN ('council', 'admin'))
  );

CREATE POLICY "Users can insert own timetable"
  ON public.timetable_entries FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own timetable"
  ON public.timetable_entries FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete own timetable"
  ON public.timetable_entries FOR DELETE
  USING (auth.uid() = user_id);

-- =============================================================================
-- SUBJECTS (과목 카탈로그 — 고교학점제)
-- =============================================================================
CREATE TABLE public.subjects (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  code text NOT NULL UNIQUE,
  name text NOT NULL,
  category text,
  year int NOT NULL DEFAULT 2026,
  semester int NOT NULL DEFAULT 1 CHECK (semester IN (1, 2)),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_subjects_year_semester ON public.subjects(year, semester);

ALTER TABLE public.subjects ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Authenticated can read subjects"
  ON public.subjects FOR SELECT TO authenticated USING (true);

CREATE POLICY "Admin can manage subjects"
  ON public.subjects FOR ALL
  USING (EXISTS (SELECT 1 FROM public.profiles WHERE user_id = auth.uid() AND role = 'admin'));

-- =============================================================================
-- SUBJECT DIVISIONS (분반 — 같은 과목 여러 분반, 교사별)
-- =============================================================================
CREATE TABLE public.subject_divisions (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  subject_id uuid NOT NULL REFERENCES public.subjects(id) ON DELETE CASCADE,
  division_name text NOT NULL DEFAULT '1분반',
  teacher_name text,
  room text,
  max_students int,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(subject_id, division_name)
);

CREATE INDEX idx_subject_divisions_subject_id ON public.subject_divisions(subject_id);

ALTER TABLE public.subject_divisions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Authenticated can read divisions"
  ON public.subject_divisions FOR SELECT TO authenticated USING (true);

CREATE POLICY "Admin can manage divisions"
  ON public.subject_divisions FOR ALL
  USING (EXISTS (SELECT 1 FROM public.profiles WHERE user_id = auth.uid() AND role = 'admin'));

-- =============================================================================
-- STUDENT ENROLLMENTS (학생 수강 등록 — 분반 배정)
-- =============================================================================
CREATE TABLE public.student_enrollments (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  profile_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  division_id uuid NOT NULL REFERENCES public.subject_divisions(id) ON DELETE CASCADE,
  enrolled_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(profile_id, division_id)
);

CREATE INDEX idx_student_enrollments_profile_id ON public.student_enrollments(profile_id);
CREATE INDEX idx_student_enrollments_division_id ON public.student_enrollments(division_id);

ALTER TABLE public.student_enrollments ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can read own enrollments"
  ON public.student_enrollments FOR SELECT
  USING (
    profile_id IN (SELECT id FROM public.profiles WHERE user_id = auth.uid())
    OR EXISTS (SELECT 1 FROM public.profiles WHERE user_id = auth.uid() AND role = 'admin')
  );

CREATE POLICY "Admin can manage enrollments"
  ON public.student_enrollments FOR ALL
  USING (EXISTS (SELECT 1 FROM public.profiles WHERE user_id = auth.uid() AND role = 'admin'));

-- =============================================================================
-- ASSIGNMENTS (과제 — 선생님이 분반별 부여, 학생이 확인)
-- =============================================================================
CREATE TABLE public.assignments (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  division_id uuid NOT NULL REFERENCES public.subject_divisions(id) ON DELETE CASCADE,
  title text NOT NULL,
  description text,
  due_at timestamptz,
  attachment_url text,
  created_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_assignments_division_id ON public.assignments(division_id);
CREATE INDEX idx_assignments_due_at ON public.assignments(due_at);
CREATE INDEX idx_assignments_created_by ON public.assignments(created_by);

ALTER TABLE public.assignments ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Enrolled students can read assignments"
  ON public.assignments FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.student_enrollments se
      WHERE se.division_id = assignments.division_id
        AND se.profile_id IN (SELECT id FROM public.profiles WHERE user_id = auth.uid())
    )
    OR EXISTS (SELECT 1 FROM public.profiles WHERE user_id = auth.uid() AND role = 'admin')
  );

CREATE POLICY "Admin can insert assignments"
  ON public.assignments FOR INSERT
  WITH CHECK (
    EXISTS (SELECT 1 FROM public.profiles WHERE user_id = auth.uid() AND role = 'admin')
  );

CREATE POLICY "Admin can update assignments"
  ON public.assignments FOR UPDATE
  USING (EXISTS (SELECT 1 FROM public.profiles WHERE user_id = auth.uid() AND role = 'admin'));

CREATE POLICY "Admin can delete assignments"
  ON public.assignments FOR DELETE
  USING (EXISTS (SELECT 1 FROM public.profiles WHERE user_id = auth.uid() AND role = 'admin'));

CREATE TRIGGER assignments_updated_at
  BEFORE UPDATE ON public.assignments
  FOR EACH ROW
  EXECUTE FUNCTION public.set_updated_at();

-- =============================================================================
-- PERSONAL EVENTS (개인 일정 — 학생/교사 자유 추가, 향후 Google Calendar 연동)
-- =============================================================================
CREATE TABLE public.personal_events (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  title text NOT NULL,
  description text,
  start_at timestamptz NOT NULL,
  end_at timestamptz,
  all_day boolean NOT NULL DEFAULT false,
  color text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_personal_events_user_id ON public.personal_events(user_id);
CREATE INDEX idx_personal_events_start_at ON public.personal_events(start_at);

ALTER TABLE public.personal_events ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can read own events"
  ON public.personal_events FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own events"
  ON public.personal_events FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own events"
  ON public.personal_events FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete own events"
  ON public.personal_events FOR DELETE
  USING (auth.uid() = user_id);

CREATE TRIGGER personal_events_updated_at
  BEFORE UPDATE ON public.personal_events
  FOR EACH ROW
  EXECUTE FUNCTION public.set_updated_at();
