-- =============================================================================
-- login_from_profiles: profiles.password 가 비어 있을 때 학번만으로 이메일 조회
-- =============================================================================
-- 관리자/백오피스에서 Auth 비밀번호만 맞추고 profiles.password 를 안 채운 경우
-- RPC 가 실패 → 앱이 school.local 만 시도하여 실제 이메일(@laon.local 등)과 불일치하던 문제를 해소.
-- 최종 비밀번호 검증은 클라이언트 signInWithPassword 에서 수행한다.

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
  v_profile_password text;
BEGIN
  IF nullif(trim(p_student_id), '') IS NULL OR nullif(trim(p_password), '') IS NULL THEN
    RAISE EXCEPTION 'invalid_input';
  END IF;

  SELECT
    p.id,
    p.user_id,
    p.password,
    jsonb_build_object(
      'id', p.id,
      'user_id', p.user_id,
      'student_id', p.student_id,
      'role', p.role,
      'must_change_password', p.must_change_password,
      'full_name', p.full_name,
      'avatar_url', p.avatar_url
    )
  INTO v_profile_id, v_user_id, v_profile_password, v_profile_data
  FROM public.profiles p
  WHERE p.student_id = trim(p_student_id)
  LIMIT 1;

  IF v_profile_id IS NULL THEN
    RAISE EXCEPTION 'invalid_credentials';
  END IF;

  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'user_not_found_in_auth';
  END IF;

  -- profiles.password 가 비어 있지 않으면 반드시 일치해야 함. 비어 있으면 Auth(signInWithPassword) 검증에 맡김.
  IF nullif(trim(v_profile_password), '') IS NOT NULL THEN
    IF v_profile_password <> p_password THEN
      RAISE EXCEPTION 'invalid_credentials';
    END IF;
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
