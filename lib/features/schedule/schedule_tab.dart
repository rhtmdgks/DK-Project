import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:myapp/core/auth/auth_state.dart';
import 'package:myapp/core/auth/auth_repository.dart';
import 'package:myapp/core/supabase_client.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:myapp/core/theme/app_theme.dart';
import 'package:myapp/core/theme/responsive.dart';
import 'package:myapp/core/widgets/async_body.dart';
import 'package:myapp/core/widgets/dismiss_keyboard.dart';
import 'package:myapp/core/widgets/m3_list.dart';
import 'package:myapp/core/widgets/tab_page_header.dart';

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

      // 학사일정(NEIS)은 연동하지 않고, 앱/백오피스에서 등록한 일정만 표시한다.
      final neisList = <Map<String, dynamic>>[];

      if (!mounted) return;
      setState(() {
        _items = List<Map<String, dynamic>>.from(scheduleRes as List);
        _personalEvents = personalRes;
        _classEvents = classRes;
        _neisItems = neisList;
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
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Column(
        children: [
          SafeArea(
            top: true,
            bottom: false,
            minimum: EdgeInsets.zero,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: context.rs(22)),
              child: TabPageHeader(
                title: '일정',
                subtitle: '날짜를 선택해 일정을 확인하세요. 개인 일정은 본인만, 「학급에 공유」로 넣은 일정은 같은 반 학생 모두에게 보입니다.',
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
            child: Material(
              type: MaterialType.transparency,
              child: AsyncBody(
                loading: _loading,
                error: _error,
                isEmpty: false,
                onRetry: _fetch,
                emptyMessage: '',
                child: RefreshIndicator(
                  onRefresh: _fetch,
                  child: ListView(
                    padding: context.horizontalPadding.copyWith(
                      top: context.rh(16),
                      bottom: context.rh(16),
                    ),
                    children: [
                      _buildCalendarSection(),
                      SizedBox(height: context.rh(24)),
                      _buildSectionTitle(),
                      SizedBox(height: context.rh(2)),
                      _buildScheduleList(),
                      SizedBox(height: context.rh(20)),
                      _buildNewEventButton(),
                      SizedBox(height: context.rh(24)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }

  /// iOS HIG 스타일: 가로로 긴, 둥근 모서리의 "새로운 이벤트" 버튼.
  Widget _buildNewEventButton() {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: context.rs(20)),
      child: Material(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: _showAddPersonalEventDialog,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: context.rs(16),
              vertical: context.rh(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.add_rounded,
                  size: context.rs(20),
                  color: theme.colorScheme.onSurface,
                ),
                SizedBox(width: context.rs(8)),
                Text(
                  '새로운 이벤트',
                  style: AppFonts.scaled(context, AppFonts.bodyMedium).copyWith(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
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
        color: Theme.of(context).colorScheme.surface,
        borderRadius: AppShapes.borderRadiusMedium,
        border: Border.all(color: AppColors.borderLight),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.06),
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
                                          : (isSunday
                                              ? AppColors.textSecondary
                                              : AppColors.textPrimary),
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
    return Padding(
      padding: EdgeInsets.only(left: context.rs(4)),
      child: Row(
        children: [
          Text(
            '$y년 $m월 $d일 일정',
            style: AppFonts.scaled(context, AppFonts.titleMedium),
          ),
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
      separatorBuilder: (_, __) => Divider(height: 1),
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

    Color leadingColor = Theme.of(context).colorScheme.primary;
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
      trailing: Icon(Icons.chevron_right, size: context.rs(20), color: AppColors.hint),
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

    // 학사일정(NEIS)은 삭제 불가. 개인 일정/학교 일정만 삭제 버튼 표시.
    if (!isNeis && id != null && (isPersonal || isClassOwner || _canEdit)) {
      actions.add(
        TextButton(
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
          child: Text('삭제', style: TextStyle(color: AppColors.error)),
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
      final added = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (dialogContext, setDialogState) {
              return AlertDialog(
                title: const Text('일정 추가'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CupertinoTextField(
                        controller: titleController,
                        placeholder: '제목',
                        padding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.border),
                        ),
                      ),
                      SizedBox(height: 8),
                      CupertinoTextField(
                        controller: descController,
                        placeholder: '설명',
                        padding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.border),
                        ),
                      ),
                      const SizedBox(height: 8),
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
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(false),
                    child: const Text('취소'),
                  ),
                  FilledButton(
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
                    child: const Text('추가'),
                  ),
                ],
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
    return ListTile(
      title: Text(label),
      subtitle: Text(
        enabled
            ? '${dateTime.year}년 ${dateTime.month}월 ${dateTime.day}일 ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}'
            : '하루 종일',
      ),
      enabled: enabled,
      onTap: enabled
          ? () async {
              final d = await showDatePicker(
                context: dialogContext,
                initialDate: dateTime,
                firstDate: DateTime(2020),
                lastDate: DateTime(2030),
              );
              if (d == null) return;
              if (!dialogContext.mounted) return;

              final t = await showTimePicker(
                context: dialogContext,
                initialTime: TimeOfDay.fromDateTime(dateTime),
              );
              if (t != null) {
                onChanged(DateTime(d.year, d.month, d.day, t.hour, t.minute));
              }
            }
          : null,
    );
  }

  Future<void> _delete(String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            child: const Text('삭제'),
          ),
        ],
      ),
    );

    if (ok == true) {
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

    if (!mounted) return;
    try {
      final added = await showModalBottomSheet<bool>(
        context: context,
        useRootNavigator: true,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        isDismissible: false,
        enableDrag: false,
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
                        color: Theme.of(innerContext).colorScheme.surface,
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
                                IconButton(
                                  onPressed: () => Navigator.of(sheetContext).pop(false),
                                  icon: const Icon(Icons.close),
                                  style: IconButton.styleFrom(
                                    foregroundColor: AppColors.textSecondary,
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
                                  CupertinoTextField(
                                    controller: titleController,
                                    placeholder: '제목',
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Theme.of(innerContext).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                                      borderRadius: BorderRadius.circular(AppShapes.radiusSmall),
                                      border: Border.all(color: AppColors.border),
                                    ),
                                  ),
                                  SizedBox(height: innerContext.rh(12)),
                                  CupertinoTextField(
                                    controller: descController,
                                    placeholder: '설명 (선택)',
                                    maxLines: 3,
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Theme.of(innerContext).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                                      borderRadius: BorderRadius.circular(AppShapes.radiusSmall),
                                      border: Border.all(color: AppColors.border),
                                    ),
                                  ),
                                  SizedBox(height: innerContext.rh(12)),
                                  CheckboxListTile(
                                    title: const Text('하루 종일'),
                                    value: allDay,
                                    onChanged: (value) => setSheetState(() => allDay = value ?? false),
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                  CheckboxListTile(
                                    title: const Text('반 전체에 공유하기'),
                                    subtitle: Text(
                                      _profile?.hasGradeClass != true
                                          ? '프로필에 학년/반 정보가 없어 학급 공유를 사용할 수 없습니다.'
                                          : '학생회 권한 없이 같은 반 학생 모두에게 표시됩니다.',
                                    ),
                                    value: shareWithClass,
                                    onChanged: _profile?.hasGradeClass == true
                                        ? (value) => setSheetState(() => shareWithClass = value ?? false)
                                        : null,
                                    contentPadding: EdgeInsets.zero,
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
                                  child: OutlinedButton(
                                    onPressed: () => Navigator.of(sheetContext).pop(false),
                                    child: const Text('취소'),
                                  ),
                                ),
                                SizedBox(width: innerContext.rs(12)),
                                Expanded(
                                  child: FilledButton(
                                    onPressed: () async {
                                      final uid = await AuthRepository.instance.getUserId();
                                      if (uid == null) {
                                        if (innerContext.mounted) {
                                          ScaffoldMessenger.of(innerContext).showSnackBar(
                                            const SnackBar(
                                              content: Text('로그인 세션이 없습니다. 로그아웃 후 다시 로그인해 주세요.'),
                                              behavior: SnackBarBehavior.floating,
                                            ),
                                          );
                                        }
                                        return;
                                      }

                                      final title = titleController.text.trim();
                                      if (title.isEmpty) {
                                        if (innerContext.mounted) {
                                          ScaffoldMessenger.of(innerContext).showSnackBar(
                                            const SnackBar(
                                              content: Text('제목을 입력해 주세요.'),
                                              behavior: SnackBarBehavior.floating,
                                            ),
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
                                                ScaffoldMessenger.of(innerContext).showSnackBar(
                                                  const SnackBar(
                                                    content: Text('학급 공유를 하려면 프로필에 학년/반 정보가 필요합니다.'),
                                                    behavior: SnackBarBehavior.floating,
                                                  ),
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
                                            // Supabase Auth 세션이 있는 경우: RLS(auth.uid() = user_id) 기준으로 직접 insert.
                                            await supabase.from('personal_events').insert({
                                              'user_id': uid,
                                              'title': title,
                                              'description': description,
                                              'start_at': start.toIso8601String(),
                                              'end_at': allDay ? null : end.toIso8601String(),
                                              'all_day': allDay,
                                            });
                                          }
                                        } else {
                                          if (innerContext.mounted) {
                                            ScaffoldMessenger.of(innerContext).showSnackBar(
                                              const SnackBar(
                                                content: Text('로그인 정보가 만료되었습니다. 다시 로그인한 뒤 개인 일정을 추가해 주세요.'),
                                                behavior: SnackBarBehavior.floating,
                                                backgroundColor: AppColors.error,
                                              ),
                                            );
                                          }
                                          return;
                                        }

                                        if (sheetContext.mounted) {
                                          Navigator.of(sheetContext).pop(true);
                                        }
                                      } on PostgrestException catch (e) {
                                        if (!innerContext.mounted) return;
                                        // 개발용 상세 로그
                                        // ignore: avoid_print
                                        print('personal_events insert error: code=${e.code}, message=${e.message}, details=${e.details}');
                                        final message = switch (e.code) {
                                          // RLS/권한 문제
                                          '42501' => '권한 문제로 일정을 저장하지 못했습니다. 관리자에게 문의해 주세요.',
                                          // 정의되지 않은 함수 등 스키마 불일치
                                          'PGRST204' || 'PGRST301' =>
                                              '서버 설정이 아직 반영되지 않아 일정을 저장할 수 없습니다. 잠시 후 다시 시도해 주세요.',
                                          _ => '일정을 저장하는 중 오류가 발생했습니다. 잠시 후 다시 시도해 주세요.',
                                        };
                                        ScaffoldMessenger.of(innerContext).showSnackBar(
                                          SnackBar(
                                            content: Text(message),
                                            behavior: SnackBarBehavior.floating,
                                            backgroundColor: AppColors.error,
                                          ),
                                        );
                                      } catch (e) {
                                        if (!innerContext.mounted) return;
                                        ScaffoldMessenger.of(innerContext).showSnackBar(
                                          const SnackBar(
                                            content: Text('일정을 저장하는 중 알 수 없는 오류가 발생했습니다. 잠시 후 다시 시도해 주세요.'),
                                            behavior: SnackBarBehavior.floating,
                                            backgroundColor: AppColors.error,
                                          ),
                                        );
                                      }
                                    },
                                    child: const Text('추가'),
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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                shareWithClass ? '학급 공유 일정이 추가되었습니다.' : '개인 일정이 추가되었습니다.',
              ),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              margin: const EdgeInsets.only(
                bottom: 80,
                left: 16,
                right: 16,
              ),
            ),
          );
        }
      }
    } catch (e, st) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('일정 추가 화면을 열 수 없습니다: ${e.toString().split('\n').first}'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.error,
          ),
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
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            child: const Text('삭제'),
          ),
        ],
      ),
    );

    if (ok == true) {
      await supabase.from('personal_events').delete().eq('id', id);
      _fetch();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('개인 일정이 삭제되었습니다.'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            margin: const EdgeInsets.only(
              bottom: 80,
              left: 16,
              right: 16,
            ),
          ),
        );
      }
    }
  }

  Future<void> _deleteClassEvent(String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            child: const Text('삭제'),
          ),
        ],
      ),
    );

    if (ok == true) {
      await supabase.from('class_events').delete().eq('id', id);
      _fetch();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('학급 공유 일정이 삭제되었습니다.'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            margin: const EdgeInsets.only(
              bottom: 80,
              left: 16,
              right: 16,
            ),
          ),
        );
      }
    }
  }
}
