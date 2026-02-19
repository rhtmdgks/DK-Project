-- 1:1 채팅 기능 지원을 위한 마이그레이션
-- =============================================================================

-- 1. chat_rooms 테이블에 type 컬럼 추가 (direct: 1:1 채팅, group: 그룹 채팅)
ALTER TABLE public.chat_rooms 
ADD COLUMN IF NOT EXISTS type text NOT NULL DEFAULT 'group' CHECK (type IN ('direct', 'group'));

-- 2. 1:1 채팅방을 위한 인덱스 추가
CREATE INDEX IF NOT EXISTS idx_chat_rooms_type ON public.chat_rooms(type);

-- 3. 사용자가 자신의 1:1 채팅방 멤버를 추가할 수 있도록 RLS 정책 추가
CREATE POLICY "Users can insert themselves into direct chat rooms"
  ON public.chat_room_members FOR INSERT
  WITH CHECK (
    auth.uid() = user_id
    AND EXISTS (
      SELECT 1 FROM public.chat_rooms 
      WHERE chat_rooms.id = chat_room_members.room_id 
      AND chat_rooms.type = 'direct'
    )
  );

-- 4. 사용자가 1:1 채팅방을 생성할 수 있도록 RLS 정책 추가
CREATE POLICY "Users can create direct chat rooms"
  ON public.chat_rooms FOR INSERT
  WITH CHECK (
    type = 'direct'
    AND EXISTS (
      SELECT 1 FROM public.chat_room_members 
      WHERE chat_room_members.room_id = chat_rooms.id 
      AND chat_room_members.user_id = auth.uid()
    )
  );

-- 5. 1:1 채팅방 생성 또는 조회 RPC 함수
CREATE OR REPLACE FUNCTION public.create_or_get_direct_chat(
  p_other_user_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_current_user_id uuid;
  v_room_id uuid;
  v_room_name text;
  v_other_user_name text;
  v_existing_room_id uuid;
BEGIN
  -- 현재 사용자 ID 확인
  v_current_user_id := auth.uid();
  IF v_current_user_id IS NULL THEN
    RAISE EXCEPTION 'not_authenticated';
  END IF;

  -- 자기 자신과의 채팅방 생성 방지
  IF v_current_user_id = p_other_user_id THEN
    RAISE EXCEPTION 'cannot_chat_with_self';
  END IF;

  -- 상대방 프로필 정보 가져오기
  SELECT full_name INTO v_other_user_name
  FROM public.profiles
  WHERE user_id = p_other_user_id;

  IF v_other_user_name IS NULL THEN
    v_other_user_name := '알 수 없음';
  END IF;

  -- 기존 1:1 채팅방이 있는지 확인
  -- 두 사용자가 모두 멤버인 direct 타입 채팅방 찾기
  SELECT cr.id INTO v_existing_room_id
  FROM public.chat_rooms cr
  WHERE cr.type = 'direct'
    AND EXISTS (
      SELECT 1 FROM public.chat_room_members crm1
      WHERE crm1.room_id = cr.id AND crm1.user_id = v_current_user_id
    )
    AND EXISTS (
      SELECT 1 FROM public.chat_room_members crm2
      WHERE crm2.room_id = cr.id AND crm2.user_id = p_other_user_id
    )
  LIMIT 1;

  -- 기존 채팅방이 있으면 반환
  IF v_existing_room_id IS NOT NULL THEN
    RETURN jsonb_build_object(
      'room_id', v_existing_room_id,
      'room_name', v_room_name,
      'created', false
    );
  END IF;

  -- 새 채팅방 생성
  v_room_name := v_other_user_name || '님과의 채팅';
  
  INSERT INTO public.chat_rooms (name, type)
  VALUES (v_room_name, 'direct')
  RETURNING id INTO v_room_id;

  -- 두 사용자를 멤버로 추가
  INSERT INTO public.chat_room_members (room_id, user_id)
  VALUES (v_room_id, v_current_user_id);

  INSERT INTO public.chat_room_members (room_id, user_id)
  VALUES (v_room_id, p_other_user_id);

  RETURN jsonb_build_object(
    'room_id', v_room_id,
    'room_name', v_room_name,
    'created', true
  );
END;
$$;

-- RPC 함수 실행 권한 부여
GRANT EXECUTE ON FUNCTION public.create_or_get_direct_chat(uuid) TO authenticated, anon;

-- 6. 채팅방의 다른 사용자 정보를 가져오는 헬퍼 함수
CREATE OR REPLACE FUNCTION public.get_direct_chat_other_user(
  p_room_id uuid
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
  v_other_user_avatar_url text;
BEGIN
  v_current_user_id := auth.uid();
  IF v_current_user_id IS NULL THEN
    RETURN NULL;
  END IF;

  -- 1:1 채팅방의 다른 사용자 찾기
  SELECT crm.user_id INTO v_other_user_id
  FROM public.chat_room_members crm
  WHERE crm.room_id = p_room_id
    AND crm.user_id != v_current_user_id
  LIMIT 1;

  IF v_other_user_id IS NULL THEN
    RETURN NULL;
  END IF;

  -- 상대방 프로필 정보 가져오기
  SELECT full_name, avatar_url
  INTO v_other_user_name, v_other_user_avatar_url
  FROM public.profiles
  WHERE user_id = v_other_user_id;

  RETURN jsonb_build_object(
    'user_id', v_other_user_id,
    'full_name', COALESCE(v_other_user_name, '알 수 없음'),
    'avatar_url', v_other_user_avatar_url
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_direct_chat_other_user(uuid) TO authenticated, anon;
