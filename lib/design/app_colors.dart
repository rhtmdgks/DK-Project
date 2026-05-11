import 'package:flutter/cupertino.dart';
import 'package:myapp/core/theme/app_theme.dart';

/// 시맨틱 색상 토큰. 가능한 한 [CupertinoColors]의 `resolveFrom`으로 라이트/다크를 따른다.
/// 브랜드 강조는 [AppColors]와 정렬한다.
abstract final class AppDesignColors {
  AppDesignColors._();

  static Color background(BuildContext context) =>
      CupertinoColors.systemBackground.resolveFrom(context);

  static Color groupedBackground(BuildContext context) =>
      CupertinoColors.systemGroupedBackground.resolveFrom(context);

  static Color surface(BuildContext context) =>
      CupertinoColors.secondarySystemGroupedBackground.resolveFrom(context);

  static Color elevatedSurface(BuildContext context) =>
      CupertinoColors.systemBackground.resolveFrom(context);

  /// 앱 브랜드 주요 액션 색.
  static Color primary(BuildContext context) => AppColors.primaryBlue;

  /// 보조 강조 (링크·보조 버튼 등).
  static Color secondary(BuildContext context) => AppColors.primaryBlue500;

  static Color label(BuildContext context) =>
      CupertinoColors.label.resolveFrom(context);

  static Color secondaryLabel(BuildContext context) =>
      CupertinoColors.secondaryLabel.resolveFrom(context);

  static Color tertiaryLabel(BuildContext context) =>
      CupertinoColors.tertiaryLabel.resolveFrom(context);

  static Color separator(BuildContext context) =>
      CupertinoColors.separator.resolveFrom(context);

  static Color destructive(BuildContext context) =>
      CupertinoColors.destructiveRed.resolveFrom(context);

  static Color success(BuildContext context) => AppColors.success;

  /// 경고 (시스템 오렌지에 가깝게; 고정값은 라이트 기준).
  static Color warning(BuildContext context) =>
      CupertinoColors.systemOrange.resolveFrom(context);
}
