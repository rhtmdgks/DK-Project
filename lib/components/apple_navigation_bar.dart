import 'package:flutter/cupertino.dart';

/// 큰 제목이 필요하면 상위에서 [CustomScrollView] + [CupertinoSliverNavigationBar]를 사용한다.
class AppleNavigationBar extends StatelessWidget
    implements ObstructingPreferredSizeWidget {
  const AppleNavigationBar({
    super.key,
    required this.title,
    this.leading,
    this.trailing,
    this.transparent = false,
    this.middle,
  });

  final String title;
  final Widget? leading;
  final Widget? trailing;
  /// true면 배경을 더 옅게 쓴다(iOS blur와 유사한 의도; 플랫폼 한계 내).
  final bool transparent;
  final Widget? middle;

  @override
  Widget build(BuildContext context) {
    return CupertinoNavigationBar(
      middle: middle ?? Text(title),
      leading: leading,
      trailing: trailing,
      backgroundColor: transparent
          ? CupertinoColors.systemBackground.resolveFrom(context).withValues(alpha: 0.9)
          : null,
      border: transparent ? null : const Border(bottom: BorderSide.none),
    );
  }

  @override
  Size get preferredSize =>
      const Size.fromHeight(kMinInteractiveDimensionCupertino);

  @override
  bool shouldFullyObstruct(BuildContext context) => !transparent;
}
