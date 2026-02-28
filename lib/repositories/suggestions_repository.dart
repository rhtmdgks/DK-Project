import 'package:myapp/core/supabase_client.dart';

/// 건의함(건의 목록·등록·1:1 채팅 생성) 데이터 접근 레이어.
class SuggestionsRepository {
  SuggestionsRepository();

  final _client = supabase;

  /// 건의 목록 (created_at 내림차순).
  Future<List<Map<String, dynamic>>> fetchSuggestions() async {
    final res = await _client
        .from('suggestions')
        .select()
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(res as List);
  }

  /// 건의 등록. [authorId]는 profiles.id.
  Future<void> addSuggestion({
    required String authorId,
    required String title,
    String? body,
  }) async {
    await _client.from('suggestions').insert({
      'author_id': authorId,
      'title': title,
      'body': body,
    });
  }

  /// 1:1 채팅방 생성 또는 조회. 반환값은 RPC 결과 (room id 등).
  Future<Map<String, dynamic>> createOrGetDirectChat({
    required String otherUserId,
    required String userId,
  }) async {
    final result = await _client.rpc(
      'create_or_get_direct_chat',
      params: {
        'p_other_user_id': otherUserId,
        'p_user_id': userId,
      },
    );
    return result as Map<String, dynamic>;
  }

  /// role이 [role]인 프로필 한 건 조회 (예: admin).
  Future<Map<String, dynamic>?> fetchProfileByRole(String role) async {
    final res = await _client
        .from('profiles')
        .select('user_id, full_name')
        .eq('role', role)
        .limit(1);
    final list = res as List;
    if (list.isEmpty) return null;
    return list.first as Map<String, dynamic>;
  }
}
