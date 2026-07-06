-- =============================================================================
-- 프로필 확장: 목표 대학 + avatars 버킷 본인 폴더 RLS
-- =============================================================================
-- 1) profiles.target_university: 학생이 프로필 편집 화면에서 설정하는 목표 대학.
--    본인만 UPDATE (기존 "Users can update own profile" 정책 재사용).
-- 2) avatars 버킷: 업로드/수정/삭제를 본인 폴더({auth.uid()}/...)로 제한.
--    읽기는 기존 "Public read avatars" 유지.

ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS target_university text;

DROP POLICY IF EXISTS "Authenticated upload avatars" ON storage.objects;
CREATE POLICY "Authenticated upload avatars"
  ON storage.objects FOR INSERT
  TO authenticated
  WITH CHECK (
    bucket_id = 'avatars'
    AND (storage.foldername(name))[1] = (SELECT auth.uid()::text)
  );

DROP POLICY IF EXISTS "Authenticated update own avatars" ON storage.objects;
CREATE POLICY "Authenticated update own avatars"
  ON storage.objects FOR UPDATE
  TO authenticated
  USING (
    bucket_id = 'avatars'
    AND (storage.foldername(name))[1] = (SELECT auth.uid()::text)
  );

DROP POLICY IF EXISTS "Authenticated delete own avatars" ON storage.objects;
CREATE POLICY "Authenticated delete own avatars"
  ON storage.objects FOR DELETE
  TO authenticated
  USING (
    bucket_id = 'avatars'
    AND (storage.foldername(name))[1] = (SELECT auth.uid()::text)
  );
