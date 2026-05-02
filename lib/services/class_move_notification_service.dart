import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:myapp/repositories/notification_settings_repository.dart';
import 'package:myapp/core/utils/timetable_utils.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz_data;

import 'package:myapp/core/supabase_client.dart';

/// 이동 수업 알림: 시간표에 표시한 이동 수업(또는 교실 변경 추정) 5분 전 알림.
///
/// - 설정에서 "이동 수업 알림" ON
/// - `is_moving_class`가 true인 교시는 항상 해당 교시 시작 5분 전 알림
/// - 그 외에는 연속 교시 간 `room`이 모두 있고 서로 다르면 이동으로 추정(기존 동작)
class ClassMoveNotificationService {
  ClassMoveNotificationService._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const _channelId = 'class_move_notification';
  static const _channelName = '이동 수업 알림';
  static const _notificationIdBase = 6;

  static bool _initialized = false;

  /// 초기화
  static Future<void> initialize() async {
    if (_initialized) return;
    tz_data.initializeTimeZones();
    try {
      tz.setLocalLocation(tz.getLocation('Asia/Seoul'));
    } catch (_) {}

    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            _channelId,
            _channelName,
            importance: Importance.high,
          ),
        );

    _initialized = true;
    if (await isClassMoveEnabled()) {
      await scheduleClassMoveNotifications();
    }
  }

  /// 이동 수업 알림 활성화 여부 확인
  static Future<bool> isClassMoveEnabled() async =>
      NotificationSettingsRepository.instance.getClassMoveEnabled();

  /// 이동 수업 알림 활성화/비활성화
  static Future<void> setClassMoveEnabled(bool enabled) async {
    await NotificationSettingsRepository.instance.setClassMoveEnabled(enabled);

    if (enabled) {
      await scheduleClassMoveNotifications();
    } else {
      // 모든 이동 수업 알림 취소
      for (int i = 0; i < 100; i++) {
        await _plugin.cancel(_notificationIdBase + i);
      }
    }
  }

  /// 이동 수업 알림 스케줄링
  static Future<void> scheduleClassMoveNotifications() async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return;
    if (!await isClassMoveEnabled()) return;

    try {
      await _cancelScheduledNotifications();

      final timetable = await supabase
          .from('timetable_entries')
          .select('day_of_week, period, room, subject, is_moving_class')
          .eq('user_id', uid)
          .order('day_of_week')
          .order('period');

      if (timetable.isEmpty) return;

      final now = tz.TZDateTime.now(tz.local);

      for (int dayOffset = 0; dayOffset < 7; dayOffset++) {
        final targetDate = now.add(Duration(days: dayOffset));
        final targetDay = TimetableUtils.dayOfWeekForDb(targetDate);

        if (targetDay == null) continue;

        final dayTimetable = timetable
            .where((entry) => entry['day_of_week'] == targetDay)
            .toList()
          ..sort(
            (a, b) => (a['period'] as int).compareTo(b['period'] as int),
          );

        if (dayTimetable.isEmpty) continue;

        final scheduledPeriods = <int>{};
        final periodStarts = TimetableUtils.periodStartTimesForDate(targetDate);

        Future<void> scheduleOne({
          required int currPeriod,
          required String body,
        }) async {
          if (currPeriod < 1 || currPeriod > periodStarts.length) return;
          if (scheduledPeriods.contains(currPeriod)) return;
          scheduledPeriods.add(currPeriod);

          final periodTime = periodStarts[currPeriod - 1];
          final notificationTime = tz.TZDateTime(
            tz.local,
            targetDate.year,
            targetDate.month,
            targetDate.day,
            periodTime[0],
            periodTime[1] - 5,
          );

          if (notificationTime.isBefore(now)) return;

          final notificationId =
              _notificationIdBase + (dayOffset * 100) + currPeriod;

          try {
            await _plugin.zonedSchedule(
              notificationId,
              '이동 수업 알림',
              body,
              notificationTime,
              NotificationDetails(
                android: AndroidNotificationDetails(
                  _channelId,
                  _channelName,
                  channelDescription: '이동 수업 알림',
                  importance: Importance.high,
                  priority: Priority.high,
                ),
                iOS: const DarwinNotificationDetails(),
              ),
              androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
              uiLocalNotificationDateInterpretation:
                  UILocalNotificationDateInterpretation.absoluteTime,
            );
          } catch (e) {
            if (e.toString().contains('exact_alarms_not_permitted')) {
              await _plugin.zonedSchedule(
                notificationId,
                '이동 수업 알림',
                body,
                notificationTime,
                NotificationDetails(
                  android: AndroidNotificationDetails(
                    _channelId,
                    _channelName,
                    channelDescription: '이동 수업 알림',
                    importance: Importance.high,
                    priority: Priority.high,
                  ),
                  iOS: const DarwinNotificationDetails(),
                ),
                androidScheduleMode:
                    AndroidScheduleMode.inexactAllowWhileIdle,
                uiLocalNotificationDateInterpretation:
                    UILocalNotificationDateInterpretation.absoluteTime,
              );
            }
          }
        }

        for (final currEntry in dayTimetable) {
          if (currEntry['is_moving_class'] != true) continue;
          final currPeriod = currEntry['period'] as int;
          final subject = currEntry['subject'] as String? ?? '수업';
          final currRoom = (currEntry['room'] as String?)?.trim();
          final body = currRoom != null && currRoom.isNotEmpty
              ? '$subject 수업이 $currRoom에서 시작됩니다 (5분 전)'
              : '$subject 수업이 곧 시작됩니다 (5분 전)';
          await scheduleOne(
            currPeriod: currPeriod,
            body: body,
          );
        }

        if (dayTimetable.length >= 2) {
          for (int i = 1; i < dayTimetable.length; i++) {
            final prevEntry = dayTimetable[i - 1];
            final currEntry = dayTimetable[i];

            final prevRoom = prevEntry['room'] as String?;
            final currRoom = currEntry['room'] as String?;
            final currPeriod = currEntry['period'] as int;

            if (prevRoom != null &&
                currRoom != null &&
                prevRoom.trim().isNotEmpty &&
                currRoom.trim().isNotEmpty &&
                prevRoom != currRoom &&
                currPeriod <= periodStarts.length) {
              final subject = currEntry['subject'] as String? ?? '수업';
              await scheduleOne(
                currPeriod: currPeriod,
                body:
                    '$subject 수업이 $currRoom에서 시작됩니다 (5분 전)',
              );
            }
          }
        }
      }
    } catch (_) {}
  }

  static Future<void> _cancelScheduledNotifications() async {
    for (int dayOffset = 0; dayOffset < 7; dayOffset++) {
      // 최대 7교시까지 사용하므로 취소 범위는 고정 유지
      for (
        int period = 1;
        period <= TimetableUtils.periodStartTimes.length;
        period++
      ) {
        await _plugin.cancel(_notificationIdBase + (dayOffset * 100) + period);
      }
    }
  }
}
