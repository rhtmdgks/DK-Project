import 'package:flutter/material.dart';

/// Material 3 Small App Bar 스타일의 탭 제목 헤더.
///
/// 기본 높이 64dp를 *최소* 기준으로 두되, 글자 크기(TextScaler)가 커지면
/// 세로로 늘어나 overflow 없이 표시한다.
class TabPageHeader extends StatelessWidget {
  const TabPageHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.leading,
    this.trailing,
    this.contentPadding,
  });

  final String title;
  final String subtitle;
  /// 탭 루트가 아닌 푸시된 화면 등에서 뒤로가기 버튼을 넣을 때 사용.
  final Widget? leading;
  final Widget? trailing;

  /// null이면 기본 좌우 패딩(16), 지정 시 해당 값 사용(예: [EdgeInsets.zero]로 끝에 붙이기).
  final EdgeInsets? contentPadding;

  static const double _minVerticalPadding = 12;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final resolvedPadding = contentPadding ??
        EdgeInsets.only(
          left: leading != null ? 4 : 16,
          right: trailing != null ? 8 : 16,
          top: _minVerticalPadding,
          bottom: _minVerticalPadding,
        );

    return Padding(
      padding: resolvedPadding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (leading != null) ...[
            leading!,
            const SizedBox(width: 4),
          ],
          Expanded(
            child: Column(
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
                const SizedBox(height: 4),
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
            const SizedBox(width: 8),
            trailing!,
          ],
        ],
      ),
    );
  }
}
