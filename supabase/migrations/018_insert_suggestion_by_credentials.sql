-- =============================================================================
-- RPC: insert_suggestion_by_credentials - 세션 없이 학번+비밀번호로 건의 등록
-- =============================================================================
-- Supabase Auth 세션이 없을 때(로그인 후 세션 미연동 등) 학번·비밀번호로 본인 확인 후
-- 건의를 등록합니다. insert_suggestion RPC가 P0001로 실패할 때 앱에서 대체 호출용.

CREATE OR REPLACE FUNCTION public.insert_suggestion_by_credentials(
  p_student_id text,
  p_password text,
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
  IF nullif(trim(p_student_id), '') IS NULL OR nullif(trim(p_password), '') IS NULL THEN
    RAISE EXCEPTION '학번과 비밀번호를 입력해 주세요.'
      USING ERRCODE = 'P0001';
  END IF;

  SELECT id INTO v_profile_id
  FROM public.profiles
  WHERE student_id = trim(p_student_id)
    AND password = p_password
  LIMIT 1;

  IF v_profile_id IS NULL THEN
    RAISE EXCEPTION '학번 또는 비밀번호가 맞지 않습니다.'
      USING ERRCODE = 'P0001';
  END IF;

  INSERT INTO public.suggestions (author_id, title, body)
  VALUES (v_profile_id, p_title, NULLIF(trim(p_body), ''))
  RETURNING id INTO v_suggestion_id;

  RETURN v_suggestion_id;
END;
$$;

COMMENT ON FUNCTION public.insert_suggestion_by_credentials(text, text, text, text) IS
  '학번·비밀번호로 본인 확인 후 건의를 등록합니다. Auth 세션이 없을 때 사용.';

GRANT EXECUTE ON FUNCTION public.insert_suggestion_by_credentials(text, text, text, text) TO anon, authenticated;
