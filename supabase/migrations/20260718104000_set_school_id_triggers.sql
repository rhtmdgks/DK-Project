-- =============================================================================
-- 멀티스쿨 1단계 (5/8): school_id 자동 채움 BEFORE INSERT 트리거
-- =============================================================================
-- 구앱(v1.0.5)과 기존 백오피스/edge function 은 INSERT 시 school_id 를 넣지 않는다.
-- BEFORE INSERT 트리거가 요청자 프로필의 학교 → (없으면) 기본 학교로 채워
-- 기존 클라이언트가 무변경으로 동작하게 하는 핵심 호환 장치.
-- RLS WITH CHECK 는 BEFORE ROW 트리거 이후의 최종 행에 대해 평가되므로,
-- 이후(8/8)의 RESTRICTIVE 정책과 순서 문제가 없다.
-- 주의: moderation_keywords 는 제외 (NULL = 전역 금칙어 의미 보존).
-- 2단계에서 default_school_id() 폴백을 RAISE 로 교체 예정 (신규 학교 시대의 오귀속 방지).

CREATE OR REPLACE FUNCTION public.set_school_id_from_profile()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
BEGIN
  IF NEW.school_id IS NULL THEN
    NEW.school_id := public.current_school_id();     -- authenticated 사용자의 소속 학교
    IF NEW.school_id IS NULL THEN
      NEW.school_id := public.default_school_id();   -- service_role/백오피스/edge fn 폴백
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

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
    'chat_rooms','personal_events','bug_reports','backoffice_accounts',
    'fcm_tokens','meal_departure_schedules','meal_departure_logs',
    'content_reports','moderation_actions','banned_users',
    'content_tombstones','account_deletion_logs'
  ] LOOP
    EXECUTE format('DROP TRIGGER IF EXISTS trg_set_school_id ON public.%I', t);
    EXECUTE format(
      'CREATE TRIGGER trg_set_school_id BEFORE INSERT ON public.%I
         FOR EACH ROW EXECUTE FUNCTION public.set_school_id_from_profile()', t
    );
  END LOOP;
END $$;

-- profiles 는 별도 처리: 신규 프로필 생성 시 school_id 미지정이면 기본 학교로.
-- (백오피스 계정 생성 함수가 school_id 를 모르는 전환기 동안의 폴백)
DROP TRIGGER IF EXISTS trg_set_school_id ON public.profiles;
CREATE TRIGGER trg_set_school_id
  BEFORE INSERT ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.set_school_id_from_profile();
