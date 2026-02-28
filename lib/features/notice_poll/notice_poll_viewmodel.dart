import 'package:flutter/foundation.dart';

import 'package:myapp/core/auth/auth_repository.dart';
import 'package:myapp/repositories/announcement_repository.dart';

/// 공지/투표 탭의 상태 및 데이터 로딩 담당.
/// UI는 이 ViewModel만 바라보고, Supabase는 [AnnouncementRepository]를 통해서만 접근한다.
class NoticePollViewModel extends ChangeNotifier {
  NoticePollViewModel({AnnouncementRepository? repository})
      : _repo = repository ?? AnnouncementRepository();

  final AnnouncementRepository _repo;

  List<Map<String, dynamic>> _announcements = [];
  List<Map<String, dynamic>> _polls = [];
  bool _loadingAnnouncements = false;
  bool _loadingPolls = false;
  String? _errorAnnouncements;
  String? _errorPolls;

  List<Map<String, dynamic>> get announcements => _announcements;
  List<Map<String, dynamic>> get polls => _polls;
  bool get loadingAnnouncements => _loadingAnnouncements;
  bool get loadingPolls => _loadingPolls;
  String? get errorAnnouncements => _errorAnnouncements;
  String? get errorPolls => _errorPolls;

  Future<void> fetchAnnouncements() async {
    _loadingAnnouncements = true;
    _errorAnnouncements = null;
    notifyListeners();

    try {
      _announcements = await _repo.fetchAnnouncements();
      _errorAnnouncements = null;
    } catch (e) {
      _errorAnnouncements = e.toString();
    }
    _loadingAnnouncements = false;
    notifyListeners();
  }

  Future<void> fetchPolls() async {
    _loadingPolls = true;
    _errorPolls = null;
    notifyListeners();

    try {
      _polls = await _repo.fetchPolls();
      _errorPolls = null;
      final ids = _polls.map((p) => p['id'] as String?).whereType<String>().toList();
      if (ids.isNotEmpty) {
        final likeCounts = await _repo.getPollLikeCounts(ids);
        final commentCounts = await _repo.getPollCommentCounts(ids);
        final uid = await AuthRepository.instance.getUserId();
        final token = await AuthRepository.instance.getSessionToken();
        final Set<String> liked;
        if (token != null) {
          liked = (await _repo.getPollLikesByToken(token)).intersection(ids.toSet());
        } else if (uid != null) {
          liked = await _repo.getPollIdsLikedByUser(ids, uid);
        } else {
          liked = <String>{};
        }
        for (final p in _polls) {
          final id = p['id'] as String?;
          if (id == null) continue;
          p['like_count'] = likeCounts[id] ?? 0;
          p['comment_count'] = commentCounts[id] ?? 0;
          p['user_has_liked'] = liked.contains(id);
        }
      }
    } catch (e) {
      _errorPolls = e.toString();
    }
    _loadingPolls = false;
    notifyListeners();
  }

  /// 투표 참여. session_token 우선, 없으면 Auth uid 사용.
  Future<void> vote(String pollId, int optionIndex) async {
    final token = await AuthRepository.instance.getSessionToken();
    final uid = await AuthRepository.instance.getUserId();
    if (token != null) {
      await _repo.voteByToken(pollId: pollId, sessionToken: token, optionIndex: optionIndex);
      return;
    }
    if (uid != null) {
      await _repo.vote(pollId: pollId, userId: uid, optionIndex: optionIndex);
      return;
    }
    throw Exception('로그인이 필요해요.');
  }

  /// 이미 투표했는지 및 선택 인덱스 조회. session_token 우선.
  Future<Map<String, dynamic>?> getPollVote(String pollId) async {
    final token = await AuthRepository.instance.getSessionToken();
    final uid = await AuthRepository.instance.getUserId();
    if (token != null) {
      return _repo.getPollVoteByToken(pollId, token);
    }
    if (uid != null) {
      return _repo.getPollVote(pollId, uid);
    }
    return null;
  }

  /// 좋아요 토글. session_token 또는 Auth uid 사용. 반환: true/false = 성공(좋아요 여부), null = 로그인 필요.
  /// 성공 시 해당 투표만 로컬에서 갱신(하트·숫자만 바뀌고 목록 새로고침 없음).
  Future<bool?> togglePollLike(String pollId) async {
    final token = await AuthRepository.instance.getSessionToken();
    final uid = await AuthRepository.instance.getUserId();
    bool? liked;
    if (token != null) {
      liked = await _repo.togglePollLikeByToken(pollId, token);
    } else if (uid != null) {
      liked = await _repo.togglePollLike(pollId, uid);
    } else {
      return null;
    }
    final i = _polls.indexWhere((p) => p['id'] == pollId);
    if (i >= 0) {
      final p = _polls[i];
      p['user_has_liked'] = liked;
      p['like_count'] = ((p['like_count'] as int?) ?? 0) + (liked ? 1 : -1);
      notifyListeners();
    }
    return liked;
  }

  /// 투표 댓글 목록.
  Future<List<Map<String, dynamic>>> getPollComments(String pollId) async {
    return _repo.getPollComments(pollId);
  }

  /// 댓글 작성. session_token 있으면 RPC 사용(RLS 통과), 없으면 프로필로 직접 insert. 둘 다 없으면 예외.
  Future<void> addPollComment({
    required String pollId,
    required String content,
  }) async {
    final token = await AuthRepository.instance.getSessionToken();
    if (token != null) {
      await _repo.addPollCommentByToken(pollId: pollId, sessionToken: token, content: content);
      return;
    }
    final profile = await AuthRepository.instance.getCurrentProfile();
    if (profile != null) {
      await _repo.addPollComment(pollId: pollId, authorId: profile.id, content: content);
      return;
    }
    throw Exception('로그인이 필요해요.');
  }
}
