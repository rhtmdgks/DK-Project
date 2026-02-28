-- 투표 작성자 프로필을 앱에서 표시하기 위해, 해당 작성자(profiles) 읽기 허용
-- 기존: 본인 프로필만 SELECT 가능 → 학생 로그인 시 어드민 프로필 조회 불가로 이름/프로필 사진 미표시
-- 참고: announcements.author_id 가 있는 DB면 동일 정책을 announcements용으로 추가 가능

CREATE POLICY "Allow read profiles that are poll authors"
  ON public.profiles FOR SELECT
  USING (
    EXISTS (SELECT 1 FROM public.polls p WHERE p.author_id = profiles.id)
  );