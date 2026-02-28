import 'package:flutter/foundation.dart';

import 'package:myapp/core/auth/auth_repository.dart';

/// 로그인 화면의 제출 결과 상태.
/// 실제 RPC/네트워크/DNS 폴백은 화면 또는 별도 서비스에서 수행하고,
/// 성공 시 [AuthRepository.setLoggedIn]만 ViewModel에서 호출할 수 있도록 분리한다.
class LoginViewModel extends ChangeNotifier {
  bool _loading = false;
  String? _error;

  bool get loading => _loading;
  String? get error => _error;

  void setLoading(bool value) {
    _loading = value;
    notifyListeners();
  }

  void setError(String? value) {
    _error = value;
    notifyListeners();
  }

  /// RPC 로그인 성공 후 호출. SharedPreferences에 로그인 상태 저장.
  Future<void> setLoggedIn(String userId) async {
    await AuthRepository.instance.setLoggedIn(userId);
  }

  /// 로그인 성공 시 상태 초기화 (에러 제거 등).
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
