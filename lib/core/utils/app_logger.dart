import 'package:flutter/foundation.dart';

/// 앱 전역 로깅 헬퍼.
///
/// 규칙:
/// - 프로덕션 코드에서는 [print] 대신 [logInfo], [logWarn], [logError] 사용.
/// - [debugPrint]는 디버그 빌드에서만 출력되며, 긴 메시지도 잘림 없이 출력된다.
/// - 사용자에게 보여줄 메시지는 이 레이어가 아닌 ViewModel/Repository에서 도메인별로 정리된 문구로 생성한다.
void logInfo(String message, [Object? detail]) {
  if (detail != null) {
    debugPrint('[$message] $detail');
  } else {
    debugPrint(message);
  }
}

void logWarn(String message, [Object? detail]) {
  if (detail != null) {
    debugPrint('⚠ $message $detail');
  } else {
    debugPrint('⚠ $message');
  }
}

void logError(String message, [Object? error, StackTrace? stackTrace]) {
  debugPrint('✖ $message');
  if (error != null) debugPrint('  $error');
  if (stackTrace != null) debugPrint('  $stackTrace');
}
