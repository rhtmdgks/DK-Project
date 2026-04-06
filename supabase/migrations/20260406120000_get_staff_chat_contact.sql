-- 건의함 1:1 채팅: 클라이언트가 profiles를 직접 조회하면 RLS로 admin 행이 보이지 않음.
-- 로그인 사용자에게만 admin → council 순으로 한 명의 user_id를 반환하는 RPC.

CREATE OR REPLACE FUNCTION public.get_staff_chat_contact()
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_result jsonb;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'not_authenticated';
  END IF;

  SELECT jsonb_build_object(
    'user_id', p.user_id,
    'full_name', p.full_name
  )
  INTO v_result
  FROM public.profiles p
  WHERE p.role IN ('admin', 'council')
  ORDER BY CASE p.role WHEN 'admin' THEN 0 ELSE 1 END, p.created_at ASC
  LIMIT 1;

  RETURN v_result;
END;
$$;

REVOKE ALL ON FUNCTION public.get_staff_chat_contact() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_staff_chat_contact() TO authenticated;

COMMENT ON FUNCTION public.get_staff_chat_contact() IS
  '건의함에서 관리자/학생회 1:1 채팅 상대 user_id 조회 (RLS 우회, 로그인 사용자만).';
