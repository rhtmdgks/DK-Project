import 'package:flutter/material.dart';
import 'package:myapp/core/theme/app_theme.dart';
import 'package:myapp/core/theme/responsive.dart';

/// Material 3 Small App Bar 스타일의 탭 제목 헤더.
///
/// Material 3 Small App Bar 스펙에 따라 구현:
/// - 높이: 64dp
/// - 좌측 패딩: 16dp
/// - 우측 패딩: 16dp (액션이 있으면 8dp)
/// - 제목: headlineSmall (24sp, w400)
/// - 서브타이틀: bodyMedium (16sp, w400)
/// - Material 3 elevation과 색상 시스템 사용
class TabPageHeader extends StatelessWidget {
  const TabPageHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.contentPadding,
  });

  final String title;
  final String subtitle;
  final Widget? trailing;

  /// null이면 기본 좌우 패딩(16), 지정 시 해당 값 사용(예: [EdgeInsets.zero]로 끝에 붙이기).
  final EdgeInsets? contentPadding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    // Material 3 Small App Bar 높이: 64dp
    const double appBarHeight = 64.0;
    final resolvedPadding = contentPadding ?? EdgeInsets.only(
      left: 16,
      right: trailing != null ? 8 : 16,
    );

    return Container(
      height: appBarHeight,
      padding: resolvedPadding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0,
                    height: 1.2,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  subtitle,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    height: 1.5,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) ...[
            SizedBox(width: 8),
            trailing!,
          ],
        ],
      ),
    );
  }
}
