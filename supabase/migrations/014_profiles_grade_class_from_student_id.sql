-- =============================================================================
-- 학번 규칙으로 profiles에 학년·반·번호 자동 기록 (알림 반별 대상용)
-- =============================================================================
-- 학번 5자리: G(1자) + 반(2자) + 번호(2자)
-- 예: 10102 → 1학년 1반 2번, 11002 → 1학년 10반 2번, 21025 → 2학년 10반 25번

-- 1) profiles에 컬럼 추가
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS grade smallint,
  ADD COLUMN IF NOT EXISTS class_num smallint,
  ADD COLUMN IF NOT EXISTS number_in_class smallint;

COMMENT ON COLUMN public.profiles.grade IS '학년(1-3). 학번 첫 자리에서 자동 설정';
COMMENT ON COLUMN public.profiles.class_num IS '반. 학번 2~3자리에서 자동 설정';
COMMENT ON COLUMN public.profiles.number_in_class IS '번. 학번 4~5자리에서 자동 설정';

-- 2) student_id에서 학년·반·번호 채우는 함수
CREATE OR REPLACE FUNCTION public.sync_profile_grade_class()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.student_id IS NOT NULL AND length(trim(NEW.student_id)) >= 5 THEN
    NEW.grade := NULLIF(substring(trim(NEW.student_id) from 1 for 1), '')::smallint;
    NEW.class_num := NULLIF(substring(trim(NEW.student_id) from 2 for 2), '')::smallint;
    NEW.number_in_class := NULLIF(substring(trim(NEW.student_id) from 4 for 2), '')::smallint;
  ELSE
    NEW.grade := NULL;
    NEW.class_num := NULL;
    NEW.number_in_class := NULL;
  END IF;
  RETURN NEW;
END;
$$;

-- 3) 트리거: INSERT/UPDATE 시 자동 반영
DROP TRIGGER IF EXISTS tr_profiles_sync_grade_class ON public.profiles;
CREATE TRIGGER tr_profiles_sync_grade_class
  BEFORE INSERT OR UPDATE OF student_id
  ON public.profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.sync_profile_grade_class();

-- 4) 기존 행 백필
UPDATE public.profiles
SET
  grade = NULLIF(substring(trim(student_id) from 1 for 1), '')::smallint,
  class_num = NULLIF(substring(trim(student_id) from 2 for 2), '')::smallint,
  number_in_class = NULLIF(substring(trim(student_id) from 4 for 2), '')::smallint
WHERE student_id IS NOT NULL AND length(trim(student_id)) >= 5;
