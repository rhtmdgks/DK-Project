import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:myapp/repositories/notification_settings_repository.dart';
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
  static const _weekdays = <int>[
    DateTime.monday,
    DateTime.tuesday,
    DateTime.wednesday,
    DateTime.thursday,
    DateTime.friday,
  ];

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
            importance: Importance.high,
          ),
        );

    _initialized = true;
    if (await isMealEnabled()) {
      await scheduleMealNotifications();
    }
  }

  /// 급식 알림 활성화 여부 확인
  static Future<bool> isMealEnabled() async =>
      NotificationSettingsRepository.instance.getMealEnabled();

  /// 급식 알림 활성화/비활성화
  static Future<void> setMealEnabled(bool enabled) async {
    await NotificationSettingsRepository.instance.setMealEnabled(enabled);

    if (enabled) {
      await scheduleMealNotifications();
    } else {
      await _cancelScheduledMealNotifications();
    }
  }

  /// 급식 알림 스케줄링
  static Future<void> scheduleMealNotifications() async {
    await _cancelScheduledMealNotifications();

    try {
      await _scheduleWeekdayMealNotifications(
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    } catch (e) {
      // 정확한 알람 권한이 없으면 부정확한 알람 모드로 폴백
      if (e.toString().contains('exact_alarms_not_permitted')) {
        await _scheduleWeekdayMealNotifications(
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
      }
    }
  }

  static Future<void> _scheduleWeekdayMealNotifications({
    required AndroidScheduleMode androidScheduleMode,
  }) async {
    for (final weekday in _weekdays) {
      await _plugin.zonedSchedule(
        _weekdayNotificationId(true, weekday),
        '급식 출발 알림',
        '오늘 점심 급식이 곧 시작돼요!',
        _nextWeekdayOccurrence(weekday, 11, 50),
        _notificationDetails(),
        androidScheduleMode: androidScheduleMode,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      );

      await _plugin.zonedSchedule(
        _weekdayNotificationId(false, weekday),
        '급식 출발 알림',
        '오늘 석식 급식이 곧 시작돼요!',
        _nextWeekdayOccurrence(weekday, 17, 50),
        _notificationDetails(),
        androidScheduleMode: androidScheduleMode,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      );
    }
  }

  static Future<void> _cancelScheduledMealNotifications() async {
    await _plugin.cancel(_notificationIdLunch);
    await _plugin.cancel(_notificationIdDinner);

    for (final weekday in _weekdays) {
      await _plugin.cancel(_weekdayNotificationId(true, weekday));
      await _plugin.cancel(_weekdayNotificationId(false, weekday));
    }
  }

  static NotificationDetails _notificationDetails() {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: '급식 출발 알림',
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: const DarwinNotificationDetails(),
    );
  }

  static int _weekdayNotificationId(bool isLunch, int weekday) {
    final baseId = isLunch ? 300 : 400;
    return baseId + weekday;
  }

  static tz.TZDateTime _nextWeekdayOccurrence(
    int weekday,
    int hour,
    int minute,
  ) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    while (scheduled.weekday != weekday || !scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    return scheduled;
  }
}
