import 'package:flutter/foundation.dart';

/// 실시간 채널 진단 로그 유틸.
///
/// - 채널 시작/해제/수신 건수를 일관된 포맷으로 기록한다.
/// - 운영 중 문제 재현 시 로그 검색 키를 고정한다.
class RealtimeObservability {
  RealtimeObservability._();

  static final Map<String, int> _receivedCounters = <String, int>{};

  static void channel(String service, String message) {
    debugPrint('[RT][$service] $message');
  }

  static void event(String service, String channel, String event) {
    final key = '$service|$channel|$event';
    final next = (_receivedCounters[key] ?? 0) + 1;
    _receivedCounters[key] = next;
    debugPrint('[RT][$service][$channel] event=$event count=$next');
  }
}
