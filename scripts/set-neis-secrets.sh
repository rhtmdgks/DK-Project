#!/usr/bin/env bash
# NEIS Edge Function 시크릿을 Supabase CLI로 등록합니다.
# 사전: supabase login 후 프로젝트 루트에서 실행 (또는 supabase link 완료).
#
# 사용 예:
#   export NEIS_API_KEY=발급받은인증키
#   export NEIS_ATPT_OFCDC_SC_CODE=B10
#   export NEIS_SD_SCHUL_CODE=학교코드
#   ./scripts/set-neis-secrets.sh
#
# 또는 인증키만:
#   NEIS_API_KEY=발급받은인증키 ./scripts/set-neis-secrets.sh

set -e
cd "$(dirname "$0")/.."

# 원격 시크릿 등록은 로그인 필요. 실패 시 안내.
trap 'if [ $? -ne 0 ]; then echo ""; echo "로그인이 필요할 수 있습니다: supabase login"; fi' EXIT

SUPABASE_CMD=""
if command -v supabase &>/dev/null; then
  SUPABASE_CMD="supabase"
elif command -v /opt/homebrew/bin/supabase &>/dev/null; then
  SUPABASE_CMD="/opt/homebrew/bin/supabase"
else
  echo "Supabase CLI를 찾을 수 없습니다. 설치: brew install supabase/tap/supabase"
  exit 1
fi

if [ -z "${NEIS_API_KEY:-}" ]; then
  echo "NEIS_API_KEY가 비어 있습니다."
  echo "다음처럼 환경 변수를 설정한 뒤 다시 실행하세요:"
  echo "  export NEIS_API_KEY=발급받은인증키"
  echo "  ./scripts/set-neis-secrets.sh"
  exit 1
fi

echo "Supabase Edge Function 시크릿 등록 중..."
$SUPABASE_CMD secrets set NEIS_API_KEY="$NEIS_API_KEY"

if [ -n "${NEIS_ATPT_OFCDC_SC_CODE:-}" ]; then
  $SUPABASE_CMD secrets set NEIS_ATPT_OFCDC_SC_CODE="$NEIS_ATPT_OFCDC_SC_CODE"
  echo "NEIS_ATPT_OFCDC_SC_CODE 설정됨."
fi
if [ -n "${NEIS_SD_SCHUL_CODE:-}" ]; then
  $SUPABASE_CMD secrets set NEIS_SD_SCHUL_CODE="$NEIS_SD_SCHUL_CODE"
  echo "NEIS_SD_SCHUL_CODE 설정됨."
fi

echo "NEIS_API_KEY 등록 완료."
