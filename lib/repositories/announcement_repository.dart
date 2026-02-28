import 'package:myapp/core/supabase_client.dart';

/// 공지사항·투표 데이터 접근 레이어.
class AnnouncementRepository {
  AnnouncementRepository();

  final _client = supabase;

  /// 공지사항 목록 (created_at 내림차순).
  Future<List<Map<String, dynamic>>> fetchAnnouncements() async {
    final res = await _client
        .from('announcements')
        .select()
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(res as List);
  }

  /// 투표 목록 (created_at 내림차순).
  Future<List<Map<String, dynamic>>> fetchPolls() async {
    final res = await _client
        .from('polls')
        .select()
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(res as List);
  }

  /// 사용자의 투표 참여.
  Future<void> vote({
    required String pollId,
    required String userId,
    required int optionIndex,
  }) async {
    await _client.from('poll_votes').insert({
      'poll_id': pollId,
      'user_id': userId,
      'option_index': optionIndex,
    });
  }

  /// 사용자가 해당 투표에 참여했는지 및 선택 인덱스 조회.
  Future<Map<String, dynamic>?> getPollVote(String pollId, String userId) async {
    final res = await _client
        .from('poll_votes')
        .select()
        .eq('poll_id', pollId)
        .eq('user_id', userId)
        .maybeSingle();
    return res;
  }
}
