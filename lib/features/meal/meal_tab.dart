import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:myapp/core/supabase_client.dart';
import 'package:myapp/core/theme/app_theme.dart';
import 'package:myapp/core/theme/responsive.dart';
import 'package:myapp/core/widgets/tab_page_header.dart';

/// Figma "급식 페이지" (node 753-7394, 758-7664) 급식 메뉴 탭.
///
/// NEIS Edge Function으로 급식 데이터를 조회한다.
/// 상단 "캘린더 들어갈 자리"에는 Flutter 기본 위젯(CupertinoIcons.calendar)으로 만든
/// 월간 캘린더를 두고, 선택한 날짜의 점심/석식 메뉴를 카드로 표시한다.
/// 반응형: compact/medium/expanded 대응.
class MealTab extends StatefulWidget {
  const MealTab({super.key});

  @override
  State<MealTab> createState() => _MealTabState();
}

bool _isSameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

class _MealTabState extends State<MealTab> {
  static final _allergenPattern = RegExp(r'\(.*?\)');
  static const _weekHeaders = ['일', '월', '화', '수', '목', '금', '토'];

  bool _loading = false;
  String? _error;
  Map<String, dynamic>? _data;
  DateTime _selectedDate = DateTime.now();
  /// 캘린더에 표시할 월 (이동용)
  DateTime _viewMonth = DateTime(DateTime.now().year, DateTime.now().month);

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final d = _selectedDate;
    final dateStr =
        '${d.year}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}';

    try {
      final res = await supabase.functions.invoke(
        'neis_meal',
        queryParameters: {'date': dateStr},
        body: {'date': dateStr},
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw Exception('요청 시간이 초과되었습니다. 네트워크를 확인해 주세요.'),
      );

      if (res.status != 200) {
        final data =
            res.data is Map ? res.data as Map<String, dynamic> : null;
        final msg = data?['message'] as String? ??
            data?['code']?.toString() ??
            '급식 정보를 불러올 수 없습니다. (${res.status})';
        throw Exception(msg);
      }

      final data = res.data;
      if (data is! Map<String, dynamic>) {
        throw Exception('급식 데이터 형식이 올바르지 않습니다.');
      }

      if (!mounted) return;
      setState(() {
        _data = data;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      String msg = e.toString();
      if (e is FunctionException && e.details != null) {
        final details = e.details;
        if (details is Map<String, dynamic>) {
          msg = details['message'] as String? ??
              details['code']?.toString() ??
              msg;
        }
      }
      msg = msg
          .replaceFirst('Exception: ', '')
          .replaceFirst('Exception:', '')
          .trim();
      if (msg.isEmpty) msg = '급식 정보를 불러올 수 없습니다.';

      setState(() {
        _error = msg;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _fetch,
        color: Theme.of(context).colorScheme.primary,
        child: ListView(
          padding: EdgeInsets.only(bottom: context.rh(24)),
          children: [
            _buildHeader(),
            SizedBox(height: context.rh(10)),
            _buildCalendarCard(),
            SizedBox(height: context.rh(10)),
            _buildBodyContent(),
          ],
        ),
      ),
    );
  }

  // ── Header ──

  Widget _buildHeader() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: context.rs(22)),
      child: TabPageHeader(
        title: '급식',
        subtitle: '점심과 석식 메뉴를 확인해보세요!',
      ),
    );
  }

  // ── 캘린더 (일정 탭과 동일한 모양) ──

  Widget _buildCalendarCard() {
    final year = _viewMonth.year;
    final month = _viewMonth.month;
    final first = DateTime(year, month, 1);
    final last = DateTime(year, month + 1, 0);
    final weekdayOfFirst = first.weekday % 7; // 일=0, 월=1, ... 토=6
    final daysInMonth = last.day;
    final totalCells = weekdayOfFirst + daysInMonth;
    final rowCount = (totalCells / 7).ceil().clamp(1, 6);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: context.rs(22)),
      child: Container(
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
                  minSize: 0,
                  onPressed: () {
                    setState(() {
                      _viewMonth = DateTime(year, month - 1);
                    });
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
                  minSize: 0,
                  onPressed: () {
                    setState(() {
                      _viewMonth = DateTime(year, month + 1);
                    });
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(7, (i) {
                final isSun = i == 0;
                return SizedBox(
                  width: context.rs(36),
                  child: Center(
                    child: Text(
                      _weekHeaders[i],
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
            LayoutBuilder(
              builder: (context, constraints) {
                final cellSize = (constraints.maxWidth - 6 * 2) / 7;
                var day = 1 - weekdayOfFirst;
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(rowCount, (r) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
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
                          return GestureDetector(
                            onTap: isCurrentMonth
                                ? () {
                                    setState(() => _selectedDate = date!);
                                    _fetch();
                                  }
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
                                child: Text(
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
      ),
    );
  }

  // ── Content (캘린더와 함께 한 ListView에서 스크롤) ──

  Widget _buildBodyContent() {
    if (_loading) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: context.rh(32)),
        child: Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      );
    }

    if (_error != null) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: context.rh(32)),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _error!,
                style: AppFonts.scaled(context, AppFonts.smallRegular)
                    .copyWith(color: AppColors.error),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: context.rh(16)),
              TextButton(
                onPressed: _fetch,
                child: const Text('다시 시도'),
              ),
            ],
          ),
        ),
      );
    }

    final meals = _data?['meals'] as List<dynamic>? ?? [];
    if (meals.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: context.rh(32)),
        child: Center(
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
                '해당 날짜에 급식이 없습니다.',
                style: AppFonts.scaled(context, AppFonts.bodyRegular),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: context.horizontalPadding.copyWith(top: context.rh(4)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          RichText(
            text: TextSpan(
              style: AppFonts.scaled(context, AppFonts.bodyMedium)
                  .copyWith(color: AppColors.textDark),
              children: [
                TextSpan(
                  text: '오늘  ',
                  style: TextStyle(color: AppColors.timetableHighlight),
                ),
                TextSpan(
                  text: '${_selectedDate.month}월 ${_selectedDate.day}일',
                ),
              ],
            ),
          ),
          SizedBox(height: context.rh(12)),
          for (final row in meals)
            _buildMealCard(row as Map<String, dynamic>),
        ],
      ),
    );
  }

  // ── Meal Card ──

  Widget _buildMealCard(Map<String, dynamic> row) {
    final dish = row['DDISH_NM'] as String? ?? '';
    final cal = row['CAL_INFO'] as String? ?? '';
    final mealType = row['MMEAL_SC_NM'] as String? ?? '';

    final menuItems = dish
        .split('<br/>')
        .map((s) => s.replaceAll(_allergenPattern, '').trim())
        .where((s) => s.isNotEmpty)
        .toList();

    final cardPad = context.rs(16);
    final mealTypeWidth = context.rs(80);

    return Container(
      margin: EdgeInsets.only(bottom: context.rh(16)),
      padding: EdgeInsets.all(cardPad),
      decoration: BoxDecoration(
        color: AppColors.timetableBg,
        borderRadius: AppShapes.borderRadiusSmall,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 좌측 - 식사 유형 + 칼로리
          SizedBox(
            width: mealTypeWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  mealType.isEmpty ? '급식' : mealType,
                  style: AppFonts.scaled(context, AppFonts.titleMedium),
                ),
                SizedBox(height: context.rh(24)),
                if (cal.isNotEmpty)
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: context.rs(8),
                      vertical: context.rh(2),
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.white.withValues(alpha: 0.7),
                      borderRadius: AppShapes.borderRadiusSmall,
                    ),
                    child: Text(
                      cal,
                      style: AppFonts.scaled(context, AppFonts.tiny)
                          .copyWith(color: AppColors.textDark.withValues(alpha: 0.7)),
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(width: context.rs(16)),

          // 우측 - 메뉴 목록
          Expanded(
            child: Container(
              padding: EdgeInsets.all(context.rs(12)),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: AppShapes.borderRadiusExtraSmall,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: menuItems
                    .map((item) => Padding(
                          padding: EdgeInsets.only(bottom: context.rh(4)),
                          child: Text(
                            item,
                            style: AppFonts.scaled(context, AppFonts.smallMedium)
                                .copyWith(color: AppColors.textDark),
                          ),
                        ))
                    .toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
