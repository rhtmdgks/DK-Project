-- admin / council / teacher 역할과 can_access_backoffice 플래그 정합 (백오피스 UI·필터와 일치)
UPDATE public.profiles
SET
  can_access_backoffice = true,
  updated_at = now()
WHERE role IN ('admin', 'council', 'teacher')
  AND (can_access_backoffice IS DISTINCT FROM true);
