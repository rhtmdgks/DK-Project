-- =============================================================================
-- 세션 없이 건의 등록: 로그인 시 발급한 토큰으로 재인증 없이 등록
-- =============================================================================
-- 1) profile_session_tokens: 로그인 시 발급·갱신, 7일 유효
-- 2) login_from_profiles: 성공 시 토큰 발급 후 반환에 session_token 포함
-- 3) insert_suggestion_by_token: 유효한 토큰으로 건의 등록 (비밀번호 재입력 불필요)

-- 토큰 테이블 (profile당 하나, 로그인 시마다 갱신)
CREATE TABLE IF NOT EXISTS public.profile_session_tokens (
  profile_id uuid PRIMARY KEY REFERENCES public.profiles(id) ON DELETE CASCADE,
  token uuid NOT NULL DEFAULT gen_random_uuid(),
  expires_at timestamptz NOT NULL DEFAULT (now() + interval '7 days')
);

COMMENT ON TABLE public.profile_session_tokens IS '로그인 시 발급. 세션 없이 건의 등록 등에 사용. 7일 유효.';

-- RPC: login_from_profiles - 반환에 session_token 추가
CREATE OR REPLACE FUNCTION public.login_from_profiles(
  p_student_id text,
  p_password text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_profile_id uuid;
  v_user_id uuid;
  v_email text;
  v_profile_data jsonb;
  v_token uuid;
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

  v_email := trim(p_student_id) || '@school.local';

  -- 토큰 발급/갱신 (7일 유효)
  INSERT INTO public.profile_session_tokens (profile_id, token, expires_at)
  VALUES (v_profile_id, gen_random_uuid(), now() + interval '7 days')
  ON CONFLICT (profile_id) DO UPDATE SET
    token = gen_random_uuid(),
    expires_at = now() + interval '7 days'
  RETURNING token INTO v_token;

  RETURN jsonb_build_object(
    'success', true,
    'user_id', v_user_id,
    'email', v_email,
    'profile_id', v_profile_id,
    'profile', v_profile_data,
    'session_token', v_token
  );
END;
$$;

-- RPC: 토큰으로 건의 등록 (재인증 없이)
CREATE OR REPLACE FUNCTION public.insert_suggestion_by_token(
  p_token uuid,
  p_title text,
  p_body text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_profile_id uuid;
  v_suggestion_id uuid;
BEGIN
  SELECT profile_id INTO v_profile_id
  FROM public.profile_session_tokens
  WHERE token = p_token
    AND expires_at > now()
  LIMIT 1;

  IF v_profile_id IS NULL THEN
    RAISE EXCEPTION '유효하지 않거나 만료된 인증입니다. 다시 로그인해 주세요.'
      USING ERRCODE = 'P0001';
  END IF;

  INSERT INTO public.suggestions (author_id, title, body)
  VALUES (v_profile_id, p_title, NULLIF(trim(p_body), ''))
  RETURNING id INTO v_suggestion_id;

  RETURN v_suggestion_id;
END;
$$;

COMMENT ON FUNCTION public.insert_suggestion_by_token(uuid, text, text) IS
  '로그인 시 발급한 토큰으로 건의 등록. Supabase 세션 없을 때 비밀번호 재입력 없이 사용.';

GRANT EXECUTE ON FUNCTION public.login_from_profiles(text, text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.insert_suggestion_by_token(uuid, text, text) TO anon, authenticated;
