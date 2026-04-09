-- =============================================================================
-- login_from_profiles: auth.users의 실제 이메일 반환
-- =============================================================================
-- 관리자/복구 계정처럼 이메일 형식이 student_id@school.local 과 다를 수 있으므로
-- profiles.user_id에 연결된 auth.users.email을 우선 반환한다.

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
    AND p.password = p_password
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
