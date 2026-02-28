import 'package:flutter/foundation.dart';

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
    } catch (e) {
      _errorPolls = e.toString();
    }
    _loadingPolls = false;
    notifyListeners();
  }

  /// 투표 참여. [userId]는 [AuthRepository.getUserId].
  Future<void> vote(String pollId, String userId, int optionIndex) async {
    await _repo.vote(pollId: pollId, userId: userId, optionIndex: optionIndex);
  }

  /// 이미 투표했는지 및 선택 인덱스 조회.
  Future<Map<String, dynamic>?> getPollVote(String pollId, String userId) async {
    return _repo.getPollVote(pollId, userId);
  }
}
