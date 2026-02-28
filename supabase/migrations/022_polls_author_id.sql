-- 투표 게시물 작성자(어드민) 표시: polls에 author_id 추가
-- 백오피스에서 투표 생성 시 로그인한 어드민 프로필을 저장, Flutter에서 이름·프로필 사진 표시

ALTER TABLE public.polls
  ADD COLUMN IF NOT EXISTS author_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_polls_author_id ON public.polls(author_id);

COMMENT ON COLUMN public.polls.author_id IS '투표 작성자(profiles.id). 백오피스에서 생성 시 로그인한 council/admin 프로필 id';
