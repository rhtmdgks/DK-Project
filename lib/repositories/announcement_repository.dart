import 'package:myapp/core/supabase_client.dart';
import 'package:myapp/core/utils/avatar_url_resolver.dart';

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
  /// 각 항목에 poll_votes(user_id, option_index, created_at) 포함. 작성자명·옵션별 투표자 아바타 보강.
  Future<List<Map<String, dynamic>>> fetchPolls() async {
    final res = await _client
        .from('polls')
        .select('*, poll_votes(user_id, option_index, created_at)')
        .order('created_at', ascending: false);
    final list = List<Map<String, dynamic>>.from(res as List);
    await _attachPollAuthorNames(list);
    await _attachOptionVoterAvatars(list);
    return list;
  }

  /// 옵션별 투표자 프로필 사진 목록 보강. 1등 옵션 4명, 2등 3명, 나머지 2명(먼저 투표한 순).
  Future<void> _attachOptionVoterAvatars(List<Map<String, dynamic>> polls) async {
    final allUserIds = <String>{};
    for (final p in polls) {
      final votes = p['poll_votes'];
      if (votes is! List) continue;
      for (final v in votes) {
        if (v is Map && v['user_id'] != null) {
          allUserIds.add(v['user_id'] as String);
        }
      }
    }
    if (allUserIds.isEmpty) return;

    final profiles = await _client
        .from('profiles')
        .select('user_id, avatar_url')
        .inFilter('user_id', allUserIds.toList());
    final profilesList = List<Map<String, dynamic>>.from(profiles as List);
    final avatarByUserId = <String, String?>{};
    for (final pr in profilesList) {
      final uid = pr['user_id'] as String?;
      if (uid != null) {
        avatarByUserId[uid] = resolveAvatarUrl(pr['avatar_url'] as String?);
      }
    }

    for (final p in polls) {
      final options = p['options'] as List<dynamic>?;
      final optionCount = options?.length ?? 0;
      if (optionCount == 0) continue;

      final votesRaw = p['poll_votes'];
      final votes = votesRaw is List
          ? (votesRaw)
              .map((e) => e is Map
                  ? (
                      e['user_id'] as String?,
                      e['option_index'] as int?,
                      e['created_at'] as String?,
                    )
                  : null)
              .whereType<(String, int?, String?)>()
              .where((e) => e.$1.isNotEmpty && e.$2 != null && e.$2! >= 0 && e.$2! < optionCount)
              .toList()
          : <(String, int?, String?)>[];

      final optionCounts = List<int>.filled(optionCount, 0);
      for (final v in votes) {
        final idx = v.$2!;
        if (idx >= 0 && idx < optionCount) optionCounts[idx]++;
      }

      final indicesByCountDesc = List.generate(optionCount, (i) => i)
        ..sort((a, b) => optionCounts[b].compareTo(optionCounts[a]));

      final optionAvatarUrls = List<List<String?>>.generate(
        optionCount,
        (_) => [],
      );

      for (int optionIndex = 0; optionIndex < optionCount; optionIndex++) {
        final votesForOption = votes
            .where((v) => v.$2 == optionIndex)
            .toList()
          ..sort((a, b) => (a.$3 ?? '').compareTo(b.$3 ?? ''));

        final rank = indicesByCountDesc.indexOf(optionIndex);
        final displayCount = rank == 0 ? 4 : rank == 1 ? 3 : 2;
        final take = displayCount.clamp(0, votesForOption.length);
        for (int i = 0; i < take; i++) {
          final uid = votesForOption[i].$1;
          optionAvatarUrls[optionIndex].add(avatarByUserId[uid]);
        }
      }
      p['option_avatar_urls'] = optionAvatarUrls;
    }
  }

  /// 투표에 작성자명(author_name)·프로필 사진(author_avatar_url) 보강.
  /// poll.author_id 우선, 없으면 announcement_id → announcements.author_id 사용.
  /// (announcements.author_id가 없는 DB에서는 poll.author_id만 사용)
  Future<void> _attachPollAuthorNames(List<Map<String, dynamic>> polls) async {
    final profileIds = <String>{};
    for (final p in polls) {
      final aid = p['author_id'] as String?;
      if (aid != null && aid.isNotEmpty) profileIds.add(aid);
    }
    final announcementIds = polls
        .map((p) => p['announcement_id'])
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();
    Map<String, String?>? annToAuthorId;
    if (announcementIds.isNotEmpty) {
      try {
        final ann = await _client
            .from('announcements')
            .select('id, author_id')
            .inFilter('id', announcementIds);
        for (final a in ann as List) {
          final id = (a as Map<String, dynamic>)['author_id'] as String?;
          if (id != null) profileIds.add(id);
        }
        final annList = List<Map<String, dynamic>>.from(ann as List);
        annToAuthorId = {
          for (final a in annList)
            a['id'] as String: a['author_id'] as String?
        };
      } catch (_) {
        // announcements에 author_id 컬럼이 없거나 조회 실패 시 무시
      }
    }
    if (profileIds.isEmpty) return;
    final profiles = await _client
        .from('profiles')
        .select('id, full_name, avatar_url')
        .inFilter('id', profileIds.toList());
    final profilesList = List<Map<String, dynamic>>.from(profiles as List);
    final nameMap = <String, String?>{};
    final avatarMap = <String, String?>{};
    for (final p in profilesList) {
      final id = p['id'] as String?;
      if (id != null) {
        nameMap[id] = p['full_name'] as String?;
        avatarMap[id] = resolveAvatarUrl(p['avatar_url'] as String?);
      }
    }
    for (final p in polls) {
      String? authorProfileId = p['author_id'] as String?;
      if (authorProfileId == null || authorProfileId.isEmpty) {
        final aid = p['announcement_id'] as String?;
        if (aid != null) authorProfileId = annToAuthorId?[aid];
      }
      if (authorProfileId != null) {
        p['author_name'] = nameMap[authorProfileId] ?? '대덕고등학교 학생회';
        p['author_avatar_url'] = avatarMap[authorProfileId];
      }
    }
  }

  /// 사용자의 투표 참여 (Supabase Auth 세션 사용).
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

  /// 사용자가 해당 투표에 참여했는지 및 선택 인덱스 조회 (세션 사용).
  Future<Map<String, dynamic>?> getPollVote(String pollId, String userId) async {
    final res = await _client
        .from('poll_votes')
        .select()
        .eq('poll_id', pollId)
        .eq('user_id', userId)
        .maybeSingle();
    return res;
  }

  // ── Poll likes ─────────────────────────────────────────────────────────

  /// 투표별 좋아요 수 조회 (RPC 사용 → anon/세션 없어도 동작).
  Future<Map<String, int>> getPollLikeCounts(List<String> pollIds) async {
    if (pollIds.isEmpty) return {};
    final res = await _client.rpc(
      'get_poll_like_counts',
      params: {'p_poll_ids': pollIds},
    );
    final map = res as Map<String, dynamic>?;
    if (map == null) return {};
    final counts = <String, int>{};
    for (final id in pollIds) {
      final v = map[id];
      counts[id] = v is int ? v : 0;
    }
    return counts;
  }

  /// 현재 사용자가 해당 투표들을 좋아요 했는지 (poll_id 목록 → 포함 여부).
  Future<Set<String>> getPollIdsLikedByUser(
    List<String> pollIds,
    String userId,
  ) async {
    if (pollIds.isEmpty) return {};
    final res = await _client
        .from('poll_likes')
        .select('poll_id')
        .inFilter('poll_id', pollIds)
        .eq('user_id', userId);
    final list = List<Map<String, dynamic>>.from(res as List);
    return list.map((e) => e['poll_id'] as String).toSet();
  }

  /// 좋아요 토글 (Supabase Auth 세션 사용). 이미 좋아요면 삭제, 아니면 추가. 반환: 현재 좋아요 여부.
  Future<bool> togglePollLike(String pollId, String userId) async {
    final existing = await _client
        .from('poll_likes')
        .select('id')
        .eq('poll_id', pollId)
        .eq('user_id', userId)
        .maybeSingle();
    if (existing != null) {
      await _client
          .from('poll_likes')
          .delete()
          .eq('poll_id', pollId)
          .eq('user_id', userId);
      return false;
    }
    await _client.from('poll_likes').insert({
      'poll_id': pollId,
      'user_id': userId,
    });
    return true;
  }

  // ── Poll comments ───────────────────────────────────────────────────────

  /// 투표 댓글 목록 (created_at 오름차순). 작성자명·프로필 사진 포함. RPC 사용(RLS 무관).
  Future<List<Map<String, dynamic>>> getPollComments(String pollId) async {
    final res = await _client.rpc(
      'get_poll_comments_with_authors',
      params: {'p_poll_id': pollId},
    );
    if (res == null) return [];
    // PostgREST: jsonb 반환 시 값 그대로 옴.
    final list = res is List ? res : <dynamic>[];
    return list
        .map((e) => e is Map ? Map<String, dynamic>.from(e) : <String, dynamic>{})
        .where((m) => m.isNotEmpty)
        .toList();
  }

  /// 투표별 댓글 수 (poll_id 목록 → count 맵).
  Future<Map<String, int>> getPollCommentCounts(List<String> pollIds) async {
    if (pollIds.isEmpty) return {};
    final res = await _client
        .from('poll_comments')
        .select('poll_id')
        .inFilter('poll_id', pollIds);
    final list = List<Map<String, dynamic>>.from(res as List);
    final counts = <String, int>{};
    for (final id in pollIds) {
      counts[id] = list.where((e) => e['poll_id'] == id).length;
    }
    return counts;
  }

  /// 댓글 추가. authorId는 profiles.id (Supabase Auth 세션 있을 때).
  Future<void> addPollComment({
    required String pollId,
    required String authorId,
    required String content,
  }) async {
    await _client.from('poll_comments').insert({
      'poll_id': pollId,
      'author_id': authorId,
      'content': content.trim(),
    });
  }

}
