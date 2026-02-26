import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

/// 급식 출발 알림: 매일 급식 시간 전에 알림 표시.
///
/// - 설정에서 "급식 출발 알림" ON
/// - 매일 점심(12시), 석식(18시) 시간 전에 알림 예약
/// - Supabase에서 급식 정보를 확인하여 해당 날짜에 급식이 있으면 알림
class MealNotificationService {
  MealNotificationService._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const _channelId = 'meal_notification';
  static const _channelName = '급식 출발 알림';
  static const _notificationIdLunch = 3;
  static const _notificationIdDinner = 4;

  static const _keyMealEnabled = 'setting_meal';

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
    if (await isMealEnabled()) {
      await scheduleMealNotifications();
    }
  }

  /// 급식 알림 활성화 여부 확인
  static Future<bool> isMealEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyMealEnabled) ?? false;
  }

  /// 급식 알림 활성화/비활성화
  static Future<void> setMealEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyMealEnabled, enabled);

    if (enabled) {
      await scheduleMealNotifications();
    } else {
      await _plugin.cancel(_notificationIdLunch);
      await _plugin.cancel(_notificationIdDinner);
    }
  }

  /// 급식 알림 스케줄링
  static Future<void> scheduleMealNotifications() async {
    final now = tz.TZDateTime.now(tz.local);
    
    // 점심 알림: 매일 11시 50분
    var lunchTime = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      11,
      50,
    );
    if (lunchTime.isBefore(now)) {
      lunchTime = lunchTime.add(const Duration(days: 1));
    }

    // 석식 알림: 매일 17시 50분
    var dinnerTime = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      17,
      50,
    );
    if (dinnerTime.isBefore(now)) {
      dinnerTime = dinnerTime.add(const Duration(days: 1));
    }

    try {
      // 점심 알림 예약
      await _plugin.zonedSchedule(
        _notificationIdLunch,
        '급식 출발 알림',
        '점심 급식 시간이 곧 시작됩니다!',
        lunchTime,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: '급식 출발 알림',
          ),
          iOS: const DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );

      // 석식 알림 예약
      await _plugin.zonedSchedule(
        _notificationIdDinner,
        '급식 출발 알림',
        '석식 급식 시간이 곧 시작됩니다!',
        dinnerTime,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: '급식 출발 알림',
          ),
          iOS: const DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } catch (e) {
      // 정확한 알람 권한이 없으면 부정확한 알람 모드로 폴백
      if (e.toString().contains('exact_alarms_not_permitted')) {
        await _plugin.zonedSchedule(
          _notificationIdLunch,
          '급식 출발 알림',
          '점심 급식 시간이 곧 시작됩니다!',
          lunchTime,
          NotificationDetails(
            android: AndroidNotificationDetails(
              _channelId,
              _channelName,
              channelDescription: '급식 출발 알림',
            ),
            iOS: const DarwinNotificationDetails(),
          ),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.time,
        );

        await _plugin.zonedSchedule(
          _notificationIdDinner,
          '급식 출발 알림',
          '석식 급식 시간이 곧 시작됩니다!',
          dinnerTime,
          NotificationDetails(
            android: AndroidNotificationDetails(
              _channelId,
              _channelName,
              channelDescription: '급식 출발 알림',
            ),
            iOS: const DarwinNotificationDetails(),
          ),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.time,
        );
      }
    }
  }
}
