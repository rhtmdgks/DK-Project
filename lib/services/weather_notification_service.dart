import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:myapp/repositories/notification_settings_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz_data;

import 'package:myapp/models/notification_item.dart';
import 'package:myapp/services/notification_service.dart';
import 'package:myapp/services/weather_service.dart';

/// 날씨 알림: 매일 AM 06:30에 알림이 뜨도록 예약.
///
/// - 설정에서 "날씨 알림" ON + (선택) 위치 저장
/// - 매일 오전 6시 30분(로컬 시간)에 알림이 표시됨 (zonedSchedule)
/// - 앱을 6:30 이후에 열었을 때 오늘 알림을 아직 안 받은 경우에만 보조로 표시 (폴백)
class WeatherNotificationService {
  WeatherNotificationService._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const _channelId = 'weather_notification';
  static const _channelName = '날씨 알림';
  static const _notificationId = 1;

  /// [zonedSchedule]은 실행 시 Dart가 돌지 않아 API를 붙일 수 없음 — 고정 멘트만 사용.
  static const _scheduledTitle = '좋은 아침이에요';
  static const _scheduledBody =
      '오늘 기온과 강수는 앱을 열면 자세히 볼 수 있어요. 하루 준비에 참고해 보세요.';

  static const _errorTitle = '날씨를 잠시 불러오지 못했어요';
  static const _errorBody =
      '네트워크 상태를 확인한 뒤, 앱에서 다시 한 번 확인해 주세요.';

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
    if (await isWeatherEnabled()) {
      await scheduleDailyNotification();
    }
  }

  static Future<bool> isWeatherEnabled() async =>
      NotificationSettingsRepository.instance.getWeatherEnabled();

  /// Android & iOS 알림 권한 요청
  static Future<bool> requestNotificationPermission() async {
    // Android 권한 요청
    final androidImplementation = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidImplementation != null) {
      final granted = await androidImplementation.requestNotificationsPermission();
      return granted ?? false;
    }

    // iOS 권한 요청
    final iosImplementation = _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();
    if (iosImplementation != null) {
      final result = await iosImplementation.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      return result ?? false;
    }

    return true; // 플랫폼을 확인할 수 없는 경우
  }

  /// 알림 권한이 허용되었는지 확인 (Android & iOS)
  static Future<bool> isNotificationPermissionGranted() async {
    // Android 확인
    final androidImplementation = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidImplementation != null) {
      final granted = await androidImplementation.areNotificationsEnabled();
      return granted ?? false;
    }

    // iOS 확인
    final iosImplementation = _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();
    if (iosImplementation != null) {
      final result = await iosImplementation.checkPermissions();
      return result?.isEnabled ?? false;
    }

    return true; // 플랫폼을 확인할 수 없는 경우
  }

  /// 날씨 알림 활성화/비활성화
  /// 
  /// [skipPermissionCheck]: true이면 알림 권한 확인을 건너뜀 (호출하는 쪽에서 이미 확인한 경우)
  static Future<void> setWeatherEnabled(bool enabled, {bool skipPermissionCheck = false}) async {
    await NotificationSettingsRepository.instance.setWeatherEnabled(enabled);
    if (enabled) {
      if (!skipPermissionCheck) {
        final hasPermission = await isNotificationPermissionGranted();
        if (!hasPermission) {
          final granted = await requestNotificationPermission();
          if (!granted) {
            await NotificationSettingsRepository.instance.setWeatherEnabled(false);
            throw Exception('알림 권한이 필요합니다. 설정에서 알림 권한을 허용해주세요.');
          }
        }
      }
      try {
        await scheduleDailyNotification();
      } catch (e) {
        debugPrint('날씨 알림 스케줄 등록 실패: $e');
        await NotificationSettingsRepository.instance.setWeatherEnabled(false);
        rethrow;
      }
    } else {
      await _plugin.cancel(_notificationId);
    }
  }

  static Future<void> saveLocation(double lat, double lon) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyWeatherLat, lat);
    await prefs.setDouble(_keyWeatherLon, lon);
  }

  /// 매일 AM 06:30에 날씨 알림이 뜨도록 예약 (로컬 시간 기준)
  static Future<void> scheduleDailyNotification() async {
    // 기존 알림 취소
    await _plugin.cancel(_notificationId);

    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      6,  // 오전 6시
      30, // 30분
    );
    
    // 이미 오늘 6:30이 지났으면 내일로 설정
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    debugPrint('날씨 알림 예약: ${scheduled.toString()}');

    try {
      await _plugin.zonedSchedule(
        _notificationId,
        _scheduledTitle,
        _scheduledBody,
        scheduled,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: '매일 오전 6시 30분 날씨 알림',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time, // 매일 같은 시간에 반복
      );
    } catch (e) {
      debugPrint('날씨 알림 exact 예약 실패: $e');
      // 정확한 알람 권한 없음 또는 기타 오류 시 inexact로 재시도
      try {
        await _plugin.zonedSchedule(
          _notificationId,
          _scheduledTitle,
          _scheduledBody,
          scheduled,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              _channelId,
              _channelName,
              channelDescription: '매일 오전 6시 30분 날씨 알림',
              importance: Importance.high,
              priority: Priority.high,
            ),
            iOS: DarwinNotificationDetails(
              presentAlert: true,
              presentBadge: true,
              presentSound: true,
            ),
          ),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.time,
        );
        debugPrint('날씨 알림 inexact 예약 성공');
      } catch (e2) {
        debugPrint('날씨 알림 inexact 예약도 실패: $e2');
        rethrow;
      }
    }
  }

  /// (폴백) 앱을 6:30 이후에 열었을 때, 오늘 알림을 아직 안 받았으면 그때 날씨 조회 후 알림. 주 동작은 AM 06:30 스케줄.
  static Future<void> maybeShowWeatherNotificationIfNeeded() async {
    final enabled = await NotificationSettingsRepository.instance.getWeatherEnabled();
    if (!enabled) return;

    final prefs = await SharedPreferences.getInstance();

    final now = DateTime.now();
    // 오전 6시 30분 이후인지 확인
    if (now.hour < 6 || (now.hour == 6 && now.minute < 30)) return;

    final today =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final lastShown = prefs.getString(_keyLastShownDate);
    if (lastShown == today) return;

    final lat = prefs.getDouble(_keyWeatherLat);
    final lon = prefs.getDouble(_keyWeatherLon);

    try {
      final copy = await WeatherService.getMorningNotificationCopy(
        latitude: lat,
        longitude: lon,
      );
      await prefs.setString(_keyLastShownDate, today);

      await NotificationService.showNotification(
        id: _notificationId,
        title: copy.title,
        body: copy.body,
        type: NotificationType.weather,
        payload: 'weather',
      );
    } catch (e) {
      debugPrint('날씨 정보 조회 실패: $e');
      await NotificationService.showNotification(
        id: _notificationId,
        title: _errorTitle,
        body: _errorBody,
        type: NotificationType.weather,
        payload: 'weather',
      );
    }
  }
}
