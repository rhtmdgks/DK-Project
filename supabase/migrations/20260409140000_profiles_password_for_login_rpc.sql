-- login_from_profiles RPC가 student_id·password로 매칭할 수 있도록 (없을 때만 추가)
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS password text;

COMMENT ON COLUMN public.profiles.password IS '학번 로그인 RPC 검증용; 일괄 리셋 시 Auth 비밀번호와 동일 값으로 맞춤';
