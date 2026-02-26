-- =============================================================================
-- FCM 토큰 저장 (앱이 꺼져 있을 때 푸시 알림용)
-- =============================================================================
-- Flutter 앱에서 firebase_messaging으로 발급받은 FCM 토큰을 user_id + 학년·반과 함께 저장.
-- Edge Function send-meal-push에서 학년·반 기준으로 토큰 조회 후 FCM 전송.

CREATE TABLE IF NOT EXISTS public.fcm_tokens (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  token text NOT NULL,
  grade smallint NOT NULL,
  class_number smallint NOT NULL,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  UNIQUE(user_id)
);

COMMENT ON TABLE public.fcm_tokens IS 'FCM 디바이스 토큰 (급식 출발 등 푸시용). user_id당 1개.';
COMMENT ON COLUMN public.fcm_tokens.grade IS '학년 1-3';
COMMENT ON COLUMN public.fcm_tokens.class_number IS '반 1-10';

CREATE INDEX IF NOT EXISTS idx_fcm_tokens_grade_class
  ON public.fcm_tokens(grade, class_number);

ALTER TABLE public.fcm_tokens ENABLE ROW LEVEL SECURITY;

-- 로그인한 사용자는 본인 행만 insert/update/delete
CREATE POLICY "Users manage own fcm_tokens"
  ON public.fcm_tokens
  FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- service_role는 Edge Function에서 전체 조회용
-- (정책이 service_role에는 적용되지 않음)

-- updated_at 자동 갱신
CREATE OR REPLACE FUNCTION public.set_fcm_tokens_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;
DROP TRIGGER IF EXISTS fcm_tokens_updated_at ON public.fcm_tokens;
CREATE TRIGGER fcm_tokens_updated_at
  BEFORE UPDATE ON public.fcm_tokens
  FOR EACH ROW EXECUTE FUNCTION public.set_fcm_tokens_updated_at();
