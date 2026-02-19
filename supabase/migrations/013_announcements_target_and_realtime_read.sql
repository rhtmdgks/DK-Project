-- =============================================================================
-- 공지사항 대상(학년) + Realtime 알림이 모든 클라이언트에 전달되도록
-- =============================================================================
-- 백오피스에서 특정 대상(1학년, 2학년, 3학년, 전체)으로 공지를 넣어도
-- Realtime INSERT 이벤트가 모든 앱에 전달되어야 알림을 켠 사용자가 받을 수 있음.
-- RLS로 SELECT를 학년별로 제한해 두면, 해당 학년이 아닌 사용자(및 anon)는
-- 이벤트 자체를 받지 못해 알림이 가지 않음.
-- 따라서 공지사항은 "모두가 SELECT 가능"하게 두고, 알림 표시 여부는 앱에서
-- target_grade와 사용자 학년을 비교해 필터링함.

-- 1) target_grade 컬럼 없으면 추가 (백오피스에서 1학년/2학년/3학년/전체 지정용)
ALTER TABLE public.announcements
  ADD COLUMN IF NOT EXISTS target_grade text;

COMMENT ON COLUMN public.announcements.target_grade IS '대상: NULL 또는 전체=전체, 1학년, 2학년, 3학년 등';

-- 반별 대상 지정용 (NULL이면 학년 전체, 값 있으면 해당 반만)
ALTER TABLE public.announcements
  ADD COLUMN IF NOT EXISTS target_class smallint;
COMMENT ON COLUMN public.announcements.target_class IS '대상 반. NULL=학년 전체, 1~12 등 = 해당 반만';

-- 2) Realtime으로 INSERT가 모든 구독자에게 전달되도록 SELECT 정책 보강
--    (기존 정책이 학년 제한으로 바뀌어 있어도, 아래 정책이 있으면 모든 행 읽기 가능)
DROP POLICY IF EXISTS "Allow all to read announcements for Realtime" ON public.announcements;
CREATE POLICY "Allow all to read announcements for Realtime"
  ON public.announcements FOR SELECT
  TO public
  USING (true);
