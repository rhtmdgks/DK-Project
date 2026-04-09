-- =============================================================================
-- login_from_profiles: profiles.password 로 게이트하지 않음 (Auth가 단일 진실)
-- =============================================================================
-- 일괄 비밀번호 리셋 등으로 auth.users 만 갱신되고 profiles.password 가 예전 값이거나
-- 업데이트 실패 시 RPC 가 먼저 막혀 앱이 올바른 이메일로 signInWithPassword 를 시도하지 못함.
-- 학번으로 등록된 계정이면 auth.users 이메일만 반환하고, 비밀번호는 항상 signInWithPassword 에서만 검증.

CREATE OR REPLACE FUNCTION public.login_from_profiles(
  p_student_id text,
  p_password text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_profile_id uuid;
  v_user_id uuid;
  v_email text;
  v_profile_data jsonb;
BEGIN
  IF nullif(trim(p_student_id), '') IS NULL OR nullif(trim(p_password), '') IS NULL THEN
    RAISE EXCEPTION 'invalid_input';
  END IF;

  SELECT
    p.id,
    p.user_id,
    jsonb_build_object(
      'id', p.id,
      'user_id', p.user_id,
      'student_id', p.student_id,
      'role', p.role,
      'must_change_password', p.must_change_password,
      'full_name', p.full_name,
      'avatar_url', p.avatar_url
    )
  INTO v_profile_id, v_user_id, v_profile_data
  FROM public.profiles p
  WHERE p.student_id = trim(p_student_id)
  LIMIT 1;

  IF v_profile_id IS NULL THEN
    RAISE EXCEPTION 'invalid_credentials';
  END IF;

  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'user_not_found_in_auth';
  END IF;

  SELECT u.email
  INTO v_email
  FROM auth.users u
  WHERE u.id = v_user_id
  LIMIT 1;

  IF nullif(trim(v_email), '') IS NULL THEN
    v_email := trim(p_student_id) || '@school.local';
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'user_id', v_user_id,
    'email', v_email,
    'profile_id', v_profile_id,
    'profile', v_profile_data
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.login_from_profiles(text, text) TO anon, authenticated;

COMMENT ON FUNCTION public.login_from_profiles(text, text) IS
  '학번으로 profiles/auth 이메일 조회. 비밀번호는 클라이언트 signInWithPassword 에서만 검증.';
