import 'package:flutter/cupertino.dart';
import 'package:myapp/core/theme/responsive.dart';
import 'package:myapp/design/app_theme.dart' as app_design;

/// Figma DK-Project에서 추출한 디자인 토큰.
///
/// 모든 색상과 텍스트 스타일은 이 파일에서 중앙 관리하며,
/// 위젯에서 직접 [Color] / [TextStyle] 리터럴을 사용하지 않도록 한다.
abstract final class AppColors {
  // ── Neutral ──
  static const background = Color(0xFFF8FAFF); // Figma Neutral/200 #f8faff
  static const white = Color(0xFFFFFFFF);
  static const border = Color(0xFFEBEFF6); // Figma Neutral Colors/300 #ebeff6
  static const borderLight = Color(0xFFF6F8FC);
  static const hint = Color(0xFFB4B9C9); // Figma Neutral/500 #b4b9c9
  static const textSecondary = Color(0xFF868DA6);
  static const navInactive = Color(0xFF6D758F); // Figma Neutral/600 #6d758f
  static const textPrimary = Color(0xFF353E5C); // Figma Neutral/700 #353e5c
  static const textDark = Color(0xFF1A1A1A);
  /// Figma Neutral/800 #19213d (약관 등 온보딩 화면 제목·본문 진한 글자)
  static const textDarkFigma = Color(0xFF19213D);

  // ── Brand ──
  static const primaryBlue = Color(0xFF0B66FF);
  static const primaryBlue500 = Color(0xFF3D80FF);
  /// 연한 파란 테두리 (약관 전체동의 박스 등). Figma 스크린 기준 #AECBFF 유사.
  static const primaryBlueLight = Color(0xFFAECBFF);
  static const error = Color(0xFFEF4444);
  /// 성공/활성화 SnackBar 등 (직관적 피드백용)
  static const success = Color(0xFF22C55E);

  // ── Timetable / Calendar ──
  static const timetableBg = Color(0xFFD2DDFF);
  static const timetableAccent = Color(0xFFA1B8FF);
  static const timetableHighlight = Color(0xFF3759BD);

  // ── Shadow ──
  static const navShadowOuter = Color(0x296D758F);
  static const navShadowInner = Color(0x146D758F);
  static const cardShadow = Color(0x0D000000);
  static const buttonShadow = Color(0x260B66FF);

  /// M3 surface 계층 (카드/컨테이너 강조용). 기존 white 대신 사용 권장.
  static const surfaceContainerLowest = Color(0xFFF8FAFF);
  static const surfaceContainerLow = Color(0xFFF2F5FA);
  static const surfaceContainer = Color(0xFFECF0F7);
  static const surfaceContainerHigh = Color(0xFFE6EBF4);
  static const surfaceContainerHighest = Color(0xFFE0E6F0);
}

/// Material 3 Shape 스케일 (트렌디한 큰 라운드).
abstract final class AppShapes {
  AppShapes._();

  static const double radiusExtraSmall = 4;
  static const double radiusSmall = 12;
  static const double radiusMedium = 16;
  static const double radiusLarge = 20;
  static const double radiusExtraLarge = 28;

  static BorderRadius get borderRadiusExtraSmall =>
      BorderRadius.circular(radiusExtraSmall);
  static BorderRadius get borderRadiusSmall =>
      BorderRadius.circular(radiusSmall);
  static BorderRadius get borderRadiusMedium =>
      BorderRadius.circular(radiusMedium);
  static BorderRadius get borderRadiusLarge =>
      BorderRadius.circular(radiusLarge);
  static BorderRadius get borderRadiusExtraLarge =>
      BorderRadius.circular(radiusExtraLarge);
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
    return themed(context, style.copyWith(fontSize: scaledSize));
  }

  /// 라이트 전용 [AppColors] 텍스트 색을 다크 모드에서 읽을 수 있는 색으로 치환한다.
  /// 브랜드/온-컬러(white, primaryBlue 등)는 그대로 둔다.
  static TextStyle themed(BuildContext context, TextStyle style) {
    final brightness =
        CupertinoTheme.of(context).brightness ?? Brightness.light;
    if (brightness == Brightness.light) return style;
    final c = style.color;
    if (c == null) {
      return style.copyWith(color: AppDarkColors.textPrimary);
    }
    if (c == AppColors.textPrimary ||
        c == AppColors.textDark ||
        c == AppColors.textDarkFigma) {
      return style.copyWith(color: AppDarkColors.textPrimary);
    }
    if (c == AppColors.textSecondary ||
        c == AppColors.navInactive ||
        c == AppColors.hint) {
      return style.copyWith(color: AppDarkColors.textSecondary);
    }
    return style;
  }
}

/// 다크 모드용 색상 토큰. 라이트 [AppColors]와 짝을 이룬다.
abstract final class AppDarkColors {
  static const background = Color(0xFF12151F);
  static const surface = Color(0xFF1A1E2B);
  static const surfaceHigh = Color(0xFF232838);
  static const border = Color(0xFF2E3446);
  static const textPrimary = Color(0xFFDDE2F0);
  static const textSecondary = Color(0xFF9AA1B8);
}

/// Cupertino 전역 테마. [app_design.buildAppCupertinoTheme]에 위임.
CupertinoThemeData buildCupertinoTheme({Brightness brightness = Brightness.light}) =>
    app_design.buildAppCupertinoTheme(brightness: brightness);
