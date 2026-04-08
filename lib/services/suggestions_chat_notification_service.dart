import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:myapp/core/realtime/realtime_observability.dart';
import 'package:myapp/core/supabase_client.dart';
import 'package:myapp/models/notification_item.dart';
import 'package:myapp/screens/suggestions_chat_screen.dart';
import 'package:myapp/services/notification_service.dart';

/// 건의함 채팅 알림 서비스.
///
/// - Supabase Realtime으로 [chat_messages] 테이블을 구독합니다.
/// - 건의함 전용 채팅방(kSuggestionsChatRoomId)에 새 메시지가 INSERT되면
///   로컬 알림 + 앱 내 알림 패널에 추가합니다.
/// - 본인이 보낸 메시지는 알림에서 제외합니다.
class SuggestionsChatNotificationService {
  SuggestionsChatNotificationService._();

  static RealtimeChannel? _channel;

  /// 건의함 채팅 실시간 알림 구독 시작.
  ///
  /// 앱이 켜져있는 동안(포그라운드/백그라운드) 새 메시지에 대해 알림을 띄웁니다.
  static Future<void> startListening() async {
    // 이미 구독 중이면 중복 구독 방지
    if (_channel != null) {
      RealtimeObservability.channel(
        'suggestions-chat-noti',
        'already-subscribed',
      );
      return;
    }

    if (supabase.auth.currentUser?.id == null) {
      // 로그인 정보가 없으면 구독하지 않음
      RealtimeObservability.channel('suggestions-chat-noti', 'skip-no-session');
      return;
    }

    RealtimeObservability.channel(
      'suggestions-chat-noti',
      'subscribe channel=suggestions_chat_notifications',
    );
    _channel = supabase
        .channel('suggestions_chat_notifications')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'chat_messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'room_id',
            value: kSuggestionsChatRoomId,
          ),
          callback: (payload) async {
            final newRow = payload.newRecord;
            if (newRow.isEmpty) return;
            RealtimeObservability.event(
              'suggestions-chat-noti',
              'suggestions_chat_notifications',
              'chat_messages.insert',
            );

            final currentUserId = supabase.auth.currentUser?.id;
            if (currentUserId == null) return;

            final senderId = newRow['sender_id'] as String?;
            if (senderId == null || senderId == currentUserId) {
              // 내가 보낸 메시지는 알림 X
              return;
            }

            final content = (newRow['content'] as String?)?.trim();
            final body = (content == null || content.isEmpty)
                ? '새 건의함 채팅 메시지가 도착했어요.'
                : content;

            await NotificationService.showNotification(
              id: 4000,
              title: '건의함 채팅',
              body: body,
              type: NotificationType.other,
              payload: 'suggestions_chat',
            );
          },
        )
        .subscribe((status, [error]) {
          RealtimeObservability.channel(
            'suggestions-chat-noti',
            'status=$status error=${error ?? '-'}',
          );
        });
  }

  /// 건의함 채팅 알림 구독 중지.
  static Future<void> stopListening() async {
    if (_channel != null) {
      try {
        RealtimeObservability.channel(
          'suggestions-chat-noti',
          'unsubscribe channel=suggestions_chat_notifications',
        );
        await supabase.removeChannel(_channel!);
      } catch (_) {}
      _channel = null;
    }
  }

  /// 세션 전환 시 구독을 안전하게 재바인딩한다.
  static Future<void> refreshSubscription() async {
    await stopListening();
    await startListening();
  }
}
