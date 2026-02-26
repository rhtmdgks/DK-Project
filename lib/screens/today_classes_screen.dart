import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:myapp/core/auth/auth_state.dart';
import 'package:myapp/core/supabase_client.dart';
import 'package:myapp/core/theme/app_theme.dart';
import 'package:myapp/core/theme/responsive.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 오늘의 수업 더보기 페이지 (Figma node 388:2726).
///
/// 메인 홈의 "오늘의 수업" 섹션에서 [더보기] 터치 시 진입.
/// 타임라인 형식으로 오늘 수강 과목을 표시한다.
class TodayClassesScreen extends StatefulWidget {
  const TodayClassesScreen({super.key});

  @override
  State<TodayClassesScreen> createState() => _TodayClassesScreenState();
}

class _TodayClassesScreenState extends State<TodayClassesScreen> {
  DateTime _selectedDate = DateTime.now();

  /// 샘플 오늘의 수업 데이터 (추후 API 연동 시 교체).
  static const _todayClasses = [
    _ClassItem(
      name: '화학',
      chapter: '3교시 - 2층 창의융합실',
      startTime: '08:30',
      endTime: '09:20',
      location: '2-창의융합실',
      teacher: '김선생님',
    ),
    _ClassItem(
      name: '수학Ⅱ',
      chapter: '1단원: 함수',
      startTime: '09:30',
      endTime: '10:20',
      location: '6-205',
      teacher: '이선생님',
    ),
    _ClassItem(
      name: '생명과학',
      chapter: '3단원: 동물계',
      startTime: '10:30',
      endTime: '11:20',
      location: '2-168',
      teacher: '오신영 선생님',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      // 세션이 있으면 기존 로직 사용
      final session = supabase.auth.currentSession;
      if (session != null) {
        await getCurrentProfile();
      } else {
        // 세션이 없으면 SharedPreferences에서 user_id를 가져와서 직접 프로필 조회
        final prefs = await SharedPreferences.getInstance();
        final loggedInUserId = prefs.getString('logged_in_user_id');
        
        if (loggedInUserId != null) {
          try {
            final row = await supabase
                .from('profiles')
                .select()
                .eq('user_id', loggedInUserId)
                .maybeSingle();
            if (row != null) {
              AppProfile.fromJson(row);
            }
          } catch (_) {
            // 프로필 조회 실패 시 무시
          }
        }
      }
      
      if (!mounted) return;
    } catch (_) {
      if (!mounted) return;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(CupertinoIcons.back),
          color: AppColors.textDark,
          onPressed: () => context.pop(),
        ),
        title: Text(
          '일정',
          style: AppFonts.scaled(context, AppFonts.titleSemiBold)
              .copyWith(color: AppColors.textDark),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: EdgeInsets.symmetric(
            horizontal: context.rs(24),
            vertical: context.rh(20),
          ),
          children: [
            _buildDateHeader(),
            SizedBox(height: context.rh(24)),
            _buildCalendarStrip(),
            SizedBox(height: context.rh(32)),
            _buildTimeline(),
          ],
        ),
      ),
    );
  }

  /// 상단 날짜 헤더: 날짜 + "Today" 표시
  Widget _buildDateHeader() {
    final now = DateTime.now();
    final year = now.year;
    final month = now.month;
    final day = now.day;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$year년 $month월 $day일',
          style: AppFonts.scaled(context, AppFonts.titleMedium)
              .copyWith(color: AppColors.textDark),
        ),
        SizedBox(height: context.rh(8)),
        Text(
          'Today',
          style: AppFonts.scaled(context, AppFonts.heading1Medium)
              .copyWith(
            fontSize: context.rs(32),
            fontWeight: FontWeight.w700,
            color: AppColors.textDark,
          ),
        ),
      ],
    );
  }

  /// 가로 캘린더 스트립
  Widget _buildCalendarStrip() {
    final now = DateTime.now();
    // 선택된 날짜가 속한 주의 시작일 계산 (월요일 기준)
    final startOfWeek = _selectedDate.subtract(
      Duration(days: (_selectedDate.weekday - 1) % 7),
    );
    final dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(7, (index) {
        final date = startOfWeek.add(Duration(days: index));
        final isToday = date.day == now.day &&
            date.month == now.month &&
            date.year == now.year;
        final isSelected = date.day == _selectedDate.day &&
            date.month == _selectedDate.month &&
            date.year == _selectedDate.year;

        return GestureDetector(
          onTap: () => setState(() => _selectedDate = date),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                dayNames[index],
                style: AppFonts.scaled(context, AppFonts.display3Regular)
                    .copyWith(
                  color: isSelected || isToday
                      ? AppColors.primaryBlue
                      : AppColors.textSecondary,
                  fontWeight: isSelected || isToday ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
              SizedBox(height: context.rh(4)),
              Text(
                '${date.day}',
                style: AppFonts.scaled(context, AppFonts.display3SemiBold)
                    .copyWith(
                  color: isSelected || isToday
                      ? AppColors.primaryBlue
                      : AppColors.textPrimary,
                  fontWeight: isSelected || isToday ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
              if (isSelected || isToday)
                Container(
                  margin: EdgeInsets.only(top: context.rh(4)),
                  width: context.rs(24),
                  height: context.rh(2),
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue,
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
            ],
          ),
        );
      }),
    );
  }

  /// 타임라인 뷰
  Widget _buildTimeline() {
    return Stack(
      children: [
        // 왼쪽 타임라인 세로선
        Positioned(
          left: context.rs(40),
          top: 0,
          bottom: 0,
          child: Container(
            width: context.rs(2),
            decoration: BoxDecoration(
              color: AppColors.primaryBlue,
              borderRadius: BorderRadius.circular(1),
            ),
          ),
        ),
        // 수업 항목들
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: _todayClasses.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            final isFirst = index == 0;
            
            return Padding(
              padding: EdgeInsets.only(
                left: context.rs(0),
                bottom: context.rh(24),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 타임라인 점과 시간
                  SizedBox(
                    width: context.rs(80),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: context.rs(12),
                              height: context.rs(12),
                              decoration: BoxDecoration(
                                color: AppColors.primaryBlue,
                                shape: BoxShape.circle,
                              ),
                            ),
                            SizedBox(width: context.rs(8)),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.startTime,
                                  style: AppFonts.scaled(
                                    context,
                                    AppFonts.display3SemiBold,
                                  ).copyWith(color: AppColors.textPrimary),
                                ),
                                Text(
                                  item.endTime,
                                  style: AppFonts.scaled(
                                    context,
                                    AppFonts.display3Regular,
                                  ).copyWith(color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: context.rs(16)),
                  // 수업 카드
                  Expanded(
                    child: isFirst
                        ? _buildClassCard(item)
                        : _buildPlaceholderCard(),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  /// 수업 카드 (첫 번째 카드: 흰색 배경 + 파란색 테두리)
  Widget _buildClassCard(_ClassItem item) {
    return Container(
      padding: EdgeInsets.all(context.rs(16)),
      decoration: BoxDecoration(
        color: AppColors.white,
        border: Border.all(
          color: AppColors.primaryBlue,
          width: 1,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            offset: const Offset(0, 2),
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${item.name} |',
                      style: AppFonts.scaled(context, AppFonts.titleSemiBold)
                          .copyWith(color: AppColors.textDark),
                    ),
                    SizedBox(height: context.rh(4)),
                    Text(
                      item.chapter,
                      style: AppFonts.scaled(context, AppFonts.display3Regular)
                          .copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.more_vert),
                iconSize: context.rs(20),
                color: AppColors.textSecondary,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () {},
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 플레이스홀더 카드 (회색 배경)
  Widget _buildPlaceholderCard() {
    return Container(
      padding: EdgeInsets.all(context.rs(16)),
      decoration: BoxDecoration(
        color: AppColors.borderLight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: SizedBox(
        height: context.rh(80),
      ),
    );
  }
}

/// 수업 항목 데이터
class _ClassItem {
  const _ClassItem({
    required this.name,
    required this.chapter,
    required this.startTime,
    required this.endTime,
    required this.location,
    required this.teacher,
  });

  final String name;
  final String chapter;
  final String startTime;
  final String endTime;
  final String location;
  final String teacher;
}
