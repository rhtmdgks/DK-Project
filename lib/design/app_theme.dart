import 'package:flutter/cupertino.dart';
import 'package:myapp/core/theme/app_theme.dart';

/// 전역 Cupertino 테마. [MaterialApp]과 병행하는 하이브리드 앱용.
CupertinoThemeData buildAppCupertinoTheme() {
  return CupertinoThemeData(
    primaryColor: AppColors.primaryBlue,
    primaryContrastingColor: AppColors.white,
    barBackgroundColor: AppColors.white,
    scaffoldBackgroundColor: AppColors.background,
    brightness: Brightness.light,
    textTheme: CupertinoTextThemeData(
      primaryColor: AppColors.primaryBlue,
    ),
  );
}
