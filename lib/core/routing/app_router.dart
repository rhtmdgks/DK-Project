import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:myapp/core/auth/auth_state.dart';
import 'package:myapp/core/theme/app_motion.dart';
import 'package:myapp/core/supabase_client.dart';
import 'package:myapp/screens/chat_list_screen.dart';
import 'package:myapp/screens/chat_screen.dart';
import 'package:myapp/screens/home_screen.dart';
import 'package:myapp/screens/login_screen.dart';
import 'package:myapp/screens/password_change_screen.dart';
import 'package:myapp/screens/privacy_policy_screen.dart';
import 'package:myapp/screens/bug_report_screen.dart';
import 'package:myapp/screens/settings_screen.dart';
import 'package:myapp/screens/splash_screen.dart';
import 'package:myapp/screens/suggestions_chat_screen.dart';
import 'package:myapp/screens/terms_screen.dart';
import 'package:myapp/screens/today_classes_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 앱 전체 라우트 경로 열거형.
enum AppRoute {
  splash('/splash'),
  terms('/terms'),
  login('/login'),
  passwordChange('/password-change'),
  home('/'),
  settings('/settings'),
  privacyPolicy('/privacy'),
  bugReport('/bug-report'),
  chatList('/chat'),
  chatRoom('/chat/:roomId'),
  suggestionsChat('/suggestions/chat'),
  todayClasses('/today-classes');

  const AppRoute(this.path);
  final String path;
}

/// SharedPreferences 키: 약관 동의 여부. [TermsScreen]에서 true로 저장한다.
const String kTermsAgreedKey = 'terms_agreed';

/// SharedPreferences 키: 로그인 상태 (profiles 테이블 기반 인증 사용 시).
const String kLoggedInKey = 'logged_in';
const String kLoggedInUserIdKey = 'logged_in_user_id';

/// 알림 탭 등 외부에서 홈 탭 이동 시 사용 (예: 공지사항 알림 → 공지/투표 탭).
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

/// Material 3 Motion: Shared Axis(수평) + Fade 페이지 전환.
CustomTransitionPage<void> _m3Page(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: AppMotion.pageTransitionDuration,
    reverseTransitionDuration: AppMotion.pageTransitionDuration,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curve = CurvedAnimation(
        parent: animation,
        curve: AppMotion.pageTransitionCurve,
        reverseCurve: AppMotion.curveAccelerated,
      );
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0.05, 0),
          end: Offset.zero,
        ).animate(curve),
        child: FadeTransition(opacity: curve, child: child),
      );
    },
  );
}

/// GoRouter 인스턴스를 생성한다.
///
/// 리다이렉트 로직:
/// 0. 최초 진입 시 약관 미동의 → 약관 화면
/// 1. 스플래시 → 패스스루
/// 2. 미인증 → 로그인
/// 3. 프로필 없음 → 로그인
/// 4. 비밀번호 변경 필요 → 비밀번호 변경
/// 5. 이미 인증된 사용자가 로그인 페이지 접근 → 홈
GoRouter createAppRouter() {
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: AppRoute.splash.path,
    redirect: _handleRedirect,
    routes: [
      GoRoute(
        path: AppRoute.splash.path,
        pageBuilder: (_, state) => _m3Page(state, const SplashScreen()),
      ),
      GoRoute(
        path: AppRoute.terms.path,
        pageBuilder: (_, state) => _m3Page(state, const TermsScreen()),
      ),
      GoRoute(
        path: AppRoute.login.path,
        pageBuilder: (_, state) => _m3Page(state, const LoginScreen()),
      ),
      GoRoute(
        path: AppRoute.passwordChange.path,
        pageBuilder: (_, state) =>
            _m3Page(state, const PasswordChangeScreen()),
      ),
      GoRoute(
        path: AppRoute.home.path,
        pageBuilder: (_, state) => _m3Page(state, const HomeScreen()),
      ),
      GoRoute(
        path: AppRoute.settings.path,
        pageBuilder: (_, state) => _m3Page(state, const SettingsScreen()),
      ),
      GoRoute(
        path: AppRoute.privacyPolicy.path,
        pageBuilder: (_, state) =>
            _m3Page(state, const PrivacyPolicyScreen()),
      ),
      GoRoute(
        path: AppRoute.bugReport.path,
        pageBuilder: (_, state) => _m3Page(state, const BugReportScreen()),
      ),
      GoRoute(
        path: AppRoute.chatList.path,
        pageBuilder: (_, state) => _m3Page(state, const ChatListScreen()),
        routes: [
          GoRoute(
            path: ':roomId',
            pageBuilder: (_, state) {
              final roomId = state.pathParameters['roomId']!;
              return _m3Page(state, ChatScreen(roomId: roomId));
            },
          ),
        ],
      ),
      GoRoute(
        path: AppRoute.suggestionsChat.path,
        pageBuilder: (_, state) =>
            _m3Page(state, const SuggestionsChatScreen()),
      ),
      GoRoute(
        path: AppRoute.todayClasses.path,
        pageBuilder: (_, state) =>
            _m3Page(state, const TodayClassesScreen()),
      ),
    ],
  );
}

Future<String?> _handleRedirect(
  BuildContext context,
  GoRouterState state,
) async {
  try {
    final location = state.matchedLocation;

    // 최초 진입: 약관 미동의 시 약관 화면으로 (개인정보처리방침은 온보딩에서 열 수 있도록 허용)
    final prefs = await SharedPreferences.getInstance();
    final termsAgreed = prefs.getBool(kTermsAgreedKey) ?? false;
    if (!termsAgreed) {
      if (location == AppRoute.terms.path) return null;
      if (location == AppRoute.privacyPolicy.path) return null;
      return AppRoute.terms.path;
    }

    // 스플래시는 리다이렉트 우회
    if (location == AppRoute.splash.path) return null;

    final session = supabase.auth.currentSession;
    final isOnLogin = location == AppRoute.login.path;

    // 세션이 없으면 SharedPreferences에서 로그인 상태 확인 (profiles 테이블 기반 인증)
    final loggedIn = prefs.getBool(kLoggedInKey) ?? false;
    final loggedInUserId = prefs.getString(kLoggedInUserIdKey);

    // 미인증 → 로그인 페이지가 아니면 로그인으로 이동
    if (session == null && !loggedIn) {
      return isOnLogin ? null : AppRoute.login.path;
    }

    // 세션이 있으면 기존 로직 사용, 없으면 SharedPreferences 기반으로 프로필 조회 시도
    AppProfile? profile;
    if (session != null) {
      profile = await getCurrentProfile();
    } else if (loggedIn && loggedInUserId != null) {
      // 세션 없이도 프로필 조회 시도 (RLS 정책이 허용하는 경우)
      try {
        final row = await supabase
            .from('profiles')
            .select()
            .eq('user_id', loggedInUserId)
            .maybeSingle();
        if (row != null) {
          profile = AppProfile.fromJson(row);
        }
      } catch (_) {
        // 프로필 조회 실패 시 로그인 상태 초기화
        await prefs.remove(kLoggedInKey);
        await prefs.remove(kLoggedInUserIdKey);
      }
    }

    if (profile == null) {
      // 로그인 상태 초기화
      await prefs.remove(kLoggedInKey);
      await prefs.remove(kLoggedInUserIdKey);
      return AppRoute.login.path;
    }

    // 비밀번호 변경 강제
    if (profile.mustChangePassword) {
      return location == AppRoute.passwordChange.path
          ? null
          : AppRoute.passwordChange.path;
    }

    // 이미 인증된 상태에서 로그인 접근 → 홈
    if (isOnLogin) return AppRoute.home.path;

    return null;
  } catch (_) {
    // Cold start(아이콘 재실행) 시 네트워크/저장소 등 예외 시 로그인으로 폴백
    return AppRoute.login.path;
  }
}
