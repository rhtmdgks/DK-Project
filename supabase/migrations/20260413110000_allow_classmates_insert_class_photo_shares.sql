-- 학급 사진 공유 업로드 권한 완화:
-- 정/부반장 제한을 제거하고 같은 반 학생이면 업로드 허용.

DROP POLICY IF EXISTS "Class managers can insert class photo shares"
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
        AND p.grade = class_photo_shares.grade
        AND p.class_number = class_photo_shares.class_number
    )
  );
