import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:myapp/core/theme/app_theme.dart';
import 'package:myapp/core/theme/responsive.dart';
import 'package:myapp/core/utils/avatar_url_resolver.dart';
import 'package:myapp/core/utils/timetable_utils.dart';
import 'package:myapp/screens/today_classes_viewmodel.dart';

class TodayClassesScreen extends StatefulWidget {
  const TodayClassesScreen({super.key});

  @override
  State<TodayClassesScreen> createState() => _TodayClassesScreenState();
}

class _TodayClassesScreenState extends State<TodayClassesScreen> {
  late final TodayClassesViewModel _vm;

  @override
  void initState() {
    super.initState();
    _vm = TodayClassesViewModel();
  }

  @override
  void dispose() {
    _vm.dispose();
    super.dispose();
  }

  static const _weekdayLabels = [
    'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN',
  ];
  static const _monthLabels = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _vm,
      builder: (context, _) => Scaffold(
        backgroundColor: AppColors.background,
        appBar: _buildAppBar(),
        body: SafeArea(
          top: false,
          child: RefreshIndicator(
            onRefresh: _vm.refresh,
            child: ListView(
              padding: EdgeInsets.symmetric(
                horizontal: context.rs(24),
                vertical: context.rh(16),
              ),
              children: [
                _buildMonthAndDateStrip(),
                SizedBox(height: context.rh(24)),
                _buildClassList(),
                SizedBox(height: context.rh(32)),
                _buildChangeLogsSection(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── AppBar ───

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppColors.background,
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: IconButton(
        icon: const Icon(CupertinoIcons.back),
        color: AppColors.primaryBlue,
        onPressed: () => context.pop(),
      ),
      title: Text(
        "Today's Class",
        style: AppFonts.scaled(context, AppFonts.titleSemiBold).copyWith(
          color: AppColors.textDark,
          fontWeight: FontWeight.w800,
        ),
      ),
      centerTitle: false,
      actions: [
        Padding(
          padding: EdgeInsets.only(right: context.rs(16)),
          child: Container(
            width: context.rs(40),
            height: context.rs(40),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.primaryBlue.withValues(alpha: 0.1),
                width: 2,
              ),
            ),
            child: ClipOval(
              child: Builder(builder: (context) {
                final resolved = resolveAvatarUrl(_vm.avatarUrl);
                if (resolved != null && resolved.isNotEmpty) {
                  return Image.network(
                    resolved,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Icon(
                      Icons.person,
                      color: AppColors.textSecondary,
                      size: context.rs(24),
                    ),
                  );
                }
                return Icon(
                  Icons.person,
                  color: AppColors.textSecondary,
                  size: context.rs(24),
                );
              }),
            ),
          ),
        ),
      ],
    );
  }

  // ─── Month Header + Date Strip ───

  Widget _buildMonthAndDateStrip() {
    final date = _vm.selectedDate;
    final monthLabel = '${_monthLabels[date.month - 1]} ${date.year}';
    final startOfMonth = DateTime(date.year, date.month, 1);
    final endOfMonth = DateTime(date.year, date.month + 1, 0);
    final daysInMonth = endOfMonth.day;
    final dates = List.generate(
      daysInMonth,
      (i) => startOfMonth.add(Duration(days: i)),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  monthLabel,
                  style: AppFonts.scaled(context, AppFonts.smallMedium)
                      .copyWith(
                    color: AppColors.textSecondary,
                    fontSize: context.rs(14),
                  ),
                ),
                SizedBox(height: context.rh(2)),
                Text(
                  'Schedule',
                  style: AppFonts.scaled(context, AppFonts.titleSemiBold)
                      .copyWith(
                    color: AppColors.textDark,
                    fontSize: context.rs(30),
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                  ),
                ),
              ],
            ),
            const Spacer(),
            Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(999),
              ),
              padding: EdgeInsets.all(context.rs(4)),
              child: Row(
                children: [
                  _MonthNavButton(
                    icon: CupertinoIcons.chevron_left,
                    onTap: () => _vm.navigateMonth(-1),
                  ),
                  SizedBox(width: context.rs(4)),
                  _MonthNavButton(
                    icon: CupertinoIcons.chevron_right,
                    onTap: () => _vm.navigateMonth(1),
                  ),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: context.rh(16)),
        SizedBox(
          height: context.rh(82),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: dates.length,
            itemBuilder: (context, index) {
              final d = dates[index];
              final isSelected = d.day == date.day &&
                  d.month == date.month &&
                  d.year == date.year;
              final label = _weekdayLabels[d.weekday - 1];

              return Padding(
                padding: EdgeInsets.only(
                  right: index < dates.length - 1 ? context.rs(8) : 0,
                ),
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(24),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(24),
                    onTap: () => _vm.selectDate(d),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOutCubic,
                      width: context.rs(56),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primaryBlue
                            : AppColors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: AppColors.primaryBlue
                                      .withValues(alpha: 0.15),
                                  offset: const Offset(0, 8),
                                  blurRadius: 24,
                                ),
                              ]
                            : null,
                      ),
                      padding: EdgeInsets.symmetric(
                        vertical: context.rh(10),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            label,
                            style: AppFonts.scaled(
                              context,
                              AppFonts.captionMedium,
                            ).copyWith(
                              color: isSelected
                                  ? AppColors.white.withValues(alpha: 0.8)
                                  : AppColors.textSecondary,
                              fontSize: context.rs(10),
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.7,
                            ),
                          ),
                          SizedBox(height: context.rh(4)),
                          Text(
                            '${d.day}',
                            style: AppFonts.scaled(
                              context,
                              AppFonts.display3SemiBold,
                            ).copyWith(
                              color: isSelected
                                  ? AppColors.white
                                  : AppColors.textDark,
                              fontWeight: FontWeight.w800,
                              fontSize: context.rs(18),
                            ),
                          ),
                          if (isSelected) ...[
                            SizedBox(height: context.rh(5)),
                            Container(
                              width: context.rs(4),
                              height: context.rs(4),
                              decoration: const BoxDecoration(
                                color: AppColors.white,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ─── Class List ───

  TimetableViewState get _viewState {
    if (_vm.error != null && _vm.classes.isEmpty) return TimetableViewState.error;
    if (_vm.timetableLoading) return TimetableViewState.loading;
    if (_vm.classes.isEmpty) {
      return TimetableUtils.isWeekday(_vm.selectedDate)
          ? TimetableViewState.emptyWeekday
          : TimetableViewState.emptyWeekend;
    }
    if (MediaQuery.textScalerOf(context).scale(1) >= 1.3) {
      return TimetableViewState.accessibility;
    }
    if (_vm.classes.any(
      (item) => item.name.runes.length > 14 || item.location.runes.length > 16,
    )) {
      return TimetableViewState.longText;
    }
    if (_vm.classes.any(_vm.isCurrent)) {
      return TimetableViewState.hasCurrentClass;
    }
    return TimetableViewState.noCurrentClass;
  }

  Widget _buildClassList() {
    final state = _viewState;
    if (state == TimetableViewState.loading) return _buildLoadingShimmer();
    if (state == TimetableViewState.error) return _buildErrorView();
    if (state == TimetableViewState.emptyWeekday) return _buildEmptyWeekdayView();
    if (state == TimetableViewState.emptyWeekend) return _buildEmptyWeekendView();

    final isA11y = state == TimetableViewState.accessibility;
    final longText = state == TimetableViewState.longText;

    return Column(
      children: _vm.classes.map((item) {
        final completed = _vm.isCompleted(item);
        final current = _vm.isCurrent(item);
        return Padding(
          padding: EdgeInsets.only(bottom: context.rh(16)),
          child: _buildClassCard(
            item,
            isCurrent: current,
            isCompleted: completed,
            isAccessibility: isA11y,
            isLongText: longText,
          ),
        );
      }).toList(),
    );
  }

  // ─── Class Card (Stitch 1:1) ───

  Widget _buildClassCard(
    ClassItem item, {
    required bool isCurrent,
    required bool isCompleted,
    required bool isAccessibility,
    required bool isLongText,
  }) {
    final isUpcoming = !isCurrent && !isCompleted;
    final minutesLeft = _vm.minutesLeftForCurrentClass(item);

    final cardColor = isCurrent
        ? AppColors.primaryBlue.withValues(alpha: 0.08)
        : isCompleted
            ? AppColors.white
            : AppColors.white;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: isCurrent
            ? [
                BoxShadow(
                  color: AppColors.primaryBlue.withValues(alpha: 0.08),
                  offset: const Offset(0, 8),
                  blurRadius: 24,
                ),
              ]
            : null,
      ),
      child: Stack(
        children: [
          if (isCurrent)
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: Center(
                child: Container(
                  width: context.rs(6),
                  height: context.rh(48),
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue,
                    borderRadius: BorderRadius.only(
                      topRight: Radius.circular(999),
                      bottomRight: Radius.circular(999),
                    ),
                  ),
                ),
              ),
            ),
          Padding(
            padding: EdgeInsets.all(context.rs(20)),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Time column
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(height: context.rh(4)),
                    Text(
                      _formatTime24h(item.startTime),
                      style: AppFonts.scaled(
                        context,
                        AppFonts.captionMedium,
                      ).copyWith(
                        color: isCurrent
                            ? AppColors.primaryBlue
                            : AppColors.textSecondary
                                .withValues(alpha: isCompleted ? 0.6 : 1.0),
                        fontSize: context.rs(12),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: context.rh(8)),
                    Container(
                      width: 2,
                      height: context.rh(40),
                      decoration: BoxDecoration(
                        color: isCurrent
                            ? AppColors.primaryBlue.withValues(alpha: 0.2)
                            : AppColors.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    SizedBox(height: context.rh(8)),
                    Text(
                      _formatTime24h(item.endTime),
                      style: AppFonts.scaled(
                        context,
                        AppFonts.captionMedium,
                      ).copyWith(
                        color: isCurrent
                            ? AppColors.primaryBlue
                            : AppColors.textSecondary
                                .withValues(alpha: isCompleted ? 0.6 : 0.75),
                        fontSize: context.rs(12),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                SizedBox(width: context.rs(16)),
                // Content column
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        item.name,
                                        maxLines:
                                            isLongText || isAccessibility
                                                ? 2
                                                : 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: AppFonts.scaled(
                                          context,
                                          AppFonts.titleSemiBold,
                                        ).copyWith(
                                          color: isCompleted
                                              ? AppColors.textDark
                                                  .withValues(alpha: 0.5)
                                              : AppColors.textDark,
                                          decoration: isCompleted
                                              ? TextDecoration.lineThrough
                                              : TextDecoration.none,
                                          fontWeight: FontWeight.w800,
                                          fontSize: context.rs(
                                            isAccessibility ? 19 : 18,
                                          ),
                                        ),
                                      ),
                                    ),
                                    if (isCurrent) ...[
                                      SizedBox(width: context.rs(8)),
                                      Container(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: context.rs(8),
                                          vertical: context.rh(2),
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.primaryBlue,
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          'NOW',
                                          style: AppFonts.scaled(
                                            context,
                                            AppFonts.captionMedium,
                                          ).copyWith(
                                            color: AppColors.white,
                                            fontSize: context.rs(10),
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                SizedBox(height: context.rh(4)),
                                Text(
                                  item.location.isEmpty
                                      ? item.chapter
                                      : '${item.chapter} - ${item.location}',
                                  maxLines: isAccessibility ? 2 : 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppFonts.scaled(
                                    context,
                                    AppFonts.display3Regular,
                                  ).copyWith(
                                    color: isCurrent
                                        ? AppColors.textSecondary
                                        : AppColors.textSecondary,
                                    fontSize: context.rs(
                                      isAccessibility ? 15 : 12,
                                    ),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(width: context.rs(8)),
                          if (isCurrent)
                            _buildStateIcon(
                              icon: Icons.near_me_rounded,
                              background: AppColors.white,
                              color: AppColors.primaryBlue,
                              shadow: true,
                            ),
                          if (isCompleted)
                            _buildStateIcon(
                              icon: Icons.check_circle,
                              background:
                                  AppColors.primaryBlue.withValues(alpha: 0.08),
                              color: AppColors.primaryBlue,
                              filled: true,
                            ),
                          if (isUpcoming)
                            Padding(
                              padding: EdgeInsets.only(top: context.rh(4)),
                              child: Icon(
                                Icons.schedule_rounded,
                                size: context.rs(20),
                                color: AppColors.textSecondary
                                    .withValues(alpha: 0.5),
                              ),
                            ),
                        ],
                      ),
                      if (isCurrent) ...[
                        SizedBox(height: context.rh(16)),
                        Row(
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(999),
                                child: LinearProgressIndicator(
                                  value: _vm.currentClassProgress(item),
                                  minHeight: context.rh(6),
                                  backgroundColor:
                                      AppColors.white.withValues(alpha: 0.5),
                                  valueColor:
                                      const AlwaysStoppedAnimation<Color>(
                                    AppColors.primaryBlue,
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(width: context.rs(12)),
                            Text(
                              minutesLeft == null
                                  ? ''
                                  : '${minutesLeft}m left',
                              style: AppFonts.scaled(
                                context,
                                AppFonts.captionMedium,
                              ).copyWith(
                                color: AppColors.primaryBlue,
                                fontSize: context.rs(10),
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStateIcon({
    required IconData icon,
    required Color background,
    required Color color,
    bool shadow = false,
    bool filled = false,
  }) {
    return Container(
      width: context.rs(32),
      height: context.rs(32),
      decoration: BoxDecoration(
        color: background,
        shape: BoxShape.circle,
        boxShadow: shadow
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  offset: const Offset(0, 2),
                  blurRadius: 4,
                ),
              ]
            : null,
      ),
      child: Icon(icon, size: context.rs(16), color: color),
    );
  }

  // ─── Loading Shimmer ───

  Widget _buildLoadingShimmer() {
    return Column(
      children: List.generate(4, (index) {
        return Padding(
          padding: EdgeInsets.only(bottom: context.rh(16)),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(24),
            ),
            padding: EdgeInsets.all(context.rs(20)),
            child: IntrinsicHeight(
              child: Row(
                children: [
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: context.rs(36),
                        height: context.rh(12),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainer,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      SizedBox(height: context.rh(8)),
                      Container(
                        width: 2,
                        height: context.rh(24),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      SizedBox(height: context.rh(8)),
                      Container(
                        width: context.rs(36),
                        height: context.rh(12),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainer,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(width: context.rs(16)),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: context.rs(120),
                          height: context.rh(18),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceContainer,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        SizedBox(height: context.rh(8)),
                        Container(
                          width: context.rs(180),
                          height: context.rh(12),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }

  // ─── Empty & Error States ───

  Widget _buildEmptyWeekdayView() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: context.rs(20),
        vertical: context.rh(28),
      ),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Container(
            width: context.rs(74),
            height: context.rs(74),
            decoration: BoxDecoration(
              color: AppColors.primaryBlue.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppShapes.radiusLarge),
            ),
            child: Icon(
              Icons.auto_awesome,
              color: AppColors.primaryBlue,
              size: context.rs(34),
            ),
          ),
          SizedBox(height: context.rh(16)),
          Text(
            '오늘은 등록된 수업이 없습니다',
            textAlign: TextAlign.center,
            style: AppFonts.scaled(context, AppFonts.titleSemiBold).copyWith(
              color: AppColors.textDark,
              fontSize: context.rs(18),
            ),
          ),
          SizedBox(height: context.rh(8)),
          Text(
            '잠깐 숨을 고르고, 남은 하루를 준비해보세요.',
            textAlign: TextAlign.center,
            style:
                AppFonts.scaled(context, AppFonts.display3Regular).copyWith(
              color: AppColors.textSecondary,
              fontSize: context.rs(13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyWeekendView() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: context.rs(20),
        vertical: context.rh(26),
      ),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Icon(
            Icons.weekend_outlined,
            size: context.rs(44),
            color: AppColors.primaryBlue,
          ),
          SizedBox(height: context.rh(14)),
          Text(
            '즐거운 주말입니다!',
            style: AppFonts.scaled(context, AppFonts.titleSemiBold).copyWith(
              color: AppColors.textDark,
              fontSize: context.rs(18),
            ),
          ),
          SizedBox(height: context.rh(8)),
          Text(
            '주말에는 정규 수업이 없어요.\n충전하고 다음 주를 준비해요.',
            textAlign: TextAlign.center,
            style:
                AppFonts.scaled(context, AppFonts.display3Regular).copyWith(
              color: AppColors.textSecondary,
              fontSize: context.rs(13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: context.rs(20),
        vertical: context.rh(28),
      ),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Icon(
            Icons.cloud_off_rounded,
            size: context.rs(44),
            color: AppColors.textSecondary,
          ),
          SizedBox(height: context.rh(14)),
          Text(
            _vm.error ?? '오류가 발생했습니다',
            textAlign: TextAlign.center,
            style: AppFonts.scaled(context, AppFonts.titleSemiBold).copyWith(
              color: AppColors.textDark,
              fontSize: context.rs(16),
            ),
          ),
          SizedBox(height: context.rh(16)),
          FilledButton.icon(
            onPressed: _vm.refresh,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('다시 시도'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primaryBlue,
              foregroundColor: AppColors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Change Logs (Bento Card Style) ───

  Widget _buildChangeLogsSection() {
    if (_vm.changeLogsLoading) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(context.rh(16)),
          child: SizedBox(
            width: context.rs(24),
            height: context.rs(24),
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.primaryBlue,
            ),
          ),
        ),
      );
    }
    if (_vm.changeLogs.isEmpty) return const SizedBox.shrink();

    const dayNames = ['월', '화', '수', '목', '금'];
    final latestLog = _vm.changeLogs.first;
    final dayLabel = latestLog.dayOfWeek >= 1 && latestLog.dayOfWeek <= 5
        ? dayNames[latestLog.dayOfWeek - 1]
        : '${latestLog.dayOfWeek}요일';
    final weekLabel = latestLog.weekOffset == 0 ? '이번 주' : '다음 주';

    String changeText;
    if (latestLog.previousSubject != null &&
        latestLog.previousSubject!.isNotEmpty) {
      changeText = '${latestLog.previousSubject} → ${latestLog.newSubject}';
    } else {
      changeText = latestLog.newSubject;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Bento card for latest change
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(context.rs(20)),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainer,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            children: [
              Container(
                width: context.rs(48),
                height: context.rs(48),
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.swap_horiz_rounded,
                  color: AppColors.white,
                  size: context.rs(24),
                ),
              ),
              SizedBox(width: context.rs(16)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '시간표 변경',
                      style: AppFonts.scaled(
                        context,
                        AppFonts.bodyMedium,
                      ).copyWith(
                        color: AppColors.textDark,
                        fontWeight: FontWeight.w700,
                        fontSize: context.rs(15),
                      ),
                    ),
                    SizedBox(height: context.rh(2)),
                    Text(
                      '$weekLabel $dayLabel ${latestLog.period}교시 · $changeText',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppFonts.scaled(
                        context,
                        AppFonts.display3Regular,
                      ).copyWith(
                        color: AppColors.textSecondary,
                        fontSize: context.rs(12),
                      ),
                    ),
                  ],
                ),
              ),
              if (_vm.changeLogs.length > 1)
                Text(
                  '+${_vm.changeLogs.length - 1}건',
                  style: AppFonts.scaled(
                    context,
                    AppFonts.captionMedium,
                  ).copyWith(
                    color: AppColors.primaryBlue,
                    fontWeight: FontWeight.w700,
                    fontSize: context.rs(12),
                  ),
                ),
            ],
          ),
        ),
        // Expandable detail list
        if (_vm.changeLogs.length > 1) ...[
          SizedBox(height: context.rh(12)),
          Container(
            padding: EdgeInsets.all(context.rs(16)),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _vm.changeLogs.skip(1).toList().asMap().entries.map(
                (entry) {
                  final index = entry.key;
                  final log = entry.value;
                  final dl = log.dayOfWeek >= 1 && log.dayOfWeek <= 5
                      ? dayNames[log.dayOfWeek - 1]
                      : '${log.dayOfWeek}요일';
                  final wl = log.weekOffset == 0 ? '이번 주' : '다음 주';
                  String ct;
                  if (log.previousSubject != null &&
                      log.previousSubject!.isNotEmpty) {
                    ct = '${log.previousSubject} → ${log.newSubject}';
                  } else {
                    ct = log.newSubject;
                  }
                  return Padding(
                    padding: EdgeInsets.only(bottom: context.rh(12)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$wl $dl ${log.period}교시',
                          style: AppFonts.scaled(
                            context,
                            AppFonts.captionMedium,
                          ).copyWith(color: AppColors.textSecondary),
                        ),
                        SizedBox(height: context.rh(4)),
                        Text(
                          ct,
                          style: AppFonts.scaled(
                            context,
                            AppFonts.bodyMedium,
                          ).copyWith(color: AppColors.textDark),
                        ),
                        if (log.reason != null && log.reason!.isNotEmpty) ...[
                          SizedBox(height: context.rh(4)),
                          Text(
                            log.reason!,
                            style: AppFonts.scaled(
                              context,
                              AppFonts.display3Regular,
                            ).copyWith(
                              color: AppColors.textSecondary,
                              fontSize: context.rs(13),
                            ),
                          ),
                        ],
                        if (index < _vm.changeLogs.length - 2)
                          Divider(
                            height: context.rh(20),
                            color: AppColors.borderLight,
                          ),
                      ],
                    ),
                  );
                },
              ).toList(),
            ),
          ),
        ],
      ],
    );
  }

  // ─── Helpers ───

  String _formatTime24h(String time24) {
    final parts = time24.split(':');
    if (parts.length < 2) return time24;
    final h = int.tryParse(parts[0]) ?? 0;
    final m = parts[1];
    return '${h.toString().padLeft(2, '0')}:$m';
  }
}

// ─── Month Navigation Button ───

class _MonthNavButton extends StatelessWidget {
  const _MonthNavButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: SizedBox(
          width: context.rs(40),
          height: context.rs(40),
          child: Icon(icon, size: context.rs(16), color: AppColors.textSecondary),
        ),
      ),
    );
  }
}
