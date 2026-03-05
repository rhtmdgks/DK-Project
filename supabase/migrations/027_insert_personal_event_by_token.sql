-- 세션 없이 개인 일정 추가: session_token으로 personal_events 등록
-- - 모바일 앱은 Supabase Auth 세션이 없을 수도 있으므로
--   profile_session_tokens 테이블 기반으로 user_id를 resolve 한다.

CREATE OR REPLACE FUNCTION public.insert_personal_event_by_token(
  p_session_token uuid,
  p_title text,
  p_description text,
  p_start_at timestamptz,
  p_end_at timestamptz,
  p_all_day boolean
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_profile_id uuid;
  v_user_id uuid;
  v_event_id uuid;
BEGIN
  SELECT t.profile_id
    INTO v_profile_id
  FROM public.profile_session_tokens t
  WHERE t.token = p_session_token
    AND t.expires_at > now()
  LIMIT 1;

  IF v_profile_id IS NULL THEN
    RAISE EXCEPTION '유효하지 않거나 만료된 인증입니다. 다시 로그인해 주세요.'
      USING ERRCODE = 'P0001';
  END IF;

  SELECT user_id
    INTO v_user_id
  FROM public.profiles
  WHERE id = v_profile_id
  LIMIT 1;

  IF v_user_id IS NULL THEN
    RAISE EXCEPTION '해당 프로필에 연결된 사용자 정보를 찾을 수 없습니다.'
      USING ERRCODE = 'P0001';
  END IF;

  INSERT INTO public.personal_events (
    user_id,
    title,
    description,
    start_at,
    end_at,
    all_day
  )
  VALUES (
    v_user_id,
    p_title,
    NULLIF(trim(p_description), ''),
    p_start_at,
    p_end_at,
    p_all_day
  )
  RETURNING id INTO v_event_id;

  RETURN v_event_id;
END;
$$;

COMMENT ON FUNCTION public.insert_personal_event_by_token(uuid, text, text, timestamptz, timestamptz, boolean) IS
  'session_token으로 개인 일정 등록. Supabase 세션 없을 때 비밀번호 재입력 없이 사용.';

GRANT EXECUTE ON FUNCTION public.insert_personal_event_by_token(uuid, text, text, timestamptz, timestamptz, boolean) TO anon, authenticated;

