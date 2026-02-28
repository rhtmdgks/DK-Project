import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:myapp/core/auth/auth_state.dart';
import 'package:myapp/repositories/notification_settings_repository.dart';
import 'package:myapp/core/supabase_client.dart';
import 'package:myapp/models/notification_item.dart';
import 'package:myapp/services/fcm_token_service.dart';
import 'package:myapp/services/notification_service.dart';

/// 실시간 급식 출발 알림 서비스
///
/// 백오피스에서 급식 출발 알림을 Supabase Realtime Broadcast로 전송하면,
/// 해당 학년·반 학생의 앱에서 즉시 로컬 알림을 표시합니다.
///
/// - 채널 이름: `meal-departure:{학년}:{반}`
/// - 이벤트: `meal-departure`
/// - 페이로드: `{ message, body, grade, class_number, at }`
class MealDepartureRealtimeService {
  MealDepartureRealtimeService._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const _androidChannelId = 'meal_notification';
  static const _androidChannelName = '급식 출발 알림';
  static const _notificationId = 2000;

  static RealtimeChannel? _channel;
  static bool _initialized = false;
  static int? _subscribedGrade;
  static int? _subscribedClassNum;

  static Future<void> initialize() async {
    if (_initialized) return;

    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            _androidChannelId,
            _androidChannelName,
            importance: Importance.high,
          ),
        );

    _initialized = true;
  }

  static Future<bool> isEnabled() async =>
      NotificationSettingsRepository.instance.getMealEnabled();

  static Future<void> setEnabled(bool enabled) async {
    await NotificationSettingsRepository.instance.setMealEnabled(enabled);

    if (enabled) {
      await startListening();
    } else {
      try {
        await FcmTokenService.unregisterIfNeeded();
      } catch (e) {
        debugPrint('FCM 토큰 해제 실패: $e');
      }
      await stopListening();
    }
  }

  /// 현재 사용자의 학년·반에 해당하는 Broadcast 채널 구독을 시작합니다.
  ///
  /// 학년·반을 알 수 없으면 구독하지 않습니다.
  /// 이미 동일 채널을 구독 중이면 중복 구독하지 않습니다.
  static Future<void> startListening() async {
    final enabled = await isEnabled();
    if (!enabled) {
      debugPrint('급식 출발 알림: 설정이 꺼져 있어 구독하지 않습니다. 설정 → 급식 출발 알림을 켜주세요.');
      return;
    }

    final profile = await getCurrentProfile();
    if (profile == null) {
      debugPrint('급식 출발 알림: 로그인된 프로필이 없어 구독하지 않습니다.');
      return;
    }

    final grade = profile.gradeOrFromStudentId;
    final classNum = profile.classNumOrFromStudentId;

    if (grade == null || classNum == null) {
      debugPrint('급식 출발 알림: 학년·반을 알 수 없어 구독하지 않습니다. (studentId=${profile.studentId}, grade=$grade, classNum=$classNum)');
      return;
    }

    if (_channel != null &&
        _subscribedGrade == grade &&
        _subscribedClassNum == classNum) {
      return;
    }

    await stopListening();

    final channelName = 'meal-departure:$grade:$classNum';
    debugPrint('급식 출발 알림: $channelName 채널 구독 시작');

    _channel = supabase
        .channel(channelName)
        .onBroadcast(
          event: 'meal-departure',
          callback: (payload) async {
            try {
              debugPrint('급식 출발 알림 수신: $payload');

              final stillEnabled = await isEnabled();
              if (!stillEnabled) return;

              final message = payload['message'] as String? ?? '급식 출발 알림';
              final body = payload['body'] as String? ?? '급식이 출발했습니다.';

              await NotificationService.showNotification(
                id: _notificationId,
                title: message,
                body: body,
                type: NotificationType.meal,
                payload: 'meal_departure',
              );
            } catch (e, st) {
              debugPrint('급식 출발 알림 수신 후 처리 실패: $e');
              debugPrint('$st');
            }
          },
        )
        .subscribe();

    _subscribedGrade = grade;
    _subscribedClassNum = classNum;

    try {
      await FcmTokenService.registerIfNeeded();
    } catch (e) {
      debugPrint('FCM 토큰 등록 실패: $e');
    }
  }

  /// Broadcast 채널 구독을 해제합니다.
  static Future<void> stopListening() async {
    if (_channel != null) {
      try {
        await supabase.removeChannel(_channel!);
      } catch (e) {
        debugPrint('급식 출발 알림 채널 해제 실패: $e');
      }
      _channel = null;
    }
    _subscribedGrade = null;
    _subscribedClassNum = null;
  }

  /// 프로필 변경(학년·반 변경) 또는 설정 변경 시 구독을 갱신합니다.
  static Future<void> refreshSubscription() async {
    await stopListening();
    await startListening();
  }
}
