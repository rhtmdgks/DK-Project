import 'package:flutter/cupertino.dart';
import 'package:myapp/core/theme/app_theme.dart';
import 'package:myapp/core/theme/responsive.dart';

/// 급식 출발(점심 11:50, 석식 17:50)까지 남은 분을 보여주는 정사각형 위젯.
class MealDepartureCountdownWidget extends StatelessWidget {
  const MealDepartureCountdownWidget({super.key});

  /// 점심 급식 출발 시각 (11:50)
  static const _lunchHour = 11;
  static const _lunchMinute = 50;

  /// 석식 급식 출발 시각 (17:50)
  static const _dinnerHour = 17;
  static const _dinnerMinute = 50;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final next = _nextMealDeparture(now);
    final label = next.isLunch ? '점심' : '석식';
    final minutesLeft = next.minutesLeft;

    if (minutesLeft < 0) {
      return _buildEmptyCard(context);
    }

    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        padding: EdgeInsets.all(context.rs(16)),
        decoration: BoxDecoration(
          color: _cardColor(next.isLunch),
          borderRadius: BorderRadius.circular(AppShapes.radiusMedium),
          boxShadow: [
            BoxShadow(
              color: const Color(0x1A000000),
              offset: const Offset(0, 4),
              blurRadius: 12,
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '급식 출발',
              style: AppFonts.scaled(context, AppFonts.display3Regular).copyWith(
                color: AppColors.white.withValues(alpha: 0.9),
                fontSize: context.rs(12),
              ),
            ),
            SizedBox(height: context.rh(4)),
            Text(
              label,
              style: AppFonts.scaled(context, AppFonts.titleSemiBold).copyWith(
                color: AppColors.white,
                fontSize: context.rs(18),
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: context.rh(12)),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  '$minutesLeft',
                  style: AppFonts.scaled(context, AppFonts.titleBold).copyWith(
                    color: AppColors.white,
                    fontSize: context.rs(32),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(width: context.rs(6)),
                Text(
                  '분 남음',
                  style: AppFonts.scaled(context, AppFonts.display3Regular).copyWith(
                    color: AppColors.white.withValues(alpha: 0.95),
                    fontSize: context.rs(16),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  ({bool isLunch, int minutesLeft}) _nextMealDeparture(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final lunch = today.add(Duration(hours: _lunchHour, minutes: _lunchMinute));
    final dinner = today.add(Duration(hours: _dinnerHour, minutes: _dinnerMinute));

    if (now.isBefore(lunch)) {
      return (isLunch: true, minutesLeft: lunch.difference(now).inMinutes);
    }
    if (now.isBefore(dinner)) {
      return (isLunch: false, minutesLeft: dinner.difference(now).inMinutes);
    }
    final tomorrowLunch = today.add(const Duration(days: 1)).add(
      Duration(hours: _lunchHour, minutes: _lunchMinute),
    );
    return (isLunch: true, minutesLeft: tomorrowLunch.difference(now).inMinutes);
  }

  Color _cardColor(bool isLunch) {
    return isLunch
        ? const Color(0xFF00B894)
        : const Color(0xFF6C5CE7);
  }

  Widget _buildEmptyCard(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        padding: EdgeInsets.all(context.rs(16)),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(AppShapes.radiusMedium),
        ),
        child: Center(
          child: Text(
            '급식 출발 전',
            style: AppFonts.scaled(context, AppFonts.bodyRegular).copyWith(
              color: AppColors.textSecondary,
              fontSize: context.rs(14),
            ),
          ),
        ),
      ),
    );
  }
}
