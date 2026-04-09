#!/usr/bin/env bash
# Xcode로 Archive 하기 전에 반드시 실행하세요.
# ios/Flutter/Generated.xcconfig(.gitignore)에 pubspec 버전이 반영되지 않으면
# CFBundleShortVersionString이 예전(예: 1.0.1)으로 남아 App Store 업로드가 실패합니다.
set -euo pipefail
cd "$(dirname "$0")/.."
flutter pub get
flutter build ios --config-only
echo ""
echo "OK: pubspec 버전이 ios/Flutter/Generated.xcconfig 에 반영되었습니다."
grep '^FLUTTER_BUILD_NAME=' ios/Flutter/Generated.xcconfig || true
grep '^FLUTTER_BUILD_NUMBER=' ios/Flutter/Generated.xcconfig || true
echo ""
echo "다음: open ios/Runner.xcworkspace → Product → Archive"
