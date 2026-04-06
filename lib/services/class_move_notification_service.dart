import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:myapp/repositories/notification_settings_repository.dart';
import 'package:myapp/core/utils/timetable_utils.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz_data;

import 'package:myapp/core/supabase_client.dart';

/// 이동 수업 알림: 시간표에 설정한 이동 수업 5분 전에 알림 표시.
///
/// - 설정에서 "이동 수업 알림" ON
/// - timetable_entries 테이블에서 사용자의 시간표 조회
/// - 이전 수업과 다음 수업의 room이 다르면 이동 수업으로 판단
/// - 수업 시작 시간 5분 전에 알림
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
            importance: Importance.defaultImportance,
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

    try {
      await _cancelScheduledNotifications();

      // 사용자의 시간표 조회
      final timetable = await supabase
          .from('timetable_entries')
          .select('day_of_week, period, room, subject')
          .eq('user_id', uid)
          .order('day_of_week')
          .order('period');

      if (timetable.isEmpty) return;

      final now = tz.TZDateTime.now(tz.local);

      // 오늘부터 일주일간의 이동 수업 알림 스케줄링
      for (int dayOffset = 0; dayOffset < 7; dayOffset++) {
        final targetDate = now.add(Duration(days: dayOffset));
        final targetDay = TimetableUtils.dayOfWeekForDb(targetDate);

        if (targetDay == null) continue;

        // 해당 요일의 시간표 필터링
        final dayTimetable = timetable.where((entry) {
          return entry['day_of_week'] == targetDay;
        }).toList();

        if (dayTimetable.length < 2) continue;

        // 이동 수업 찾기: 이전 수업과 다음 수업의 room이 다르면 이동 수업
        for (int i = 1; i < dayTimetable.length; i++) {
          final prevEntry = dayTimetable[i - 1];
          final currEntry = dayTimetable[i];

          final prevRoom = prevEntry['room'] as String?;
          final currRoom = currEntry['room'] as String?;
          final currPeriod = currEntry['period'] as int;

          // room이 있고, 이전 수업과 다르면 이동 수업
          if (prevRoom != null &&
              currRoom != null &&
              prevRoom.trim().isNotEmpty &&
              currRoom.trim().isNotEmpty &&
              prevRoom != currRoom &&
              currPeriod <= TimetableUtils.periodStartTimesForDate(targetDate).length) {
            // 수업 시작 시간 5분 전에 알림
            final periodTime =
                TimetableUtils.periodStartTimesForDate(targetDate)[currPeriod - 1];
            final notificationTime = tz.TZDateTime(
              tz.local,
              targetDate.year,
              targetDate.month,
              targetDate.day,
              periodTime[0],
              periodTime[1] - 5, // 5분 전
            );

            // 이미 지난 시간이면 스킵
            if (notificationTime.isBefore(now)) continue;

            final subject = currEntry['subject'] as String? ?? '수업';
            final notificationId =
                _notificationIdBase + (dayOffset * 100) + currPeriod;

            try {
              await _plugin.zonedSchedule(
                notificationId,
                '이동 수업 알림',
                '$subject 수업이 $currRoom에서 시작됩니다 (5분 전)',
                notificationTime,
                NotificationDetails(
                  android: AndroidNotificationDetails(
                    _channelId,
                    _channelName,
                    channelDescription: '이동 수업 알림',
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
                  '$subject 수업이 $currRoom에서 시작됩니다 (5분 전)',
                  notificationTime,
                  NotificationDetails(
                    android: AndroidNotificationDetails(
                      _channelId,
                      _channelName,
                      channelDescription: '이동 수업 알림',
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
        }
      }
    } catch (_) {
      // 오류 발생 시 무시 (시간표가 없거나 권한 문제 등)
    }
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
