import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:myapp/core/auth/auth_state.dart';
import 'package:myapp/core/supabase_client.dart';
import 'package:myapp/core/theme/app_theme.dart';
import 'package:myapp/core/theme/responsive.dart';
import 'package:myapp/core/utils/avatar_url_resolver.dart';
import 'package:myapp/core/utils/timetable_utils.dart';

/// 오늘의 수업 더보기 페이지 (Figma node 388:2726).
///
/// 메인 홈의 "오늘의 수업" 섹션에서 [더보기] 터치 시 진입.
/// 타임라인 형식으로 오늘 수강 과목을 표시한다.
class TodayClassesScreen extends StatefulWidget {
  const TodayClassesScreen({super.key});

  @override
  State<TodayClassesScreen> createState() => _TodayClassesScreenState();
}

/// 반 시간표 변경 사유 한 건 (학생 조회용)
class _TimetableChangeLogItem {
  const _TimetableChangeLogItem({
    required this.weekOffset,
    required this.dayOfWeek,
    required this.period,
    this.previousSubject,
    this.previousTeacher,
    required this.newSubject,
    this.newTeacher,
    this.reason,
    required this.createdAt,
  });

  final int weekOffset;
  final int dayOfWeek;
  final int period;
  final String? previousSubject;
  final String? previousTeacher;
  final String newSubject;
  final String? newTeacher;
  final String? reason;
  final DateTime createdAt;

  static _TimetableChangeLogItem? fromMap(Map<String, dynamic>? map) {
    if (map == null) return null;
    final createdAt = map['created_at'];
    return _TimetableChangeLogItem(
      weekOffset: (map['week_offset'] as num?)?.toInt() ?? 0,
      dayOfWeek: (map['day_of_week'] as num?)?.toInt() ?? 1,
      period: (map['period'] as num?)?.toInt() ?? 1,
      previousSubject: map['previous_subject'] as String?,
      previousTeacher: map['previous_teacher'] as String?,
      newSubject: (map['new_subject'] as String?) ?? '',
      newTeacher: map['new_teacher'] as String?,
      reason: map['reason'] as String?,
      createdAt: createdAt is String
          ? DateTime.tryParse(createdAt) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

class _TodayClassesScreenState extends State<TodayClassesScreen> {
  DateTime _selectedDate = DateTime.now();
  List<_ClassItem> _todayClasses = [];
  bool _timetableLoading = true;
  String? _avatarUrl;
  List<_TimetableChangeLogItem> _changeLogs = [];
  bool _changeLogsLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadTimetableForDate(_selectedDate);
    _loadChangeLogs();
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await getCurrentProfile();
      if (!mounted) return;
      setState(() => _avatarUrl = profile?.avatarUrl);
    } catch (_) {
      if (!mounted) return;
    }
  }

  Future<void> _loadTimetableForDate(DateTime date) async {
    final uid = supabase.auth.currentUser?.id;
    setState(() => _timetableLoading = true);
    if (uid == null) {
      if (!mounted) return;
      setState(() {
        _todayClasses = [];
        _timetableLoading = false;
      });
      return;
    }
    final dayOfWeek = TimetableUtils.dayOfWeekForDb(date);
    if (dayOfWeek == null) {
      if (!mounted) return;
      setState(() {
        _todayClasses = [];
        _timetableLoading = false;
      });
      return;
    }
    try {
      final res = await supabase
          .from('timetable_entries')
          .select('subject, period, room, teacher')
          .eq('user_id', uid)
          .eq('day_of_week', dayOfWeek)
          .order('period');
      final list = List<Map<String, dynamic>>.from(res as List);
      if (!mounted) return;
      setState(() {
        _todayClasses = list.map((e) {
          final period = (e['period'] as num?)?.toInt() ?? 0;
          final subject = (e['subject'] as String?)?.trim() ?? '(없음)';
          final room = (e['room'] as String?)?.trim() ?? '';
          final teacher = (e['teacher'] as String?)?.trim() ?? '';
          return _ClassItem(
            name: subject,
            period: period,
            chapter: '$period교시${room.isNotEmpty ? ' - $room' : ''}',
            startTime: TimetableUtils.startTimeString(period),
            endTime: TimetableUtils.endTimeString(period),
            location: room,
            teacher: teacher.isEmpty ? '-' : teacher,
          );
        }).toList();
        _timetableLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _todayClasses = [];
        _timetableLoading = false;
      });
    }
  }

  Future<void> _loadChangeLogs() async {
    setState(() => _changeLogsLoading = true);
    try {
      final res = await supabase
          .from('class_timetable_change_logs')
          .select()
          .order('created_at', ascending: false)
          .limit(30);
      final list = List<Map<String, dynamic>>.from(res as List);
      if (!mounted) return;
      setState(() {
        _changeLogs = list
            .map((e) => _TimetableChangeLogItem.fromMap(e))
            .whereType<_TimetableChangeLogItem>()
            .toList();
        _changeLogsLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _changeLogs = [];
        _changeLogsLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(CupertinoIcons.back),
          color: AppColors.textDark,
          onPressed: () => context.pop(),
        ),
        title: Text(
          '오늘의 수업',
          style: AppFonts.scaled(context, AppFonts.titleSemiBold)
              .copyWith(color: AppColors.textDark, fontWeight: FontWeight.w700),
        ),
        centerTitle: false,
        actions: [
          Padding(
            padding: EdgeInsets.only(right: context.rs(16)),
            child: Builder(
              builder: (context) {
                final resolved = resolveAvatarUrl(_avatarUrl);
                return CircleAvatar(
                  radius: context.rs(18),
                  backgroundColor: AppColors.borderLight,
                  backgroundImage: resolved != null && resolved.isNotEmpty
                      ? NetworkImage(resolved)
                      : null,
                  child: resolved == null || resolved.isEmpty
                      ? Icon(Icons.person, color: AppColors.textSecondary, size: context.rs(24))
                      : null,
                );
              },
            ),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          onRefresh: () async {
            await _loadTimetableForDate(_selectedDate);
            await _loadChangeLogs();
          },
          child: ListView(
            padding: EdgeInsets.symmetric(
              horizontal: context.rs(24),
              vertical: context.rh(20),
            ),
            children: [
              _buildMonthAndDateStrip(),
              SizedBox(height: context.rh(24)),
              _buildTimeline(),
              SizedBox(height: context.rh(32)),
              _buildChangeLogsSection(),
            ],
          ),
        ),
      ),
    );
  }

  static const _weekdayLabels = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
  static const _weekdayNamesKo = ['월요일', '화요일', '수요일', '목요일', '금요일', '토요일', '일요일'];
  static const _monthLabels = ['JANUARY', 'FEBRUARY', 'MARCH', 'APRIL', 'MAY', 'JUNE',
      'JULY', 'AUGUST', 'SEPTEMBER', 'OCTOBER', 'NOVEMBER', 'DECEMBER'];

  /// 월 라벨 + 가로 스크롤 날짜 스트립 (선택일 "28 THU" 강조)
  Widget _buildMonthAndDateStrip() {
    final monthLabel = _monthLabels[_selectedDate.month - 1];
    final startOfMonth = DateTime(_selectedDate.year, _selectedDate.month, 1);
    final endOfMonth = DateTime(_selectedDate.year, _selectedDate.month + 1, 0);
    final daysInMonth = endOfMonth.day;
    final dates = List.generate(daysInMonth, (i) => startOfMonth.add(Duration(days: i)));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          monthLabel,
          style: AppFonts.scaled(context, AppFonts.display3Regular)
              .copyWith(color: AppColors.textSecondary, fontSize: context.rs(14)),
        ),
        SizedBox(height: context.rh(12)),
        SizedBox(
          height: context.rh(56),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: dates.length,
            itemBuilder: (context, index) {
              final date = dates[index];
              final isSelected = date.day == _selectedDate.day &&
                  date.month == _selectedDate.month &&
                  date.year == _selectedDate.year;
              final weekday = date.weekday; // 1=Mon .. 7=Sun
              final label = _weekdayLabels[weekday - 1];

              return Padding(
                padding: EdgeInsets.only(right: index < dates.length - 1 ? context.rs(12) : 0),
                child: GestureDetector(
                  onTap: () {
                    setState(() => _selectedDate = date);
                    _loadTimetableForDate(date);
                  },
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: context.rs(14),
                      vertical: context.rh(6),
                    ),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.surfaceContainer : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '${date.day}',
                            style: AppFonts.scaled(context, AppFonts.display3SemiBold)
                                .copyWith(
                              color: isSelected ? AppColors.textDark : AppColors.textSecondary,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                              fontSize: context.rs(18),
                            ),
                          ),
                          SizedBox(height: context.rh(2)),
                          Text(
                            label,
                            style: AppFonts.scaled(context, AppFonts.display3Regular)
                                .copyWith(
                              color: isSelected ? AppColors.textDark : AppColors.textSecondary,
                              fontSize: context.rs(11),
                            ),
                          ),
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

  /// 24h "09:00" → 12h "9:00 AM"
  String _formatTime12h(String time24) {
    final parts = time24.split(':');
    if (parts.length < 2) return time24;
    var h = int.tryParse(parts[0]) ?? 0;
    final m = parts[1];
    final suffix = h >= 12 ? 'PM' : 'AM';
    if (h > 12) h -= 12;
    if (h == 0) h = 12;
    return '$h:$m $suffix';
  }

  /// 오늘 선택 시 현재 교시 번호(1-based), 아니면 null
  int? get _currentPeriodIfToday {
    final now = DateTime.now();
    if (_selectedDate.year != now.year ||
        _selectedDate.month != now.month ||
        _selectedDate.day != now.day) {
      return null;
    }
    final res = TimetableUtils.currentPeriodAndSecondsLeft(now);
    return res.period;
  }

  /// 오늘 선택 시 item이 과거 교시인지 (완료)
  bool _isCompleted(_ClassItem item) {
    if (_currentPeriodIfToday == null) return false;
    return item.period < _currentPeriodIfToday!;
  }

  /// 오늘 선택 시 item이 현재 진행 중인지
  bool _isCurrent(_ClassItem item) {
    return _currentPeriodIfToday == item.period;
  }

  /// 타임라인 뷰: 세로선 + 상태별 원(완료/진행중/예정) + 시간 + 과목·강의실·선생님
  Widget _buildTimeline() {
    if (_timetableLoading) {
      return Padding(
        padding: EdgeInsets.only(top: context.rh(24)),
        child: Center(
          child: CircularProgressIndicator(color: AppColors.primaryBlue),
        ),
      );
    }
    if (_todayClasses.isEmpty) {
      final d = _selectedDate;
      final dateLabel = '${d.month}월 ${d.day}일';
      final weekdayName = _weekdayNamesKo[d.weekday - 1];
      final isWeekend = !TimetableUtils.isWeekday(_selectedDate);
      final message = isWeekend
          ? '$dateLabel ($weekdayName)\n주말에는 수업이 없어요.'
          : '$dateLabel ($weekdayName)\n등록된 수업이 없어요.';
      return Padding(
        padding: EdgeInsets.only(top: context.rh(24)),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                message,
                textAlign: TextAlign.center,
                style: AppFonts.scaled(context, AppFonts.bodyRegular)
                    .copyWith(color: AppColors.textSecondary),
              ),
              if (isWeekend) ...[
                SizedBox(height: context.rh(8)),
                Text(
                  '기기 날짜(연도)가 맞는지 확인해 보세요.',
                  textAlign: TextAlign.center,
                  style: AppFonts.scaled(context, AppFonts.display3Regular)
                      .copyWith(color: AppColors.hint, fontSize: context.rs(12)),
                ),
              ],
            ],
          ),
        ),
      );
    }
    const circleRadius = 8.0;
    final lineLeft = circleRadius; // 세로선이 원 중앙을 지나도록

    return Stack(
      children: [
        Positioned(
          left: context.rs(lineLeft) - 1,
          top: context.rs(circleRadius + 4),
          bottom: context.rs(circleRadius + 4),
          child: Container(
            width: 2,
            decoration: BoxDecoration(
              color: AppColors.textSecondary.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(1),
            ),
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: _todayClasses.asMap().entries.map((entry) {
            final item = entry.value;
            final completed = _isCompleted(item);
            final current = _isCurrent(item);

            return Padding(
              padding: EdgeInsets.only(bottom: context.rh(20)),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: context.rs(circleRadius * 2 + 12 + 48),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: context.rs(circleRadius * 2),
                          height: context.rs(circleRadius * 2),
                          child: _buildTimelineCircle(completed: completed, current: current),
                        ),
                        SizedBox(width: context.rs(12)),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _formatTime12h(item.startTime),
                              style: AppFonts.scaled(context, AppFonts.display3SemiBold)
                                  .copyWith(
                                color: AppColors.textSecondary,
                                fontSize: context.rs(13),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: _buildTimelineRow(item, isCurrent: current),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  /// 반 시간표 변경 사유 섹션 (해당 반 학생만 RLS로 조회됨)
  Widget _buildChangeLogsSection() {
    if (_changeLogsLoading) {
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
    if (_changeLogs.isEmpty) {
      return const SizedBox.shrink();
    }
    const dayNames = ['월', '화', '수', '목', '금'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '시간표 변경 사유',
          style: AppFonts.scaled(context, AppFonts.titleSemiBold).copyWith(
            color: AppColors.textDark,
            fontWeight: FontWeight.w700,
            fontSize: context.rs(16),
          ),
        ),
        SizedBox(height: context.rh(12)),
        Container(
          padding: EdgeInsets.all(context.rs(16)),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(AppShapes.radiusLarge),
            border: Border.all(color: AppColors.borderLight),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                offset: const Offset(0, 2),
                blurRadius: 8,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: _changeLogs.asMap().entries.map((entry) {
              final index = entry.key;
              final log = entry.value;
              final dayLabel = log.dayOfWeek >= 1 && log.dayOfWeek <= 5
                  ? dayNames[log.dayOfWeek - 1]
                  : '${log.dayOfWeek}요일';
              final weekLabel = log.weekOffset == 0 ? '이번 주' : '다음 주';
              String changeText;
              if (log.previousSubject != null &&
                  log.previousSubject!.isNotEmpty) {
                changeText = '${log.previousSubject} → ${log.newSubject}';
              } else {
                changeText = log.newSubject;
              }
              if (log.newTeacher != null && log.newTeacher!.isNotEmpty) {
                changeText += ' (${log.newTeacher})';
              }
              return Padding(
                padding: EdgeInsets.only(bottom: context.rh(12)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$weekLabel $dayLabel ${log.period}교시',
                      style: AppFonts.scaled(context, AppFonts.captionMedium)
                          .copyWith(color: AppColors.textSecondary),
                    ),
                    SizedBox(height: context.rh(4)),
                    Text(
                      changeText,
                      style: AppFonts.scaled(context, AppFonts.bodyMedium)
                          .copyWith(color: AppColors.textDark),
                    ),
                    if (log.reason != null && log.reason!.isNotEmpty) ...[
                      SizedBox(height: context.rh(4)),
                      Text(
                        log.reason!,
                        style: AppFonts.scaled(context, AppFonts.display3Regular)
                            .copyWith(
                              color: AppColors.textSecondary,
                              fontSize: context.rs(13),
                            ),
                      ),
                    ],
                    if (index < _changeLogs.length - 1)
                      Divider(
                        height: context.rh(20),
                        color: AppColors.borderLight,
                      ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildTimelineCircle({required bool completed, required bool current}) {
    final fillColor = completed || current ? AppColors.primaryBlue : Colors.transparent;
    final borderColor = AppColors.primaryBlue;

    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: context.rs(16),
          height: context.rs(16),
          decoration: BoxDecoration(
            color: fillColor,
            shape: BoxShape.circle,
            border: Border.all(color: borderColor, width: 2),
          ),
        ),
        if (completed)
          Icon(Icons.check, size: context.rs(10), color: AppColors.white),
      ],
    );
  }

  Widget _buildTimelineRow(_ClassItem item, {required bool isCurrent}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                item.name,
                style: AppFonts.scaled(context, AppFonts.titleSemiBold)
                    .copyWith(
                  color: AppColors.textDark,
                  fontWeight: FontWeight.w700,
                  fontSize: context.rs(16),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isCurrent) ...[
              SizedBox(width: context.rs(8)),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: context.rs(8),
                  vertical: context.rh(4),
                ),
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Now',
                  style: AppFonts.scaled(context, AppFonts.display3Regular)
                      .copyWith(
                    color: AppColors.white,
                    fontSize: context.rs(12),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
        SizedBox(height: context.rh(6)),
        Row(
          children: [
            Icon(Icons.location_on_outlined, size: context.rs(14), color: AppColors.primaryBlue),
            SizedBox(width: context.rs(4)),
            Text(
              item.location.isEmpty ? '-' : item.location,
              style: AppFonts.scaled(context, AppFonts.display3Regular)
                  .copyWith(color: AppColors.textSecondary, fontSize: context.rs(13)),
            ),
          ],
        ),
        SizedBox(height: context.rh(2)),
        Row(
          children: [
            Icon(Icons.person_outline, size: context.rs(14), color: AppColors.primaryBlue),
            SizedBox(width: context.rs(4)),
            Text(
              item.teacher,
              style: AppFonts.scaled(context, AppFonts.display3Regular)
                  .copyWith(color: AppColors.textSecondary, fontSize: context.rs(13)),
            ),
          ],
        ),
      ],
    );
  }
}

/// 수업 항목 데이터
class _ClassItem {
  const _ClassItem({
    required this.name,
    required this.period,
    required this.chapter,
    required this.startTime,
    required this.endTime,
    required this.location,
    required this.teacher,
  });

  final String name;
  final int period;
  final String chapter;
  final String startTime;
  final String endTime;
  final String location;
  final String teacher;
}
