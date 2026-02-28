import 'package:shared_preferences/shared_preferences.dart';

/// 알림 설정(토글)의 단일 저장소.
///
/// 모든 `setting_*` 및 날씨 알림 키의 소유권을 가지며,
/// [NotificationService]와 개별 알림 서비스는 이 Repository를 통해서만 설정을 읽고 쓴다.
class NotificationSettingsRepository {
  NotificationSettingsRepository._();

  static final NotificationSettingsRepository instance =
      NotificationSettingsRepository._();

  static const String keyMeal = 'setting_meal';
  static const String keySchedule = 'setting_schedule';
  static const String keyClassMove = 'setting_class_move';
  static const String keyNotice = 'setting_notice';
  static const String keyWeather = 'weather_notification_enabled';

  Future<SharedPreferences> _prefs() => SharedPreferences.getInstance();

  Future<bool> getMealEnabled() async =>
      (await _prefs()).getBool(keyMeal) ?? false;

  Future<void> setMealEnabled(bool value) async =>
      (await _prefs()).setBool(keyMeal, value);

  Future<bool> getScheduleEnabled() async =>
      (await _prefs()).getBool(keySchedule) ?? false;

  Future<void> setScheduleEnabled(bool value) async =>
      (await _prefs()).setBool(keySchedule, value);

  Future<bool> getClassMoveEnabled() async =>
      (await _prefs()).getBool(keyClassMove) ?? false;

  Future<void> setClassMoveEnabled(bool value) async =>
      (await _prefs()).setBool(keyClassMove, value);

  Future<bool> getNoticeEnabled() async =>
      (await _prefs()).getBool(keyNotice) ?? false;

  Future<void> setNoticeEnabled(bool value) async =>
      (await _prefs()).setBool(keyNotice, value);

  Future<bool> getWeatherEnabled() async =>
      (await _prefs()).getBool(keyWeather) ?? false;

  Future<void> setWeatherEnabled(bool value) async =>
      (await _prefs()).setBool(keyWeather, value);

  /// 설정 키로 조회 (SettingsScreen 등에서 키 기반 루프 시 사용).
  Future<bool> getByKey(String key) async {
    final prefs = await _prefs();
    if (key == 'weather') return prefs.getBool(keyWeather) ?? false;
    return prefs.getBool('setting_$key') ?? false;
  }

  /// 설정 키로 저장. [key]는 'meal', 'schedule', 'class_move', 'notice', 'weather' 중 하나.
  Future<void> setByKey(String key, bool value) async {
    final prefs = await _prefs();
    if (key == 'weather') {
      await prefs.setBool(keyWeather, value);
    } else {
      await prefs.setBool('setting_$key', value);
    }
  }
}
