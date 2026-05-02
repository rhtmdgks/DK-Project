-- 학생이 자신의 학년·반 class_timetable만 조회 (앱 MergedSchoolTimetable).
-- 테이블이 없는 로컬/분리 DB에서는 건너뜀.

DO $$
BEGIN
  IF to_regclass('public.class_timetable') IS NULL THEN
    RAISE NOTICE 'class_timetable 없음: 정책 스킵';
    RETURN;
  END IF;

  EXECUTE $p$
    DROP POLICY IF EXISTS "Students can read own class timetable grid" ON public.class_timetable
  $p$;

  EXECUTE $p$
    CREATE POLICY "Students can read own class timetable grid"
      ON public.class_timetable
      FOR SELECT
      TO authenticated
      USING (
        EXISTS (
          SELECT 1
          FROM public.profiles p
          WHERE p.user_id = auth.uid()
            AND coalesce(p.role, '') = 'student'
            AND p.grade IS NOT NULL
            AND p.class_number IS NOT NULL
            AND p.grade = class_timetable.grade
            AND p.class_number = class_timetable.class_number
        )
      )
  $p$;
END $$;
