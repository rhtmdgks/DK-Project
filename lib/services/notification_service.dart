import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';
import 'package:myapp/core/routing/app_router.dart';
import 'package:myapp/models/notification_item.dart';
import 'package:myapp/providers/notification_provider.dart';
import 'package:myapp/services/announcement_notification_service.dart';
import 'package:myapp/services/class_move_notification_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:myapp/services/suggestions_chat_notification_service.dart';
import 'package:myapp/services/fcm_token_service.dart';
import 'package:myapp/services/meal_departure_realtime_service.dart';
import 'package:myapp/services/meal_notification_service.dart';
import 'package:myapp/services/schedule_notification_service.dart';
import 'package:myapp/services/weather_notification_service.dart';

/// 통합 알림 서비스
/// 
/// 모든 알림 타입을 관리하고 앱 내 알림 목록과 로컬 알림을 통합 처리합니다.
class NotificationService {
  NotificationService._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static NotificationProvider? _notificationProvider;
  static bool _initialized = false;

  /// 알림 서비스 초기화
  static Future<void> initialize(NotificationProvider provider) async {
    if (_initialized) return;

    _notificationProvider = provider;

    // 플러그인 초기화
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // 각 알림 서비스 초기화
    try {
      await WeatherNotificationService.initialize();
    } catch (e) {
      debugPrint('날씨 알림 서비스 초기화 실패: $e');
    }

    try {
      await AnnouncementNotificationService.initialize();
    } catch (e) {
      debugPrint('공지사항 알림 서비스 초기화 실패: $e');
    }

    try {
      await MealNotificationService.initialize();
    } catch (e) {
      debugPrint('급식 알림 서비스 초기화 실패: $e');
    }

    try {
      await ScheduleNotificationService.initialize();
    } catch (e) {
      debugPrint('일정 알림 서비스 초기화 실패: $e');
    }

    try {
      await ClassMoveNotificationService.initialize();
    } catch (e) {
      debugPrint('이동 수업 알림 서비스 초기화 실패: $e');
    }

    // 건의함 채팅 실시간 알림 구독
    try {
      await SuggestionsChatNotificationService.startListening();
    } catch (e) {
      debugPrint('건의함 채팅 알림 서비스 초기화/구독 실패: $e');
    }

    // 공지사항 실시간 구독 시작
    try {
      await AnnouncementNotificationService.startListening();
    } catch (e) {
      debugPrint('공지사항 실시간 구독 실패: $e');
    }

    // 급식 출발 실시간 알림 초기화 및 구독 시작
    try {
      await MealDepartureRealtimeService.initialize();
      await MealDepartureRealtimeService.startListening();
    } catch (e) {
      debugPrint('급식 출발 실시간 알림 초기화/구독 실패: $e');
    }

    // FCM 포그라운드 수신 시 로컬 알림 표시 (백그라운드/종료 시는 OS가 표시)
    try {
      await FcmTokenService.ensureFirebaseInitialized();
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        final title = message.notification?.title ?? message.data['message'] ?? '급식 출발 알림';
        final body = message.notification?.body ?? message.data['body'] ?? '급식이 출발했습니다.';
        showNotification(
          id: 2000,
          title: title.toString(),
          body: body.toString(),
          type: NotificationType.meal,
          payload: 'meal_departure',
        );
      });
    } catch (e) {
      debugPrint('FCM onMessage 리스너 설정 실패: $e');
    }

    _initialized = true;
  }

  /// 앱이 포그라운드로 돌아왔을 때 호출
  static Future<void> onAppResumed() async {
    try {
      await WeatherNotificationService.maybeShowWeatherNotificationIfNeeded();
    } catch (e) {
      debugPrint('날씨 알림 확인 실패: $e');
    }

    try {
      await ScheduleNotificationService.showTodayScheduleIfNeeded();
    } catch (e) {
      debugPrint('일정 알림 확인 실패: $e');
    }
  }

  /// 앱 종료 시 호출
  static Future<void> dispose() async {
    try {
      await AnnouncementNotificationService.stopListening();
    } catch (e) {
      debugPrint('공지사항 구독 중지 실패: $e');
    }
    try {
      await MealDepartureRealtimeService.stopListening();
    } catch (e) {
      debugPrint('급식 출발 알림 구독 중지 실패: $e');
    }
    try {
      await SuggestionsChatNotificationService.stopListening();
    } catch (e) {
      debugPrint('건의함 채팅 알림 구독 중지 실패: $e');
    }
  }

  /// 알림 탭 시 처리
  static void _onNotificationTapped(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null) return;

    final context = _getNavigatorContext();
    if (context == null) return;

    // payload에 따라 적절한 화면으로 이동
    if (payload == 'suggestions_chat') {
      context.push(AppRoute.suggestionsChat.path);
      return;
    }

    // 기본값: 홈 화면으로 이동
    context.push(AppRoute.home.path);
  }

  /// Navigator context 가져오기 (GoRouter용)
  static BuildContext? _getNavigatorContext() {
    return rootNavigatorKey.currentContext;
  }

  /// 앱 내 알림 추가 (앱 내 목록 먼저 추가 후 로컬 알림 표시)
  /// 패널에 반드시 보이도록 목록 추가를 먼저 하고, 시스템 알림은 실패해도 패널에는 남김.
  static Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    required NotificationType type,
    String? payload,
  }) async {
    final notification = NotificationItem(
      id: '${type.name}_${DateTime.now().millisecondsSinceEpoch}',
      type: type,
      title: title,
      body: body,
      timestamp: DateTime.now(),
      payload: payload,
    );

    // 1) 앱 내 알림 목록에 먼저 추가 (패널에 항상 표시)
    if (_notificationProvider != null) {
      await _notificationProvider!.addNotification(notification);
    } else {
      debugPrint('NotificationService.showNotification: _notificationProvider가 null이라 앱 내 목록에 추가하지 못함. initialize() 완료 여부 확인 필요.');
    }

    // 2) 로컬(시스템) 알림 표시
    try {
      await _plugin.show(
        id,
        title,
        body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _getChannelId(type),
            _getChannelName(type),
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: payload,
      );
    } catch (e) {
      debugPrint('NotificationService.showNotification: 시스템 알림 표시 실패 ($type): $e');
    }
  }

  /// 프로필 변경 시 프로필 의존 구독을 갱신합니다.
  static Future<void> onProfileChanged() async {
    try {
      await MealDepartureRealtimeService.refreshSubscription();
    } catch (e) {
      debugPrint('급식 출발 알림 구독 갱신 실패: $e');
    }
  }

  /// 로그아웃 시 모든 실시간 구독을 해제하고 FCM 토큰을 해제합니다.
  static Future<void> onLogout() async {
    try {
      await FcmTokenService.unregisterIfNeeded();
    } catch (e) {
      debugPrint('FCM 토큰 해제 실패: $e');
    }
    try {
      await AnnouncementNotificationService.stopListening();
    } catch (e) {
      debugPrint('공지사항 구독 중지 실패: $e');
    }
    try {
      await MealDepartureRealtimeService.stopListening();
    } catch (e) {
      debugPrint('급식 출발 알림 구독 중지 실패: $e');
    }
    _initialized = false;
  }

  static String _getChannelId(NotificationType type) {
    switch (type) {
      case NotificationType.weather:
        return 'weather_notification';
      case NotificationType.announcement:
        return 'announcement_notification';
      case NotificationType.meal:
        return 'meal_notification';
      case NotificationType.schedule:
        return 'schedule_notification';
      case NotificationType.classMove:
        return 'class_move_notification';
      default:
        return 'default_notification';
    }
  }

  static String _getChannelName(NotificationType type) {
    switch (type) {
      case NotificationType.weather:
        return '날씨 알림';
      case NotificationType.announcement:
        return '공지사항 알림';
      case NotificationType.meal:
        return '급식 출발 알림';
      case NotificationType.schedule:
        return '일정 알림';
      case NotificationType.classMove:
        return '이동 수업 알림';
      default:
        return '기본 알림';
    }
  }
}
