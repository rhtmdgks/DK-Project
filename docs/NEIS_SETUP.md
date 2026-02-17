# NEIS API 설정 (급식·학사일정)

Edge Function `neis_meal`(급식), `neis_academic_calendar`(학사일정)에서 나이스 오픈API 인증키와 학교 정보를 사용합니다.

## 1. Supabase CLI로 시크릿 등록 (권장)

1. **한 번만** 로그인: 터미널에서 `supabase login`
2. 프로젝트 루트에서 시크릿 스크립트 실행:

```bash
export NEIS_API_KEY=발급받은인증키
# 선택: 시도교육청코드·학교코드 (급식/학사 조회 시 사용)
export NEIS_ATPT_OFCDC_SC_CODE=B10
export NEIS_SD_SCHUL_CODE=학교코드

./scripts/set-neis-secrets.sh
```

인증키만 등록할 때: `NEIS_API_KEY=인증키 ./scripts/set-neis-secrets.sh`

**인증키 재발급 후 적용 예시 (G10, 7430030 사용 시):**
```bash
supabase secrets set NEIS_API_KEY=e1abbc86923f4ca8927a6c194de8b663 NEIS_ATPT_OFCDC_SC_CODE=G10 NEIS_SD_SCHUL_CODE=7430030
```
적용 후 앱에서 Meal 탭을 새로고침해 급식이 나오는지 확인하면 됩니다.

## 2. Dashboard에서 시크릿 등록

**Supabase Dashboard**에서 다음 경로로 이동한 뒤 시크릿을 추가할 수도 있습니다.

- **Project Settings** → **Edge Functions** → **Secrets**  
  또는  
- **Edge Functions** → 해당 함수 선택 → **Secrets** 탭

등록할 항목:

| 이름 | 설명 | 예시 |
|------|------|------|
| `NEIS_API_KEY` | 나이스 오픈API 인증키 (필수) | 발급받은 인증키 |
| `NEIS_ATPT_OFCDC_SC_CODE` | 시도교육청코드 (급식/학사 조회 시 필요) | B10 (서울) |
| `NEIS_SD_SCHUL_CODE` | 학교코드 (급식/학사 조회 시 필요) | 나이스 포털 또는 명세서 참고 |

코드 값은 **급식식단정보_오픈API명세서.xls**, **학사일정_오픈API명세서.xls** 등에서 확인할 수 있습니다.

### 학교코드(SD_SCHUL_CODE)와 행정표준코드

- NEIS API에서 쓰는 **SD_SCHUL_CODE**는 나이스에서 정한 **표준학교코드**이며, **7자리 숫자(문자열)** 형식입니다.
- **행정표준코드**(시도교육청에서 관리하는 기관코드)와 **같은 값**을 쓰는 경우가 많습니다. 행정표준코드를 그대로 7자리로 넣어 사용해도 됩니다.
- 반드시 **해당 시도교육청(ATPT_OFCDC_SC_CODE) 소속**으로 등록된 코드여야 합니다. 예: G10(경기도교육청)이면 경기 소속 학교코드만 유효.

### 학교코드 검증 방법 (HTTP 500 시)

1. **나이스 포털** [open.neis.go.kr](https://open.neis.go.kr) → 개발자 가이드 / API 소개 페이지에서 학교검색 또는 **학교기본정보** API 명세서로 해당 교육청·학교 조회.
2. **학교기본정보 API**로 확인: 같은 인증키·`ATPT_OFCDC_SC_CODE`·`SD_SCHUL_CODE`로 `schoolInfo` API를 호출해 해당 학교가 조회되면 코드 조합이 맞는 것입니다. (조회되지 않으면 교육청 코드 또는 학교코드가 잘못된 경우가 많습니다.)
3. **공공데이터포털**의 "전국초중등학교기본정보표준데이터" 등에서 학교명으로 검색해 표준학교코드(행정표준코드)를 확인한 뒤, 위 2번으로 한 번 더 검증하는 것을 권장합니다.

## 3. 로컬에서 Edge Function 실행 시

`supabase functions serve`로 로컬 실행 시에는 `supabase/.env`에 같은 변수를 넣으면 됩니다.  
(이미 `.gitignore`로 제외되어 있으므로 인증키가 저장소에 올라가지 않습니다.)

```bash
cp supabase/.env.example supabase/.env
# supabase/.env 를 열어 NEIS_API_KEY 등 실제 값 입력
```

## 4. 앱에서 사용

- **급식**: `supabase.functions.invoke('neis_meal', queryParameters: {'date': 'YYYYMMDD'})`
- **학사일정**: 해당 Edge Function 호출 시 동일한 시크릿이 사용됩니다.

시도교육청코드·학교코드를 시크릿에 넣지 않으면, 호출 시 쿼리 파라미터 `ATPT_OFCDC_SC_CODE`, `SD_SCHUL_CODE`로 넘겨도 됩니다.
