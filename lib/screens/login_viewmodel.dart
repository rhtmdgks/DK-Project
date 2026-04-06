import 'package:flutter/foundation.dart';

/// 로그인 화면의 제출 결과 상태.
/// 실제 인증은 Supabase Auth 세션을 사용하며,
/// ViewModel은 로딩/에러 상태만 관리한다.
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

  /// 로그인 성공 시 상태 초기화 (에러 제거 등).
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
