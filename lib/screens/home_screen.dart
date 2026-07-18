import 'package:flutter/cupertino.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:myapp/core/theme/app_resolved_colors.dart';
import 'package:myapp/core/theme/app_theme.dart';
import 'package:myapp/design/glass.dart';
import 'package:myapp/features/home/home_tab.dart';
import 'package:myapp/features/meal/meal_tab.dart';
import 'package:myapp/features/notice_poll/notice_poll_tab.dart';
import 'package:myapp/features/schedule/schedule_tab.dart';
import 'package:myapp/features/suggestions/suggestions_tab.dart';
import 'package:myapp/services/notification_service.dart';

/// 메인 탭 네비게이션을 호스팅하는 루트 화면.
///
/// [IndexedStack]으로 탭 상태를 유지하고, [GlassTabBar.bottom]으로 전환한다.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  bool _handledNoticeTab = false;

  @override
  void initState() {
    super.initState();
    // 로그인 직후 또는 앱 재실행 후 홈 진입 시 급식 출발 등 프로필 기반 Realtime 구독 갱신
    NotificationService.onProfileChanged().catchError((Object e, StackTrace _) {
      debugPrint('프로필 기반 알림 구독 갱신 실패: $e');
    });
  }

  static const _tabs = <Widget>[
    HomeTab(),
    MealTab(),
    ScheduleTab(),
    SuggestionsTab(),
    NoticePollTab(),
  ];

  List<GlassTab> _glassTabs(BuildContext context) {
    const assets = <(String, String)>[
      ('홈', 'assets/images/nav_home_inactive.svg'),
      ('급식', 'assets/images/nav_meal.svg'),
      ('일정', 'assets/images/nav_schedule_inactive.svg'),
      ('건의함', 'assets/images/nav_suggestion.svg'),
      ('공지/투표', 'assets/images/nav_notice.svg'),
    ];
    return [
      for (final (label, asset) in assets)
        GlassTab(
          label: label,
          glowColor: AppColors.primaryBlue.withValues(alpha: 0.35),
          icon: SvgPicture.asset(
            asset,
            width: 24,
            height: 24,
            colorFilter: const ColorFilter.mode(
              AppColors.navInactive,
              BlendMode.srcIn,
            ),
          ),
          activeIcon: SvgPicture.asset(
            asset,
            width: 24,
            height: 24,
            colorFilter: const ColorFilter.mode(
              AppColors.primaryBlue,
              BlendMode.srcIn,
            ),
          ),
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    // 공지사항 알림 탭 시 /?tab=notice 로 들어오면 공지/투표 탭으로 전환
    final tab = GoRouterState.of(context).uri.queryParameters['tab'];
    if (tab == 'notice' && !_handledNoticeTab) {
      _handledNoticeTab = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _currentIndex = 4);
        context.go('/');
      });
    } else if (tab != 'notice') {
      _handledNoticeTab = false;
    }

    final colors = context.appColors;

    return GlassScaffold(
      backgroundColor: colors.background,
      resizeToAvoidBottomInset: false,
      edgeFade: false,
      body: IndexedStack(
        index: _currentIndex,
        children: _tabs,
      ),
      bottomBar: GlassTabBar.bottom(
        tabs: _glassTabs(context),
        selectedIndex: _currentIndex,
        onTabSelected: (i) => setState(() => _currentIndex = i),
        quality: kAppGlassQuality,
        selectedIconColor: AppColors.primaryBlue,
        unselectedIconColor: AppColors.navInactive,
        selectedLabelColor: AppColors.primaryBlue,
        unselectedLabelColor: AppColors.navInactive,
        selectedLabelStyle: AppFonts.displaySemiBold.copyWith(
          color: AppColors.primaryBlue,
          fontSize: 11,
        ),
        unselectedLabelStyle: AppFonts.displayRegular.copyWith(
          color: AppColors.navInactive,
          fontSize: 11,
        ),
      ),
    );
  }
}
