import 'package:flutter/cupertino.dart';
import 'package:myapp/core/theme/app_theme.dart';

/// Cupertino 밝기 기준 시맨틱 색. Material [ColorScheme]/[Theme.of] 대체.
class AppResolvedColors {
  const AppResolvedColors({
    required this.brightness,
    required this.background,
    required this.surface,
    required this.surfaceContainerHighest,
    required this.onSurface,
    required this.onSurfaceVariant,
    required this.primary,
    required this.primaryContainer,
    required this.shadow,
    required this.border,
  });

  final Brightness brightness;
  final Color background;
  final Color surface;
  final Color surfaceContainerHighest;
  final Color onSurface;
  final Color onSurfaceVariant;
  final Color primary;
  final Color primaryContainer;
  final Color shadow;
  final Color border;

  bool get isDark => brightness == Brightness.dark;

  static AppResolvedColors of(BuildContext context) {
    final brightness =
        CupertinoTheme.of(context).brightness ?? Brightness.light;
    if (brightness == Brightness.dark) {
      return const AppResolvedColors(
        brightness: Brightness.dark,
        background: AppDarkColors.background,
        surface: AppDarkColors.surface,
        surfaceContainerHighest: AppDarkColors.surfaceHigh,
        onSurface: AppDarkColors.textPrimary,
        onSurfaceVariant: AppDarkColors.textSecondary,
        primary: AppColors.primaryBlue,
        primaryContainer: Color(0xFF1A3A6E),
        shadow: Color(0xFF000000),
        border: AppDarkColors.border,
      );
    }
    return const AppResolvedColors(
      brightness: Brightness.light,
      background: AppColors.background,
      surface: AppColors.white,
      surfaceContainerHighest: AppColors.surfaceContainerHighest,
      onSurface: AppColors.textPrimary,
      onSurfaceVariant: AppColors.textSecondary,
      primary: AppColors.primaryBlue,
      primaryContainer: AppColors.timetableBg,
      shadow: Color(0xFF000000),
      border: AppColors.border,
    );
  }
}

extension AppResolvedColorsX on BuildContext {
  AppResolvedColors get appColors => AppResolvedColors.of(this);
  Brightness get appBrightness => appColors.brightness;
  bool get isAppDark => appColors.isDark;
}
