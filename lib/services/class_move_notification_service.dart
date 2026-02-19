import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

  static const _keyClassMoveEnabled = 'setting_class_move';

  static bool _initialized = false;

  // 기본 수업 시간표 (교시별 시작 시간, 분 단위)
  static const _periodTimes = [
    [9, 0],   // 1교시: 09:00
    [10, 0],  // 2교시: 10:00
    [11, 0],  // 3교시: 11:00
    [12, 0],  // 4교시: 12:00
    [13, 30], // 5교시: 13:30
    [14, 30], // 6교시: 14:30
    [15, 30], // 7교시: 15:30
    [16, 30], // 8교시: 16:30
    [17, 30], // 9교시: 17:30
    [18, 30], // 10교시: 18:30
  ];

  /// 초기화
  static Future<void> initialize() async {
    if (_initialized) return;
    tz_data.initializeTimeZones();
    try {
      tz.setLocalLocation(tz.getLocation('Asia/Seoul'));
    } catch (_) {}

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
    if (await isClassMoveEnabled()) {
      await scheduleClassMoveNotifications();
    }
  }

  /// 이동 수업 알림 활성화 여부 확인
  static Future<bool> isClassMoveEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyClassMoveEnabled) ?? false;
  }

  /// 이동 수업 알림 활성화/비활성화
  static Future<void> setClassMoveEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyClassMoveEnabled, enabled);

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
      // 사용자의 시간표 조회
      final timetable = await supabase
          .from('timetable_entries')
          .select()
          .eq('user_id', uid)
          .order('day_of_week')
          .order('period');

      if (timetable.isEmpty) return;

      final now = tz.TZDateTime.now(tz.local);
      final today = now.weekday % 7; // 0=일요일, 1=월요일, ..., 6=토요일

      // 오늘부터 일주일간의 이동 수업 알림 스케줄링
      for (int dayOffset = 0; dayOffset < 7; dayOffset++) {
        final targetDay = (today + dayOffset) % 7;
        final targetDate = now.add(Duration(days: dayOffset));

        // 해당 요일의 시간표 필터링
        final dayTimetable = timetable.where((entry) {
          return entry['day_of_week'] == targetDay;
        }).toList();

        if (dayTimetable.length < 2) continue;

        // 이동 수업 찾기: 이전 수업과 다음 수업의 room이 다르면 이동 수업
        for (int i = 1; i < dayTimetable.length; i++) {
          final prevEntry = dayTimetable[i - 1] as Map<String, dynamic>;
          final currEntry = dayTimetable[i] as Map<String, dynamic>;

          final prevRoom = prevEntry['room'] as String?;
          final currRoom = currEntry['room'] as String?;
          final currPeriod = currEntry['period'] as int;

          // room이 있고, 이전 수업과 다르면 이동 수업
          if (prevRoom != null &&
              currRoom != null &&
              prevRoom.trim().isNotEmpty &&
              currRoom.trim().isNotEmpty &&
              prevRoom != currRoom &&
              currPeriod <= _periodTimes.length) {
            // 수업 시작 시간 5분 전에 알림
            final periodTime = _periodTimes[currPeriod - 1];
            var notificationTime = tz.TZDateTime(
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
            final notificationId = _notificationIdBase + (dayOffset * 100) + currPeriod;

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
                  androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
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
}
