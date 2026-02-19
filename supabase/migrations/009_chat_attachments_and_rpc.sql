-- =============================================================================
-- 채팅 메시지 첨부파일 지원 + 메시지 조회/삽입 RPC (발신자 프로필 포함)
-- =============================================================================

-- 1. chat_messages에 첨부 컬럼 추가
ALTER TABLE public.chat_messages
  ADD COLUMN IF NOT EXISTS attachment_url text,
  ADD COLUMN IF NOT EXISTS attachment_type text;

-- 2. 메시지 조회 RPC: 발신자 프로필(full_name, student_id, avatar_url) 포함
CREATE OR REPLACE FUNCTION public.get_chat_messages(
  p_room_id uuid,
  p_user_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_member_ok boolean;
  v_result jsonb;
BEGIN
  -- 방 멤버인지 확인
  SELECT EXISTS (
    SELECT 1 FROM public.chat_room_members
    WHERE room_id = p_room_id AND user_id = p_user_id
  ) INTO v_member_ok;

  IF NOT v_member_ok THEN
    RETURN '[]'::jsonb;
  END IF;

  SELECT coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id', m.id,
        'room_id', m.room_id,
        'sender_id', m.sender_id,
        'content', m.content,
        'created_at', m.created_at,
        'attachment_url', m.attachment_url,
        'attachment_type', m.attachment_type,
        'sender_full_name', p.full_name,
        'sender_student_id', p.student_id,
        'sender_avatar_url', p.avatar_url
      )
      ORDER BY m.created_at ASC
    ),
    '[]'::jsonb
  ) INTO v_result
  FROM public.chat_messages m
  LEFT JOIN public.profiles p ON p.user_id = m.sender_id
  WHERE m.room_id = p_room_id;

  RETURN v_result;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_chat_messages(uuid, uuid) TO authenticated, anon;

-- 3. 메시지 삽입 RPC: 텍스트 + 선택적 첨부
CREATE OR REPLACE FUNCTION public.insert_chat_message(
  p_room_id uuid,
  p_sender_id uuid,
  p_content text,
  p_attachment_url text DEFAULT NULL,
  p_attachment_type text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_member_ok boolean;
  v_new_id uuid;
BEGIN
  -- 방 멤버인지 확인
  SELECT EXISTS (
    SELECT 1 FROM public.chat_room_members
    WHERE room_id = p_room_id AND user_id = p_sender_id
  ) INTO v_member_ok;

  IF NOT v_member_ok THEN
    RAISE EXCEPTION 'not_room_member';
  END IF;

  INSERT INTO public.chat_messages (
    room_id,
    sender_id,
    content,
    attachment_url,
    attachment_type
  )
  VALUES (
    p_room_id,
    p_sender_id,
    coalesce(trim(p_content), ''),
    NULLIF(trim(p_attachment_url), ''),
    NULLIF(trim(p_attachment_type), '')
  )
  RETURNING id INTO v_new_id;

  RETURN v_new_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.insert_chat_message(uuid, uuid, text, text, text) TO authenticated, anon;

-- 4. 스토리지 버킷 (채팅 이미지 첨부용). 없으면 생성.
-- (호스트 환경에서 storage 스키마가 없으면 이 블록은 건너뛰고, 대시보드에서
-- 버킷 'chat-attachments', public=true 로 생성 후 정책만 적용 가능)
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'chat-attachments',
  'chat-attachments',
  true,
  5242880,
  ARRAY['image/jpeg', 'image/png', 'image/gif', 'image/webp']::text[]
)
ON CONFLICT (id) DO NOTHING;

-- 버킷 정책: 인증된 사용자 업로드/읽기
DROP POLICY IF EXISTS "Authenticated upload chat attachments" ON storage.objects;
CREATE POLICY "Authenticated upload chat attachments"
  ON storage.objects FOR INSERT
  TO authenticated
  WITH CHECK (bucket_id = 'chat-attachments');

DROP POLICY IF EXISTS "Public read chat attachments" ON storage.objects;
CREATE POLICY "Public read chat attachments"
  ON storage.objects FOR SELECT
  TO public
  USING (bucket_id = 'chat-attachments');
