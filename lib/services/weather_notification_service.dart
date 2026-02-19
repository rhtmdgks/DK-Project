import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz_data;

import 'package:myapp/services/weather_service.dart';

/// 날씨 알림: 6시 30분에 현지 날씨를 반영한 알림 표시.
///
/// - 설정에서 "날씨 알림" ON + (선택) 위치 저장
/// - 매일 6:30 로컬 시간에 알림 예약
/// - 앱이 6:30 이후에 열리면 아직 오늘 알림을 안 띄웠을 때 날씨 조회 후 알림 표시
class WeatherNotificationService {
  WeatherNotificationService._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const _channelId = 'weather_notification';
  static const _channelName = '날씨 알림';
  static const _notificationId = 1;

  static const _keyWeatherEnabled = 'weather_notification_enabled';
  static const _keyWeatherLat = 'weather_lat';
  static const _keyWeatherLon = 'weather_lon';
  static const _keyLastShownDate = 'weather_last_shown_date';

  static bool _initialized = false;

  /// 앱 시작 시 호출. 초기화 후 날씨 알림이 켜져 있으면 6:30 알림을 다시 등록(재부팅 대응).
  static Future<void> initialize() async {
    if (_initialized) return;
    tz_data.initializeTimeZones();
    try {
      tz.setLocalLocation(tz.getLocation('Asia/Seoul'));
    } catch (_) {}

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
    );
    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
      onDidReceiveNotificationResponse: (_) {},
    );

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
    if (await isWeatherEnabled()) await scheduleDailyNotification();
  }

  static Future<bool> isWeatherEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyWeatherEnabled) ?? false;
  }

  static Future<void> setWeatherEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyWeatherEnabled, enabled);
    if (enabled) {
      await scheduleDailyNotification();
    } else {
      await _plugin.cancel(_notificationId);
    }
  }

  static Future<void> saveLocation(double lat, double lon) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyWeatherLat, lat);
    await prefs.setDouble(_keyWeatherLon, lon);
  }

  static Future<void> scheduleDailyNotification() async {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      6,
      30,
    );
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    await _plugin.zonedSchedule(
      _notificationId,
      '오늘 날씨',
      '오늘 날씨를 확인해보세요.',
      scheduled,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: '6시 30분 날씨 알림',
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  /// 앱이 포그라운드로 올라왔을 때 호출. 6:30 지났고 오늘 아직 안 띄웠으면 날씨 조회 후 알림.
  static Future<void> maybeShowWeatherNotificationIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool(_keyWeatherEnabled) ?? false;
    if (!enabled) return;

    final now = DateTime.now();
    if (now.hour < 6 || (now.hour == 6 && now.minute < 30)) return;

    final today =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final lastShown = prefs.getString(_keyLastShownDate);
    if (lastShown == today) return;

    final lat = prefs.getDouble(_keyWeatherLat);
    final lon = prefs.getDouble(_keyWeatherLon);

    try {
      final message = await WeatherService.getMorningSummary(
        latitude: lat,
        longitude: lon,
      );
      await prefs.setString(_keyLastShownDate, today);
      await _plugin.show(
        _notificationId,
        '오늘 날씨',
        message,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
          ),
          iOS: const DarwinNotificationDetails(),
        ),
      );
    } catch (_) {
      await _plugin.show(
        _notificationId,
        '오늘 날씨',
        '날씨를 불러오지 못했어요. 앱에서 다시 확인해보세요.',
        NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
          ),
          iOS: const DarwinNotificationDetails(),
        ),
      );
    }
  }
}
