import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:myapp/core/auth/auth_state.dart';
import 'package:myapp/core/routing/app_router.dart';
import 'package:myapp/core/theme/app_theme.dart';
import 'package:myapp/core/theme/responsive.dart';
import 'package:myapp/core/widgets/laon_icon.dart';

/// Figma "App Wireframes > HOME" (node 296:5429) 홈 대시보드 탭.
///
/// 구성:
/// 1. 커스텀 앱바 (LAON 로고 + 알림/설정 아이콘)
/// 2. 프로필 인사말
/// 3. 오늘의 수업 (수평 스크롤 카드)
/// 4. 다음 시간 과목 (상세 정보 카드)
class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  String? _fullName;
  bool _loading = true;

  /// 샘플 오늘의 수업 데이터 (추후 API 연동 시 교체)
  static const _todayClasses = [
    _SubjectCard(name: '수학Ⅱ', iconAsset: 'assets/images/icon_math_formula.svg'),
    _SubjectCard(name: '수학Ⅱ', iconAsset: 'assets/images/icon_math_formula.svg'),
    _SubjectCard(name: '화학 I', iconAsset: 'assets/images/icon_h2o.svg'),
    _SubjectCard(name: '국어', iconAsset: null),
    _SubjectCard(name: '영어', iconAsset: null),
  ];

  /// 샘플 다음 시간 과목 데이터
  static const _nextClass = _NextClassInfo(
    name: '화학 I',
    period: 3,
    location: '2층 창의융합실',
    time: '10:30',
    teacher: '이은하 선생님',
    notice: '수행평가가 예정되어있어요!',
    iconAsset: 'assets/images/icon_h2o.svg',
  );

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await getCurrentProfile();
      if (!mounted) return;
      setState(() {
        _fullName = profile?.fullName;
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
            ? const Center(child: CupertinoActivityIndicator(radius: 12))
            : ListView(
                padding: EdgeInsets.zero,
                children: [
                  _buildAppBar(),
                  _buildGreeting(),
                  SizedBox(height: context.rh(16)),
                  _buildTodayClassesSection(),
                  SizedBox(height: context.rh(8)),
                  _buildDivider(),
                  SizedBox(height: context.rh(8)),
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
            onTap: () {
              // TODO: 알림 화면 이동
            },
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
    final avatarSize = context.rmin(48);

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
            child: Icon(
              CupertinoIcons.person_fill,
              size: context.rmin(28),
              color: AppColors.primaryBlue500,
            ),
          ),
          SizedBox(width: context.rs(19)),
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
              GestureDetector(
                onTap: () {
                  // TODO: 전체 시간표 화면 이동
                },
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: context.rs(12),
                    vertical: context.rh(6),
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue500.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '더보기',
                    style: AppFonts.scaled(
                      context,
                      AppFonts.display3Medium,
                    ).copyWith(
                      color: AppColors.primaryBlue500,
                      fontWeight: FontWeight.w600,
                      fontSize: context.rs(14),
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
        _buildClassCardsList(),
      ],
    );
  }

  Widget _buildClassCardsList() {
    final cardWidth = context.rs(179);
    final cardHeight = context.rh(140);
    final iconSize = context.rmin(49);

    return SizedBox(
      height: cardHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: context.rs(23)),
        itemCount: _todayClasses.length,
        separatorBuilder: (_, __) => SizedBox(width: context.rs(17)),
        itemBuilder: (_, index) {
          final subject = _todayClasses[index];
          return Container(
            width: cardWidth,
            height: cardHeight,
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(context.rs(20)),
              border: Border.all(color: AppColors.borderLight),
              boxShadow: const [
                BoxShadow(
                  color: AppColors.cardShadow,
                  offset: Offset(0, 4),
                  blurRadius: 12,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(context.rs(20)),
              child: Stack(
                children: [
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 0,
                    height: cardHeight * 0.5,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppColors.primaryBlue500.withOpacity(0.15),
                            AppColors.timetableBg,
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (subject.iconAsset != null)
                  Positioned(
                    top: cardHeight * 0.2,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: SvgPicture.asset(
                        subject.iconAsset!,
                        width: iconSize,
                        height: iconSize,
                        fit: BoxFit.contain,
                      ),
                    ),
                  )
                else
                  Positioned(
                    top: cardHeight * 0.25,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Text(
                        subject.name.substring(0, 1),
                        style: TextStyle(
                          fontFamily: AppFonts.fontFamily,
                          fontSize: context.rs(32),
                          fontWeight: FontWeight.w600,
                          color: AppColors.primaryBlue500,
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  bottom: context.rh(12),
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
        },
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
    final iconAreaWidth = context.rs(77);
    final infoIconSize = context.rs(20);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: context.rs(23),
        vertical: context.rh(22),
      ),
      decoration: BoxDecoration(
        color: AppColors.textPrimary,
        borderRadius: BorderRadius.circular(context.rs(20)),
        boxShadow: const [
          BoxShadow(
            color: AppColors.cardShadow,
            offset: Offset(0, 6),
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
                  ).copyWith(color: AppColors.background),
                ),
                SizedBox(height: context.rh(2)),
                Text(
                  '${info.period}교시 - ${info.location}',
                  style: AppFonts.scaled(
                    context,
                    AppFonts.display3Light,
                  ),
                ),
                SizedBox(height: context.rh(14)),
                _buildInfoRow(
                  'assets/images/icon_clock.svg',
                  info.time,
                  infoIconSize,
                ),
                SizedBox(height: context.rh(8)),
                _buildInfoRow(
                  'assets/images/icon_user.svg',
                  info.teacher,
                  infoIconSize,
                ),
                SizedBox(height: context.rh(8)),
                _buildInfoRow(
                  'assets/images/icon_clipboard.svg',
                  info.notice,
                  infoIconSize,
                ),
              ],
            ),
          ),
          // 오른쪽: 과목 일러스트
          if (info.iconAsset != null)
            SizedBox(
              width: iconAreaWidth,
              child: SvgPicture.asset(
                info.iconAsset!,
                width: iconAreaWidth,
                fit: BoxFit.contain,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String iconPath, String text, double iconSize) {
    return Row(
      children: [
        SvgPicture.asset(
          iconPath,
          width: iconSize,
          height: iconSize,
          fit: BoxFit.contain,
        ),
        SizedBox(width: context.rs(10)),
        Expanded(
          child: Text(
            text,
            style: AppFonts.scaled(
              context,
              AppFonts.display3Regular,
            ).copyWith(color: AppColors.background),
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

/// 오늘의 수업 카드 데이터.
class _SubjectCard {
  const _SubjectCard({
    required this.name,
    required this.iconAsset,
  });

  final String name;
  final String? iconAsset;
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
    this.iconAsset,
  });

  final String name;
  final int period;
  final String location;
  final String time;
  final String teacher;
  final String notice;
  final String? iconAsset;
}
