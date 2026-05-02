-- 반 시간표는 매주 동일: week_offset ≠ 0 인 행 제거 후 0만 허용
DELETE FROM public.class_timetable WHERE week_offset <> 0;

ALTER TABLE public.class_timetable
  DROP CONSTRAINT IF EXISTS class_timetable_week_offset_zero_only;

ALTER TABLE public.class_timetable
  ADD CONSTRAINT class_timetable_week_offset_zero_only CHECK (week_offset = 0);

COMMENT ON COLUMN public.class_timetable.week_offset IS '항상 0 (매주 동일 시간표 템플릿). 주차 구분 없음.';
