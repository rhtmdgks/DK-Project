-- =============================================================================
-- 멀티스쿨 1단계 (6/8): 아이디 기반 로그인 RPC v2
-- =============================================================================
-- 새 로그인 플로우: 학교 선택 → 아이디 + 비밀번호.
--  * login_with_username: (학교 slug, 아이디) → auth email 반환.
--    비밀번호는 여기서 검증하지 않는다 — Auth(signInWithPassword)가 단일 진실
--    (기존 login_from_profiles 와 동일한 설계 계약).
--  * login_from_profiles(레거시)는 구앱 호환을 위해 그대로 유지 (deprecated 코멘트만).
--  * list_active_schools: 로그인 화면(anon)의 학교 선택 목록.
--  * check_username_available: 계정 생성(백오피스) 시 아이디 중복 확인.

CREATE OR REPLACE FUNCTION public.login_with_username(
  p_school_slug text,
  p_username text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_school_id uuid;
  v_profile_id uuid;
  v_user_id uuid;
  v_email text;
  v_profile_data jsonb;
BEGIN
  IF nullif(trim(p_school_slug), '') IS NULL OR nullif(trim(p_username), '') IS NULL THEN
    RAISE EXCEPTION 'invalid_input';
  END IF;

  SELECT s.id INTO v_school_id
  FROM public.schools s
  WHERE s.slug = lower(trim(p_school_slug)) AND s.status = 'active'
  LIMIT 1;

  -- 학교 존재 여부를 별도 에러로 노출하지 않음 (계정 열거 방지)
  IF v_school_id IS NULL THEN
    RAISE EXCEPTION 'invalid_credentials';
  END IF;

  SELECT
    p.id,
    p.user_id,
    jsonb_build_object(
      'id', p.id,
      'user_id', p.user_id,
      'student_id', p.student_id,
      'username', p.username,
      'role', p.role,
      'org_roles', to_jsonb(p.org_roles),
      'must_change_password', p.must_change_password,
      'full_name', p.full_name,
      'avatar_url', p.avatar_url,
      'school_id', p.school_id
    )
  INTO v_profile_id, v_user_id, v_profile_data
  FROM public.profiles p
  WHERE p.school_id = v_school_id
    AND lower(p.username) = lower(trim(p_username))
  LIMIT 1;

  IF v_profile_id IS NULL THEN
    RAISE EXCEPTION 'invalid_credentials';
  END IF;

  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'user_not_found_in_auth';
  END IF;

  SELECT u.email INTO v_email
  FROM auth.users u
  WHERE u.id = v_user_id
  LIMIT 1;

  -- auth email 이 비어 있으면 신규 규칙으로 유도 (기존 사용자는 항상 auth email 존재)
  IF nullif(trim(v_email), '') IS NULL THEN
    v_email := lower(trim(p_username)) || '@' || lower(trim(p_school_slug)) || '.laon.local';
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'user_id', v_user_id,
    'email', v_email,
    'profile_id', v_profile_id,
    'school_id', v_school_id,
    'profile', v_profile_data
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.login_with_username(text, text) TO anon, authenticated;

COMMENT ON FUNCTION public.login_with_username(text, text) IS
  '(학교 slug, 아이디)로 auth 이메일 조회. 비밀번호는 signInWithPassword 에서만 검증.';

-- 아이디 중복 확인 (백오피스 계정 생성용. anon 에 열지 않아 계정 열거 방지)
CREATE OR REPLACE FUNCTION public.check_username_available(
  p_school_slug text,
  p_username text
)
RETURNS boolean
LANGUAGE sql STABLE
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
  SELECT trim(coalesce(p_username, '')) ~ '^[a-zA-Z0-9._-]{2,32}$'
     AND NOT EXISTS (
       SELECT 1
       FROM public.profiles p
       JOIN public.schools s ON s.id = p.school_id
       WHERE s.slug = lower(trim(p_school_slug))
         AND lower(p.username) = lower(trim(p_username))
     );
$$;

GRANT EXECUTE ON FUNCTION public.check_username_available(text, text) TO authenticated;

-- 로그인 화면 학교 목록 (anon)
CREATE OR REPLACE FUNCTION public.list_active_schools()
RETURNS TABLE (id uuid, slug text, name text, name_en text)
LANGUAGE sql STABLE
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
  SELECT s.id, s.slug, s.name, s.name_en
  FROM public.schools s
  WHERE s.status = 'active'
  ORDER BY s.name;
$$;

GRANT EXECUTE ON FUNCTION public.list_active_schools() TO anon, authenticated;

-- 레거시 로그인 RPC deprecated 표기 (동작 불변 — 구앱 v1.0.5 호환)
COMMENT ON FUNCTION public.login_from_profiles(text, text) IS
  '[DEPRECATED] 학번 기반 레거시 로그인. login_with_username 으로 대체됨. '
  '구앱(v1.0.5) 지원 종료 후 2단계에서 제거 예정.';
