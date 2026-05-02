-- 테스트용 0학년 0반 시간표를 3학년 7반과 동일하게 유지 (INSERT/UPDATE/DELETE 미러).
-- 프로필 grade=0, class_number=0 허용.

-- ---------------------------------------------------------------------------
-- class_timetable: (0,0) 또는 (1..3, 1..10)
-- ---------------------------------------------------------------------------
ALTER TABLE public.class_timetable DROP CONSTRAINT IF EXISTS class_timetable_grade_check;
ALTER TABLE public.class_timetable DROP CONSTRAINT IF EXISTS class_timetable_class_number_check;

ALTER TABLE public.class_timetable
  ADD CONSTRAINT class_timetable_grade_class_test_bounds CHECK (
    (grade >= 1 AND grade <= 3 AND class_number >= 1 AND class_number <= 10)
    OR (grade = 0 AND class_number = 0)
  );

-- ---------------------------------------------------------------------------
-- profiles: 기존 조합 유지 + (0,0) 테스트 페어만 추가
-- ---------------------------------------------------------------------------
ALTER TABLE public.profiles DROP CONSTRAINT IF EXISTS profiles_grade_check;
ALTER TABLE public.profiles DROP CONSTRAINT IF EXISTS profiles_class_number_check;

ALTER TABLE public.profiles
  ADD CONSTRAINT profiles_grade_class_test_bounds CHECK (
    (grade IS NULL AND (class_number IS NULL OR (class_number >= 1 AND class_number <= 10)))
    OR (grade >= 1 AND grade <= 3 AND (class_number IS NULL OR (class_number >= 1 AND class_number <= 10)))
    OR (grade = 0 AND class_number = 0)
  );

-- ---------------------------------------------------------------------------
-- 트리거: 소스 = 3학년 7반 → 대상 = 0학년 0반
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.mirror_class_timetable_37_to_test_00()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF TG_OP = 'DELETE' THEN
    IF OLD.grade = 3 AND OLD.class_number = 7 THEN
      DELETE FROM public.class_timetable c
      WHERE c.grade = 0
        AND c.class_number = 0
        AND c.week_offset = OLD.week_offset
        AND c.day_of_week = OLD.day_of_week
        AND c.period = OLD.period;
    END IF;
    RETURN OLD;
  END IF;

  IF TG_OP = 'UPDATE' THEN
    IF OLD.grade = 3
       AND OLD.class_number = 7
       AND (NEW.grade <> 3 OR NEW.class_number <> 7) THEN
      DELETE FROM public.class_timetable c
      WHERE c.grade = 0
        AND c.class_number = 0
        AND c.week_offset = OLD.week_offset
        AND c.day_of_week = OLD.day_of_week
        AND c.period = OLD.period;
    END IF;
  END IF;

  IF NEW.grade = 3 AND NEW.class_number = 7 THEN
    INSERT INTO public.class_timetable (
      grade,
      class_number,
      week_offset,
      day_of_week,
      period,
      subject,
      teacher,
      original_subject,
      original_teacher,
      room,
      updated_at
    )
    VALUES (
      0,
      0,
      NEW.week_offset,
      NEW.day_of_week,
      NEW.period,
      NEW.subject,
      NEW.teacher,
      NEW.original_subject,
      NEW.original_teacher,
      NEW.room,
      COALESCE(NEW.updated_at, now())
    )
    ON CONFLICT (grade, class_number, week_offset, day_of_week, period)
    DO UPDATE SET
      subject = EXCLUDED.subject,
      teacher = EXCLUDED.teacher,
      original_subject = EXCLUDED.original_subject,
      original_teacher = EXCLUDED.original_teacher,
      room = EXCLUDED.room,
      updated_at = EXCLUDED.updated_at;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS tr_mirror_class_timetable_37_to_00 ON public.class_timetable;

CREATE TRIGGER tr_mirror_class_timetable_37_to_00
AFTER INSERT OR UPDATE OR DELETE ON public.class_timetable
FOR EACH ROW
EXECUTE FUNCTION public.mirror_class_timetable_37_to_test_00();

COMMENT ON FUNCTION public.mirror_class_timetable_37_to_test_00() IS
  '테스트용: class_timetable 3학년 7반 변경 시 0학년 0반 동일 슬롯 미러';

-- 기존 3-7 데이터 → 0-0 초기 복사 (트리거 대상이 아니므로 직접 INSERT만 수행)
INSERT INTO public.class_timetable (
  grade,
  class_number,
  week_offset,
  day_of_week,
  period,
  subject,
  teacher,
  original_subject,
  original_teacher,
  room,
  updated_at
)
SELECT
  0,
  0,
  s.week_offset,
  s.day_of_week,
  s.period,
  s.subject,
  s.teacher,
  s.original_subject,
  s.original_teacher,
  s.room,
  s.updated_at
FROM public.class_timetable s
WHERE s.grade = 3
  AND s.class_number = 7
ON CONFLICT (grade, class_number, week_offset, day_of_week, period)
DO UPDATE SET
  subject = EXCLUDED.subject,
  teacher = EXCLUDED.teacher,
  original_subject = EXCLUDED.original_subject,
  original_teacher = EXCLUDED.original_teacher,
  room = EXCLUDED.room,
  updated_at = EXCLUDED.updated_at;
