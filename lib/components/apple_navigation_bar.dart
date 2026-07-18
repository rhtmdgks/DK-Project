import 'package:flutter/cupertino.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:myapp/core/theme/app_resolved_colors.dart';

/// GlassAppBar 기반 네비게이션 바 어댑터.
class AppleNavigationBar extends StatelessWidget
    implements PreferredSizeWidget {
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
  final bool transparent;
  final Widget? middle;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return GlassAppBar(
      centerTitle: true,
      backgroundColor: transparent
          ? colors.surface.withValues(alpha: 0.72)
          : colors.surface,
      title: middle ?? Text(title),
      leading: leading,
      actions: trailing != null ? [trailing!] : null,
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(44);
}
