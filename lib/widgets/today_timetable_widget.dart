import 'package:flutter/material.dart';
import 'package:myapp/core/theme/app_theme.dart';
import 'package:myapp/core/theme/responsive.dart';
import 'package:myapp/core/utils/subject_theme_service.dart';
import 'package:myapp/core/utils/timetable_utils.dart';

/// 오늘의 시간표를 가로로 넓은 직사각형 카드로 보여주는 위젯.
///
/// [todayEntries]는 교시순으로 정렬된 subject, period 리스트.
class TodayTimetableWidget extends StatelessWidget {
  const TodayTimetableWidget({
    super.key,
    this.todayEntries,
    this.loading = false,
  });

  /// 오늘 시간표 (교시순). subject, period.
  final List<({String subject, int period})>? todayEntries;

  final bool loading;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 2.2,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(
          horizontal: context.rs(20),
          vertical: context.rh(16),
        ),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(AppShapes.radiusMedium),
          border: Border.all(color: AppColors.border, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              offset: const Offset(0, 2),
              blurRadius: 8,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Text(
                  '오늘의 시간표',
                  style: AppFonts.scaled(context, AppFonts.titleSemiBold).copyWith(
                    color: AppColors.textPrimary,
                    fontSize: context.rs(16),
                  ),
                ),
              ],
            ),
            SizedBox(height: context.rh(12)),
            if (loading)
              Expanded(
                child: Center(
                  child: SizedBox(
                    width: context.rs(24),
                    height: context.rs(24),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              )
            else if (todayEntries == null || todayEntries!.isEmpty)
              Expanded(
                child: Center(
                  child: Text(
                    TimetableUtils.isWeekday(DateTime.now())
                        ? '등록된 수업이 없어요.'
                        : '주말에는 수업이 없어요.',
                    style: AppFonts.scaled(context, AppFonts.bodyRegular).copyWith(
                      color: AppColors.textSecondary,
                      fontSize: context.rs(14),
                    ),
                  ),
                ),
              )
            else
              Expanded(
                child: SingleChildScrollView(
                  child: Wrap(
                    spacing: context.rs(8),
                    runSpacing: context.rh(8),
                    children: todayEntries!
                        .map((e) => _PeriodChip(
                              period: e.period,
                              subject: e.subject,
                            ))
                        .toList(),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PeriodChip extends StatelessWidget {
  const _PeriodChip({
    required this.period,
    required this.subject,
  });

  final int period;
  final String subject;

  @override
  Widget build(BuildContext context) {
    final theme = SubjectThemeService.getThemeForSubject(subject);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: context.rs(12),
        vertical: context.rh(8),
      ),
      decoration: BoxDecoration(
        color: theme.color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppShapes.radiusSmall),
        border: Border.all(
          color: theme.color.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$period교시',
            style: AppFonts.scaled(context, AppFonts.display3Medium).copyWith(
              color: AppColors.textSecondary,
              fontSize: context.rs(12),
            ),
          ),
          SizedBox(width: context.rs(6)),
          Text(
            subject,
            style: AppFonts.scaled(context, AppFonts.titleMedium).copyWith(
              color: AppColors.textPrimary,
              fontSize: context.rs(14),
            ),
          ),
        ],
      ),
    );
  }
}
