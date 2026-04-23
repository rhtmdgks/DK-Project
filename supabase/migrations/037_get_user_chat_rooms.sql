-- get_user_chat_rooms: 사용자가 참여 중인 채팅방 목록 반환 (RLS 우회)
-- 앱에서 supabase.rpc('get_user_chat_rooms', params: {'p_user_id': uid}) 로 호출

CREATE OR REPLACE FUNCTION public.get_user_chat_rooms(
  p_user_id uuid
)
RETURNS TABLE (
  id        uuid,
  name      text,
  type      text,
  created_at timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF p_user_id IS NULL THEN
    RETURN;
  END IF;

  RETURN QUERY
  SELECT
    cr.id,
    cr.name,
    cr.type,
    cr.created_at
  FROM public.chat_rooms cr
  WHERE EXISTS (
    SELECT 1
    FROM public.chat_room_members crm
    WHERE crm.room_id = cr.id
      AND crm.user_id = p_user_id
  )
  ORDER BY cr.created_at DESC;
END;
$$;

REVOKE ALL ON FUNCTION public.get_user_chat_rooms(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_user_chat_rooms(uuid) TO authenticated, anon;

COMMENT ON FUNCTION public.get_user_chat_rooms(uuid) IS
  '사용자가 참여 중인 채팅방 목록 조회 (SECURITY DEFINER, RLS 우회)';
