-- =============================================================================
-- 초성 욕 검열 수정: 정규화 regex가 자모(ㅅㅂ 등)를 제거하던 버그
-- =============================================================================
-- 기존 [^[:alnum:]\uac00-\ud7a3...] 패턴은 PostgreSQL에서 \u 이스케이프가
-- 동작하지 않아 ㅂ·ㅅ 등 호환 자모가 삭제됨 → 키워드 매칭 실패.

INSERT INTO public.moderation_keywords (keyword) VALUES
  ('ㅂㅅ'),
  ('ㅆㅂ'),
  ('ㅈㄹ'),
  ('ㅄ'),
  ('ㄱㅅㄲ'),
  ('ㅁㅊ'),
  ('ㅂㅆ'),
  ('ㅅ1ㅂ'),
  ('시1발'),
  ('씨1발')
ON CONFLICT (keyword) DO NOTHING;

CREATE OR REPLACE FUNCTION public.contains_blocked_keyword(p_text text)
RETURNS boolean
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_normalized text;
BEGIN
  IF p_text IS NULL OR trim(p_text) = '' THEN
    RETURN false;
  END IF;
  -- 한글 음절(가-힣) + 호환 자모(ㄱ-ㅎ, ㅏ-ㅣ) + 영숫자 유지, 나머지 제거
  v_normalized := lower(regexp_replace(p_text, '[^[:alnum:]가-힣ㄱ-ㅎㅏ-ㅣ]+', '', 'g'));
  RETURN EXISTS (
    SELECT 1 FROM public.moderation_keywords k
    WHERE k.is_active
      AND v_normalized LIKE '%' || lower(replace(k.keyword, ' ', '')) || '%'
  );
END;
$$;
