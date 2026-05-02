#!/usr/bin/env bash
# Play App Signing — 새 업로드 키 로컬 생성 (Google 문서 9842756 "Create an upload key" 절차와 동일).
# 참고: https://support.google.com/googleplay/android-developer/answer/9842756
#
# 요구: RSA 2048비트 이상, 유효 기간 설정.
# 생성 후 나온 .pem 을 Play Console에 등록(또는 업로드 키 재설정 요청 후 등록).
#
# 사용:
#   chmod +x android/scripts/create_upload_keystore.sh
#   ./android/scripts/create_upload_keystore.sh
#
# 환경 변수로 경로·별칭 바꿀 수 있음:
#   UPLOAD_KEYSTORE_PATH=/절대경로/my-upload.jks UPLOAD_KEY_ALIAS=myalias ./android/scripts/create_upload_keystore.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ANDROID_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
DEFAULT_KS="${ANDROID_ROOT}/app/upload-keystore.jks"
OUT="${UPLOAD_KEYSTORE_PATH:-$DEFAULT_KS}"
ALIAS="${UPLOAD_KEY_ALIAS:-upload}"

if [[ -f "$OUT" ]]; then
  echo "오류: 이미 파일이 있습니다 — 덮어쓰지 않습니다: $OUT"
  exit 1
fi

command -v keytool >/dev/null || {
  echo "keytool 을 찾을 수 없습니다. JDK를 설치하고 PATH를 확인하세요."
  exit 1
}

echo ""
echo "=== 새 Play 업로드 키스토어 생성 ==="
echo "저장 경로: $OUT"
echo "별칭(alias): $ALIAS"
echo ""
echo "다음 단계(업로드 키를 분실한 경우):"
echo "  1) 개발자 계정 소유자가 Play Console에서 업로드 키 재설정 요청"
echo "  2) 이 스크립트가 만든 upload_certificate.pem 을 Google 안내에 따라 제출"
echo "  3) 승인 후 android/key.properties 에 storeFile / 비밀번호 / 별칭 설정"
echo ""
read -r -p "계속할까요? [y/N] " ok
[[ "${ok:-}" =~ ^[Yy]$ ]] || exit 0

mkdir -p "$(dirname "$OUT")"

# Google: upload key must be RSA 2048+ (9842756)
keytool -genkeypair -v \
  -storetype JKS \
  -keystore "$OUT" \
  -alias "$ALIAS" \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000

PEM="${OUT%.jks}_certificate.pem"
keytool -export -rfc -keystore "$OUT" -alias "$ALIAS" -file "$PEM"

echo ""
echo "완료."
echo "  키스토어: $OUT"
echo "  등록용 공개 인증서(PEM): $PEM"
echo ""
echo "SHA1 확인 (Play Console 지문과 비교):"
keytool -list -v -keystore "$OUT" -alias "$ALIAS" | grep -E 'SHA1:|SHA256:' || true
