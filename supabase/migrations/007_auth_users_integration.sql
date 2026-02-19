-- =============================================================================
-- RPC: login_from_profiles - Auth.users 통합 버전
-- =============================================================================
-- 백오피스 Auth 변경사항 반영:
-- 모든 사용자가 auth.users에 존재하도록 보장됨
-- profiles.user_id는 항상 auth.users.id를 참조
-- 
-- 이 함수는 profiles 테이블에서 인증을 확인하고,
-- user_id와 email을 반환합니다.
-- 백오피스에서 이미 auth.users를 생성하고 profiles.user_id를 업데이트하므로,
-- 이 함수는 기존 로직을 유지합니다.

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
BEGIN
  -- 입력 검증
  IF nullif(trim(p_student_id), '') IS NULL OR nullif(trim(p_password), '') IS NULL THEN
    RAISE EXCEPTION 'invalid_input';
  END IF;
  
  -- profiles 테이블에서 student_id와 password 확인 및 프로필 정보 가져오기
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
  
  -- user_id가 없으면 에러 (백오피스에서 이미 생성되어 있어야 함)
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'user_not_found_in_auth';
  END IF;
  
  -- 이메일 생성 (백오피스와 동일한 형식)
  -- 백오피스에서는 ${username}-${profileId}@laon.local 형식 사용
  -- 하지만 기존 호환성을 위해 ${studentId}@school.local도 지원
  -- Flutter 앱에서 signInWithPassword 시도 시 두 형식 모두 시도 가능
  v_email := trim(p_student_id) || '@school.local';
  
  -- 성공 시 user_id, email, profile_data 반환
  -- user_id는 항상 auth.users.id를 참조 (백오피스에서 보장)
  RETURN jsonb_build_object(
    'success', true,
    'user_id', v_user_id,
    'email', v_email,
    'profile_id', v_profile_id,
    'profile', v_profile_data
  );
END;
$$;

-- anon과 authenticated 모두 호출 가능 (로그인 전이므로 anon 필요)
GRANT EXECUTE ON FUNCTION public.login_from_profiles(text, text) TO anon, authenticated;
