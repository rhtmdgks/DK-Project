import 'package:flutter/cupertino.dart';
import 'package:myapp/core/theme/app_theme.dart';
import 'package:myapp/design/app_colors.dart';

/// 디자인 시스템 공용 타이포그래피.
/// 기존 앱 기본 폰트([AppFonts.fontFamily])를 유지하면서 iOS 계층 크기만 맞춘다.
abstract final class AppTypography {
  AppTypography._();

  static TextStyle _base(
    BuildContext context, {
    required double size,
    required FontWeight weight,
    Color? color,
    double? letterSpacing,
  }) {
    return AppFonts.scaled(
      context,
      TextStyle(
        fontFamily: AppFonts.fontFamily,
        fontSize: size,
        fontWeight: weight,
        color: color ?? AppDesignColors.label(context),
        letterSpacing: letterSpacing,
      ),
    );
  }

  static TextStyle largeTitle(BuildContext context) =>
      _base(context, size: 34, weight: FontWeight.w700, letterSpacing: 0.37);

  static TextStyle title1(BuildContext context) =>
      _base(context, size: 28, weight: FontWeight.w600, letterSpacing: 0.36);

  static TextStyle title2(BuildContext context) =>
      _base(context, size: 22, weight: FontWeight.w600, letterSpacing: 0.35);

  static TextStyle title3(BuildContext context) =>
      _base(context, size: 20, weight: FontWeight.w600, letterSpacing: 0.38);

  static TextStyle headline(BuildContext context) =>
      _base(context, size: 17, weight: FontWeight.w600);

  static TextStyle body(BuildContext context) =>
      _base(context, size: 17, weight: FontWeight.w400);

  static TextStyle callout(BuildContext context) =>
      _base(context, size: 16, weight: FontWeight.w400, letterSpacing: -0.2);

  static TextStyle subheadline(BuildContext context) => _base(
        context,
        size: 15,
        weight: FontWeight.w400,
        color: AppDesignColors.secondaryLabel(context),
      );

  static TextStyle footnote(BuildContext context) => _base(
        context,
        size: 13,
        weight: FontWeight.w400,
        color: AppDesignColors.secondaryLabel(context),
      );

  static TextStyle caption(BuildContext context) => _base(
        context,
        size: 12,
        weight: FontWeight.w400,
        color: AppDesignColors.secondaryLabel(context),
      );
}
