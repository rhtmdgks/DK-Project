-- =============================================================================
-- POLL LIKES (투표 좋아요, 1인 1좋아요)
-- =============================================================================
CREATE TABLE IF NOT EXISTS public.poll_likes (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  poll_id uuid NOT NULL REFERENCES public.polls(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(poll_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_poll_likes_poll_id ON public.poll_likes(poll_id);
CREATE INDEX IF NOT EXISTS idx_poll_likes_user_id ON public.poll_likes(user_id);

ALTER TABLE public.poll_likes ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Anyone authenticated can read poll likes" ON public.poll_likes;
CREATE POLICY "Anyone authenticated can read poll likes"
  ON public.poll_likes FOR SELECT
  TO authenticated
  USING (true);

DROP POLICY IF EXISTS "Users can insert own like" ON public.poll_likes;
CREATE POLICY "Users can insert own like"
  ON public.poll_likes FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can delete own like" ON public.poll_likes;
CREATE POLICY "Users can delete own like"
  ON public.poll_likes FOR DELETE
  TO authenticated
  USING (auth.uid() = user_id);

-- =============================================================================
-- POLL COMMENTS (투표 댓글)
-- =============================================================================
CREATE TABLE IF NOT EXISTS public.poll_comments (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  poll_id uuid NOT NULL REFERENCES public.polls(id) ON DELETE CASCADE,
  author_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  content text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_poll_comments_poll_id ON public.poll_comments(poll_id);
CREATE INDEX IF NOT EXISTS idx_poll_comments_author_id ON public.poll_comments(author_id);
CREATE INDEX IF NOT EXISTS idx_poll_comments_created_at ON public.poll_comments(created_at DESC);

ALTER TABLE public.poll_comments ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Anyone authenticated can read poll comments" ON public.poll_comments;
CREATE POLICY "Anyone authenticated can read poll comments"
  ON public.poll_comments FOR SELECT
  TO authenticated
  USING (true);

DROP POLICY IF EXISTS "Users can insert own comment" ON public.poll_comments;
CREATE POLICY "Users can insert own comment"
  ON public.poll_comments FOR INSERT
  TO authenticated
  WITH CHECK (
    author_id IN (SELECT id FROM public.profiles WHERE user_id = auth.uid())
  );

DROP POLICY IF EXISTS "Authors can update own comment" ON public.poll_comments;
CREATE POLICY "Authors can update own comment"
  ON public.poll_comments FOR UPDATE
  TO authenticated
  USING (author_id IN (SELECT id FROM public.profiles WHERE user_id = auth.uid()))
  WITH CHECK (author_id IN (SELECT id FROM public.profiles WHERE user_id = auth.uid()));

DROP POLICY IF EXISTS "Authors can delete own comment" ON public.poll_comments;
CREATE POLICY "Authors can delete own comment"
  ON public.poll_comments FOR DELETE
  TO authenticated
  USING (author_id IN (SELECT id FROM public.profiles WHERE user_id = auth.uid()));
