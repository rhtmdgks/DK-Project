import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:myapp/core/supabase_client.dart';

/// 공지사항 알림: 새 공지사항이 생성되면 실시간으로 알림 표시.
///
/// - 설정에서 "공지사항 알림" ON
/// - Supabase Realtime으로 announcements 테이블 구독
/// - 새 공지사항 INSERT 시 로컬 알림 표시
class AnnouncementNotificationService {
  AnnouncementNotificationService._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const _channelId = 'announcement_notification';
  static const _channelName = '공지사항 알림';
  static const _notificationId = 2;

  static const _keyNoticeEnabled = 'setting_notice';

  static RealtimeChannel? _channel;

  /// 공지사항 알림 활성화 여부 확인
  static Future<bool> isNoticeEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyNoticeEnabled) ?? false;
  }

  /// 공지사항 알림 채널 생성 (Android)
  static Future<void> _createNotificationChannel() async {
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
  }

  /// iOS 알림 권한 요청
  static Future<bool> _requestIOSPermission() async {
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
    return true; // iOS가 아닌 경우
  }

  /// 알림 권한 확인 (Android & iOS)
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

  /// 알림 권한 요청 (Android & iOS)
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
    return await _requestIOSPermission();
  }

  /// 공지사항 알림 구독 시작
  static Future<void> startListening() async {
    // 이미 구독 중이면 중복 구독 방지
    if (_channel != null) return;

    final enabled = await isNoticeEnabled();
    if (!enabled) return;

    // Android 채널 생성 및 iOS 권한 확인
    await _createNotificationChannel();
    
    // 알림 권한 확인 및 요청 (필요한 경우)
    final hasPermission = await isNotificationPermissionGranted();
    if (!hasPermission) {
      await requestNotificationPermission();
    }

    _channel = supabase
        .channel('announcements')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'announcements',
          callback: (payload) async {
            final newRow = payload.newRecord;
            if (newRow.isEmpty) return;

            // 설정에서 공지사항 알림이 켜져있는지 다시 확인
            final stillEnabled = await isNoticeEnabled();
            if (!stillEnabled) return;

            final title = newRow['title'] as String? ?? '새 공지사항';
            final body = newRow['body'] as String?;

            await _plugin.show(
              _notificationId,
              title,
              body ?? '새로운 공지사항이 등록되었습니다.',
              NotificationDetails(
                android: AndroidNotificationDetails(
                  _channelId,
                  _channelName,
                  channelDescription: '새 공지사항 알림',
                ),
                iOS: const DarwinNotificationDetails(),
              ),
            );
          },
        )
        .subscribe();
  }

  /// 공지사항 알림 구독 중지
  static Future<void> stopListening() async {
    await _channel?.unsubscribe();
    _channel = null;
  }

  /// 공지사항 알림 설정 변경 시 호출 (구독 재시작)
  static Future<void> refreshSubscription() async {
    await stopListening();
    await startListening();
  }
}
