import 'package:myapp/core/supabase_client.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 학생 의견 공개 모집(캠페인·제출) 데이터 접근 레이어.
///
/// 익명 규칙: author_id는 항상 저장하되 앱 UI에서는 작성자를 노출하지 않는다.
class OpinionRepository {
  OpinionRepository._();

  static final OpinionRepository instance = OpinionRepository._();

  SupabaseClient get _client => supabase;

  /// 진행 중(open) 캠페인 목록. RLS로 학생은 open만 조회된다.
  Future<List<Map<String, dynamic>>> fetchOpenCampaigns() async {
    final res = await _client
        .from('opinion_campaigns')
        .select()
        .eq('status', 'open')
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(res as List);
  }

  /// 내가 제출한 캠페인 id 집합 (제출 완료 표시용).
  Future<Set<String>> fetchMySubmittedCampaignIds(String profileId) async {
    final res = await _client
        .from('opinion_submissions')
        .select('campaign_id')
        .eq('author_id', profileId);
    return List<Map<String, dynamic>>.from(res as List)
        .map((r) => (r['campaign_id'] ?? '').toString())
        .where((id) => id.isNotEmpty)
        .toSet();
  }

  /// 의견 제출. 캠페인당 1회 (DB UNIQUE).
  Future<void> submitOpinion({
    required String campaignId,
    required String authorProfileId,
    required String body,
  }) async {
    await _client.from('opinion_submissions').insert({
      'campaign_id': campaignId,
      'author_id': authorProfileId,
      'body': body,
    });
  }
}
