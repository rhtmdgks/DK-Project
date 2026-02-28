import 'package:flutter/foundation.dart';

import 'package:myapp/core/auth/auth_state.dart';
import 'package:myapp/repositories/suggestions_repository.dart';

/// 건의함 탭의 상태 및 데이터 로딩/등록/채팅 담당.
class SuggestionsViewModel extends ChangeNotifier {
  SuggestionsViewModel({SuggestionsRepository? repository})
      : _repo = repository ?? SuggestionsRepository();

  final SuggestionsRepository _repo;

  List<Map<String, dynamic>> _list = [];
  bool _loading = false;
  String? _error;
  AppProfile? _profile;

  List<Map<String, dynamic>> get list => _list;
  bool get loading => _loading;
  String? get error => _error;
  AppProfile? get profile => _profile;

  Future<void> loadProfile() async {
    _profile = await getCurrentProfile();
    notifyListeners();
  }

  Future<void> fetch() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _list = await _repo.fetchSuggestions();
      _error = null;
    } catch (e) {
      _error = e.toString();
    }
    _loading = false;
    notifyListeners();
  }

  Future<void> addSuggestion({
    required String authorId,
    required String title,
    String? body,
  }) async {
    await _repo.addSuggestion(authorId: authorId, title: title, body: body);
    await fetch();
  }

  /// 1:1 채팅방 생성 또는 조회. 반환: RPC 결과 맵 (room id 등).
  Future<Map<String, dynamic>> createOrGetDirectChat({
    required String otherUserId,
    required String userId,
  }) async {
    return _repo.createOrGetDirectChat(
      otherUserId: otherUserId,
      userId: userId,
    );
  }

  Future<Map<String, dynamic>?> fetchAdminProfile() async {
    return _repo.fetchProfileByRole('admin');
  }
}
