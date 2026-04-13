-- 시간표 유실 진단 + 반별 시간표 기반 재동기화 SQL
-- 순서:
-- 1) 아래 "진단 쿼리"만 먼저 실행해 실제 유실 범위를 확인
-- 2) 결과를 검토한 뒤 "복구/동기화 쿼리"를 실행
-- 3) 마지막 "사후 검증"으로 반영 확인

-- =========================
-- 1) 진단 쿼리 (READ ONLY)
-- =========================

-- 현재 테이블 존재 여부 확인
SELECT
  to_regclass('public.timetable_entries') AS timetable_entries_table,
  to_regclass('public.class_timetable') AS class_timetable_table,
  to_regclass('public.class_timetable_change_logs') AS class_timetable_change_logs_table;

-- 전체 시간표 건수 / 사용자별 분포 (timetable_entries가 있을 때만)
DO $$
DECLARE
  v_count bigint;
  r record;
BEGIN
  IF to_regclass('public.timetable_entries') IS NULL THEN
    RAISE NOTICE '[DIAG] public.timetable_entries 가 없습니다.';
  ELSE
    EXECUTE 'SELECT COUNT(*) FROM public.timetable_entries' INTO v_count;
    RAISE NOTICE '[DIAG] timetable_entries_count = %', v_count;

    RAISE NOTICE '[DIAG] user_id 별 상위 건수(최대 50):';
    FOR r IN EXECUTE
      'SELECT user_id, COUNT(*) AS row_count
       FROM public.timetable_entries
       GROUP BY user_id
       ORDER BY row_count DESC
       LIMIT 50'
    LOOP
      RAISE NOTICE '  user_id=% rows=%', r.user_id, r.row_count;
    END LOOP;
  END IF;
END $$;

-- profiles와 auth.users 정합성 점검
SELECT
  p.id AS profile_id,
  p.user_id,
  p.student_id,
  p.grade,
  COALESCE(
    NULLIF(to_jsonb(p)->>'class_num', '')::smallint,
    NULLIF(to_jsonb(p)->>'class_number', '')::smallint
  ) AS class_num,
  (u.id IS NOT NULL) AS has_auth_user
FROM public.profiles p
LEFT JOIN auth.users u ON u.id = p.user_id
ORDER BY p.student_id NULLS LAST
LIMIT 200;

-- class_timetable_change_logs 최근 이력 (테이블 존재 시)
DO $$
DECLARE
  r record;
BEGIN
  IF to_regclass('public.class_timetable_change_logs') IS NULL THEN
    RAISE NOTICE '[DIAG] public.class_timetable_change_logs 가 없습니다.';
  ELSE
    RAISE NOTICE '[DIAG] class_timetable_change_logs 최근 100건:';
    FOR r IN EXECUTE
      'SELECT grade, class_number, week_offset, day_of_week, period, new_subject, created_at
       FROM public.class_timetable_change_logs
       ORDER BY created_at DESC
       LIMIT 100'
    LOOP
      RAISE NOTICE '  g=% c=% w=% d=% p=% subj=% at=%',
        r.grade, r.class_number, r.week_offset, r.day_of_week, r.period, r.new_subject, r.created_at;
    END LOOP;
  END IF;
END $$;

-- =========================
-- 2) 복구/동기화 쿼리
-- =========================
-- 조건:
-- - class_timetable 테이블이 존재할 때만 실행됨
-- - week_offset = 0(기본 반별 시간표)만 학생 개인 시간표에 반영
-- - 월/금 7교시는 제외

DO $$
BEGIN
  IF to_regclass('public.class_timetable') IS NULL THEN
    RAISE NOTICE 'public.class_timetable does not exist. Skip sync.';
    RETURN;
  END IF;
  IF to_regclass('public.timetable_entries') IS NULL THEN
    RAISE NOTICE 'public.timetable_entries does not exist. Skip sync.';
    RETURN;
  END IF;

  INSERT INTO public.timetable_entries (
    user_id,
    day_of_week,
    period,
    subject,
    room
  )
  SELECT
    p.user_id,
    ct.day_of_week,
    ct.period,
    ct.subject,
    ct.room
  FROM public.class_timetable ct
  JOIN public.profiles p
    ON p.grade = ct.grade
   AND COALESCE(
         NULLIF(to_jsonb(p)->>'class_num', '')::smallint,
         NULLIF(to_jsonb(p)->>'class_number', '')::smallint
       ) = ct.class_number
  WHERE ct.week_offset = 0
    AND p.user_id IS NOT NULL
    AND NOT ((ct.day_of_week = 1 OR ct.day_of_week = 5) AND ct.period = 7)
  ON CONFLICT (user_id, day_of_week, period)
  DO UPDATE SET
    subject = EXCLUDED.subject,
    room = EXCLUDED.room;
END $$;

-- =========================
-- 3) 사후 검증
-- =========================

DO $$
DECLARE
  v_count bigint;
  r record;
BEGIN
  IF to_regclass('public.timetable_entries') IS NULL THEN
    RAISE NOTICE '[POST] public.timetable_entries 가 없어 사후 검증을 건너뜁니다.';
    RETURN;
  END IF;

  EXECUTE 'SELECT COUNT(*) FROM public.timetable_entries' INTO v_count;
  RAISE NOTICE '[POST] timetable_entries_count_after_sync = %', v_count;

  RAISE NOTICE '[POST] day_of_week / period 분포:';
  FOR r IN EXECUTE
    'SELECT day_of_week, period, COUNT(*) AS rows_per_slot
     FROM public.timetable_entries
     GROUP BY day_of_week, period
     ORDER BY day_of_week, period'
  LOOP
    RAISE NOTICE '  day=% period=% rows=%', r.day_of_week, r.period, r.rows_per_slot;
  END LOOP;
END $$;
