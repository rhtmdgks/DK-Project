import 'package:flutter/cupertino.dart';
import 'package:myapp/core/theme/app_theme_mode.dart';
import 'package:myapp/repositories/user_preferences_repository.dart';

/// 앱 전역 표시 설정(다크모드·글자 크기) 상태.
///
/// [App]에서 생성해 CupertinoApp의 brightness·textScaler에 주입하고,
/// 설정 화면에서 변경 시 즉시 전체 UI에 반영된다.
class UserPreferencesProvider extends ChangeNotifier {
  UserPreferencesProvider() {
    _load();
  }

  final UserPreferencesRepository _repo = UserPreferencesRepository.instance;

  AppThemeMode _themeMode = AppThemeMode.system;
  double _fontScale = UserPreferencesRepository.defaultFontScale;
  bool _loaded = false;

  AppThemeMode get themeMode => _themeMode;
  double get fontScale => _fontScale;
  bool get loaded => _loaded;

  Future<void> _load() async {
    _themeMode = await _repo.getThemeMode();
    _fontScale = await _repo.getFontScale();
    _loaded = true;
    notifyListeners();
  }

  Future<void> setThemeMode(AppThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();
    await _repo.setThemeMode(mode);
  }

  Future<void> setFontScale(double scale) async {
    if (_fontScale == scale) return;
    _fontScale = scale;
    notifyListeners();
    await _repo.setFontScale(scale);
  }
}
