-- 세션 없이 개인 일정 조회: session_token으로 personal_events 가져오기

CREATE OR REPLACE FUNCTION public.get_personal_events_by_token(
  p_session_token uuid
)
RETURNS SETOF public.personal_events
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_profile_id uuid;
  v_user_id uuid;
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

  RETURN QUERY
  SELECT *
  FROM public.personal_events
  WHERE user_id = v_user_id
  ORDER BY start_at;
END;
$$;

COMMENT ON FUNCTION public.get_personal_events_by_token(uuid) IS
  'session_token으로 개인 일정 목록 조회. Supabase 세션 없을 때 사용.';

GRANT EXECUTE ON FUNCTION public.get_personal_events_by_token(uuid) TO anon, authenticated;

