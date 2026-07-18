import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:myapp/components/apple_button.dart';
import 'package:myapp/components/apple_text_field.dart';
import 'package:myapp/core/routing/app_router.dart';
import 'package:myapp/core/auth/auth_state.dart';
import 'package:myapp/core/auth/auth_repository.dart';
import 'package:myapp/core/supabase_client.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:myapp/core/theme/app_resolved_colors.dart';
import 'package:myapp/core/theme/app_theme.dart';
import 'package:myapp/core/theme/responsive.dart';
import 'package:myapp/core/widgets/app_feedback.dart';
import 'package:myapp/core/widgets/async_body.dart';
import 'package:myapp/core/widgets/dismiss_keyboard.dart';
import 'package:myapp/core/widgets/m3_list.dart';
import 'package:myapp/core/widgets/tab_page_header.dart';
import 'package:myapp/design/glass.dart';
import 'package:myapp/repositories/personal_event_attachment_repository.dart';
import 'package:myapp/repositories/schedule_repository.dart';
import 'package:url_launcher/url_launcher.dart';

/// [DateTime]이 같은 날인지 비교 (로컬 날짜 기준).
bool _isSameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

/// ISO 문자열을 [DateTime]으로 파싱. 실패 시 null.
DateTime? _parseUtc(String? s) {
  if (s == null || s.isEmpty) return null;
  try {
    return DateTime.parse(s);
  } catch (_) {
    return null;
  }
}

Future<DateTime?> _pickDateTime(BuildContext context, DateTime initial) async {
  var picked = initial;
  return showCupertinoModalPopup<DateTime>(
    context: context,
    builder: (ctx) {
      final colors = ctx.appColors;
      return Container(
        height: 320,
        color: colors.surface,
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                CupertinoButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('취소'),
                ),
                CupertinoButton(
                  onPressed: () => Navigator.of(ctx).pop(picked),
                  child: const Text('확인'),
                ),
              ],
            ),
            Expanded(
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.dateAndTime,
                initialDateTime: initial,
                onDateTimeChanged: (dt) => picked = dt,
              ),
            ),
          ],
        ),
      );
    },
  );
}

Future<bool> _confirmDelete(BuildContext context) async {
  final result = await GlassDialog.show<bool>(
    context: context,
    quality: kAppGlassQuality,
    title: '삭제하시겠습니까?',
    actions: [
      GlassDialogAction(
        label: '취소',
        onPressed: () => Navigator.of(context).pop(false),
      ),
      GlassDialogAction(
        label: '삭제',
        isDestructive: true,
        onPressed: () => Navigator.of(context).pop(true),
      ),
    ],
  );
  return result ?? false;
}

/// 일정 관리 탭. 반응형 대응.
///
/// 상단에 Flutter 기본 위젯으로 만든 캘린더를 두고,
/// 선택한 날짜의 일정만 목록으로 표시한다. 시간표(데이터/기능)는 기존과 동일하게 유지.
  /// council / admin은 학교 일정 수정, 정반장/부반장은 학급 공유 일정을 관리한다.
class ScheduleTab extends StatefulWidget {
  const ScheduleTab({super.key});

  @override
  State<ScheduleTab> createState() => _ScheduleTabState();
}

class _ScheduleTabState extends State<ScheduleTab> {
  bool _loading = false;
  String? _error;
  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _personalEvents = [];
  List<Map<String, dynamic>> _classEvents = [];
  /// NEIS 학사일정 (시도교육청·학교 코드는 급식과 동일한 env 사용)
  List<Map<String, dynamic>> _neisItems = [];
  /// 법정공휴일: 'yyyy-MM-dd' → 공휴일명
  Map<String, String> _holidays = {};
  final _scheduleRepo = ScheduleRepository();
  AppProfile? _profile;
  String? _currentUserId;

  /// 캘린더에 표시할 월 (이동용)
  DateTime _viewMonth;
  /// 사용자가 선택한 날짜 (해당 날짜 일정 필터링)
  DateTime _selectedDate;

  _ScheduleTabState()
      : _viewMonth = DateTime(DateTime.now().year, DateTime.now().month),
        _selectedDate = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _fetch();
  }

  Future<void> _loadProfile() async {
    final p = await getCurrentProfile();
    final uid = await AuthRepository.instance.getUserId();
    if (mounted) {
      setState(() {
        _profile = p;
        _currentUserId = uid;
      });
    }
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // 학교 전체 일정 (Supabase)
      final scheduleRes = await supabase
          .from('schedule_items')
          .select()
          .order('start_at', ascending: true);

      // 개인 일정 (Supabase Auth 세션 기반 조회)
      final uid = await AuthRepository.instance.getUserId();
      final session = supabase.auth.currentSession;
      List<Map<String, dynamic>> personalRes = [];
      List<Map<String, dynamic>> classRes = [];

      if (session != null && uid != null && uid.isNotEmpty) {
        // Supabase Auth 세션이 있는 경우: RLS(auth.uid() = user_id) 기준으로 직접 조회.
        final personalResRaw = await supabase
            .from('personal_events')
            .select()
            .eq('user_id', uid)
            .order('start_at', ascending: true);
        personalRes = List<Map<String, dynamic>>.from(personalResRaw as List)
            .map((item) => {...item, 'event_scope': 'personal'})
            .toList();
      }

      final profile = _profile;
      final grade = profile?.gradeOrFromStudentId;
      final classNum = profile?.classNumOrFromStudentId;
      if (session != null && grade != null && classNum != null) {
        final classResRaw = await supabase
            .from('class_events')
            .select()
            .eq('grade', grade)
            .eq('class_number', classNum)
            .order('start_at', ascending: true);
        classRes = List<Map<String, dynamic>>.from(classResRaw as List)
            .map((item) => {...item, 'event_scope': 'class'})
            .toList();
      }

      // NEIS 학사일정 (방학·재량휴업 등). 실패해도 나머지 일정은 표시.
      var neisList = <Map<String, dynamic>>[];
      try {
        neisList = await _scheduleRepo.fetchAcademicCalendar(_viewMonth);
      } catch (_) {
        neisList = [];
      }

      // 법정공휴일 (빨간 날 표시). 실패해도 무시.
      var holidayMap = <String, String>{};
      try {
        final holidayRes = await _scheduleRepo.fetchPublicHolidays(_viewMonth);
        holidayMap = {
          for (final h in holidayRes)
            (h['holiday_date'] ?? '').toString(): (h['name'] ?? '').toString(),
        };
      } catch (_) {
        holidayMap = {};
      }

      if (!mounted) return;
      setState(() {
        _items = List<Map<String, dynamic>>.from(scheduleRes as List);
        _personalEvents = personalRes;
        _classEvents = classRes;
        _neisItems = neisList;
        _holidays = holidayMap;
        _currentUserId = uid;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  bool get _canEdit => _profile?.isPrivileged ?? false;

  /// 선택한 날짜에 해당하는 일정만 반환 (학교 일정 + 개인 일정 + 학사일정).
  List<Map<String, dynamic>> get _itemsForSelectedDay {
    final allItems = [..._items, ..._neisItems, ..._classEvents, ..._personalEvents];
    return allItems.where((item) => _eventOverlapsDay(item, _selectedDate)).toList();
  }

  /// 해당 날짜에 일정이 있으면 true (시작일·종료일 기준).
  bool _hasEventOnDate(DateTime day) {
    final allItems = [..._items, ..._neisItems, ..._classEvents, ..._personalEvents];
    return allItems.any((item) => _eventOverlapsDay(item, day));
  }

  String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// 법정공휴일명. 공휴일이 아니면 null.
  String? _holidayNameOnDate(DateTime day) => _holidays[_dateKey(day)];

  /// NEIS 휴업일(방학·재량휴업 등) 여부.
  bool _isNeisDayOff(DateTime day) {
    return _neisItems.any((item) =>
        item['is_day_off'] == true && _eventOverlapsDay(item, day));
  }

  /// 캘린더에서 빨간 날 표시 대상 (공휴일 또는 NEIS 휴업일).
  bool _isRedDay(DateTime day) =>
      _holidayNameOnDate(day) != null || _isNeisDayOff(day);

  bool _eventOverlapsDay(Map<String, dynamic> item, DateTime day) {
    final start = _parseUtc(item['start_at'] as String?);
    if (start == null) return false;
    final end = _parseUtc(item['end_at'] as String?);
    final startDay = DateTime(start.year, start.month, start.day);
    final endDay = end != null ? DateTime(end.year, end.month, end.day) : startDay;
    final target = DateTime(day.year, day.month, day.day);
    return !target.isBefore(startDay) && !target.isAfter(endDay);
  }

  @override
  Widget build(BuildContext context) {
    return DismissKeyboard(
      child: ColoredBox(
        color: context.appColors.background,
        child: Column(
          children: [
            SafeArea(
              top: true,
              bottom: false,
              minimum: EdgeInsets.zero,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: context.rs(22)),
                child: TabPageHeader(
                  title: '일정',
                  subtitle: '날짜를 선택해 일정을 확인하세요.',
                  trailing: _canEdit
                      ? CupertinoButton(
                          padding: EdgeInsets.zero,
                          onPressed: _showAddDialog,
                          child: const Icon(CupertinoIcons.add),
                        )
                      : null,
                ),
              ),
            ),
            Expanded(
              child: AsyncBody(
                loading: _loading,
                error: _error,
                isEmpty: false,
                onRetry: _fetch,
                emptyMessage: '',
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  slivers: [
                    CupertinoSliverRefreshControl(onRefresh: _fetch),
                    SliverPadding(
                      padding: context.horizontalPadding.copyWith(
                        top: context.rh(16),
                        bottom: context.rh(16),
                      ),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          _buildCalendarSection(),
                          SizedBox(height: context.rh(24)),
                          _buildSectionTitle(),
                          SizedBox(height: context.rh(2)),
                          _buildScheduleList(),
                          SizedBox(height: context.rh(20)),
                          _buildNewEventButton(),
                          SizedBox(height: context.rh(24)),
                          _buildClassPhotoSection(),
                          SizedBox(height: context.rh(24)),
                        ]),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClassPhotoSection() {
    final colors = context.appColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(left: context.rs(4), bottom: context.rh(8)),
          child: Text(
            '반별 사진',
            style: AppFonts.scaled(context, AppFonts.sectionTitle),
          ),
        ),
        GestureDetector(
          onTap: () => context.push(AppRoute.classPhotoShares.path),
          behavior: HitTestBehavior.opaque,
          child: Container(
            decoration: BoxDecoration(
              color: colors.surfaceContainerHighest.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(12),
            ),
            padding: EdgeInsets.symmetric(
              horizontal: context.rs(16),
              vertical: context.rh(14),
            ),
            child: Row(
              children: [
                Icon(
                  CupertinoIcons.photo_on_rectangle,
                  size: context.rs(22),
                  color: colors.primary,
                ),
                SizedBox(width: context.rs(10)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '반별 사진 공유',
                        style: AppFonts.scaled(context, AppFonts.titleMedium),
                      ),
                      SizedBox(height: context.rh(2)),
                      Text(
                        '같은 반 친구들과 사진을 올리고 볼 수 있어요.',
                        style: AppFonts.scaled(context, AppFonts.captionRegular),
                      ),
                    ],
                  ),
                ),
                Icon(
                  CupertinoIcons.chevron_right,
                  size: context.rs(22),
                  color: AppColors.hint,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNewEventButton() {
    final colors = context.appColors;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: context.rs(20)),
      child: GestureDetector(
        onTap: _showAddPersonalEventDialog,
        behavior: HitTestBehavior.opaque,
        child: Container(
          decoration: BoxDecoration(
            color: colors.surfaceContainerHighest.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(12),
          ),
          padding: EdgeInsets.symmetric(
            horizontal: context.rs(16),
            vertical: context.rh(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                CupertinoIcons.add,
                size: context.rs(20),
                color: colors.onSurface,
              ),
              SizedBox(width: context.rs(8)),
              Text(
                '새로운 이벤트',
                style: AppFonts.scaled(context, AppFonts.bodyMedium).copyWith(
                  color: colors.onSurface,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Flutter 기본 위젯만 사용한 월간 캘린더 (CupertinoIcons.calendar 등).
  Widget _buildCalendarSection() {
    final year = _viewMonth.year;
    final month = _viewMonth.month;
    final first = DateTime(year, month, 1);
    final last = DateTime(year, month + 1, 0);
    final weekdayOfFirst = first.weekday % 7; // 일=0, 월=1, ... 토=6
    final daysInMonth = last.day;
    final weekHeaders = ['일', '월', '화', '수', '목', '금', '토'];

    return Container(
      padding: EdgeInsets.all(context.rs(16)),
      decoration: BoxDecoration(
        color: context.appColors.surface,
        borderRadius: AppShapes.borderRadiusMedium,
        border: Border.all(color: AppColors.borderLight),
        boxShadow: [
          BoxShadow(
            color: context.appColors.shadow.withValues(alpha: 0.06),
            offset: const Offset(0, 2),
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              CupertinoButton(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                onPressed: () {
                  setState(() {
                    _viewMonth = DateTime(year, month - 1);
                  });
                  _fetch();
                },
                child: Icon(
                  CupertinoIcons.chevron_left,
                  color: AppColors.textPrimary,
                  size: context.rs(28),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    CupertinoIcons.calendar,
                    size: context.rs(20),
                    color: AppColors.primaryBlue,
                  ),
                  SizedBox(width: context.rs(6)),
                  Text(
                    '$year년 $month월',
                    style: AppFonts.scaled(context, AppFonts.titleSemiBold),
                  ),
                ],
              ),
              CupertinoButton(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                onPressed: () {
                  setState(() {
                    _viewMonth = DateTime(year, month + 1);
                  });
                  _fetch();
                },
                child: Icon(
                  CupertinoIcons.chevron_right,
                  color: AppColors.textPrimary,
                  size: context.rs(28),
                ),
              ),
            ],
          ),
          SizedBox(height: context.rh(16)),
          // 요일 헤더
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(7, (i) {
              final isSun = i == 0;
              return SizedBox(
                width: context.rs(36),
                child: Center(
                  child: Text(
                    weekHeaders[i],
                    style: AppFonts.scaled(context, AppFonts.captionMedium)
                        .copyWith(
                      color: isSun ? AppColors.error : AppColors.textSecondary,
                    ),
                  ),
                ),
              );
            }),
          ),
          SizedBox(height: context.rh(8)),
          // 날짜 그리드 (6주 x 7일) — Flutter 기본 위젯만 사용
          LayoutBuilder(
            builder: (context, constraints) {
              final cellSize = (constraints.maxWidth - 6 * 2) / 7;
              final totalCells = weekdayOfFirst + daysInMonth;
              final rowCount = (totalCells / 7).ceil().clamp(1, 6);
              var day = 1 - weekdayOfFirst;
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(rowCount, (r) {
                  return Padding(
                    padding: EdgeInsets.only(bottom: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(7, (c) {
                        final d = day++;
                        final isCurrentMonth = d >= 1 && d <= daysInMonth;
                        final date = isCurrentMonth
                            ? DateTime(year, month, d)
                            : null;
                        final isSelected = date != null &&
                            _isSameDay(date, _selectedDate);
                        final isToday = date != null &&
                            _isSameDay(
                              date,
                              DateTime(DateTime.now().year,
                                  DateTime.now().month, DateTime.now().day),
                            );
                        final isSunday = c == 0;
                        final hasEvent = date != null && _hasEventOnDate(date);
                        final isRedDay = date != null && _isRedDay(date);
                        return GestureDetector(
                          onTap: isCurrentMonth
                              ? () => setState(() => _selectedDate = date!)
                              : null,
                          child: Container(
                            width: cellSize - 2,
                            height: cellSize - 2,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.primaryBlue
                                  : (isToday
                                      ? AppColors.primaryBlue.withValues(alpha: 0.12)
                                      : null),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    isCurrentMonth ? '$d' : '',
                                    style: AppFonts.scaled(
                                      context,
                                      AppFonts.smallMedium,
                                    ).copyWith(
                                      color: isSelected
                                          ? AppColors.white
                                          : (isRedDay
                                              ? AppColors.error
                                              : (isSunday
                                                  ? AppColors.textSecondary
                                                  : AppColors.textPrimary)),
                                      fontWeight:
                                          isRedDay ? FontWeight.w600 : null,
                                    ),
                                  ),
                                  if (hasEvent) ...[
                                    SizedBox(height: context.rh(2)),
                                    Container(
                                      width: 4,
                                      height: 4,
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? AppColors.white
                                            : AppColors.primaryBlue,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  );
                }),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle() {
    final y = _selectedDate.year;
    final m = _selectedDate.month;
    final d = _selectedDate.day;
    final holidayName = _holidayNameOnDate(_selectedDate);
    return Padding(
      padding: EdgeInsets.only(left: context.rs(4)),
      child: Row(
        children: [
          Text(
            '$y년 $m월 $d일 일정',
            style: AppFonts.scaled(context, AppFonts.titleMedium),
          ),
          if (holidayName != null) ...[
            SizedBox(width: context.rs(8)),
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: context.rs(8),
                vertical: context.rh(2),
              ),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(context.rs(8)),
              ),
              child: Text(
                holidayName,
                style: AppFonts.scaled(context, AppFonts.captionMedium)
                    .copyWith(color: AppColors.error),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildScheduleList() {
    final list = _itemsForSelectedDay;
    if (list.isEmpty) {
      return Container(
        padding: EdgeInsets.symmetric(vertical: context.rh(32)),
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              CupertinoIcons.calendar_badge_plus,
              size: context.rs(48),
              color: AppColors.hint,
            ),
            SizedBox(height: context.rh(12)),
            Text(
              '해당 날짜에 일정이 없습니다.',
              style: AppFonts.scaled(context, AppFonts.bodyRegular),
            ),
          ],
        ),
      );
    }
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: list.length,
      separatorBuilder: (_, __) => Container(height: 1, color: context.appColors.border),
      itemBuilder: (context, i) => _buildScheduleTile(list[i]),
    );
  }

  String _scheduleTimeStr(Map<String, dynamic> item) {
    final start = _parseUtc(item['start_at'] as String?);
    final end = _parseUtc(item['end_at'] as String?);
    if (start != null && end != null) {
      return '${_formatTime(start)} - ${_formatTime(end)}';
    }
    if (start != null && end == null) {
      return '${start.month}월 ${start.day}일'; // 학사일정 등 종일 일정
    }
    if (item['start_at'] != null || item['end_at'] != null) {
      return '${item['start_at']} - ${item['end_at']}';
    }
    return '';
  }

  Widget _buildScheduleTile(Map<String, dynamic> item) {
    final title = item['title'] as String? ?? '';
    final desc = item['description'] as String? ?? '';
    final timeStr = _scheduleTimeStr(item);
    final scope = item['event_scope'] as String?;
    final isPersonal = scope == 'personal';
    final isClass = scope == 'class';
    final isNeis = item['is_neis'] == true || scope == 'neis';

    final subtitle = [
      if (isPersonal) '개인 일정',
      if (isClass) '${item['grade']}학년 ${item['class_number']}반 공유',
      if (!isPersonal && !isClass && !isNeis) '학교 일정',
      if (timeStr.isNotEmpty) timeStr,
      if (desc.isNotEmpty) desc,
    ]
        .join(' · ');
    final subtitleTrim = subtitle.isEmpty ? null : subtitle;

    Color leadingColor = context.appColors.primary;
    if (isPersonal) leadingColor = AppColors.primaryBlue500;
    if (isClass) leadingColor = AppColors.primaryBlue;
    if (isNeis) leadingColor = AppColors.timetableHighlight;

    return M3ListTileInbox(
      title: title.isEmpty ? '(제목 없음)' : title,
      subtitle: subtitleTrim,
      leading: Container(
        width: 4,
        height: context.rh(44),
        decoration: BoxDecoration(
          color: leadingColor,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      trailing: Icon(CupertinoIcons.chevron_right, size: context.rs(20), color: AppColors.hint),
      onTap: () => _showScheduleDetail(
        context,
        item,
        isPersonal: isPersonal,
        isClass: isClass,
        isNeis: isNeis,
      ),
    );
  }

  void _showScheduleDetail(
    BuildContext context,
    Map<String, dynamic> item, {
    bool isPersonal = false,
    bool isClass = false,
    bool isNeis = false,
  }) {
    final title = item['title'] as String? ?? '';
    final desc = item['description'] as String? ?? '';
    final timeStr = _scheduleTimeStr(item);
    final body = desc.isEmpty ? (timeStr.isEmpty ? '내용 없음' : '시간: $timeStr') : desc;
    final secondaryParts = <String>[
      if (isClass) '${item['grade']}학년 ${item['class_number']}반 공유 일정',
      if (timeStr.isNotEmpty) '시간: $timeStr',
    ];
    final secondary = secondaryParts.isEmpty ? null : secondaryParts.join(' · ');

    final actions = <Widget>[];
    final id = item['id'] as String?;
    final isClassOwner = isClass && item['created_by_user_id'] == _currentUserId;

    // 개인 일정: 첨부파일 열람 버튼.
    if (isPersonal && id != null) {
      actions.add(
        AppleButton(
          label: '첨부파일',
          variant: AppleButtonVariant.plain,
          icon: CupertinoIcons.paperclip,
          onPressed: () => _showAttachmentsSheet(id),
        ),
      );
    }

    if (!isNeis && id != null && (isPersonal || isClassOwner || _canEdit)) {
      actions.add(
        AppleButton(
          label: '삭제',
          variant: AppleButtonVariant.destructive,
          onPressed: () async {
            if (isPersonal) {
              await _deletePersonalEvent(id);
            } else if (isClass) {
              await _deleteClassEvent(id);
            } else {
              await _delete(id);
            }
            if (context.mounted) Navigator.of(context).pop();
          },
        ),
      );
    }

    showM3DetailSheet(
      context,
      title: title.isEmpty ? '(제목 없음)' : title,
      body: body,
      secondary: secondary,
      actions: actions.isEmpty ? null : actions,
    );
  }

  /// 개인 일정 첨부파일 목록 시트. 탭하면 서명 URL로 연다.
  Future<void> _showAttachmentsSheet(String eventId) async {
    List<Map<String, dynamic>> attachments;
    try {
      attachments = await PersonalEventAttachmentRepository.instance
          .fetchAttachments(eventId);
    } catch (_) {
      attachments = [];
    }
    if (!mounted) return;

    GlassSheet.show<void>(
      context: context,
      quality: kAppGlassQuality,
      builder: (sheetContext) => SafeArea(
        child: attachments.isEmpty
            ? Padding(
                padding: EdgeInsets.all(sheetContext.rs(32)),
                child: Text(
                  '첨부파일이 없습니다.',
                  textAlign: TextAlign.center,
                  style: AppFonts.scaled(sheetContext, AppFonts.bodyRegular),
                ),
              )
            : ListView(
                shrinkWrap: true,
                children: [
                  for (final a in attachments)
                    GestureDetector(
                      onTap: () async {
                        final path = a['storage_path'] as String?;
                        if (path == null) return;
                        try {
                          final url = await PersonalEventAttachmentRepository
                              .instance
                              .createSignedUrl(path);
                          await launchUrl(
                            Uri.parse(url),
                            mode: LaunchMode.externalApplication,
                          );
                        } catch (_) {
                          if (sheetContext.mounted) {
                            AppFeedback.showError(
                              sheetContext,
                              '파일을 열 수 없습니다.',
                            );
                          }
                        }
                      },
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: sheetContext.rs(16),
                          vertical: sheetContext.rh(12),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              (a['mime_type'] as String? ?? '').contains('pdf')
                                  ? CupertinoIcons.doc_fill
                                  : CupertinoIcons.photo,
                              color: AppColors.primaryBlue,
                            ),
                            SizedBox(width: sheetContext.rs(12)),
                            Expanded(
                              child: Text(
                                a['file_name'] as String? ?? '파일',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour;
    final m = dt.minute;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  Future<void> _showAddDialog() async {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    var start = DateTime.now();
    var end = DateTime.now().add(const Duration(hours: 1));

    try {
      final added = await GlassSheet.show<bool>(
        context: context,
        quality: kAppGlassQuality,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (dialogContext, setDialogState) {
              return SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '일정 추가',
                        style: AppFonts.scaled(dialogContext, AppFonts.titleBold),
                      ),
                      const SizedBox(height: 16),
                      AppleTextField(controller: titleController, placeholder: '제목'),
                      const SizedBox(height: 12),
                      AppleTextField(controller: descController, placeholder: '설명'),
                      const SizedBox(height: 12),
                      _buildDateTimeTile(
                        dialogContext: dialogContext,
                        label: '시작',
                        dateTime: start,
                        onChanged: (dt) => setDialogState(() => start = dt),
                      ),
                      _buildDateTimeTile(
                        dialogContext: dialogContext,
                        label: '종료',
                        dateTime: end,
                        onChanged: (dt) => setDialogState(() => end = dt),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: AppleButton(
                              label: '취소',
                              variant: AppleButtonVariant.secondary,
                              onPressed: () => Navigator.of(dialogContext).pop(false),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: AppleButton(
                              label: '추가',
                              onPressed: () async {
                                final profile = _profile;
                                if (profile == null) return;
                                await supabase.from('schedule_items').insert({
                                  'title': titleController.text,
                                  'description': descController.text.isEmpty
                                      ? null
                                      : descController.text,
                                  'start_at': start.toIso8601String(),
                                  'end_at': end.toIso8601String(),
                                  'created_by': profile.id,
                                });
                                if (dialogContext.mounted) {
                                  Navigator.of(dialogContext).pop(true);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      );

      if (added == true) _fetch();
    } finally {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        titleController.dispose();
        descController.dispose();
      });
    }
  }

  Widget _buildDateTimeTile({
    required BuildContext dialogContext,
    required String label,
    required DateTime dateTime,
    required ValueChanged<DateTime> onChanged,
    bool enabled = true,
  }) {
    return GestureDetector(
      onTap: enabled
          ? () async {
              final picked = await _pickDateTime(dialogContext, dateTime);
              if (picked != null) onChanged(picked);
            }
          : null,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: AppFonts.scaled(dialogContext, AppFonts.bodyMedium)),
            const SizedBox(height: 4),
            Text(
              enabled
                  ? '${dateTime.year}년 ${dateTime.month}월 ${dateTime.day}일 ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}'
                  : '하루 종일',
              style: AppFonts.scaled(dialogContext, AppFonts.captionRegular).copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _delete(String id) async {
    final ok = await _confirmDelete(context);

    if (ok) {
      await supabase.from('schedule_items').delete().eq('id', id);
      _fetch();
    }
  }

  Future<void> _showAddPersonalEventDialog() async {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    final now = DateTime.now();
    var start = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      now.hour,
      now.minute,
    );
    var end = start.add(const Duration(hours: 1));
    var allDay = false;
    var shareWithClass = false;
    // 첨부할 파일 (개인 일정만 지원). 이미지·PDF.
    final pickedFiles = <PlatformFile>[];

    if (!mounted) return;
    try {
      final added = await GlassSheet.show<bool>(
        context: context,
        quality: kAppGlassQuality,
        builder: (sheetContext) {
          return DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.7,
            minChildSize: 0.4,
            maxChildSize: 0.95,
            builder: (ctx, scrollController) {
              return StatefulBuilder(
                builder: (innerContext, setSheetState) {
                  return GestureDetector(
                    onTap: () => FocusScope.of(innerContext).unfocus(),
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      decoration: BoxDecoration(
                        color: innerContext.appColors.surface,
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(AppShapes.radiusLarge),
                        ),
                      ),
                      child: SafeArea(
                      top: false,
                      child: Column(
                        children: [
                          // 드래그 핸들
                          Padding(
                            padding: EdgeInsets.only(top: innerContext.rh(12)),
                            child: Container(
                              width: innerContext.rs(36),
                              height: 4,
                              decoration: BoxDecoration(
                                color: AppColors.hint.withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: innerContext.rs(22),
                              vertical: innerContext.rh(16),
                            ),
                            child: Row(
                              children: [
                                Text(
                                  '개인/학급 일정 추가',
                                  style: AppFonts.scaled(innerContext, AppFonts.titleBold),
                                ),
                                const Spacer(),
                                CupertinoButton(
                                  padding: EdgeInsets.zero,
                                  onPressed: () => Navigator.of(sheetContext).pop(false),
                                  child: Icon(
                                    CupertinoIcons.xmark,
                                    color: AppColors.textSecondary,
                                    size: innerContext.rs(22),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: SingleChildScrollView(
                              controller: scrollController,
                              padding: EdgeInsets.fromLTRB(
                                innerContext.rs(22),
                                0,
                                innerContext.rs(22),
                                innerContext.rh(24),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  AppleTextField(
                                    controller: titleController,
                                    placeholder: '제목',
                                  ),
                                  SizedBox(height: innerContext.rh(12)),
                                  AppleTextField(
                                    controller: descController,
                                    placeholder: '설명 (선택)',
                                    maxLines: 3,
                                  ),
                                  SizedBox(height: innerContext.rh(12)),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          '하루 종일',
                                          style: AppFonts.scaled(
                                            innerContext,
                                            AppFonts.bodyRegular,
                                          ),
                                        ),
                                      ),
                                      CupertinoSwitch(
                                        value: allDay,
                                        onChanged: (value) =>
                                            setSheetState(() => allDay = value),
                                      ),
                                    ],
                                  ),
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '반 전체에 공유하기',
                                              style: AppFonts.scaled(
                                                innerContext,
                                                AppFonts.bodyRegular,
                                              ),
                                            ),
                                            Text(
                                              _profile?.hasGradeClass != true
                                                  ? '프로필에 학년/반 정보가 없어 학급 공유를 사용할 수 없습니다.'
                                                  : '학생회 권한 없이 같은 반 학생 모두에게 표시됩니다.',
                                              style: AppFonts.scaled(
                                                innerContext,
                                                AppFonts.captionRegular,
                                              ).copyWith(color: AppColors.textSecondary),
                                            ),
                                          ],
                                        ),
                                      ),
                                      CupertinoSwitch(
                                        value: shareWithClass,
                                        onChanged: _profile?.hasGradeClass == true
                                            ? (value) => setSheetState(
                                                () => shareWithClass = value,
                                              )
                                            : null,
                                      ),
                                    ],
                                  ),
                                  _buildDateTimeTile(
                                    dialogContext: innerContext,
                                    label: '시작',
                                    dateTime: start,
                                    onChanged: (dt) => setSheetState(() => start = dt),
                                    enabled: !allDay,
                                  ),
                                  _buildDateTimeTile(
                                    dialogContext: innerContext,
                                    label: '종료',
                                    dateTime: end,
                                    onChanged: (dt) => setSheetState(() => end = dt),
                                    enabled: !allDay,
                                  ),
                                  SizedBox(height: innerContext.rh(8)),
                                  // 파일 첨부 (개인 일정만). 시험 시간표 이미지·PDF 등.
                                  if (!shareWithClass) ...[
                                    AppleButton(
                                      label: '파일 첨부 (이미지·PDF)',
                                      variant: AppleButtonVariant.secondary,
                                      icon: CupertinoIcons.paperclip,
                                      onPressed: () async {
                                        final result =
                                            await FilePicker.pickFiles(
                                          type: FileType.custom,
                                          allowedExtensions:
                                              PersonalEventAttachmentRepository
                                                  .allowedExtensions,
                                          allowMultiple: true,
                                        );
                                        if (result == null) return;
                                        setSheetState(() {
                                          pickedFiles.addAll(result.files
                                              .where((f) => f.path != null));
                                        });
                                      },
                                    ),
                                    for (var i = 0; i < pickedFiles.length; i++)
                                      Padding(
                                        padding: EdgeInsets.symmetric(
                                          vertical: innerContext.rh(4),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              pickedFiles[i].extension == 'pdf'
                                                  ? CupertinoIcons.doc_fill
                                                  : CupertinoIcons.photo,
                                              color: AppColors.primaryBlue,
                                            ),
                                            SizedBox(width: innerContext.rs(8)),
                                            Expanded(
                                              child: Text(
                                                pickedFiles[i].name,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            CupertinoButton(
                                              padding: EdgeInsets.zero,
                                              minimumSize: Size.zero,
                                              onPressed: () => setSheetState(
                                                () => pickedFiles.removeAt(i),
                                              ),
                                              child: Icon(
                                                CupertinoIcons.xmark,
                                                size: innerContext.rs(18),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.fromLTRB(
                              innerContext.rs(22),
                              0,
                              innerContext.rs(22),
                              innerContext.rh(24),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: AppleButton(
                                    label: '취소',
                                    variant: AppleButtonVariant.secondary,
                                    onPressed: () => Navigator.of(sheetContext).pop(false),
                                  ),
                                ),
                                SizedBox(width: innerContext.rs(12)),
                                Expanded(
                                  child: AppleButton(
                                    label: '추가',
                                    onPressed: () async {
                                      final uid = await AuthRepository.instance.getUserId();
                                      if (uid == null) {
                                        if (innerContext.mounted) {
                                          AppFeedback.showError(
                                            innerContext,
                                            '로그인 세션이 없습니다. 로그아웃 후 다시 로그인해 주세요.',
                                          );
                                        }
                                        return;
                                      }

                                      final title = titleController.text.trim();
                                      if (title.isEmpty) {
                                        if (innerContext.mounted) {
                                          AppFeedback.showError(
                                            innerContext,
                                            '제목을 입력해 주세요.',
                                          );
                                        }
                                        return;
                                      }

                                      try {
                                        final session = supabase.auth.currentSession;
                                        if (session != null) {
                                          final description = descController.text.trim().isEmpty
                                              ? null
                                              : descController.text.trim();
                                          if (shareWithClass) {
                                            final profile = _profile;
                                            final grade = profile?.gradeOrFromStudentId;
                                            final classNum = profile?.classNumOrFromStudentId;
                                            if (profile == null || grade == null || classNum == null) {
                                              if (innerContext.mounted) {
                                                AppFeedback.showError(
                                                  innerContext,
                                                  '학급 공유를 하려면 프로필에 학년/반 정보가 필요합니다.',
                                                );
                                              }
                                              return;
                                            }

                                            await supabase.from('class_events').insert({
                                              'grade': grade,
                                              'class_number': classNum,
                                              'title': title,
                                              'description': description,
                                              'start_at': start.toIso8601String(),
                                              'end_at': allDay ? null : end.toIso8601String(),
                                              'all_day': allDay,
                                              'created_by_user_id': uid,
                                              'created_by_profile_id': profile.id,
                                            });
                                          } else {
                                            final inserted = await supabase
                                                .from('personal_events')
                                                .insert({
                                                  'user_id': uid,
                                                  'title': title,
                                                  'description': description,
                                                  'start_at': start.toIso8601String(),
                                                  'end_at': allDay ? null : end.toIso8601String(),
                                                  'all_day': allDay,
                                                })
                                                .select('id')
                                                .single();

                                            final eventId =
                                                inserted['id'] as String?;
                                            if (eventId != null) {
                                              for (final f in pickedFiles) {
                                                final p = f.path;
                                                if (p == null) continue;
                                                try {
                                                  await PersonalEventAttachmentRepository
                                                      .instance
                                                      .uploadAttachment(
                                                    eventId: eventId,
                                                    file: File(p),
                                                    fileName: f.name,
                                                  );
                                                } catch (_) {}
                                              }
                                            }
                                          }
                                        } else {
                                          if (innerContext.mounted) {
                                            AppFeedback.showError(
                                              innerContext,
                                              '로그인 정보가 만료되었습니다. 다시 로그인한 뒤 개인 일정을 추가해 주세요.',
                                            );
                                          }
                                          return;
                                        }

                                        if (sheetContext.mounted) {
                                          Navigator.of(sheetContext).pop(true);
                                        }
                                      } on PostgrestException catch (e) {
                                        if (!innerContext.mounted) return;
                                        print('personal_events insert error: code=${e.code}, message=${e.message}, details=${e.details}');
                                        final message = switch (e.code) {
                                          '42501' => '권한 문제로 일정을 저장하지 못했습니다. 관리자에게 문의해 주세요.',
                                          'PGRST204' || 'PGRST301' =>
                                              '서버 설정이 아직 반영되지 않아 일정을 저장할 수 없습니다. 잠시 후 다시 시도해 주세요.',
                                          _ => '일정을 저장하는 중 오류가 발생했습니다. 잠시 후 다시 시도해 주세요.',
                                        };
                                        AppFeedback.showError(innerContext, message);
                                      } catch (e) {
                                        if (!innerContext.mounted) return;
                                        AppFeedback.showError(
                                          innerContext,
                                          '일정을 저장하는 중 알 수 없는 오류가 발생했습니다. 잠시 후 다시 시도해 주세요.',
                                        );
                                      }
                                    },
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
                },
              );
            },
          );
        },
      );

      if (added == true) {
        if (!mounted) return;
        _fetch();
        if (mounted) {
          AppFeedback.showSuccess(
            context,
            shareWithClass ? '학급 공유 일정이 추가되었습니다.' : '개인 일정이 추가되었습니다.',
          );
        }
      }
    } catch (e, st) {
      if (mounted) {
        AppFeedback.showError(
          context,
          '일정 추가 화면을 열 수 없습니다: ${e.toString().split('\n').first}',
        );
      }
      debugPrint('_showAddPersonalEventDialog error: $e\n$st');
    } finally {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        titleController.dispose();
        descController.dispose();
      });
    }
  }

  Future<void> _deletePersonalEvent(String id) async {
    final ok = await _confirmDelete(context);

    if (ok) {
      try {
        await PersonalEventAttachmentRepository.instance
            .deleteStorageFilesForEvent(id);
      } catch (_) {}
      await supabase.from('personal_events').delete().eq('id', id);
      _fetch();
      if (mounted) {
        AppFeedback.showSuccess(context, '개인 일정이 삭제되었습니다.');
      }
    }
  }

  Future<void> _deleteClassEvent(String id) async {
    final ok = await _confirmDelete(context);

    if (ok) {
      await supabase.from('class_events').delete().eq('id', id);
      _fetch();
      if (mounted) {
        AppFeedback.showSuccess(context, '학급 공유 일정이 삭제되었습니다.');
      }
    }
  }
}
