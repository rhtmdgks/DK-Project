-- =============================================================================
-- [STAGED — 적용 금지] 멀티스쿨 2단계: 레거시 role 컷오버
-- =============================================================================
-- ⚠️ 이 파일은 supabase/migrations/ 밖(migrations_staged/)에 있어 db push 대상이 아니다.
-- 적용 전제 조건 (전부 충족 후 수동 적용):
--   (a) 앱 v2(학교 선택 로그인 + 신규 role 인지) 강제 업데이트 완료 — v1.0.5 세션 잔존 0 근접
--   (b) 백오피스가 school_admin/super_admin/org_roles 를 인지
--   (c) login_from_profiles 호출 로그 0 확인 (get_logs)
-- 이 파일의 각 블록은 독립 검토 후 순서대로 적용할 것.

-- ---------------------------------------------------------------------------
-- 0. 가드
-- ---------------------------------------------------------------------------
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM public.profiles
             WHERE role = 'council' AND NOT ('council' = ANY(org_roles))) THEN
    RAISE EXCEPTION 'org_roles backfill incomplete';
  END IF;
END $$;

-- ---------------------------------------------------------------------------
-- 1. role 값 플립 (구앱이 완전히 사라진 뒤에만 — 구앱은 role 문자열을 직접 비교)
-- ---------------------------------------------------------------------------
UPDATE public.profiles SET role = 'student'      WHERE role = 'council';
UPDATE public.profiles SET role = 'school_admin' WHERE role = 'admin';

-- role CHECK 에서 legacy 값 제거
ALTER TABLE public.profiles DROP CONSTRAINT profiles_role_check;
ALTER TABLE public.profiles ADD CONSTRAINT profiles_role_check
  CHECK (role IN ('student', 'teacher', 'parent', 'school_admin', 'super_admin'));

-- ---------------------------------------------------------------------------
-- 2. student_id 글로벌 unique → 학교별 unique (login_from_profiles 완전 폐기 이후)
-- ---------------------------------------------------------------------------
ALTER TABLE public.profiles DROP CONSTRAINT profiles_student_id_key;
CREATE UNIQUE INDEX profiles_school_student_id_key
  ON public.profiles (school_id, student_id)
  WHERE student_id IS NOT NULL;

-- ---------------------------------------------------------------------------
-- 3. class_timetable unique 를 school 포함으로 교체
--    ⚠️ sync_timetable_entries_from_class_fn 의 ON CONFLICT 컬럼 목록을
--    같은 트랜잭션에서 함께 재작성해야 함 (분리 시 RPC 즉시 파손)
-- ---------------------------------------------------------------------------
-- ALTER TABLE public.class_timetable DROP CONSTRAINT <기존 unique 제약명>;
-- ALTER TABLE public.class_timetable ADD CONSTRAINT class_timetable_school_slot_key
--   UNIQUE (school_id, grade, class_number, week_offset, day_of_week, period);
-- CREATE OR REPLACE FUNCTION public.sync_timetable_entries_from_class_fn(...) ...;

-- ---------------------------------------------------------------------------
-- 4. 잔여 하드닝
-- ---------------------------------------------------------------------------
-- * set_school_id_from_profile(): default_school_id() 폴백을 RAISE EXCEPTION 으로 교체
--   (신규 학교 시대에 school_id 누락 INSERT 가 기본 학교로 오귀속되는 것 방지)
-- * profiles 에 tenant_isolation RESTRICTIVE 정책 추가 (TO authenticated)
-- * announcements/poll_votes 의 anon SELECT 정책 축소 또는 학교 스코프화
-- * class_photo_shares 정책 3종을 (school_id, grade, class_number) 컬럼 기반으로 재작성
-- * 헬퍼 함수(is_school_admin/has_council 등)에서 legacy 값 제거
-- * login_from_profiles / backoffice_login_from_profiles DROP
-- * moderation-ban-user edge function 원격 미배포 상태 정리 (배포 or 소스 제거)
