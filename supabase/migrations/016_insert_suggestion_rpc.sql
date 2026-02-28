-- =============================================================================
-- RPC: insert_suggestion - 건의 등록 (RLS policy 대신 사용, auth.uid() 기반)
-- =============================================================================
-- 앱에서 Supabase Auth 세션이 있으면 auth.uid()로 프로필을 찾아 건의를 등록합니다.
-- SECURITY DEFINER로 RLS를 우회해 삽입하며, author_id는 서버에서 결정합니다.

CREATE OR REPLACE FUNCTION public.insert_suggestion(
  p_title text,
  p_body text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid;
  v_profile_id uuid;
  v_suggestion_id uuid;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION '로그인 세션이 없습니다. 다시 로그인해 주세요.'
      USING ERRCODE = 'P0001';
  END IF;

  SELECT id INTO v_profile_id
  FROM public.profiles
  WHERE user_id = v_user_id
  LIMIT 1;

  IF v_profile_id IS NULL THEN
    RAISE EXCEPTION '프로필을 찾을 수 없습니다.'
      USING ERRCODE = 'P0002';
  END IF;

  INSERT INTO public.suggestions (author_id, title, body)
  VALUES (v_profile_id, p_title, NULLIF(trim(p_body), ''))
  RETURNING id INTO v_suggestion_id;

  RETURN v_suggestion_id;
END;
$$;

COMMENT ON FUNCTION public.insert_suggestion(text, text) IS
  '현재 로그인 사용자(auth.uid())로 건의를 등록합니다. Auth 세션이 있어야 합니다.';

GRANT EXECUTE ON FUNCTION public.insert_suggestion(text, text) TO anon, authenticated;
