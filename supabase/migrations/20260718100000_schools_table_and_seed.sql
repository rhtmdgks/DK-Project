-- =============================================================================
-- 멀티스쿨 1단계 (1/8): schools 테이블 + 기존 학교(대덕고) 시드
-- =============================================================================
-- 목적: 여러 학교를 하나의 프로젝트에서 서비스하기 위한 테넌트 루트 테이블.
-- 원칙: additive only. 기존 테이블/데이터 무변경. 구앱(v1.0.5)은 이 테이블을 모름.
-- anon(로그인 전)에게는 로그인 화면의 학교 선택용 최소 컬럼만 노출한다
-- (RLS는 컬럼 단위 제한이 불가하므로 컬럼 GRANT + 정책 조합).

CREATE TABLE IF NOT EXISTS public.schools (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  slug                text NOT NULL UNIQUE
                        CHECK (slug ~ '^[a-z0-9][a-z0-9-]{1,30}[a-z0-9]$'),
  name                text NOT NULL,
  name_en             text,
  status              text NOT NULL DEFAULT 'active'
                        CHECK (status IN ('active', 'inactive', 'preparing')),
  -- 전환기 폴백용 기본 학교(기존 단일 학교). 정확히 1개만 허용.
  is_default          boolean NOT NULL DEFAULT false,
  -- NEIS 연동 코드 (edge function이 service role로 조회)
  atpt_ofcdc_sc_code  text,
  sd_schul_code       text,
  timezone            text NOT NULL DEFAULT 'Asia/Seoul',
  settings            jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at          timestamptz NOT NULL DEFAULT now(),
  updated_at          timestamptz NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS schools_one_default_idx
  ON public.schools (is_default) WHERE is_default;
CREATE UNIQUE INDEX IF NOT EXISTS schools_neis_codes_idx
  ON public.schools (atpt_ofcdc_sc_code, sd_schul_code)
  WHERE sd_schul_code IS NOT NULL;

DROP TRIGGER IF EXISTS trg_schools_updated_at ON public.schools;
CREATE TRIGGER trg_schools_updated_at
  BEFORE UPDATE ON public.schools
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

ALTER TABLE public.schools ENABLE ROW LEVEL SECURITY;

-- 컬럼 단위 노출 제어: anon은 로그인 화면에 필요한 최소 컬럼만.
REVOKE ALL ON public.schools FROM anon, authenticated;
GRANT SELECT (id, slug, name, name_en, status) ON public.schools TO anon;
GRANT SELECT ON public.schools TO authenticated;

CREATE POLICY schools_anon_list_active ON public.schools
  FOR SELECT TO anon
  USING (status = 'active');

-- 테넌트 격리는 이 테이블에 불필요(학교 메타데이터는 로그인 사용자에게 공개 무해).
CREATE POLICY schools_authenticated_read ON public.schools
  FOR SELECT TO authenticated
  USING (true);

-- 쓰기 정책 없음: 학교 생성/수정은 super admin 백오피스(service_role)만.

-- 기존 학교 시드 (멱등). slug는 신규 계정 auth email 도메인({username}@{slug}.laon.local)에
-- 박제되므로 변경 금지.
INSERT INTO public.schools (slug, name, name_en, status, is_default, atpt_ofcdc_sc_code, sd_schul_code)
VALUES ('daedeok', '대덕고등학교', 'Daedeok High School', 'active', true, 'G10', '7430030')
ON CONFLICT (slug) DO NOTHING;

COMMENT ON TABLE public.schools IS '테넌트(학교) 루트. is_default=true 행은 전환기 폴백용 기존 학교.';
