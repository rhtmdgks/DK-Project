import 'package:flutter/material.dart';
import 'package:myapp/core/theme/app_theme.dart';
import 'package:myapp/core/theme/responsive.dart';
import 'package:myapp/core/utils/subject_theme_service.dart';
import 'package:myapp/core/utils/timetable_utils.dart';

/// 이번 시간 수업 몇 분/초 남았는지 보여주는 정사각형 위젯.
///
/// [todayEntries]가 있으면 해당 교시 과목명을 표시하고, 없으면 "수업"만 표시.
/// 부모에서 1초마다 setState하면 남은 초가 갱신된다.
class ClassTimeLeftWidget extends StatelessWidget {
  const ClassTimeLeftWidget({
    super.key,
    this.todayEntries,
  });

  /// 오늘 시간표 (교시순). subject, period.
  final List<({String subject, int period})>? todayEntries;

  static const int _durationSeconds = 50 * 60;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    if (!TimetableUtils.isWeekday(now)) {
      return _buildEmptyCard(context);
    }

    final res = TimetableUtils.currentPeriodAndSecondsLeft(now);
    if (res.period == null || res.secondsLeft == null) {
      return _buildEmptyCard(context);
    }

    final subjectName = _subjectForPeriod(res.period!) ?? '수업';
    final theme = SubjectThemeService.getThemeForSubject(subjectName);
    final secondsLeft = res.secondsLeft!;

    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        padding: EdgeInsets.all(context.rs(16)),
        decoration: BoxDecoration(
          color: theme.color,
          borderRadius: BorderRadius.circular(AppShapes.radiusMedium),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
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
              '이번 시간',
              style: AppFonts.scaled(context, AppFonts.display3Regular).copyWith(
                color: AppColors.white.withValues(alpha: 0.9),
                fontSize: context.rs(12),
              ),
            ),
            SizedBox(height: context.rh(4)),
            Text(
              subjectName,
              style: AppFonts.scaled(context, AppFonts.titleSemiBold).copyWith(
                color: AppColors.white,
                fontSize: context.rs(18),
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: context.rh(12)),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${secondsLeft ~/ 60}',
                      style: AppFonts.scaled(context, AppFonts.titleBold).copyWith(
                        color: AppColors.white,
                        fontSize: context.rs(28),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '분 ${secondsLeft % 60}초 남음',
                      style: AppFonts.scaled(context, AppFonts.display3Regular).copyWith(
                        color: AppColors.white.withValues(alpha: 0.95),
                        fontSize: context.rs(12),
                      ),
                    ),
                  ],
                ),
                SizedBox(
                  width: context.rs(48),
                  height: context.rs(48),
                  child: CircularProgressIndicator(
                    value: secondsLeft / _durationSeconds,
                    strokeWidth: context.rs(4),
                    backgroundColor: AppColors.white.withValues(alpha: 0.3),
                    valueColor: const AlwaysStoppedAnimation<Color>(AppColors.white),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String? _subjectForPeriod(int period) {
    final list = todayEntries;
    if (list == null) return null;
    for (final e in list) {
      if (e.period == period) return e.subject;
    }
    return null;
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
            '수업 없음',
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
