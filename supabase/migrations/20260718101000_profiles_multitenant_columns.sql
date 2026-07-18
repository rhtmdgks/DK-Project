-- =============================================================================
-- 멀티스쿨 1단계 (2/8): profiles 멀티테넌트 컬럼 + parent_student_links
-- =============================================================================
-- additive only:
--  * school_id/username/org_roles/recovery_email 컬럼 추가 (NULL 허용, 테이블 rewrite 없음)
--  * role CHECK 를 레거시(student/council/admin/teacher) + 신규(super_admin/school_admin/parent)
--    7값 허용으로 확장 — 기존 행 값은 변경하지 않음 (role 플립은 2단계 staged)
--  * backfill: school_id=기본 학교, username=student_id(기존 사용자는 학번이 곧 아이디),
--    council 사용자의 org_roles 에 'council' 추가 (role 값 자체는 유지)
--  * 기존 profiles_student_id_key(글로벌 unique)는 유지 — 구앱 login_from_profiles 의존.
--    (school_id, student_id) 교체는 2단계.

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS school_id uuid REFERENCES public.schools(id),
  ADD COLUMN IF NOT EXISTS username text,
  ADD COLUMN IF NOT EXISTS org_roles text[] NOT NULL DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS recovery_email text,
  ADD COLUMN IF NOT EXISTS recovery_email_verified_at timestamptz;

COMMENT ON COLUMN public.profiles.school_id IS '소속 학교 (schools.id)';
COMMENT ON COLUMN public.profiles.username IS '로그인 아이디. 학교 내 유일(lower 비교). 기존 사용자는 학번과 동일';
COMMENT ON COLUMN public.profiles.org_roles IS '보직 플래그 배열 (예: council=학생회). role 과 별개';
COMMENT ON COLUMN public.profiles.recovery_email IS '아이디/비밀번호 찾기용 실제 이메일 (인증 플로우는 추후 단계)';

-- role CHECK 확장 (라이브 제약명 확인 완료: profiles_role_check)
ALTER TABLE public.profiles DROP CONSTRAINT IF EXISTS profiles_role_check;
ALTER TABLE public.profiles ADD CONSTRAINT profiles_role_check
  CHECK (role IN (
    'student', 'council', 'admin', 'teacher',          -- legacy (2단계에서 council/admin 플립)
    'super_admin', 'school_admin', 'parent'            -- new
  ));

-- backfill
UPDATE public.profiles
   SET school_id = (SELECT id FROM public.schools WHERE is_default LIMIT 1)
 WHERE school_id IS NULL;

UPDATE public.profiles
   SET username = student_id
 WHERE username IS NULL AND student_id IS NOT NULL;

UPDATE public.profiles
   SET org_roles = array_append(org_roles, 'council')
 WHERE role = 'council' AND NOT ('council' = ANY(org_roles));

-- 아이디는 학교 내 유일 (대소문자 무시)
CREATE UNIQUE INDEX IF NOT EXISTS profiles_school_username_key
  ON public.profiles (school_id, lower(username))
  WHERE username IS NOT NULL;

ALTER TABLE public.profiles ADD CONSTRAINT profiles_username_format
  CHECK (username IS NULL OR username ~ '^[a-zA-Z0-9._-]{2,32}$');

CREATE INDEX IF NOT EXISTS profiles_school_id_idx ON public.profiles (school_id);
CREATE INDEX IF NOT EXISTS profiles_recovery_email_idx
  ON public.profiles (lower(recovery_email))
  WHERE recovery_email IS NOT NULL;

-- 학부모-학생 연결 (스키마만 준비. RLS on + 정책 없음 = service_role 외 전면 차단)
CREATE TABLE IF NOT EXISTS public.parent_student_links (
  id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  school_id          uuid NOT NULL REFERENCES public.schools(id),
  parent_profile_id  uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  student_profile_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  relationship       text NOT NULL DEFAULT 'guardian'
                       CHECK (relationship IN ('mother', 'father', 'guardian')),
  status             text NOT NULL DEFAULT 'pending'
                       CHECK (status IN ('pending', 'approved', 'rejected', 'revoked')),
  approved_by        uuid REFERENCES public.profiles(id),
  created_at         timestamptz NOT NULL DEFAULT now(),
  UNIQUE (parent_profile_id, student_profile_id)
);

CREATE INDEX IF NOT EXISTS parent_student_links_student_idx
  ON public.parent_student_links (student_profile_id);

ALTER TABLE public.parent_student_links ENABLE ROW LEVEL SECURITY;

COMMENT ON TABLE public.parent_student_links IS
  '학부모-학생 연결 (학부모 기능 준비용 스키마. 정책은 학부모 기능 구현 시 추가)';
