-- fcm_tokens에 platform 컬럼 추가 (ios / android 구분)
ALTER TABLE public.fcm_tokens
  ADD COLUMN IF NOT EXISTS platform text;

COMMENT ON COLUMN public.fcm_tokens.platform IS '디바이스 플랫폼: ios | android';
