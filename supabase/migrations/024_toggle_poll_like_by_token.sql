-- 세션 없이 좋아요/카운트: session_token 또는 auth.uid()로 투표 좋아요 토글·조회
-- anon은 poll_likes 직접 읽기 불가이므로 RPC로만 카운트·내 좋아요 목록 제공

-- 1) 좋아요 토글
CREATE OR REPLACE FUNCTION public.toggle_poll_like(
  p_poll_id uuid,
  p_session_token uuid DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid;
  v_profile_id uuid;
  v_exists boolean;
  v_liked boolean;
BEGIN
  -- 1) user_id 결정: auth.uid() 우선, 없으면 토큰으로 프로필 → user_id
  v_user_id := auth.uid();

  IF v_user_id IS NULL AND p_session_token IS NOT NULL THEN
    SELECT t.profile_id INTO v_profile_id
    FROM public.profile_session_tokens t
    WHERE t.token = p_session_token
      AND t.expires_at > now()
    LIMIT 1;
    IF v_profile_id IS NOT NULL THEN
      SELECT p.user_id INTO v_user_id
      FROM public.profiles p
      WHERE p.id = v_profile_id
      LIMIT 1;
    END IF;
  END IF;

  IF v_user_id IS NULL THEN
    RAISE EXCEPTION '로그인이 필요합니다.'
      USING ERRCODE = 'P0001';
  END IF;

  -- 2) 이미 좋아요 했는지 확인
  SELECT EXISTS(
    SELECT 1 FROM public.poll_likes
    WHERE poll_id = p_poll_id AND user_id = v_user_id
  ) INTO v_exists;

  IF v_exists THEN
    DELETE FROM public.poll_likes
    WHERE poll_id = p_poll_id AND user_id = v_user_id;
    v_liked := false;
  ELSE
    INSERT INTO public.poll_likes (poll_id, user_id)
    VALUES (p_poll_id, v_user_id)
    ON CONFLICT (poll_id, user_id) DO NOTHING;
    v_liked := true;
  END IF;

  RETURN jsonb_build_object('liked', v_liked);
END;
$$;

COMMENT ON FUNCTION public.toggle_poll_like(uuid, uuid) IS
  '투표 좋아요 토글. auth.uid() 또는 session_token으로 사용자 식별.';

-- 2) 투표별 좋아요 수 (anon 호출 가능, 목록 화면용)
CREATE OR REPLACE FUNCTION public.get_poll_like_counts(p_poll_ids uuid[])
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN COALESCE(
    (SELECT jsonb_object_agg(poll_id::text, cnt)
     FROM (
       SELECT poll_id, count(*)::int AS cnt
       FROM public.poll_likes
       WHERE poll_id = ANY(p_poll_ids)
       GROUP BY poll_id
     ) t),
    '{}'::jsonb
  );
END;
$$;
COMMENT ON FUNCTION public.get_poll_like_counts(uuid[]) IS 'poll_id 배열 → 좋아요 수 맵. anon 호출 가능.';

-- 3) 토큰으로 "내가 좋아요한 poll_id" 목록 (anon + token)
CREATE OR REPLACE FUNCTION public.get_poll_likes_by_token(p_session_token uuid)
RETURNS uuid[]
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
  WHERE t.token = p_session_token AND t.expires_at > now()
  LIMIT 1;
  IF v_user_id IS NULL THEN
    RETURN ARRAY[]::uuid[];
  END IF;
  RETURN ARRAY(
    SELECT poll_id FROM public.poll_likes WHERE user_id = v_user_id
  );
END;
$$;
COMMENT ON FUNCTION public.get_poll_likes_by_token(uuid) IS 'session_token으로 내가 좋아요한 poll_id 배열.';

GRANT EXECUTE ON FUNCTION public.toggle_poll_like(uuid, uuid) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.get_poll_like_counts(uuid[]) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.get_poll_likes_by_token(uuid) TO anon, authenticated;
