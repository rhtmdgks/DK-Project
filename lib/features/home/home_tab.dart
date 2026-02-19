import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:myapp/core/auth/auth_state.dart';
import 'package:myapp/core/routing/app_router.dart';
import 'package:myapp/core/theme/app_theme.dart';
import 'package:myapp/core/theme/responsive.dart';
import 'package:myapp/core/widgets/laon_icon.dart';
import 'package:myapp/widgets/notification_side_sheet.dart';

/// Figma "App Wireframes > HOME" (node 296:5429) 홈 대시보드 탭.
///
/// 구성:
/// 1. 커스텀 앱바 (LAON 로고 + 알림/설정 아이콘)
/// 2. 프로필 인사말
/// 3. 오늘의 수업 (Material 3 카드)
/// 4. 다음 시간 과목 (상세 정보 카드)
class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  String? _fullName;
  String? _avatarUrl;
  bool _loading = true;


  /// 샘플 오늘의 수업 데이터 (추후 API 연동 시 교체). 아이콘은 Material 3 Icons.
  static const _todayClasses = [
    _SubjectCard(name: '수학Ⅱ', icon: Icons.calculate_outlined, period: 1),
    _SubjectCard(name: '수학Ⅱ', icon: Icons.calculate_outlined, period: 2),
    _SubjectCard(name: '생명과학', icon: Icons.science_outlined, period: 3),
    _SubjectCard(name: '국어', icon: Icons.menu_book_outlined, period: 4),
    _SubjectCard(name: '영어', icon: Icons.translate, period: 5),
  ];

  /// 샘플 다음 시간 과목 데이터
  static const _nextClass = _NextClassInfo(
    name: '생명과학',
    period: 3,
    location: '2-10',
    time: '10:30',
    teacher: '오신영 선생님',
    notice: '수행평가가 예정되어있어요!',
    icon: Icons.science_outlined,
  );

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await getCurrentProfile();
      if (!mounted) return;
      setState(() {
        _fullName = profile?.fullName;
        _avatarUrl = profile?.avatarUrl;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: _loadProfile,
        child: _loading
            ? Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Theme.of(context).colorScheme.primary,
                ),
              )
            : ListView(
                padding: EdgeInsets.zero,
                children: [
                  _buildAppBar(),
                  SizedBox(height: context.rh(24)),
                  _buildGreeting(),
                  SizedBox(height: context.rh(28)),
                  _buildTodayClassesSection(),
                  SizedBox(height: context.rh(24)),
                  _buildNextClassSection(),
                  SizedBox(height: context.rh(32)),
                ],
              ),
      ),
    );
  }

  // ── 1. 앱바: LAON 로고 + 알림/설정 ──

  Widget _buildAppBar() {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: context.rs(22),
        vertical: context.rh(12),
      ),
      child: Row(
        children: [
          LaonIcon(size: context.rmin(36)),
          SizedBox(width: context.rs(7)),
          Text(
            'LAON',
            style: AppFonts.scaled(context, AppFonts.heading2Medium),
          ),
          const Spacer(),
          _buildIconButton(
            'assets/images/icon_bell.svg',
            onTap: () => showNotificationSideSheet(context),
          ),
          SizedBox(width: context.rs(28)),
          _buildIconButton(
            'assets/images/icon_settings.svg',
            onTap: () => context.push(AppRoute.settings.path),
          ),
        ],
      ),
    );
  }

  Widget _buildIconButton(String svgPath, {VoidCallback? onTap}) {
    final size = context.rs(24);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: size,
        height: size,
        child: SvgPicture.asset(
          svgPath,
          width: size,
          height: size,
          fit: BoxFit.contain,
        ),
      ),
    );
  }


  // ── 2. 프로필 인사말 ──

  Widget _buildGreeting() {
    final name = _fullName ?? '학생';
    final avatarSize = context.rmin(64);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: context.rs(22)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: avatarSize,
            height: avatarSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.white,
              border: Border.all(
                color: AppColors.border,
                width: 1.5,
              ),
              boxShadow: const [
                BoxShadow(
                  color: AppColors.cardShadow,
                  offset: Offset(0, 2),
                  blurRadius: 8,
                ),
              ],
            ),
            child: ClipOval(
              child: _avatarUrl != null && _avatarUrl!.isNotEmpty
                  ? SvgPicture.network(
                      _avatarUrl!,
                      width: avatarSize,
                      height: avatarSize,
                      fit: BoxFit.contain,
                      placeholderBuilder: (context) => Icon(
                        CupertinoIcons.person_fill,
                        size: context.rmin(36),
                        color: AppColors.primaryBlue500,
                      ),
                    )
                  : Icon(
                      CupertinoIcons.person_fill,
                      size: context.rmin(36),
                      color: AppColors.primaryBlue500,
                    ),
            ),
          ),
          SizedBox(width: context.rs(12)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '안녕하세요 $name님,',
                  style: AppFonts.scaled(context, AppFonts.titleMedium),
                ),
                Text(
                  _greetingMessage(),
                  style: AppFonts.scaled(context, AppFonts.titleMedium),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── 3. 오늘의 수업 섹션 ──

  Widget _buildTodayClassesSection() {
    final name = _fullName ?? '학생';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: context.rs(26)),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '오늘의 수업',
                style: AppFonts.scaled(context, AppFonts.sectionTitle),
              ),
              const Spacer(),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => context.push(AppRoute.todayClasses.path),
                  borderRadius: AppShapes.borderRadiusExtraLarge,
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: context.rs(14),
                      vertical: context.rh(8),
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .primaryContainer
                          .withValues(alpha: 0.6),
                      borderRadius: AppShapes.borderRadiusExtraLarge,
                    ),
                    child: Text(
                      '더보기',
                      style: AppFonts.scaled(
                        context,
                        AppFonts.display3Medium,
                      ).copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w600,
                        fontSize: context.rs(14),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: context.rh(2)),
        Padding(
          padding: EdgeInsets.only(left: context.rs(27)),
          child: Text(
            '오늘 $name님이 수강하실 과목이에요.',
            style: AppFonts.scaled(context, AppFonts.display3Regular),
          ),
        ),
        SizedBox(height: context.rh(16)),
        _buildTodayClassesList(),
      ],
    );
  }

  /// 오늘의 수업 리스트 (가로 스크롤)
  static const double _cardSquareSize = 160;

  Widget _buildTodayClassesList() {
    return SizedBox(
      height: _cardSquareSize,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: context.rs(22)),
        itemCount: _todayClasses.length,
        itemBuilder: (context, index) {
          return Padding(
            padding: EdgeInsets.only(
              right: index < _todayClasses.length - 1 ? context.rs(12) : 0,
            ),
            child: _buildTodayClassCard(_todayClasses[index]),
          );
        },
      ),
    );
  }

  /// M2 스타일 정사각형 카드. Card + elevation, 교시 + 과목 아이콘 + 이름.
  Widget _buildTodayClassCard(_SubjectCard subject) {
    const double size = _cardSquareSize;
    final theme = Theme.of(context);

    return SizedBox(
      width: size,
      height: size,
      child: Card(
        elevation: 2,
        shadowColor: theme.colorScheme.shadow.withValues(alpha: 0.2),
        shape: RoundedRectangleBorder(
          borderRadius: AppShapes.borderRadiusLarge,
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {},
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer.withValues(alpha: 0.6),
                    borderRadius: AppShapes.borderRadiusSmall,
                  ),
                  child: Text(
                    '${subject.period}교시',
                    style: AppFonts.scaled(context, AppFonts.display3Medium).copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
                    borderRadius: AppShapes.borderRadiusMedium,
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    subject.icon,
                    size: 32,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  subject.name,
                  style: AppFonts.scaled(context, AppFonts.display3SemiBold).copyWith(
                    color: AppColors.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── 4. 구분선 ──

  Widget _buildDivider() {
    return Container(
      height: 1,
      margin: EdgeInsets.symmetric(horizontal: context.rs(2)),
      decoration: BoxDecoration(
        color: AppColors.border,
        borderRadius: BorderRadius.circular(80),
      ),
    );
  }

  // ── 5. 다음 시간 과목 섹션 ──

  Widget _buildNextClassSection() {
    final name = _fullName ?? '학생';

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: context.rs(26)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '다음 시간 과목',
            style: AppFonts.scaled(context, AppFonts.sectionTitle),
          ),
          SizedBox(height: context.rh(2)),
          Text(
            '$name님의 다음 시간 과목 정보에요.',
            style: AppFonts.scaled(context, AppFonts.display3Regular),
          ),
          SizedBox(height: context.rh(12)),
          _buildNextClassCard(_nextClass),
        ],
      ),
    );
  }

  Widget _buildNextClassCard(_NextClassInfo info) {
    final iconSize = context.rs(48);
    final infoIconSize = context.rs(20);
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: context.rs(23),
        vertical: context.rh(22),
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.inverseSurface,
        borderRadius: AppShapes.borderRadiusLarge,
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withValues(alpha: 0.08),
            offset: const Offset(0, 6),
            blurRadius: 16,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 왼쪽: 과목 정보
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  info.name,
                  style: AppFonts.scaled(
                    context,
                    AppFonts.titleSemiBold,
                  ).copyWith(color: theme.colorScheme.onInverseSurface),
                ),
                SizedBox(height: context.rh(2)),
                Text(
                  '${info.period}교시 - ${info.location}',
                  style: AppFonts.scaled(
                    context,
                    AppFonts.display3Light,
                  ).copyWith(color: theme.colorScheme.onInverseSurface),
                ),
                SizedBox(height: context.rh(14)),
                _buildInfoRow(
                  context,
                  Icons.schedule_outlined,
                  info.time,
                  infoIconSize,
                ),
                SizedBox(height: context.rh(8)),
                _buildInfoRow(
                  context,
                  Icons.person_outline,
                  info.teacher,
                  infoIconSize,
                ),
                SizedBox(height: context.rh(8)),
                _buildInfoRow(
                  context,
                  Icons.assignment_outlined,
                  info.notice,
                  infoIconSize,
                ),
              ],
            ),
          ),
          // 오른쪽: 과목 아이콘 (영역 축소해 notice 한 줄 유지)
          SizedBox(
            width: iconSize,
            height: iconSize,
            child: Icon(
              info.icon,
              size: iconSize,
              color: theme.colorScheme.onInverseSurface.withValues(alpha: 0.9),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(
      BuildContext context, IconData icon, String text, double iconSize) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(
          icon,
          size: iconSize,
          color: theme.colorScheme.onInverseSurface.withValues(alpha: 0.85),
        ),
        SizedBox(width: context.rs(10)),
        Expanded(
          child: Text(
            text,
            style: AppFonts.scaled(
              context,
              AppFonts.display3Regular,
            ).copyWith(color: theme.colorScheme.onInverseSurface),
          ),
        ),
      ],
    );
  }

  // ── Helpers ──

  String _greetingMessage() {
    final weekday = DateTime.now().weekday;
    const dayNames = ['월', '화', '수', '목', '금', '토', '일'];
    final dayName = dayNames[weekday - 1];
    final hour = DateTime.now().hour;

    if (hour < 6) return '아직 이른 시간이에요. 좋은 꿈 꾸세요!';
    if (hour < 12) return '오늘도 찾아온 $dayName요병. 쌈@뽕하게 이겨내요..!';
    if (hour < 18) return '오늘 하루 절반 지났어요. 화이팅!';
    return '오늘도 수고 많았어요!';
  }
}

/// 오늘의 수업 카드 데이터. [icon]은 Material 3 Icons.
class _SubjectCard {
  const _SubjectCard({
    required this.name,
    required this.icon,
    required this.period,
  });

  final String name;
  final IconData icon;
  final int period;
}

/// 다음 시간 과목 상세 정보 데이터.
class _NextClassInfo {
  const _NextClassInfo({
    required this.name,
    required this.period,
    required this.location,
    required this.time,
    required this.teacher,
    required this.notice,
    required this.icon,
  });

  final String name;
  final int period;
  final String location;
  final String time;
  final String teacher;
  final String notice;
  final IconData icon;
}
