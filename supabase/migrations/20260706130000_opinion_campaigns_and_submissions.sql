-- =============================================================================
-- 학생 의견 공개 모집: 캠페인 + 제출
-- =============================================================================
-- 익명 규칙: author_id는 항상 저장하되 앱 UI에서는 노출하지 않는다.
-- 백오피스(council/admin)는 author 프로필을 조인해 실명 확인 가능.

CREATE TABLE IF NOT EXISTS public.opinion_campaigns (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  title text NOT NULL,
  description text,
  status text NOT NULL DEFAULT 'draft' CHECK (status IN ('draft', 'open', 'closed')),
  starts_at timestamptz,
  ends_at timestamptz,
  created_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_opinion_campaigns_status ON public.opinion_campaigns(status);
CREATE INDEX IF NOT EXISTS idx_opinion_campaigns_created_at ON public.opinion_campaigns(created_at DESC);

CREATE TABLE IF NOT EXISTS public.opinion_submissions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  campaign_id uuid NOT NULL REFERENCES public.opinion_campaigns(id) ON DELETE CASCADE,
  author_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  body text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(campaign_id, author_id)
);

CREATE INDEX IF NOT EXISTS idx_opinion_submissions_campaign_id ON public.opinion_submissions(campaign_id);
CREATE INDEX IF NOT EXISTS idx_opinion_submissions_author_id ON public.opinion_submissions(author_id);

ALTER TABLE public.opinion_campaigns ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.opinion_submissions ENABLE ROW LEVEL SECURITY;

-- 캠페인: 학생은 open만, council/admin은 전체
DROP POLICY IF EXISTS "Students read open campaigns" ON public.opinion_campaigns;
CREATE POLICY "Students read open campaigns"
  ON public.opinion_campaigns FOR SELECT
  TO authenticated
  USING (
    status = 'open'
    OR EXISTS (
      SELECT 1 FROM public.profiles
      WHERE user_id = auth.uid() AND role IN ('council', 'admin')
    )
  );

DROP POLICY IF EXISTS "Council admin manage campaigns" ON public.opinion_campaigns;
CREATE POLICY "Council admin manage campaigns"
  ON public.opinion_campaigns FOR ALL
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

-- 제출: 본인 또는 council/admin만 SELECT
DROP POLICY IF EXISTS "Read own submissions or staff" ON public.opinion_submissions;
CREATE POLICY "Read own submissions or staff"
  ON public.opinion_submissions FOR SELECT
  TO authenticated
  USING (
    author_id IN (SELECT id FROM public.profiles WHERE user_id = auth.uid())
    OR EXISTS (
      SELECT 1 FROM public.profiles
      WHERE user_id = auth.uid() AND role IN ('council', 'admin')
    )
  );

-- 제출 INSERT: 본인 author_id + open 캠페인만
DROP POLICY IF EXISTS "Insert own submission to open campaign" ON public.opinion_submissions;
CREATE POLICY "Insert own submission to open campaign"
  ON public.opinion_submissions FOR INSERT
  TO authenticated
  WITH CHECK (
    author_id IN (SELECT id FROM public.profiles WHERE user_id = auth.uid())
    AND EXISTS (
      SELECT 1 FROM public.opinion_campaigns c
      WHERE c.id = campaign_id AND c.status = 'open'
    )
  );

CREATE TRIGGER opinion_campaigns_updated_at
  BEFORE UPDATE ON public.opinion_campaigns
  FOR EACH ROW
  EXECUTE FUNCTION public.set_updated_at();
