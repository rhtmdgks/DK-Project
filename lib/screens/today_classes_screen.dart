import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:myapp/core/auth/auth_state.dart';
import 'package:myapp/core/theme/app_theme.dart';
import 'package:myapp/core/theme/responsive.dart';

/// 오늘의 수업 더보기 페이지 (Figma DK-Project node 751-4242).
///
/// 메인 홈의 "오늘의 수업" 섹션에서 [더보기] 터치 시 진입.
/// 오늘 수강 과목을 세로 리스트 카드로 표시한다.
class TodayClassesScreen extends StatefulWidget {
  const TodayClassesScreen({super.key});

  @override
  State<TodayClassesScreen> createState() => _TodayClassesScreenState();
}

class _TodayClassesScreenState extends State<TodayClassesScreen> {
  String? _fullName;

  /// 홈과 동일한 샘플 오늘의 수업 데이터 (추후 API 연동 시 교체). 아이콘은 Material 3 Icons.
  static const _todayClasses = [
    _SubjectItem(name: '수학Ⅱ', icon: Icons.calculate_outlined),
    _SubjectItem(name: '수학Ⅱ', icon: Icons.calculate_outlined),
    _SubjectItem(name: '생명과학', icon: Icons.science_outlined),
    _SubjectItem(name: '국어', icon: Icons.menu_book_outlined),
    _SubjectItem(name: '영어', icon: Icons.translate),
  ];

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await getCurrentProfile();
      if (!mounted) return;
      setState(() => _fullName = profile?.fullName);
    } catch (_) {
      if (!mounted) return;
      setState(() => _fullName = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = _fullName ?? '학생';

    return CupertinoPageScaffold(
      backgroundColor: AppColors.background,
      navigationBar: CupertinoNavigationBar(
        heroTag: 'nav-today-classes',
        transitionBetweenRoutes: true,
        backgroundColor: AppColors.white,
        border: null,
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => context.pop(),
          child: const Icon(CupertinoIcons.back),
        ),
        middle: Text(
          '오늘의 수업',
          style: AppFonts.scaled(context, AppFonts.titleSemiBold)
              .copyWith(color: AppColors.textDark),
        ),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: SafeArea(
          top: false,
          child: ListView(
            padding: EdgeInsets.only(
              left: context.rs(24),
              right: context.rs(24),
              top: context.rh(8),
              bottom: context.rh(24),
            ),
            children: [
              Text(
                '오늘 $name님이 수강하실 과목이에요.',
                style: AppFonts.scaled(context, AppFonts.display3Regular),
              ),
              SizedBox(height: context.rh(20)),
              ..._todayClasses.asMap().entries.map((entry) {
                final index = entry.key;
                final subject = entry.value;
                return Padding(
                  padding: EdgeInsets.only(bottom: context.rh(16)),
                  child: _buildClassCard(context, subject),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildClassCard(BuildContext context, _SubjectItem subject) {
    final cardHeight = context.rh(120);
    final iconSize = context.rmin(44);

    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      height: cardHeight,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: AppShapes.borderRadiusLarge,
        border: Border.all(color: AppColors.borderLight),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withValues(alpha: 0.06),
            offset: const Offset(0, 4),
            blurRadius: 12,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: AppShapes.borderRadiusLarge,
        child: Stack(
          children: [
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              height: cardHeight * 0.55,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
                      AppColors.timetableBg,
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              top: cardHeight * 0.18,
              left: 0,
              right: 0,
              child: Center(
                child: Icon(
                  subject.icon,
                  size: iconSize,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
            Positioned(
              bottom: context.rh(14),
              left: 0,
              right: 0,
              child: Center(
                child: Text(
                  subject.name,
                  style: AppFonts.scaled(
                    context,
                    AppFonts.display3SemiBold,
                  ).copyWith(color: AppColors.textPrimary),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 과목 항목. [icon]은 Material 3 Icons.
class _SubjectItem {
  const _SubjectItem({
    required this.name,
    required this.icon,
  });

  final String name;
  final IconData icon;
}
