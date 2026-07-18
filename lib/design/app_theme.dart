import 'package:flutter/cupertino.dart';
import 'package:myapp/core/theme/app_theme.dart';

/// 전역 Cupertino 테마. Paperlogy + [AppColors] 브랜드 토큰.
CupertinoThemeData buildAppCupertinoTheme({Brightness brightness = Brightness.light}) {
  final isDark = brightness == Brightness.dark;
  final label = isDark ? AppDarkColors.textPrimary : AppColors.textPrimary;
  final secondary = isDark ? AppDarkColors.textSecondary : AppColors.textSecondary;
  return CupertinoThemeData(
    primaryColor: AppColors.primaryBlue,
    primaryContrastingColor: AppColors.white,
    barBackgroundColor: isDark ? AppDarkColors.surface : AppColors.white,
    scaffoldBackgroundColor:
        isDark ? AppDarkColors.background : AppColors.background,
    brightness: brightness,
    textTheme: CupertinoTextThemeData(
      primaryColor: AppColors.primaryBlue,
      textStyle: TextStyle(
        fontFamily: AppFonts.fontFamily,
        fontSize: 17,
        fontWeight: FontWeight.w400,
        color: label,
      ),
      actionTextStyle: TextStyle(
        fontFamily: AppFonts.fontFamily,
        fontSize: 17,
        fontWeight: FontWeight.w400,
        color: AppColors.primaryBlue,
      ),
      navTitleTextStyle: TextStyle(
        fontFamily: AppFonts.fontFamily,
        fontSize: 17,
        fontWeight: FontWeight.w600,
        color: label,
      ),
      navLargeTitleTextStyle: TextStyle(
        fontFamily: AppFonts.fontFamily,
        fontSize: 34,
        fontWeight: FontWeight.w700,
        color: label,
      ),
      navActionTextStyle: TextStyle(
        fontFamily: AppFonts.fontFamily,
        fontSize: 17,
        fontWeight: FontWeight.w400,
        color: AppColors.primaryBlue,
      ),
      tabLabelTextStyle: TextStyle(
        fontFamily: AppFonts.fontFamily,
        fontSize: 10,
        fontWeight: FontWeight.w500,
        color: secondary,
      ),
      dateTimePickerTextStyle: TextStyle(
        fontFamily: AppFonts.fontFamily,
        fontSize: 21,
        fontWeight: FontWeight.w400,
        color: label,
      ),
      pickerTextStyle: TextStyle(
        fontFamily: AppFonts.fontFamily,
        fontSize: 21,
        fontWeight: FontWeight.w400,
        color: label,
      ),
    ),
  );
}
