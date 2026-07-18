-- =============================================================================
-- 멀티스쿨 1단계 (7/8): role 참조 DB 함수 재작성
-- =============================================================================
-- 대상 (라이브 pg_get_functiondef 로 원본 확인 후 작성):
--  * get_staff_chat_contact: 헬퍼 role 집합 + 학교 스코프 추가 (backfill 완료 상태라 결과 불변)
--  * backoffice_create_account: backoffice_accounts.school_id 자동 세팅 (시그니처 불변)
--  * backoffice_login_from_profiles: **의도적으로 미변경.**
--    라이브 원본이 이미 삭제된 profiles.password 컬럼을 참조해 호출 시 오류가 나는
--    죽은 함수임을 확인 (20260331130000_remove_plaintext_profile_password 이후).
--    수정 없이 그대로 두고, 멀티스쿨 백오피스 인증은 2단계에서 재설계.
--
-- [백업] get_staff_chat_contact 라이브 원본 (2026-07-18 덤프):
--   CREATE OR REPLACE FUNCTION public.get_staff_chat_contact() RETURNS jsonb
--   ... SELECT jsonb_build_object('user_id', p.user_id, 'full_name', p.full_name)
--       FROM public.profiles p
--       WHERE p.role IN ('admin', 'council')
--       ORDER BY CASE p.role WHEN 'admin' THEN 0 ELSE 1 END, p.created_at ASC LIMIT 1;
--
-- [백업] backoffice_create_account 라이브 원본 (2026-07-18 덤프):
--   CREATE OR REPLACE FUNCTION public.backoffice_create_account(
--     p_username text, p_password text, p_name text, p_role text DEFAULT 'council')
--   RETURNS json ... INSERT INTO public.backoffice_accounts
--     (username, password_hash, name, role)
--   VALUES (p_username, crypt(p_password, gen_salt('bf')), p_name, p_role) ...

-- 상담(건의) 채팅 연락 대상: 같은 학교의 관리자(legacy admin/school_admin) 우선,
-- 다음 학생회(legacy council 또는 org_roles) 순.
CREATE OR REPLACE FUNCTION public.get_staff_chat_contact()
RETURNS jsonb
LANGUAGE plpgsql
STABLE SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_result jsonb;
  v_school uuid;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'not_authenticated';
  END IF;

  v_school := public.current_school_id();

  SELECT jsonb_build_object(
    'user_id', p.user_id,
    'full_name', p.full_name
  )
  INTO v_result
  FROM public.profiles p
  WHERE (p.role IN ('admin', 'school_admin')
         OR p.role = 'council'
         OR 'council' = ANY(p.org_roles))
    AND (v_school IS NULL OR p.school_id = v_school)
  ORDER BY
    CASE WHEN p.role IN ('admin', 'school_admin') THEN 0 ELSE 1 END,
    p.created_at ASC
  LIMIT 1;

  RETURN v_result;
END;
$$;

-- 백오피스 계정 생성: school_id 를 기본 학교로 자동 세팅 (시그니처 불변 —
-- 파라미터 추가 시 오버로드가 생겨 기존 3~4인자 호출이 모호해지므로 금지).
-- 멀티스쿨 백오피스가 생기면 2단계에서 school 파라미터가 있는 신규 함수로 대체.
CREATE OR REPLACE FUNCTION public.backoffice_create_account(
  p_username text,
  p_password text,
  p_name text,
  p_role text DEFAULT 'council'::text
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
  v_id uuid;
BEGIN
  INSERT INTO public.backoffice_accounts (username, password_hash, name, role, school_id)
  VALUES (
    p_username,
    crypt(p_password, gen_salt('bf')),
    p_name,
    p_role,
    public.default_school_id()
  )
  RETURNING id INTO v_id;

  RETURN json_build_object('success', true, 'id', v_id);
EXCEPTION WHEN unique_violation THEN
  RETURN json_build_object('success', false, 'error', 'username_exists');
END;
$function$;
