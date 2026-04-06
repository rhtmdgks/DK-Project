-- 학급 사진 공유: 같은 학년/반만 조회, 정·부반장·교사·관리자만 업로드
-- Flutter: lib/screens/class_photo_shares_screen.dart, 버킷 class-photo-shares

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS class_number smallint;

-- 일부 DB는 예전 `class_num`만 있고, 일부는 `class_number`만 있음
DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'profiles'
      AND column_name = 'class_num'
  ) THEN
    UPDATE public.profiles
    SET class_number = class_num
    WHERE class_number IS NULL AND class_num IS NOT NULL;
  END IF;
END $$;

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS class_leader_role text;

CREATE TABLE IF NOT EXISTS public.class_photo_shares (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  uploader_profile_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  grade smallint NOT NULL CHECK (grade BETWEEN 1 AND 3),
  class_number smallint NOT NULL CHECK (class_number BETWEEN 1 AND 10),
  title text NOT NULL,
  subject text,
  description text,
  storage_bucket text NOT NULL DEFAULT 'class-photo-shares',
  storage_path text NOT NULL,
  original_file_name text,
  mime_type text,
  size_bytes bigint,
  deleted_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_class_photo_shares_grade_class_created
  ON public.class_photo_shares(grade, class_number, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_class_photo_shares_uploader
  ON public.class_photo_shares(uploader_profile_id);

ALTER TABLE public.class_photo_shares ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Classmates can read class photo shares"
  ON public.class_photo_shares FOR SELECT
  TO authenticated
  USING (
    deleted_at IS NULL
    AND EXISTS (
      SELECT 1
      FROM public.profiles p
      WHERE p.user_id = auth.uid()
        AND p.grade = class_photo_shares.grade
        AND p.class_number = class_photo_shares.class_number
    )
  );

CREATE POLICY "Class managers can insert class photo shares"
  ON public.class_photo_shares FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM public.profiles p
      WHERE p.user_id = auth.uid()
        AND p.id = class_photo_shares.uploader_profile_id
        AND p.grade = class_photo_shares.grade
        AND p.class_number = class_photo_shares.class_number
        AND (
          p.role IN ('admin', 'teacher')
          OR p.class_leader_role IN ('president', 'vice_president')
        )
    )
  );

CREATE POLICY "Uploader or class managers can delete class photo shares"
  ON public.class_photo_shares FOR DELETE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles u
      WHERE u.id = class_photo_shares.uploader_profile_id AND u.user_id = auth.uid()
    )
    OR EXISTS (
      SELECT 1
      FROM public.profiles p
      WHERE p.user_id = auth.uid()
        AND p.grade = class_photo_shares.grade
        AND p.class_number = class_photo_shares.class_number
        AND (
          p.role IN ('admin', 'teacher')
          OR p.class_leader_role IN ('president', 'vice_president')
        )
    )
  );

-- Storage: 공개 읽기, 인증된 업로드/삭제 (행 단위 권한은 위 RLS와 앱에서 보장)
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'class-photo-shares',
  'class-photo-shares',
  true,
  10485760,
  ARRAY['image/jpeg', 'image/png', 'image/gif', 'image/webp']::text[]
)
ON CONFLICT (id) DO NOTHING;

DROP POLICY IF EXISTS "Public read class photo shares" ON storage.objects;
CREATE POLICY "Public read class photo shares"
  ON storage.objects FOR SELECT
  TO public
  USING (bucket_id = 'class-photo-shares');

DROP POLICY IF EXISTS "Authenticated upload class photo shares" ON storage.objects;
CREATE POLICY "Authenticated upload class photo shares"
  ON storage.objects FOR INSERT
  TO authenticated
  WITH CHECK (bucket_id = 'class-photo-shares');

DROP POLICY IF EXISTS "Authenticated delete own class photo shares" ON storage.objects;
CREATE POLICY "Authenticated delete own class photo shares"
  ON storage.objects FOR DELETE
  TO authenticated
  USING (
    bucket_id = 'class-photo-shares'
    AND (
      split_part(name, '/', 3) = 'uploader-' || (SELECT id::text FROM public.profiles WHERE user_id = auth.uid() LIMIT 1)
      OR EXISTS (
        SELECT 1
        FROM public.profiles p
        WHERE p.user_id = auth.uid()
          AND (
            p.role IN ('admin', 'teacher')
            OR p.class_leader_role IN ('president', 'vice_president')
          )
          AND p.grade = NULLIF(replace(split_part(name, '/', 1), 'grade-', ''), '')::smallint
          AND p.class_number
            = NULLIF(replace(split_part(name, '/', 2), 'class-', ''), '')::smallint
      )
    )
  );
