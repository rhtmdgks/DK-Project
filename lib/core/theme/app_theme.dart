import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:myapp/core/theme/responsive.dart';

/// Figma DK-Project에서 추출한 디자인 토큰.
///
/// 모든 색상과 텍스트 스타일은 이 파일에서 중앙 관리하며,
/// 위젯에서 직접 [Color] / [TextStyle] 리터럴을 사용하지 않도록 한다.
abstract final class AppColors {
  // ── Neutral ──
  static const background = Color(0xFFF8FAFF);
  static const white = Color(0xFFFFFFFF);
  static const border = Color(0xFFEBEFF6);
  static const borderLight = Color(0xFFF6F8FC);
  static const hint = Color(0xFFB4B9C9);
  static const textSecondary = Color(0xFF868DA6);
  static const navInactive = Color(0xFF6D758F);
  static const textPrimary = Color(0xFF353E5C);
  static const textDark = Color(0xFF1A1A1A);

  // ── Brand ──
  static const primaryBlue = Color(0xFF0B66FF);
  static const primaryBlue500 = Color(0xFF3D80FF);
  static const error = Color(0xFFEF4444);

  // ── Timetable / Calendar ──
  static const timetableBg = Color(0xFFD2DDFF);
  static const timetableAccent = Color(0xFFA1B8FF);
  static const timetableHighlight = Color(0xFF3759BD);

  // ── Shadow ──
  static const navShadowOuter = Color(0x296D758F);
  static const navShadowInner = Color(0x146D758F);
  static const cardShadow = Color(0x0D000000);
  static const buttonShadow = Color(0x260B66FF);
}

/// Figma 기반 텍스트 스타일 토큰.
///
/// 모든 스타일은 [fontFamily]로 Paperlogy를 사용한다.
/// 위젯에서 `TextStyle(fontFamily: ...)` 를 직접 쓰지 않도록 한다.
abstract final class AppFonts {
  static const fontFamily = 'Paperlogy';

  // ── Heading ──

  /// heading/1/medium – 32px, w500, 1.2 line-height, -0.5 letter-spacing
  static const heading1Medium = TextStyle(
    fontFamily: fontFamily,
    fontSize: 32,
    fontWeight: FontWeight.w500,
    height: 1.2,
    letterSpacing: -0.5,
    color: AppColors.textPrimary,
  );

  /// heading/2/medium – 28px, w500, 1.25 line-height ("LAON" 타이틀 등)
  static const heading2Medium = TextStyle(
    fontFamily: fontFamily,
    fontSize: 28,
    fontWeight: FontWeight.w500,
    height: 1.25,
    color: AppColors.textPrimary,
  );

  // ── Section Title ──

  /// display/6/medium – 24px, w500, 32px line-height (섹션 제목)
  static const sectionTitle = TextStyle(
    fontFamily: fontFamily,
    fontSize: 24,
    fontWeight: FontWeight.w500,
    height: 32 / 24,
    color: AppColors.textDark,
  );

  // ── Title ──

  /// title/bold – 24px, w700
  static const titleBold = TextStyle(
    fontFamily: fontFamily,
    fontSize: 24,
    fontWeight: FontWeight.w700,
    color: AppColors.textDark,
  );

  /// title/medium – 18px, w500, 24px line-height
  static const titleMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: 18,
    fontWeight: FontWeight.w500,
    height: 24 / 18,
    color: AppColors.textPrimary,
  );

  /// title/semibold – 18px, w600, 24px line-height
  static const titleSemiBold = TextStyle(
    fontFamily: fontFamily,
    fontSize: 18,
    fontWeight: FontWeight.w600,
    height: 24 / 18,
    color: AppColors.textPrimary,
  );

  /// title/regular – 18px, w400
  static const titleRegular = TextStyle(
    fontFamily: fontFamily,
    fontSize: 18,
    fontWeight: FontWeight.w400,
    color: AppColors.textDark,
  );

  // ── Body ──

  /// body/medium – 16px, w500, 1.5 line-height
  static const bodyMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w500,
    height: 1.5,
    color: AppColors.textPrimary,
  );

  /// body/regular – 16px, w400, 1.5 line-height
  static const bodyRegular = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.5,
    color: AppColors.textSecondary,
  );

  // ── Display 3 (Figma display/3) ──

  /// display/3/regular – 16px, w400, 22px line-height
  static const display3Regular = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 22 / 16,
    color: AppColors.navInactive,
  );

  /// display/3/medium – 16px, w500, 22px line-height
  static const display3Medium = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w500,
    height: 22 / 16,
    color: AppColors.textPrimary,
  );

  /// display/3/semibold – 16px, w600, 22px line-height
  static const display3SemiBold = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 22 / 16,
    color: AppColors.background,
  );

  /// display/3/light – 16px, w400 (Light 폰트 미설치 시 Regular fallback), 22px line-height
  static const display3Light = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 22 / 16,
    color: AppColors.background,
  );

  // ── Small ──

  /// small/medium – 14px, w500, 1.4 line-height
  static const smallMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.4,
    color: AppColors.textPrimary,
  );

  /// small/regular – 14px, w400, 1.4 line-height
  static const smallRegular = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.4,
    color: AppColors.textSecondary,
  );

  // ── Caption / Display ──

  /// caption/medium – 13px, w500
  static const captionMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: AppColors.textSecondary,
  );

  /// caption/regular – 13px, w400
  static const captionRegular = TextStyle(
    fontFamily: fontFamily,
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
  );

  /// display/regular – 12px, w400, 18px line-height
  static const displayRegular = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 18 / 12,
    color: AppColors.navInactive,
  );

  /// display/semibold – 12px, w600, 18px line-height
  static const displaySemiBold = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w600,
    height: 18 / 12,
    color: AppColors.primaryBlue,
  );

  /// tiny – 10px, w400
  static const tiny = TextStyle(
    fontFamily: fontFamily,
    fontSize: 10,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
  );

  /// [style]의 fontSize를 화면 너비에 비례하여 스케일링한다.
  ///
  /// 기본 TextStyle 상수는 375pt 기준이므로,
  /// 넓은 화면에서는 약간 커지고 좁은 화면에서는 약간 작아진다.
  ///
  /// ```dart
  /// Text('제목', style: AppFonts.scaled(context, AppFonts.titleBold));
  /// ```
  static TextStyle scaled(BuildContext context, TextStyle style) {
    final scaledSize = context.rs(style.fontSize ?? 14);
    return style.copyWith(fontSize: scaledSize);
  }
}

/// 앱 전역 [ThemeData]. [MaterialApp]의 `theme`에 전달한다.
/// textTheme에 decoration: none을 명시해 Material 미제공 구간에서도 노란 밑줄이 나오지 않게 한다.
ThemeData buildAppTheme() {
  const noUnderline = TextStyle(decoration: TextDecoration.none);
  return ThemeData(
    fontFamily: AppFonts.fontFamily,
    scaffoldBackgroundColor: AppColors.background,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primaryBlue,
      surface: AppColors.background,
    ),
    textTheme: TextTheme(
      displayLarge: noUnderline,
      displayMedium: noUnderline,
      displaySmall: noUnderline,
      headlineLarge: noUnderline,
      headlineMedium: noUnderline,
      headlineSmall: noUnderline,
      titleLarge: noUnderline,
      titleMedium: noUnderline,
      titleSmall: noUnderline,
      bodyLarge: noUnderline,
      bodyMedium: noUnderline,
      bodySmall: noUnderline,
      labelLarge: noUnderline,
      labelMedium: noUnderline,
      labelSmall: noUnderline,
    ),
  );
}

/// Cupertino 전역 테마. 화이트·블루 유지, iOS 스타일 적용.
CupertinoThemeData buildCupertinoTheme() {
  return CupertinoThemeData(
    primaryColor: AppColors.primaryBlue,
    primaryContrastingColor: AppColors.white,
    barBackgroundColor: AppColors.white,
    scaffoldBackgroundColor: AppColors.background,
    brightness: Brightness.light,
  );
}
