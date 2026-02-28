-- =============================================================================
-- SUGGESTION COMMENTS (건의함 댓글) + 공개/비공개·비밀번호
-- =============================================================================
-- 테이블이 없으면 생성, 있으면 is_private·password 컬럼만 추가합니다.
CREATE TABLE IF NOT EXISTS public.suggestion_comments (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  suggestion_id uuid NOT NULL REFERENCES public.suggestions(id) ON DELETE CASCADE,
  author_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  content text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  is_private boolean NOT NULL DEFAULT false,
  password text
);

CREATE INDEX IF NOT EXISTS idx_suggestion_comments_suggestion_id
  ON public.suggestion_comments(suggestion_id);
CREATE INDEX IF NOT EXISTS idx_suggestion_comments_author_id
  ON public.suggestion_comments(author_id);
CREATE INDEX IF NOT EXISTS idx_suggestion_comments_created_at
  ON public.suggestion_comments(created_at);

-- 기존 테이블에 컬럼이 없을 수 있으므로 추가 (IF NOT EXISTS)
ALTER TABLE public.suggestion_comments
  ADD COLUMN IF NOT EXISTS is_private boolean NOT NULL DEFAULT false;
ALTER TABLE public.suggestion_comments
  ADD COLUMN IF NOT EXISTS password text;

COMMENT ON COLUMN public.suggestion_comments.is_private IS '비공개 댓글 여부. true면 비밀번호 입력 후 내용 표시';
COMMENT ON COLUMN public.suggestion_comments.password IS '비공개 댓글 비밀번호 (평문 또는 해시, 클라이언트 검증용)';

ALTER TABLE public.suggestion_comments ENABLE ROW LEVEL SECURITY;

-- 정책: 건의 글 읽기 권한이 있으면 해당 건의의 댓글 목록 조회 가능 (비공개도 메타는 보임, 내용은 앱에서 비밀번호 검증 후 표시)
DROP POLICY IF EXISTS "Users can read suggestion comments" ON public.suggestion_comments;
CREATE POLICY "Users can read suggestion comments"
  ON public.suggestion_comments FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.suggestions s
      WHERE s.id = suggestion_comments.suggestion_id
      AND (
        s.author_id IN (SELECT id FROM public.profiles WHERE user_id = auth.uid())
        OR EXISTS (SELECT 1 FROM public.profiles WHERE user_id = auth.uid() AND role IN ('council', 'admin'))
      )
    )
  );

DROP POLICY IF EXISTS "Authors can insert own comment" ON public.suggestion_comments;
CREATE POLICY "Authors can insert own comment"
  ON public.suggestion_comments FOR INSERT
  WITH CHECK (
    author_id IN (SELECT id FROM public.profiles WHERE user_id = auth.uid())
  );

DROP POLICY IF EXISTS "Authors can update own comment" ON public.suggestion_comments;
CREATE POLICY "Authors can update own comment"
  ON public.suggestion_comments FOR UPDATE
  USING (author_id IN (SELECT id FROM public.profiles WHERE user_id = auth.uid()))
  WITH CHECK (author_id IN (SELECT id FROM public.profiles WHERE user_id = auth.uid()));

DROP POLICY IF EXISTS "Authors can delete own comment" ON public.suggestion_comments;
CREATE POLICY "Authors can delete own comment"
  ON public.suggestion_comments FOR DELETE
  USING (author_id IN (SELECT id FROM public.profiles WHERE user_id = auth.uid()));
