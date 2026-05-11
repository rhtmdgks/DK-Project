import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:myapp/design/app_colors.dart';
import 'package:myapp/core/widgets/app_bottom_nav_bar.dart';
import 'package:myapp/features/home/home_tab.dart';
import 'package:myapp/features/meal/meal_tab.dart';
import 'package:myapp/features/notice_poll/notice_poll_tab.dart';
import 'package:myapp/features/schedule/schedule_tab.dart';
import 'package:myapp/features/suggestions/suggestions_tab.dart';
import 'package:myapp/services/notification_service.dart';

/// 메인 탭 네비게이션을 호스팅하는 루트 화면.
///
/// [IndexedStack]으로 탭 상태를 유지하고, [AppBottomNavBar]를 통해 전환한다.
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
    return Scaffold(
      backgroundColor: AppDesignColors.background(context),
      resizeToAvoidBottomInset: false,
      body: Material(
        type: MaterialType.transparency,
        child: Column(
          children: [
          Expanded(
            child: IndexedStack(
              index: _currentIndex,
              children: _tabs,
            ),
          ),
          AppBottomNavBar(
            currentIndex: _currentIndex,
            onTap: (i) => setState(() => _currentIndex = i),
          ),
        ],
        ),
      ),
    );
  }
}
