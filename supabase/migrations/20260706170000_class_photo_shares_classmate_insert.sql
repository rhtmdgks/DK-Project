-- 학급 사진 업로드: 같은 반 학생 전원 허용
-- (원격에 Class managers 정책만 남아 일반 학생 INSERT가 42501로 차단됨)

DROP POLICY IF EXISTS "Class managers can insert class photo shares"
  ON public.class_photo_shares;
DROP POLICY IF EXISTS "Classmates can insert class photo shares"
  ON public.class_photo_shares;

CREATE POLICY "Classmates can insert class photo shares"
  ON public.class_photo_shares FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM public.profiles p
      WHERE p.user_id = auth.uid()
        AND p.id = class_photo_shares.uploader_profile_id
        AND COALESCE(
          p.grade,
          CASE
            WHEN length(trim(p.student_id)) = 5
              THEN substring(trim(p.student_id), 1, 1)::integer
            ELSE NULL
          END
        ) = class_photo_shares.grade
        AND COALESCE(
          p.class_number,
          CASE
            WHEN length(trim(p.student_id)) = 5
              THEN substring(trim(p.student_id), 2, 2)::integer
            ELSE NULL
          END
        ) = class_photo_shares.class_number
    )
  );

-- 조회도 학번 파싱 fallback (프로필 grade/class_number 비어 있어도 동반 조회)
DROP POLICY IF EXISTS "Classmates can read class photo shares"
  ON public.class_photo_shares;

CREATE POLICY "Classmates can read class photo shares"
  ON public.class_photo_shares FOR SELECT
  TO authenticated
  USING (
    deleted_at IS NULL
    AND EXISTS (
      SELECT 1
      FROM public.profiles p
      WHERE p.user_id = auth.uid()
        AND COALESCE(
          p.grade,
          CASE
            WHEN length(trim(p.student_id)) = 5
              THEN substring(trim(p.student_id), 1, 1)::integer
            ELSE NULL
          END
        ) = class_photo_shares.grade
        AND COALESCE(
          p.class_number,
          CASE
            WHEN length(trim(p.student_id)) = 5
              THEN substring(trim(p.student_id), 2, 2)::integer
            ELSE NULL
          END
        ) = class_photo_shares.class_number
    )
  );
