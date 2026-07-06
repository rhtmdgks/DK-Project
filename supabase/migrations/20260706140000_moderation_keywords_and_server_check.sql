-- =============================================================================
-- 채팅 검열 강화: 금칙어 DB화 + insert_chat_message 서버 검열
-- =============================================================================
-- 클라이언트 키워드 필터만으로는 우회 가능하므로 RPC에서 2차 검사한다.
-- 정규화: 공백·특수문자 제거 + 소문자화 후 활성 키워드 부분 일치.

CREATE TABLE IF NOT EXISTS public.moderation_keywords (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  keyword text NOT NULL UNIQUE,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.moderation_keywords ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Authenticated read moderation keywords" ON public.moderation_keywords;
CREATE POLICY "Authenticated read moderation keywords"
  ON public.moderation_keywords FOR SELECT
  TO authenticated
  USING (true);

DROP POLICY IF EXISTS "Council admin manage moderation keywords" ON public.moderation_keywords;
CREATE POLICY "Council admin manage moderation keywords"
  ON public.moderation_keywords FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE user_id = auth.uid() AND role IN ('council', 'admin')
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE user_id = auth.uid() AND role IN ('council', 'admin')
    )
  );

-- 기본 키워드 시드 (앱 클라이언트 목록 + 확장)
INSERT INTO public.moderation_keywords (keyword) VALUES
  ('지랄'), ('병신'), ('씨발'), ('시발'), ('ㅅㅂ'), ('개새끼'), ('새끼'), ('좆되'),
  ('죽어'), ('꺼져'), ('미친'), ('개같'), ('fuck'), ('shit'), ('bitch'), ('asshole')
ON CONFLICT (keyword) DO NOTHING;

-- 서버 검열 함수: 공백/특수문자 제거 후 활성 키워드 매칭
CREATE OR REPLACE FUNCTION public.contains_blocked_keyword(p_text text)
RETURNS boolean
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_normalized text;
BEGIN
  IF p_text IS NULL OR trim(p_text) = '' THEN
    RETURN false;
  END IF;
  -- 공백·구두점 등 비문자 제거 + 소문자화 (leet/띄어쓰기 우회 방지)
  v_normalized := lower(regexp_replace(p_text, '[^[:alnum:]\uac00-\ud7a3\u3131-\u318e]+', '', 'g'));
  RETURN EXISTS (
    SELECT 1 FROM public.moderation_keywords k
    WHERE k.is_active
      AND v_normalized LIKE '%' || lower(replace(k.keyword, ' ', '')) || '%'
  );
END;
$$;

-- insert_chat_message에 서버 검열 추가 (20260331131000 버전 대체)
CREATE OR REPLACE FUNCTION public.insert_chat_message(
  p_room_id uuid,
  p_sender_id uuid,
  p_content text,
  p_attachment_url text DEFAULT null,
  p_attachment_type text DEFAULT null
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_member_ok boolean;
  v_new_id uuid;
  v_uid uuid;
BEGIN
  v_uid := auth.uid();
  IF v_uid IS NULL OR v_uid <> p_sender_id THEN
    RAISE EXCEPTION 'unauthorized' USING errcode = 'P0001';
  END IF;

  SELECT EXISTS (
    SELECT 1 FROM public.chat_room_members
    WHERE room_id = p_room_id AND user_id = v_uid
  ) INTO v_member_ok;

  IF NOT v_member_ok THEN
    RAISE EXCEPTION 'not_room_member' USING errcode = 'P0001';
  END IF;

  -- 서버 측 금칙어 검사 (클라이언트 우회 방지)
  IF public.contains_blocked_keyword(p_content) THEN
    RAISE EXCEPTION 'message_blocked' USING errcode = 'P0001';
  END IF;

  INSERT INTO public.chat_messages (
    room_id, sender_id, content, attachment_url, attachment_type
  )
  VALUES (
    p_room_id,
    v_uid,
    coalesce(trim(p_content), ''),
    nullif(trim(p_attachment_url), ''),
    nullif(trim(p_attachment_type), '')
  )
  RETURNING id INTO v_new_id;

  RETURN v_new_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.insert_chat_message(uuid, uuid, text, text, text) FROM anon;
GRANT EXECUTE ON FUNCTION public.insert_chat_message(uuid, uuid, text, text, text) TO authenticated;
REVOKE EXECUTE ON FUNCTION public.contains_blocked_keyword(text) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.contains_blocked_keyword(text) FROM anon;
GRANT EXECUTE ON FUNCTION public.contains_blocked_keyword(text) TO authenticated;
