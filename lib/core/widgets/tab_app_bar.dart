import 'package:flutter/cupertino.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:myapp/core/theme/app_resolved_colors.dart';
import 'package:myapp/core/theme/app_theme.dart';

/// 탭용 Glass 앱바.
///
/// [CupertinoNavigationBar]는 라우트가 아닌 [IndexedStack] 탭에서
/// transitionBetweenRoutes가 false로 고정되어 heroTag 사용 시 assert가 발생하므로,
/// 홈 내 탭(일정/건의함/공지·투표)에서는 이 위젯을 사용한다.
class TabAppBar extends StatelessWidget implements PreferredSizeWidget {
  const TabAppBar({
    super.key,
    required this.title,
    this.trailing,
    this.leading,
  });

  final String title;
  final Widget? trailing;
  final Widget? leading;

  @override
  Size get preferredSize => const Size.fromHeight(44);

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return GlassAppBar(
      centerTitle: true,
      backgroundColor: colors.surface.withValues(alpha: 0.72),
      title: Text(
        title,
        style: AppFonts.titleSemiBold.copyWith(color: colors.onSurface),
      ),
      leading: leading,
      actions: trailing != null ? [trailing!] : null,
    );
  }
}
