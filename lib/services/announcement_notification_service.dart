import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:myapp/repositories/notification_settings_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:myapp/core/auth/auth_state.dart';
import 'package:myapp/core/supabase_client.dart';
import 'package:myapp/models/notification_item.dart';
import 'package:myapp/services/notification_service.dart';

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

  static RealtimeChannel? _channel;
  static bool _initialized = false;

  /// 초기화
  static Future<void> initialize() async {
    if (_initialized) return;

    await _createNotificationChannel();
    _initialized = true;
  }

  /// 공지사항 알림 활성화 여부 확인
  static Future<bool> isNoticeEnabled() async =>
      NotificationSettingsRepository.instance.getNoticeEnabled();

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

  static String? _stringArg(Map<String, dynamic> m, String key) {
    final v = m[key];
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }

  static int? _intOrNull(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    return int.tryParse(v.toString());
  }

  /// 공지 대상(target_grade, target_class)이 현재 사용자에게 해당하는지 판단.
  /// target_grade: null/빈값/전체 → 학년 무시. '1학년','2학년','3학년'이면 해당 학년만.
  /// target_class: null → 학년 전체. 값 있으면 해당 반만 (학년+반 일치 시 알림).
  static Future<bool> _shouldNotifyCurrentUser(
    String? targetGrade,
    int? targetClass,
  ) async {
    final profile = await getCurrentProfile();
    final userGrade = profile?.gradeOrFromStudentId;
    final userClass = profile?.classNumOrFromStudentId;

    // 학년 필터
    if (targetGrade != null && targetGrade.trim().isNotEmpty) {
      final t = targetGrade.trim().toLowerCase();
      if (t != '전체' && t != 'all') {
        if (userGrade == null) return true; // 학년 모르면 전체로 간주
        switch (t) {
          case '1학년':
          case '1':
            if (userGrade != 1) return false;
            break;
          case '2학년':
          case '2':
            if (userGrade != 2) return false;
            break;
          case '3학년':
          case '3':
            if (userGrade != 3) return false;
            break;
          default:
            return false;
        }
      }
    }

    // 반 필터: target_class가 있으면 해당 반만
    if (targetClass != null) {
      if (userClass == null) return true; // 반을 알 수 없으면 알림(학년만 맞으면)
      if (userClass != targetClass) return false;
    }

    return true;
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

            // 대상(학년·반) 필터 (백오피스는 target_class_number 사용)
            final targetGrade = _stringArg(newRow, 'target_grade') ??
                _stringArg(newRow, 'target_audience') ??
                _stringArg(newRow, 'target');
            final targetClass = _intOrNull(newRow['target_class_number']) ??
                _intOrNull(newRow['target_class']);
            if (!await _shouldNotifyCurrentUser(targetGrade, targetClass)) return;

            final title = newRow['title'] as String? ?? '새 공지사항';
            final body = newRow['body'] as String?;

            // NotificationService를 통해 알림 표시
            await NotificationService.showNotification(
              id: _notificationId,
              title: title,
              body: body ?? '새로운 공지사항이 등록되었습니다.',
              type: NotificationType.announcement,
              payload: 'announcement',
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
