import 'package:flutter/cupertino.dart';
import 'package:myapp/core/theme/app_theme.dart';

/// 전역 Cupertino 테마. [MaterialApp]과 병행하는 하이브리드 앱용.
/// [brightness]는 Material [ThemeMode]와 동기화해 [AppDesignColors]가 다크모드에서 올바르게 resolve되게 한다.
CupertinoThemeData buildAppCupertinoTheme({Brightness brightness = Brightness.light}) {
  final isDark = brightness == Brightness.dark;
  return CupertinoThemeData(
    primaryColor: AppColors.primaryBlue,
    primaryContrastingColor: AppColors.white,
    barBackgroundColor: isDark ? AppDarkColors.surface : AppColors.white,
    scaffoldBackgroundColor:
        isDark ? AppDarkColors.background : AppColors.background,
    brightness: brightness,
    textTheme: CupertinoTextThemeData(
      primaryColor: AppColors.primaryBlue,
    ),
  );
}
