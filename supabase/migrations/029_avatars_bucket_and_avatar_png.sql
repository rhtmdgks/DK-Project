-- =============================================================================
-- 프로필 사진 연동: avatars 버킷 + DiceBear PNG 통일
-- =============================================================================
-- 1) avatars 버킷: 백오피스/Flutter 프로필 사진 업로드·표시용. public read.
-- 2) 트리거: avatar_url 비어 있을 때 DiceBear PNG URL 설정 (Flutter Image.network 호환).
-- 3) 기존 SVG URL을 PNG로 일괄 변경.

-- 1. avatars 스토리지 버킷

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'avatars',
  'avatars',
  true,
  2097152,
  ARRAY['image/jpeg', 'image/png', 'image/gif', 'image/webp']::text[]
)
ON CONFLICT (id) DO NOTHING;

-- 2. avatars 버킷 정책: 공개 읽기, 인증된 사용자 업로드
DROP POLICY IF EXISTS "Public read avatars" ON storage.objects;
CREATE POLICY "Public read avatars"
  ON storage.objects FOR SELECT
  TO public
  USING (bucket_id = 'avatars');

DROP POLICY IF EXISTS "Authenticated upload avatars" ON storage.objects;
CREATE POLICY "Authenticated upload avatars"
  ON storage.objects FOR INSERT
  TO authenticated
  WITH CHECK (bucket_id = 'avatars');

-- 3. DiceBear 트리거 함수: SVG → PNG (Flutter Image.network 호환)
CREATE OR REPLACE FUNCTION public.set_profile_avatar_dicebear()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.avatar_url IS NULL OR trim(NEW.avatar_url) = '' THEN
    NEW.avatar_url := 'https://api.dicebear.com/9.x/notionists/png?seed=' || NEW.user_id;
  END IF;
  RETURN NEW;
END;
$$;

-- 4. 기존 DiceBear SVG URL을 PNG로 일괄 변경
UPDATE public.profiles
SET avatar_url = 'https://api.dicebear.com/9.x/notionists/png?seed=' || user_id
WHERE avatar_url IS NOT NULL
  AND trim(avatar_url) <> ''
  AND avatar_url LIKE 'https://api.dicebear.com/9.x/notionists/svg?seed=%';
