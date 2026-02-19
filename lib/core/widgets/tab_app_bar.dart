import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:myapp/core/theme/app_theme.dart';

/// Hero를 사용하지 않는 탭용 앱바.
///
/// [CupertinoNavigationBar]는 라우트가 아닌 [IndexedStack] 탭에서
/// transitionBetweenRoutes가 false로 고정되어 heroTag 사용 시 assert가 발생하므로,
/// 홈 내 탭(일정/건의함/공지·투표)에서는 이 위젯을 사용한다.
class TabAppBar extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.white,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: SizedBox(
        height: 44,
        child: Row(
          children: [
            if (leading != null) leading!,
            Expanded(
              child: Center(
                child: Text(
                  title,
                  style: AppFonts.titleSemiBold.copyWith(
                    color: AppColors.textDark,
                  ),
                ),
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}
