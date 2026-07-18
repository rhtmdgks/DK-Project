import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:myapp/core/theme/app_theme.dart';
import 'package:myapp/core/theme/responsive.dart';

/// Figma (node 388:2732) 커스텀 하단 네비게이션 바.
///
/// 5개 탭: 홈, 급식, 일정, 건의함, 공지/투표.
/// 상단 라운드 24px, 이중 그림자, 활성/비활성 색상 분리.
/// 반응형: 아이콘/텍스트/패딩이 화면 크기에 비례하여 스케일링된다.
class AppBottomNavBar extends StatelessWidget {
  const AppBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  static const _items = <_NavItem>[
    _NavItem(label: '홈', svgAsset: 'assets/images/nav_home_inactive.svg'),
    _NavItem(label: '급식', svgAsset: 'assets/images/nav_meal.svg'),
    _NavItem(label: '일정', svgAsset: 'assets/images/nav_schedule_inactive.svg'),
    _NavItem(label: '건의함', svgAsset: 'assets/images/nav_suggestion.svg'),
    _NavItem(label: '공지/투표', svgAsset: 'assets/images/nav_notice.svg'),
  ];

  @override
  Widget build(BuildContext context) {
    final bottomPadding = context.safeArea.bottom;
    final hPad = context.rs(28);
    final vPad = context.rh(12);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(AppShapes.radiusExtraLarge),
          topRight: Radius.circular(AppShapes.radiusExtraLarge),
        ),
        border: Border(
          top: BorderSide(
            color: isDark ? AppDarkColors.border : AppColors.borderLight,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withValues(alpha: 0.08),
            offset: const Offset(0, -8),
            blurRadius: 28,
          ),
          BoxShadow(
            color: AppColors.navShadowInner,
            offset: const Offset(0, -2),
            blurRadius: 12,
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.only(
          top: vPad,
          bottom: bottomPadding > 0 ? bottomPadding : vPad,
          left: hPad,
          right: hPad,
        ),
        child: Row(
          children: List.generate(_items.length, (i) {
            return Expanded(
              child: GestureDetector(
                onTap: () => onTap(i),
                behavior: HitTestBehavior.opaque,
                child: _NavButton(
                  item: _items[i],
                  selected: i == currentIndex,
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({required this.item, required this.selected});

  final _NavItem item;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primaryBlue : AppColors.navInactive;
    final iconSize = context.rs(24);
    final gap = context.rh(6);

    return Padding(
      padding: EdgeInsets.symmetric(vertical: context.rh(8)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SvgPicture.asset(
            item.svgAsset,
            width: iconSize,
            height: iconSize,
            colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
          ),
          SizedBox(height: gap),
          Text(
            item.label,
            style: AppFonts.scaled(
              context,
              selected ? AppFonts.displaySemiBold : AppFonts.displayRegular,
            ).copyWith(color: color),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _NavItem {
  const _NavItem({required this.label, required this.svgAsset});

  final String label;
  final String svgAsset;
}
