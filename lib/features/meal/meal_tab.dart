import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:myapp/core/supabase_client.dart';
import 'package:myapp/core/theme/app_theme.dart';
import 'package:myapp/core/theme/responsive.dart';

/// Figma "급식 페이지" (node 263:1526) 급식 탭.
///
/// NEIS Edge Function을 통해 급식 데이터를 조회하고,
/// 주간 날짜 선택기와 함께 점심/석식 메뉴를 카드로 표시한다.
/// 반응형: compact/medium/expanded 대응.
class MealTab extends StatefulWidget {
  const MealTab({super.key});

  @override
  State<MealTab> createState() => _MealTabState();
}

class _MealTabState extends State<MealTab> {
  static final _allergenPattern = RegExp(r'\(.*?\)');
  static const _weekdays = ['일', '월', '화', '수', '목', '금', '토'];

  bool _loading = false;
  String? _error;
  Map<String, dynamic>? _data;
  DateTime _selectedDate = DateTime.now();

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

    try {
      final d = _selectedDate;
      final dateStr = '${d.year}'
          '${d.month.toString().padLeft(2, '0')}'
          '${d.day.toString().padLeft(2, '0')}';

      final res = await supabase.functions.invoke(
        'neis_meal',
        queryParameters: {'date': dateStr},
      );

      if (res.status != 200) {
        final data =
            res.data is Map ? res.data as Map<String, dynamic> : null;
        final msg = data?['message'] ??
            data?['code']?.toString() ??
            '급식 정보를 불러올 수 없습니다';
        throw Exception(msg);
      }

      if (!mounted) return;
      setState(() {
        _data = res.data as Map<String, dynamic>?;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      String msg = e.toString();
      if (e is FunctionException && e.details != null) {
        final d = e.details as Map<String, dynamic>?;
        msg = d?['message'] as String? ?? d?['code']?.toString() ?? msg;
      }

      setState(() {
        _error = msg.replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  void _changeDate(int delta) {
    setState(() => _selectedDate = _selectedDate.add(Duration(days: delta)));
    _fetch();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          SizedBox(height: context.rh(16)),
          _buildDateSelector(),
          SizedBox(height: context.rh(16)),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  // ── Header ──

  Widget _buildHeader() {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        context.rs(14),
        context.rh(14),
        context.rs(14),
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '급식',
            style: AppFonts.scaled(context, AppFonts.titleBold),
          ),
          SizedBox(height: context.rh(4)),
          Text(
            '점심과 석식 메뉴를 확인해보세요!',
            style: AppFonts.scaled(context, AppFonts.captionRegular).copyWith(
              color: AppColors.textDark.withAlpha(153),
            ),
          ),
        ],
      ),
    );
  }

  // ── Date Selector ──

  Widget _buildDateSelector() {
    final weekdayIndex = _selectedDate.weekday % 7;
    final selectorPad = context.rs(32);

    return Column(
      children: [
        // 월 표시 + 화살표
        Padding(
          padding: EdgeInsets.symmetric(horizontal: selectorPad),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: () => _changeDate(-7),
                child: Padding(
                  padding: EdgeInsets.all(context.rs(8)),
                  child: Text(
                    '<',
                    style: AppFonts.scaled(context, AppFonts.smallMedium)
                        .copyWith(color: AppColors.timetableHighlight),
                  ),
                ),
              ),
              const Spacer(),
              Text(
                '${_selectedDate.month}월',
                style: AppFonts.scaled(context, AppFonts.smallMedium)
                    .copyWith(color: AppColors.textDark),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => _changeDate(7),
                child: Padding(
                  padding: EdgeInsets.all(context.rs(8)),
                  child: Text(
                    '>',
                    style: AppFonts.scaled(context, AppFonts.smallMedium)
                        .copyWith(color: AppColors.timetableHighlight),
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: context.rh(8)),

        // 요일 헤더
        Padding(
          padding: EdgeInsets.symmetric(horizontal: selectorPad),
          child: Row(
            children: List.generate(7, (i) {
              final Color color;
              if (i == 0) {
                color = AppColors.error;
              } else if (i == 6) {
                color = AppColors.timetableHighlight;
              } else {
                color = AppColors.textDark;
              }

              return Expanded(
                child: Center(
                  child: Text(
                    _weekdays[i],
                    style: AppFonts.scaled(context, AppFonts.displayRegular)
                        .copyWith(
                      color: color,
                      fontWeight:
                          i == weekdayIndex ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
        SizedBox(height: context.rh(6)),

        // 날짜 숫자 행
        Container(
          margin: EdgeInsets.symmetric(horizontal: selectorPad),
          padding: EdgeInsets.symmetric(vertical: context.rh(8)),
          decoration: BoxDecoration(
            color: AppColors.timetableBg,
            borderRadius: BorderRadius.circular(context.rs(4)),
          ),
          child: Row(
            children: List.generate(7, (i) {
              final offset = i - weekdayIndex;
              final d = _selectedDate.add(Duration(days: offset));
              final isSelected =
                  d.day == _selectedDate.day && d.month == _selectedDate.month;
              final dotSize = context.rs(24);

              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() => _selectedDate = d);
                    _fetch();
                  },
                  child: Center(
                    child: Container(
                      width: dotSize,
                      height: dotSize,
                      decoration: isSelected
                          ? BoxDecoration(
                              shape: BoxShape.circle,
                              color:
                                  AppColors.timetableHighlight.withAlpha(77),
                            )
                          : null,
                      alignment: Alignment.center,
                      child: Text(
                        '${d.day}',
                        style: AppFonts.scaled(
                                context, AppFonts.displayRegular)
                            .copyWith(
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.w400,
                          color: AppColors.textDark,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),

        // 접기 표시기
        Container(
          margin: EdgeInsets.symmetric(horizontal: selectorPad),
          padding: EdgeInsets.symmetric(vertical: context.rh(4)),
          decoration: BoxDecoration(
            color: AppColors.timetableAccent,
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(context.rs(20)),
              bottomRight: Radius.circular(context.rs(20)),
            ),
          ),
          child: Center(
            child: Icon(
              CupertinoIcons.chevron_down,
              size: context.rs(16),
              color: AppColors.textDark,
            ),
          ),
        ),
      ],
    );
  }

  // ── Content ──

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CupertinoActivityIndicator(radius: 12));
    }

    if (_error != null) {
      return Center(
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
      );
    }

    final meals = _data?['meals'] as List<dynamic>? ?? [];
    if (meals.isEmpty) {
      return Center(
        child: Text(
          '해당 날짜에 급식이 없습니다.',
          style: AppFonts.scaled(context, AppFonts.bodyRegular),
          textAlign: TextAlign.center,
        ),
      );
    }

    return ListView(
      padding: context.horizontalPadding.copyWith(
        top: context.rh(8),
        bottom: context.rh(8),
      ),
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
        SizedBox(height: context.rh(16)),
        for (final row in meals)
          _buildMealCard(row as Map<String, dynamic>),
      ],
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
        borderRadius: BorderRadius.circular(context.rs(12)),
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
                      color: AppColors.white.withAlpha(179),
                      borderRadius: BorderRadius.circular(context.rs(10)),
                    ),
                    child: Text(
                      cal,
                      style: AppFonts.scaled(context, AppFonts.tiny)
                          .copyWith(color: AppColors.textDark.withAlpha(179)),
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
                color: AppColors.white,
                borderRadius: BorderRadius.circular(context.rs(8)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: menuItems
                    .map((item) => Padding(
                          padding: EdgeInsets.only(bottom: context.rh(2)),
                          child: Text(
                            item,
                            style: AppFonts.scaled(context, AppFonts.tiny)
                                .copyWith(
                              color: AppColors.textDark.withAlpha(179),
                            ),
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
