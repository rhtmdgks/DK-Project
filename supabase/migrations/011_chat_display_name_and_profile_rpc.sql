-- =============================================================================
-- 채팅 "알 수 없음" 해결: 세션 없이 상대방 이름 조회 + 프로필 표시용 RPC
-- =============================================================================

-- 1. get_direct_chat_other_user: p_user_id 추가 (앱이 세션 없이 로그인 시 사용)
CREATE OR REPLACE FUNCTION public.get_direct_chat_other_user(
  p_room_id uuid,
  p_user_id uuid DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_current_user_id uuid;
  v_other_user_id uuid;
  v_other_user_name text;
  v_other_student_id text;
  v_other_user_avatar_url text;
BEGIN
  v_current_user_id := COALESCE(p_user_id, auth.uid());
  IF v_current_user_id IS NULL THEN
    RETURN NULL;
  END IF;

  SELECT crm.user_id INTO v_other_user_id
  FROM public.chat_room_members crm
  WHERE crm.room_id = p_room_id
    AND crm.user_id != v_current_user_id
  LIMIT 1;

  IF v_other_user_id IS NULL THEN
    RETURN NULL;
  END IF;

  SELECT full_name, student_id, avatar_url
  INTO v_other_user_name, v_other_student_id, v_other_user_avatar_url
  FROM public.profiles
  WHERE user_id = v_other_user_id;

  RETURN jsonb_build_object(
    'user_id', v_other_user_id,
    'full_name', COALESCE(v_other_user_name, '알 수 없음'),
    'student_id', v_other_student_id,
    'avatar_url', v_other_user_avatar_url
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_direct_chat_other_user(uuid, uuid) TO authenticated, anon;

-- 2. 프로필 표시용 RPC (이름 없을 때 앱에서 보강용, SECURITY DEFINER로 RLS 우회)
CREATE OR REPLACE FUNCTION public.get_profile_display(
  p_user_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_full_name text;
  v_student_id text;
  v_avatar_url text;
BEGIN
  SELECT full_name, student_id, avatar_url
  INTO v_full_name, v_student_id, v_avatar_url
  FROM public.profiles
  WHERE user_id = p_user_id;

  IF v_full_name IS NULL AND v_student_id IS NULL THEN
    RETURN NULL;
  END IF;

  RETURN jsonb_build_object(
    'full_name', COALESCE(v_full_name, ''),
    'student_id', COALESCE(v_student_id, ''),
    'avatar_url', v_avatar_url
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_profile_display(uuid) TO authenticated, anon;
