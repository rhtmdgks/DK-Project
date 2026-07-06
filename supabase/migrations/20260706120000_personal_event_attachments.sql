-- =============================================================================
-- 개인 일정 첨부파일: 메타 테이블 + 비공개 Storage 버킷
-- =============================================================================
-- 시험 시간표 이미지·PDF 등을 개인 일정에 첨부. 본인만 접근(서명 URL).

CREATE TABLE IF NOT EXISTS public.personal_event_attachments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id uuid NOT NULL REFERENCES public.personal_events(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  file_name text NOT NULL,
  storage_path text NOT NULL,
  mime_type text,
  file_size int,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_personal_event_attachments_event_id
  ON public.personal_event_attachments(event_id);
CREATE INDEX IF NOT EXISTS idx_personal_event_attachments_user_id
  ON public.personal_event_attachments(user_id);

ALTER TABLE public.personal_event_attachments ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users manage own event attachments" ON public.personal_event_attachments;
CREATE POLICY "Users manage own event attachments"
  ON public.personal_event_attachments FOR ALL
  TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- 비공개 버킷: 서명 URL로만 접근. 경로 {user_id}/{event_id}/{timestamp}.{ext}
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'personal-event-attachments',
  'personal-event-attachments',
  false,
  10485760,
  ARRAY['image/jpeg', 'image/png', 'image/gif', 'image/webp', 'application/pdf']::text[]
)
ON CONFLICT (id) DO NOTHING;

DROP POLICY IF EXISTS "Own folder read personal event attachments" ON storage.objects;
CREATE POLICY "Own folder read personal event attachments"
  ON storage.objects FOR SELECT
  TO authenticated
  USING (
    bucket_id = 'personal-event-attachments'
    AND (storage.foldername(name))[1] = (SELECT auth.uid()::text)
  );

DROP POLICY IF EXISTS "Own folder upload personal event attachments" ON storage.objects;
CREATE POLICY "Own folder upload personal event attachments"
  ON storage.objects FOR INSERT
  TO authenticated
  WITH CHECK (
    bucket_id = 'personal-event-attachments'
    AND (storage.foldername(name))[1] = (SELECT auth.uid()::text)
  );

DROP POLICY IF EXISTS "Own folder delete personal event attachments" ON storage.objects;
CREATE POLICY "Own folder delete personal event attachments"
  ON storage.objects FOR DELETE
  TO authenticated
  USING (
    bucket_id = 'personal-event-attachments'
    AND (storage.foldername(name))[1] = (SELECT auth.uid()::text)
  );
