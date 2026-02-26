import 'package:myapp/models/notification_item.dart';
import 'package:myapp/services/notification_service.dart';

/// 테스트용 알림 생성 헬퍼
class NotificationTestHelper {
  /// 샘플 알림들을 생성
  static Future<void> createSampleNotifications() async {
    // 급식 알림
    await NotificationService.showNotification(
      id: 1001,
      title: '급식 출발 알림',
      body: '오늘 점심 급식이 12시에 출발해요.',
      type: NotificationType.meal,
      payload: 'meal',
    );

    // 일정 알림
    await NotificationService.showNotification(
      id: 1002,
      title: '일정 알림',
      body: '내일 09:00 수학 수행평가가 있어요.',
      type: NotificationType.schedule,
      payload: 'schedule',
    );

    // 공지사항 알림
    await NotificationService.showNotification(
      id: 1003,
      title: '공지사항',
      body: '2026학년도 1학기 수강신청 안내가 등록되었어요.',
      type: NotificationType.announcement,
      payload: 'announcement',
    );

    // 날씨 알림
    await NotificationService.showNotification(
      id: 1004,
      title: '날씨 알림',
      body: '오늘은 맑음, 최고 기온 15°C 예상됩니다.',
      type: NotificationType.weather,
      payload: 'weather',
    );

    // 이동 수업 알림
    await NotificationService.showNotification(
      id: 1005,
      title: '이동 수업 알림',
      body: '5분 후 3교시 과학실로 이동하세요.',
      type: NotificationType.classMove,
    );
  }
}
