import 'package:flutter/cupertino.dart';

/// 앱 로컬 테마 모드. Material [ThemeMode] 의존을 제거한다.
enum AppThemeMode {
  system,
  light,
  dark;

  Brightness resolve(Brightness platformBrightness) => switch (this) {
        AppThemeMode.dark => Brightness.dark,
        AppThemeMode.light => Brightness.light,
        AppThemeMode.system => platformBrightness,
      };

  String get storageValue => switch (this) {
        AppThemeMode.light => 'light',
        AppThemeMode.dark => 'dark',
        AppThemeMode.system => 'system',
      };

  static AppThemeMode fromStorage(String? raw) => switch (raw) {
        'light' => AppThemeMode.light,
        'dark' => AppThemeMode.dark,
        _ => AppThemeMode.system,
      };
}
