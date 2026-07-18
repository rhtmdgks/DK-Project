import 'package:myapp/core/theme/app_theme_mode.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 사용자 표시 설정(테마·글자 크기)의 단일 저장소.
///
/// [NotificationSettingsRepository]와 동일하게 SharedPreferences를 사용하며,
/// 앱 전역 테마는 [UserPreferencesProvider]가 이 Repository를 통해 로드/저장한다.
class UserPreferencesRepository {
  UserPreferencesRepository._();

  static final UserPreferencesRepository instance =
      UserPreferencesRepository._();

  static const String keyThemeMode = 'pref_theme_mode';
  static const String keyFontScale = 'pref_font_scale';

  /// 글자 크기 단계. 값은 TextScaler 배율.
  static const List<double> fontScaleSteps = [0.9, 1.0, 1.15, 1.3];
  static const double defaultFontScale = 1.0;

  Future<SharedPreferences> _prefs() => SharedPreferences.getInstance();

  Future<AppThemeMode> getThemeMode() async {
    final raw = (await _prefs()).getString(keyThemeMode);
    return AppThemeMode.fromStorage(raw);
  }

  Future<void> setThemeMode(AppThemeMode mode) async {
    await (await _prefs()).setString(keyThemeMode, mode.storageValue);
  }

  Future<double> getFontScale() async {
    final v = (await _prefs()).getDouble(keyFontScale) ?? defaultFontScale;
    // 저장된 값이 허용 단계 밖이면 기본값으로 보정.
    if (!fontScaleSteps.contains(v)) return defaultFontScale;
    return v;
  }

  Future<void> setFontScale(double scale) async {
    await (await _prefs()).setDouble(keyFontScale, scale);
  }
}
