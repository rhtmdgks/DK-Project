import 'package:myapp/core/auth/auth_state.dart';
import 'package:myapp/core/supabase_client.dart';

/// 커뮤니티 게시글·댓글·채팅 메시지 신고 저장.
class ContentReportRepository {
  ContentReportRepository();

  /// 콘텐츠 신고를 저장한다.
  ///
  /// [contentType] 예: 'suggestion', 'suggestion_comment', 'chat_message'.
  /// [contentId] 는 신고 대상 레코드의 id(uuid) 문자열.
  Future<void> reportContent({
    required String contentType,
    required String contentId,
    required String reason,
  }) async {
    final profile = await getCurrentProfile();
    if (profile == null) {
      throw Exception('로그인 후에만 신고할 수 있습니다.');
    }

    await supabase.from('content_reports').insert({
      'content_type': contentType,
      'content_id': contentId,
      'reporter_profile_id': profile.id,
      'reason': reason,
    });
  }
}

