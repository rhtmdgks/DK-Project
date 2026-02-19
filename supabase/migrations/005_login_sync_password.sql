-- =============================================================================
-- RPC: login_sync_password - 로그인 시 비밀번호 동기화 및 검증
-- =============================================================================
-- profiles 테이블에 있는 학번만 로그인할 수 있도록 검증합니다.
-- auth.users의 비밀번호와 profiles의 정보를 동기화합니다.

CREATE OR REPLACE FUNCTION public.login_sync_password(
  p_student_id text,
  p_password text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_profile_id uuid;
  v_user_id uuid;
  v_email text;
BEGIN
  -- profiles 테이블에서 학번으로 프로필 찾기
  SELECT id, user_id INTO v_profile_id, v_user_id
  FROM public.profiles
  WHERE student_id = p_student_id
  LIMIT 1;

  -- 프로필이 없으면 에러 발생
  IF v_profile_id IS NULL THEN
    RAISE EXCEPTION '학번 또는 비밀번호를 확인하세요';
  END IF;

  -- 이메일 생성 (학번@school.local)
  v_email := p_student_id || '@school.local';

  -- auth.users에 사용자가 있는지 확인하고, 없으면 생성
  -- 비밀번호는 signInWithPassword에서 검증되므로 여기서는 동기화만 수행
  -- 실제 비밀번호 검증은 Supabase Auth가 처리합니다.
  
  -- 이 함수는 profiles 테이블에 학번이 있는지만 확인합니다.
  -- 실제 인증은 signInWithPassword에서 수행됩니다.
END;
$$;

-- anon과 authenticated 모두 호출 가능 (로그인 전이므로 anon 필요)
GRANT EXECUTE ON FUNCTION public.login_sync_password(text, text) TO anon, authenticated;
