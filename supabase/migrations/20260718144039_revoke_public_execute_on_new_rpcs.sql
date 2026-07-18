-- =============================================================================
-- 멀티스쿨 1단계 (9/9): 신규 함수의 기본 PUBLIC EXECUTE 제거
-- =============================================================================
-- Postgres 는 함수 생성 시 PUBLIC 에 EXECUTE 를 기본 부여한다.
-- 의도한 대상에게만 GRANT 가 유지되도록 잔여 권한을 회수한다.

-- check_username_available: authenticated 전용 (anon 계정 열거 방지)
REVOKE EXECUTE ON FUNCTION public.check_username_available(text, text) FROM PUBLIC, anon;

-- 트리거 전용 함수는 직접 호출 불필요
REVOKE EXECUTE ON FUNCTION public.set_school_id_from_profile() FROM PUBLIC, anon, authenticated;
