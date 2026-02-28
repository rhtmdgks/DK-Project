-- 세션 없이 댓글 등록: session_token으로 투표 댓글 추가 (auth.uid() 없을 때)
-- 앱에서 댓글 목록 조회가 anon으로도 되도록 SELECT 정책 추가 (목록 노출용)

CREATE POLICY "Anon can read poll comments"
  ON public.poll_comments FOR SELECT
  TO anon
  USING (true);

CREATE OR REPLACE FUNCTION public.insert_poll_comment_by_token(
  p_poll_id uuid,
  p_session_token uuid,
  p_content text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_profile_id uuid;
  v_comment_id uuid;
BEGIN
  IF nullif(trim(p_content), '') IS NULL THEN
    RAISE EXCEPTION '댓글 내용을 입력해 주세요.'
      USING ERRCODE = 'P0001';
  END IF;

  SELECT t.profile_id INTO v_profile_id
  FROM public.profile_session_tokens t
  WHERE t.token = p_session_token
    AND t.expires_at > now()
  LIMIT 1;

  IF v_profile_id IS NULL THEN
    RAISE EXCEPTION '로그인이 필요합니다. 다시 로그인해 주세요.'
      USING ERRCODE = 'P0001';
  END IF;

  INSERT INTO public.poll_comments (poll_id, author_id, content)
  VALUES (p_poll_id, v_profile_id, trim(p_content))
  RETURNING id INTO v_comment_id;

  RETURN v_comment_id;
END;
$$;

COMMENT ON FUNCTION public.insert_poll_comment_by_token(uuid, uuid, text) IS
  'session_token으로 투표 댓글 등록. Supabase 세션 없을 때 사용.';

GRANT EXECUTE ON FUNCTION public.insert_poll_comment_by_token(uuid, uuid, text) TO anon, authenticated;
