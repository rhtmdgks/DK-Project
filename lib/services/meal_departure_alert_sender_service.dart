import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:myapp/core/supabase_client.dart';

/// 앱에서 급식 출발 알림을 전송하는 서비스.
///
/// 백오피스와 동일하게:
/// 1. Supabase Realtime Broadcast 전송 (해당 학년·반 구독 앱에 즉시 전달)
/// 2. FCM 푸시는 Edge Function send-meal-push 호출 (앱이 꺼져 있어도 수신)
class MealDepartureAlertSenderService {
  MealDepartureAlertSenderService._();

  static const _event = 'meal-departure';

  /// [grade] 1~3, [classNumber] 1~10.
  /// Realtime Broadcast 전송 후, Edge Function으로 FCM 푸시 전송 시도.
  /// Returns (realtimeSent: true, fcmSent: count or null on skip/fail).
  static Future<({bool realtimeOk, int? fcmSent})> send({
    required int grade,
    required int classNumber,
    String message = '급식 출발 알림',
    String? body,
  }) async {
    final bodyText = body ?? '$grade학년 $classNumber반 급식이 출발했습니다.';
    final payload = <String, dynamic>{
      'message': message,
      'body': bodyText,
      'grade': grade,
      'class_number': classNumber,
      'at': DateTime.now().toUtc().toIso8601String(),
    };

    final channelName = 'meal-departure:$grade:$classNumber';
    final channel = supabase.channel(channelName);

    final completer = Completer<void>();
    channel.subscribe((status, [err]) {
      if (status == RealtimeSubscribeStatus.subscribed) {
        if (!completer.isCompleted) completer.complete();
      } else if (status == RealtimeSubscribeStatus.channelError ||
          status == RealtimeSubscribeStatus.timedOut ||
          status == RealtimeSubscribeStatus.closed) {
        if (!completer.isCompleted) {
          completer.completeError(err ?? Exception('Channel $status'));
        }
      }
    });

    try {
      await completer.future;
      await channel.sendBroadcastMessage(
        event: _event,
        payload: payload,
      );
    } finally {
      supabase.removeChannel(channel);
    }

    int? fcmSent;
    try {
      final res = await supabase.functions.invoke(
        'send-meal-push',
        body: {
          'grade': grade,
          'class_number': classNumber,
          'message': message,
          'body': bodyText,
        },
      );
      final data = res.data as Map<String, dynamic>?;
      if (data != null && identical(data['ok'], true) && data['sent'] != null) {
        fcmSent = data['sent'] as int;
      }
    } catch (_) {
      // FCM 실패해도 Realtime은 이미 전송됨
    }

    return (realtimeOk: true, fcmSent: fcmSent);
  }
}
