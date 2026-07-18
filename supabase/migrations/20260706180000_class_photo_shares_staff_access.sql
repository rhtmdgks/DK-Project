-- 교사·관리자: 프로필에 학년/반이 없어도 반별 사진 조회·업로드 허용

DROP POLICY IF EXISTS "Classmates can insert class photo shares"
  ON public.class_photo_shares;
DROP POLICY IF EXISTS "Classmates can read class photo shares"
  ON public.class_photo_shares;

CREATE POLICY "Classmates can read class photo shares"
  ON public.class_photo_shares FOR SELECT
  TO authenticated
  USING (
    deleted_at IS NULL
    AND (
      EXISTS (
        SELECT 1
        FROM public.profiles p
        WHERE p.user_id = auth.uid()
          AND p.role IN ('admin', 'teacher')
      )
      OR EXISTS (
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
    )
  );

CREATE POLICY "Classmates can insert class photo shares"
  ON public.class_photo_shares FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM public.profiles p
      WHERE p.user_id = auth.uid()
        AND p.id = class_photo_shares.uploader_profile_id
        AND (
          p.role IN ('admin', 'teacher')
          OR (
            COALESCE(
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
        )
    )
  );
