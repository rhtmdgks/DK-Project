-- =============================================================================
-- 멀티스쿨 1단계 (3/8): 테넌트/역할 판별 헬퍼 함수
-- =============================================================================
-- 원칙:
--  * 모든 헬퍼는 SECURITY DEFINER + STABLE + search_path 고정 (profiles RLS 우회 조회)
--  * 레거시 role 값('admin','council')과 신규 값('school_admin','super_admin' 등)을
--    동등하게 취급 — 2단계 role 플립 전후 모두 동일하게 동작
--  * RLS 정책에서는 (SELECT fn()) initplan 형태로 호출해 행별 재평가를 방지할 것

CREATE OR REPLACE FUNCTION public.default_school_id()
RETURNS uuid
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
  SELECT id FROM public.schools WHERE is_default LIMIT 1;
$$;

CREATE OR REPLACE FUNCTION public.current_school_id()
RETURNS uuid
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
  SELECT p.school_id FROM public.profiles p WHERE p.user_id = auth.uid() LIMIT 1;
$$;

CREATE OR REPLACE FUNCTION public.is_super_admin()
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.profiles p
    WHERE p.user_id = auth.uid() AND p.role = 'super_admin'
  );
$$;

-- 학교 관리자: legacy 'admin' == new 'school_admin'. super_admin 은 상위 포함.
CREATE OR REPLACE FUNCTION public.is_school_admin()
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.profiles p
    WHERE p.user_id = auth.uid()
      AND p.role IN ('admin', 'school_admin', 'super_admin')
  );
$$;

-- 기존에 is_teacher 계열 함수가 없음을 확인했으나, 향후 충돌 여지를 없애기 위해 _v2 접미 사용
CREATE OR REPLACE FUNCTION public.is_teacher_v2()
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.profiles p
    WHERE p.user_id = auth.uid() AND p.role = 'teacher'
  );
$$;

-- 교직원/관리자 (교사 + 학교 관리자 + 슈퍼 관리자)
CREATE OR REPLACE FUNCTION public.is_staff()
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.profiles p
    WHERE p.user_id = auth.uid()
      AND p.role IN ('admin', 'school_admin', 'teacher', 'super_admin')
  );
$$;

-- 학생회: legacy role='council' 또는 org_roles 에 'council'
CREATE OR REPLACE FUNCTION public.has_council()
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.profiles p
    WHERE p.user_id = auth.uid()
      AND (p.role = 'council' OR 'council' = ANY(p.org_roles))
  );
$$;

CREATE OR REPLACE FUNCTION public.is_council_or_staff()
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.profiles p
    WHERE p.user_id = auth.uid()
      AND (p.role IN ('admin', 'school_admin', 'teacher', 'super_admin', 'council')
           OR 'council' = ANY(p.org_roles))
  );
$$;

-- 테넌트 격리 판별: 대상 행의 school_id 가 내 학교이거나 내가 super_admin
CREATE OR REPLACE FUNCTION public.same_school(p_school_id uuid)
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
  SELECT p_school_id IS NOT NULL
     AND (p_school_id = public.current_school_id() OR public.is_super_admin());
$$;

GRANT EXECUTE ON FUNCTION
  public.default_school_id(),
  public.current_school_id(),
  public.is_super_admin(),
  public.is_school_admin(),
  public.is_teacher_v2(),
  public.is_staff(),
  public.has_council(),
  public.is_council_or_staff(),
  public.same_school(uuid)
TO anon, authenticated;
