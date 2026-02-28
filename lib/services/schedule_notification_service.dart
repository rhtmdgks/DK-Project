import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:myapp/repositories/notification_settings_repository.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:myapp/core/supabase_client.dart';
import 'package:myapp/models/notification_item.dart';
import 'package:myapp/services/notification_service.dart';

/// 일정 알림: 매일 아침 8시에 오늘 일정을 알림 표시.
///
/// - 설정에서 "일정 알림" ON
/// - 매일 아침 8시에 schedule_items 테이블에서 오늘 일정을 조회하여 알림
/// - Supabase Realtime으로 schedule_items 변경 감지
class ScheduleNotificationService {
  ScheduleNotificationService._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const _channelId = 'schedule_notification';
  static const _channelName = '일정 알림';
  static const _notificationId = 5;

  static RealtimeChannel? _channel;
  static bool _initialized = false;

  /// 초기화
  static Future<void> initialize() async {
    if (_initialized) return;

    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            _channelId,
            _channelName,
            importance: Importance.defaultImportance,
          ),
        );

    _initialized = true;
    if (await isScheduleEnabled()) {
      await scheduleDailyNotification();
      await startListening();
    }
  }

  /// 일정 알림 활성화 여부 확인
  static Future<bool> isScheduleEnabled() async =>
      NotificationSettingsRepository.instance.getScheduleEnabled();

  /// 일정 알림 활성화/비활성화
  static Future<void> setScheduleEnabled(bool enabled) async {
    await NotificationSettingsRepository.instance.setScheduleEnabled(enabled);

    if (enabled) {
      await scheduleDailyNotification();
      await startListening();
    } else {
      await _plugin.cancel(_notificationId);
      await stopListening();
    }
  }

  /// 매일 아침 8시 알림 스케줄링
  static Future<void> scheduleDailyNotification() async {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      8,
      0,
    );
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    try {
      await _plugin.zonedSchedule(
        _notificationId,
        '오늘의 일정',
        '오늘 일정을 확인해보세요.',
        scheduled,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: '매일 아침 8시 일정 알림',
          ),
          iOS: const DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: 'schedule_daily',
      );
    } catch (e) {
      if (e.toString().contains('exact_alarms_not_permitted')) {
        await _plugin.zonedSchedule(
          _notificationId,
          '오늘의 일정',
          '오늘 일정을 확인해보세요.',
          scheduled,
          NotificationDetails(
            android: AndroidNotificationDetails(
              _channelId,
              _channelName,
              channelDescription: '매일 아침 8시 일정 알림',
            ),
            iOS: const DarwinNotificationDetails(),
          ),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.time,
          payload: 'schedule_daily',
        );
      }
    }
  }

  /// 일정 변경 감지 구독 시작
  static Future<void> startListening() async {
    if (_channel != null) return;

    final enabled = await isScheduleEnabled();
    if (!enabled) return;

    _channel = supabase
        .channel('schedule_items')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'schedule_items',
          callback: (payload) async {
            final newRow = payload.newRecord;
            if (newRow.isEmpty) return;

            final stillEnabled = await isScheduleEnabled();
            if (!stillEnabled) return;

            final title = newRow['title'] as String? ?? '새 일정';
            final startAt = newRow['start_at'] as String?;
            
            if (startAt != null) {
              try {
                final startDate = DateTime.parse(startAt);
                final now = DateTime.now();
                final today = DateTime(now.year, now.month, now.day);
                final scheduleDate = DateTime(startDate.year, startDate.month, startDate.day);
                
                // 오늘 일정이면 즉시 알림
                if (scheduleDate == today) {
                  await NotificationService.showNotification(
                    id: _notificationId + 1000,
                    title: '새 일정이 추가되었습니다',
                    body: title,
                    type: NotificationType.schedule,
                    payload: 'schedule',
                  );
                }
              } catch (_) {}
            }
          },
        )
        .subscribe();
  }

  /// 구독 중지
  static Future<void> stopListening() async {
    await _channel?.unsubscribe();
    _channel = null;
  }

  /// 구독 재시작
  static Future<void> refreshSubscription() async {
    await stopListening();
    await startListening();
  }

  /// 오늘 일정 조회 및 알림 표시 (앱이 8시 이후에 열렸을 때 호출)
  static Future<void> showTodayScheduleIfNeeded() async {
    final enabled = await isScheduleEnabled();
    if (!enabled) return;

    final now = DateTime.now();
    if (now.hour < 8) return;

    try {
      final today = DateTime(now.year, now.month, now.day);
      final tomorrow = today.add(const Duration(days: 1));

      final schedules = await supabase
          .from('schedule_items')
          .select()
          .gte('start_at', today.toIso8601String())
          .lt('start_at', tomorrow.toIso8601String())
          .order('start_at');

      if (schedules.isEmpty) return;

      final count = schedules.length;
      final firstSchedule = schedules[0];
      final firstTitle = firstSchedule['title'] as String? ?? '일정';

      await NotificationService.showNotification(
        id: _notificationId,
        title: '오늘의 일정',
        body: count == 1
            ? firstTitle
            : '$firstTitle 외 ${count - 1}개 일정이 있습니다',
        type: NotificationType.schedule,
        payload: 'schedule',
      );
    } catch (_) {}
  }
}
