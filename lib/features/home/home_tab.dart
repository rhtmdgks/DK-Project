import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:myapp/core/auth/auth_state.dart';
import 'package:myapp/core/routing/app_router.dart';
import 'package:myapp/core/theme/app_theme.dart';
import 'package:myapp/core/theme/responsive.dart';
import 'package:myapp/core/utils/subject_theme_service.dart';
import 'package:myapp/core/widgets/laon_icon.dart';
import 'package:myapp/core/widgets/m3_carousel_scroll_physics.dart';
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


  /// 샘플 오늘의 수업 데이터 (추후 API 연동 시 교체).
  /// Figma 노드 41:1 기준: 카드 크기 148x119 (첫 번째는 149x119), cornerRadius 16
  /// 색상, 아이콘, 장식 벡터는 [SubjectThemeService]를 통해 자동 할당됩니다.
  static const _todayClasses = [
    _SubjectCard(name: '수학Ⅱ', period: 1),
    _SubjectCard(name: '생명과학', period: 2),
    _SubjectCard(name: '국어', period: 3),
    _SubjectCard(name: '영어', period: 4),
  ];

  /// 샘플 다음 시간 과목 데이터
  /// 아이콘과 색상은 [SubjectThemeService]를 통해 자동 할당됩니다.
  static const _nextClass = _NextClassInfo(
    name: '생명과학',
    periodName: '3단원: 동물계', // 교시명
    location: '2-10', // 교실 위치 (형식: 2-10)
    time: '10:30', // 시작 시간
    teacher: '오신영 선생님',
    notice: '다음시간 수행평가 준비해오세요~', // 기타 알림
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
  /// Figma 노드 41:1 기준: 카드 크기 148x119 (첫 번째는 149x119)
  static const double _cardHeight = 119;
  static const double _cardWidth = 148;
  static const double _firstCardWidth = 149; // 첫 번째 카드만 149

  Widget _buildTodayClassesList() {
    return SizedBox(
      height: _cardHeight,
      child: ScrollConfiguration(
        behavior: M3CarouselScrollBehavior(),
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          physics: const ClampingScrollPhysics(), // 양쪽 끝에서 스크롤 멈춤
          padding: EdgeInsets.symmetric(horizontal: context.rs(22)),
          itemCount: _todayClasses.length,
          itemBuilder: (context, index) {
            return Padding(
              padding: EdgeInsets.only(
                right: index < _todayClasses.length - 1 ? context.rs(12) : 0,
              ),
              child: _buildTodayClassCard(_todayClasses[index], index == 0),
            );
          },
        ),
      ),
    );
  }

  /// Figma 노드 41:1 디자인 기반 카드
  /// 첫 번째 카드 (Mathematics): 149x119
  ///   - 아이콘: x: -3663 (카드 x: -3679) = 16, y: 2311 (카드 y: 2295) = 16
  ///   - 텍스트: x: -3663 = 16, y: 2374 (카드 y: 2295) = 79
  ///   - 메뉴: x: -3566 (카드 x: -3679) = 113, right: 149 - 113 - 24 = 12
  /// 세 번째 카드 (Geography): 148x119
  ///   - 아이콘: x: -3498 (카드 x: -3514) = 16, y: 2311 (카드 y: 2295) = 16
  ///   - 텍스트: x: -3498 = 16, y: 2374 (카드 y: 2295) = 79
  ///   - 메뉴: x: -3402 (카드 x: -3514) = 112, right: 148 - 112 - 24 = 12
  Widget _buildTodayClassCard(_SubjectCard subject, bool isFirst) {
    final cardWidth = isFirst ? _firstCardWidth : _cardWidth;
    final theme = SubjectThemeService.getThemeForSubject(subject.name);
    
    return SizedBox(
      width: cardWidth,
      height: _cardHeight,
      child: Container(
        decoration: BoxDecoration(
          color: theme.color,
          borderRadius: BorderRadius.circular(16), // Figma cornerRadius 16
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              offset: const Offset(0, 4),
              blurRadius: 12,
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            // 상단 왼쪽: 아이콘 (24x24, 위치: 16, 16)
            Positioned(
              left: context.rs(16),
              top: context.rs(16),
              child: Icon(
                theme.icon,
                size: context.rs(24),
                color: AppColors.white,
              ),
            ),
            // 우측 상단: 벡터 장식 (vec1, vec2 활용, 우측 상단 일부만 보이도록)
            if (theme.decorationPath != null)
              Positioned(
                right: -cardWidth * 0.6, // 벡터를 블록 밖으로 배치
                top: -_cardHeight * 0.6, // 벡터를 블록 밖으로 배치
                child: SvgPicture.asset(
                  theme.decorationPath!,
                  width: cardWidth * 1.2,
                  height: _cardHeight * 1.2,
                  fit: BoxFit.contain,
                  alignment: Alignment.topRight,
                ),
              ),
            // 하단 왼쪽: 과목명
            // 텍스트 y: 2374, 카드 y: 2295, 상대 위치: 79
            // 카드 높이 119에서 79 위치 = bottom: 119 - 79 - 24 = 16
            Positioned(
              left: context.rs(16),
              bottom: context.rs(16),
              child: Text(
                subject.name,
                style: AppFonts.scaled(context, AppFonts.titleSemiBold)
                    .copyWith(
                  color: AppColors.white,
                  fontSize: context.rs(16), // Figma: 16px
                  fontWeight: FontWeight.w600, // Figma: SemiBold 600
                  height: 1.5, // Figma: lineHeightPx 24 / fontSize 16 = 1.5
                ),
              ),
            ),
            // 상단 오른쪽: 메뉴 아이콘 (24x24, right: 12) - 점 2개
            Positioned(
              right: context.rs(12),
              top: context.rs(16),
              child: GestureDetector(
                onTap: () {},
                child: SvgPicture.asset(
                  'assets/icons/ellipsis_v_2dots.svg', // 점 2개 메뉴
                  width: context.rs(24),
                  height: context.rs(24),
                  colorFilter: const ColorFilter.mode(
                    AppColors.white,
                    BlendMode.srcIn,
                  ),
                ),
              ),
            ),
            // 다음 시간 과목 블럭의 메뉴 아이콘도 점 2개로 변경
          ],
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

  /// Figma 노드 3:692 디자인 기반 다음 시간 과목 카드
  /// 크기: 319x137 (기본), 필요시 높이 확장 가능
  /// 레이아웃: 과목명, 교시명, 교실 위치, 시작 시간, 선생님 이름, 기타 알림
  Widget _buildNextClassCard(_NextClassInfo info) {
    final subjectTheme = SubjectThemeService.getThemeForSubject(info.name);
    final infoIconSize = context.rs(18); // 아이콘 크기 증가: 16 → 18

    return Container(
      width: double.infinity,
      constraints: BoxConstraints(
        minHeight: context.rh(137), // 최소 높이
      ),
      padding: EdgeInsets.all(context.rs(16)), // 패딩 조정: 20 → 16
      decoration: BoxDecoration(
        color: subjectTheme.color, // 과목별 색상 사용
        borderRadius: BorderRadius.circular(16), // Figma: cornerRadius 16
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            offset: const Offset(0, 4),
            blurRadius: 12,
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // 상단: 과목명과 메뉴 아이콘
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 과목명 (크기 증가: 16px → 20px)
                  Expanded(
                    child: Text(
                      info.name,
                      style: AppFonts.scaled(context, AppFonts.titleSemiBold)
                          .copyWith(
                        color: AppColors.white,
                        fontSize: context.rs(20), // 16px → 20px
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                      ),
                    ),
                  ),
                  SizedBox(width: context.rs(8)),
                  // 메뉴 아이콘 (Figma: 24x24, x: -3400, y: 2538)
                  GestureDetector(
                    onTap: () {},
                    child: SvgPicture.asset(
                      'assets/icons/ellipsis_v_2dots.svg',
                      width: context.rs(24),
                      height: context.rs(24),
                      colorFilter: const ColorFilter.mode(
                        AppColors.white,
                        BlendMode.srcIn,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: context.rh(2)), // 과목명과 교시명 사이 마진 줄임
              // 교시명 (크기 증가: 12px → 15px)
              Text(
                info.periodName,
                style: AppFonts.scaled(context, AppFonts.display3Regular)
                    .copyWith(
                  color: AppColors.white,
                  fontSize: context.rs(15), // 12px → 15px
                  fontWeight: FontWeight.w500,
                  height: 1.4,
                ),
              ),
              SizedBox(height: context.rh(8)), // 교시명과 하단 정보 사이 간격 조정: 12 → 8
              // 교실 위치 (크기 증가: 12px → 14px)
              Row(
                children: [
                  Icon(
                    Icons.location_on_outlined,
                    size: infoIconSize,
                    color: AppColors.white,
                  ),
                  SizedBox(width: context.rs(4)),
                  Text(
                    info.location, // "Room" 제거, 형식: 2-10
                    style: AppFonts.scaled(context, AppFonts.display3Regular)
                        .copyWith(
                      color: AppColors.white,
                      fontSize: context.rs(14), // 12px → 14px
                      fontWeight: FontWeight.w500, // 더 굵게
                      height: 1.4,
                    ),
                  ),
                ],
              ),
              SizedBox(height: context.rh(2)), // 간격 조정: 4 → 2
              // 시작 시간 (크기 증가: 12px → 14px)
              Row(
                children: [
                  Icon(
                    Icons.schedule_outlined,
                    size: infoIconSize,
                    color: AppColors.white,
                  ),
                  SizedBox(width: context.rs(4)),
                  Text(
                    info.time,
                    style: AppFonts.scaled(context, AppFonts.display3Regular)
                        .copyWith(
                      color: AppColors.white,
                      fontSize: context.rs(14), // 12px → 14px
                      fontWeight: FontWeight.w500, // 더 굵게
                      height: 1.4,
                    ),
                  ),
                ],
              ),
              SizedBox(height: context.rh(2)), // 간격 조정: 4 → 2
              // 선생님 이름 (크기 증가: 12px → 14px)
              Row(
                children: [
                  Container(
                    width: context.rs(18), // 16 → 18
                    height: context.rs(18), // 16 → 18
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.white.withValues(alpha: 0.3),
                    ),
                    child: Icon(
                      Icons.person,
                      size: context.rs(14), // 12 → 14
                      color: AppColors.white,
                    ),
                  ),
                  SizedBox(width: context.rs(4)),
                  Text(
                    info.teacher,
                    style: AppFonts.scaled(context, AppFonts.display3Regular)
                        .copyWith(
                      color: AppColors.white,
                      fontSize: context.rs(14), // 12px → 14px
                      fontWeight: FontWeight.w500, // 더 굵게
                      height: 1.4,
                    ),
                  ),
                ],
              ),
              // 기타 알림 (description 스타일: 더 굵고 잘 보이게, 좌우 정렬)
              if (info.notice.isNotEmpty) ...[
                SizedBox(height: context.rh(6)), // 마진 조정: 10 → 6
                Text(
                  info.notice,
                  textAlign: TextAlign.justify, // 좌우 정렬
                  style: AppFonts.scaled(context, AppFonts.titleMedium)
                      .copyWith(
                    color: AppColors.white,
                    fontSize: context.rs(15),
                    fontWeight: FontWeight.w600, // SemiBold로 더 굵게
                    height: 1.4,
                  ),
                  maxLines: 2, // 2줄까지 표시 가능
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
    );
  }

  Widget _buildInfoRow(
      BuildContext context, IconData icon, String text, double iconSize) {
    return Row(
      children: [
        Icon(
          icon,
          size: iconSize,
          color: AppColors.white.withValues(alpha: 0.85),
        ),
        SizedBox(width: context.rs(10)),
        Expanded(
          child: Text(
            text,
            style: AppFonts.scaled(
              context,
              AppFonts.display3Regular,
            ).copyWith(color: AppColors.white),
          ),
        ),
      ],
    );
  }

  // ── Helpers ──

  String _greetingMessage() {
    final messages = [
      '설날 지나고 힘드시죠? 오늘도 힘내봐요!',
      '오늘도 찾아온 새로운 하루. 쌈@뽕하게 이겨내요..!',
      '오늘 하루 절반 지났어요. 화이팅!',
      '오늘도 수고 많았어요!',
      '아직 이른 시간이에요. 좋은 꿈 꾸세요!',
      '새로운 하루를 시작해봐요!',
      '오늘도 멋진 하루 보내세요!',
    ];
    
    final random = Random();
    return messages[random.nextInt(messages.length)];
  }
}

/// 오늘의 수업 카드 데이터. [icon]은 Material 3 Icons.
/// 오늘의 수업 카드 데이터.
/// 색상, 아이콘, 장식 벡터는 [SubjectThemeService]를 통해 자동 할당됩니다.
class _SubjectCard {
  const _SubjectCard({
    required this.name,
    required this.period,
  });

  final String name;
  final int period;
}

/// 다음 시간 과목 상세 정보 데이터.
/// 다음 시간 과목 정보.
/// 아이콘과 색상은 [SubjectThemeService]를 통해 자동 할당됩니다.
class _NextClassInfo {
  const _NextClassInfo({
    required this.name,
    required this.periodName,
    required this.location,
    required this.time,
    required this.teacher,
    required this.notice,
  });

  final String name; // 과목명
  final String periodName; // 교시명 (예: "3단원: 동물계")
  final String location; // 교실 위치
  final String time; // 시작 시간
  final String teacher; // 선생님 이름
  final String notice; // 기타 알림 (한줄 짧게)
}
