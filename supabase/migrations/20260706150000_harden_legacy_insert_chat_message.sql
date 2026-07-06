-- =============================================================================
-- 레거시 insert_chat_message(3-인자) 우회 경로 차단
-- =============================================================================
-- 5-인자 버전은 auth.uid() 검증 + 서버 금칙어 검열을 수행하지만,
-- 레거시 3-인자 오버로드는 검열도 없고 sender 위조도 가능하며 anon에도 열려 있었다.
-- 앱/백오피스는 모두 5-인자 버전만 호출하므로, 3-인자 버전은 5-인자 버전에
-- 위임하도록 재정의해 검열/인증을 강제한다.

CREATE OR REPLACE FUNCTION public.insert_chat_message(
  p_room_id uuid,
  p_sender_id uuid,
  p_content text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_new_id uuid;
BEGIN
  -- 검열·인증이 포함된 정식 5-인자 버전에 위임
  v_new_id := public.insert_chat_message(p_room_id, p_sender_id, p_content, null, null);
  RETURN jsonb_build_object('success', true, 'message_id', v_new_id);
END;
$$;

REVOKE EXECUTE ON FUNCTION public.insert_chat_message(uuid, uuid, text) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.insert_chat_message(uuid, uuid, text) FROM anon;
GRANT EXECUTE ON FUNCTION public.insert_chat_message(uuid, uuid, text) TO authenticated;

-- 5-인자 버전도 함수 기본 PUBLIC 권한이 남아 anon이 상속받는다.
-- (auth.uid() 검사로 실제 삽입은 막히지만) 방어적으로 PUBLIC에서 회수.
REVOKE EXECUTE ON FUNCTION public.insert_chat_message(uuid, uuid, text, text, text) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.insert_chat_message(uuid, uuid, text, text, text) FROM anon;
GRANT EXECUTE ON FUNCTION public.insert_chat_message(uuid, uuid, text, text, text) TO authenticated;
