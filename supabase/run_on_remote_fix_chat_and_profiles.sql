-- =============================================================================
-- 원격 Supabase에서 한 번 실행: 채팅 프로필/미리보기 반영용
-- (첨부 컬럼 추가 + get_chat_messages 프로필·첨부 포함 + profiles.avatar_url 백필)
-- =============================================================================

-- 0) chat_messages에 첨부 컬럼이 없으면 추가 (나갔다 들어왔을 때 미리보기 안 나오는 문제 해결)
ALTER TABLE public.chat_messages
  ADD COLUMN IF NOT EXISTS attachment_url text,
  ADD COLUMN IF NOT EXISTS attachment_type text;

-- 1) get_chat_messages: 발신자 프로필 + attachment_url, attachment_type 포함
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

-- 2) insert_chat_message: 인자 5개 (첨부 포함) — 사진/동영상 전송 가능
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
  SELECT EXISTS (
    SELECT 1 FROM public.chat_room_members
    WHERE room_id = p_room_id AND user_id = p_sender_id
  ) INTO v_member_ok;
  IF NOT v_member_ok THEN
    RAISE EXCEPTION 'not_room_member';
  END IF;

  INSERT INTO public.chat_messages (room_id, sender_id, content, attachment_url, attachment_type)
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

-- 3) profiles.avatar_url 비어 있는 행은 DiceBear URL로 채우기
UPDATE public.profiles
SET avatar_url = 'https://api.dicebear.com/9.x/notionists/png?seed=' || user_id
WHERE avatar_url IS NULL OR trim(avatar_url) = '';

-- 4) 스토리지 버킷 chat-attachments 없으면 생성 (대시보드에서 이미 만들었으면 무시됨)
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'chat-attachments',
  'chat-attachments',
  true,
  5242880,
  ARRAY['image/jpeg', 'image/png', 'image/gif', 'image/webp', 'video/mp4', 'video/quicktime', 'video/webm', 'video/x-m4v']::text[]
)
ON CONFLICT (id) DO NOTHING;

-- 5) storage.objects RLS: chat-attachments 버킷에 anon/authenticated 업로드 허용
-- (기존 정책 제거 후 하나로 통일 — "new row violates row-level security policy" 방지)
DROP POLICY IF EXISTS "Anon upload chat attachments" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated upload chat attachments" ON storage.objects;
-- 대시보드에서 만든 동일 이름+접미사 정책이 있으면 SQL Editor에서 수동 삭제 후 아래 실행
CREATE POLICY "Allow upload chat-attachments"
  ON storage.objects FOR INSERT
  TO public
  WITH CHECK (bucket_id = 'chat-attachments');
-- 읽기(공개 URL)용 SELECT 정책이 없으면 추가
DROP POLICY IF EXISTS "Public read chat attachments" ON storage.objects;
CREATE POLICY "Public read chat attachments"
  ON storage.objects FOR SELECT
  TO public
  USING (bucket_id = 'chat-attachments');
