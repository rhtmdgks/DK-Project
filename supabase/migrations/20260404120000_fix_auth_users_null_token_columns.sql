-- GoTrue 로그인 시 500 / "Database error querying schema" / confirmation_token NULL 스캔 오류 완화
-- 원인: auth.users 행에 confirmation_token 등이 NULL이면 비밀번호 로그인 시 스캔 실패
--       (백오피스·SQL로 사용자만 넣은 경우 등)
-- 참고: https://github.com/supabase/auth/issues/1940
--
-- 원격 프로젝트에서 마이그레이션 권한으로 auth.users UPDATE가 막히면
-- Supabase Dashboard → SQL Editor에서 동일 UPDATE를 postgres로 실행하세요.

UPDATE auth.users
SET
  confirmation_token = COALESCE(confirmation_token, ''),
  email_change = COALESCE(email_change, ''),
  email_change_token_new = COALESCE(email_change_token_new, ''),
  recovery_token = COALESCE(recovery_token, '')
WHERE confirmation_token IS NULL
   OR email_change IS NULL
   OR email_change_token_new IS NULL
   OR recovery_token IS NULL;

-- 일부 GoTrue 버전에서 추가로 NULL이면 문제되는 컬럼 (있을 때만 갱신)
DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'auth'
      AND table_name = 'users'
      AND column_name = 'email_change_token_current'
  ) THEN
    EXECUTE $u$
      UPDATE auth.users
      SET email_change_token_current = COALESCE(email_change_token_current, '')
      WHERE email_change_token_current IS NULL
    $u$;
  END IF;
END
$$;
