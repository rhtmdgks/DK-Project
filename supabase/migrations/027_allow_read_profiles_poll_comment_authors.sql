-- 댓글 작성자 프로필(이름·프로필 사진) 표시를 위해, poll_comments.author_id인 프로필 읽기 허용
-- 023은 투표 작성자만 허용 → 댓글 작성자는 조회 불가로 아바타/이름 미표시됨

DROP POLICY IF EXISTS "Allow read profiles that are poll comment authors" ON public.profiles;
CREATE POLICY "Allow read profiles that are poll comment authors"
  ON public.profiles FOR SELECT
  USING (
    EXISTS (SELECT 1 FROM public.poll_comments pc WHERE pc.author_id = profiles.id)
  );
