-- 개인 시간표에서 '이동 수업' 표시 및 알림용 플래그

ALTER TABLE public.timetable_entries
  ADD COLUMN IF NOT EXISTS is_moving_class boolean NOT NULL DEFAULT false;

COMMENT ON COLUMN public.timetable_entries.is_moving_class IS
  '이동 수업으로 표시·알림(설정 시 해당 교시 시작 5분 전 푸시).';
