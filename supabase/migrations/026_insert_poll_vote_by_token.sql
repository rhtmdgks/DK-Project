-- 세션 없이 투표하기: session_token으로 poll_votes 등록 및 조회

-- 1) 토큰으로 투표 등록 (한 번만 가능, UNIQUE(poll_id, user_id) 유지)
CREATE OR REPLACE FUNCTION public.insert_poll_vote_by_token(
  p_poll_id uuid,
  p_session_token uuid,
  p_option_index int
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid;
BEGIN
  SELECT p.user_id INTO v_user_id
  FROM public.profile_session_tokens t
  JOIN public.profiles p ON p.id = t.profile_id
  WHERE t.token = p_session_token
    AND t.expires_at > now()
  LIMIT 1;

  IF v_user_id IS NULL THEN
    RAISE EXCEPTION '로그인이 필요합니다. 다시 로그인해 주세요.'
      USING ERRCODE = 'P0001';
  END IF;

  INSERT INTO public.poll_votes (poll_id, user_id, option_index)
  VALUES (p_poll_id, v_user_id, p_option_index)
  ON CONFLICT (poll_id, user_id) DO UPDATE SET option_index = EXCLUDED.option_index;
END;
$$;

COMMENT ON FUNCTION public.insert_poll_vote_by_token(uuid, uuid, int) IS
  'session_token으로 투표 등록. 이미 투표한 경우 선택지만 변경.';

-- 2) 토큰으로 내 투표 여부·선택 인덱스 조회 (세션 없을 때)
CREATE OR REPLACE FUNCTION public.get_poll_vote_by_token(
  p_poll_id uuid,
  p_session_token uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid;
  v_option_index int;
BEGIN
  SELECT p.user_id INTO v_user_id
  FROM public.profile_session_tokens t
  JOIN public.profiles p ON p.id = t.profile_id
  WHERE t.token = p_session_token
    AND t.expires_at > now()
  LIMIT 1;

  IF v_user_id IS NULL THEN
    RETURN NULL;
  END IF;

  SELECT option_index INTO v_option_index
  FROM public.poll_votes
  WHERE poll_id = p_poll_id AND user_id = v_user_id
  LIMIT 1;

  IF v_option_index IS NULL THEN
    RETURN NULL;
  END IF;

  RETURN jsonb_build_object('option_index', v_option_index);
END;
$$;

COMMENT ON FUNCTION public.get_poll_vote_by_token(uuid, uuid) IS
  'session_token으로 해당 투표에서 내가 선택한 option_index 조회. 없으면 null.';

GRANT EXECUTE ON FUNCTION public.insert_poll_vote_by_token(uuid, uuid, int) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.get_poll_vote_by_token(uuid, uuid) TO anon, authenticated;
