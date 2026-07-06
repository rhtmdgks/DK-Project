import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:myapp/core/auth/auth_repository.dart';
import 'package:myapp/core/supabase_client.dart';
import 'package:myapp/core/theme/app_motion.dart';
import 'package:myapp/screens/app_info_screen.dart';
import 'package:myapp/screens/blocked_users_screen.dart';
import 'package:myapp/screens/bug_report_screen.dart';
import 'package:myapp/screens/chat_list_screen.dart';
import 'package:myapp/screens/chat_screen.dart';
import 'package:myapp/screens/home_screen.dart';
import 'package:myapp/screens/login_screen.dart';
import 'package:myapp/screens/meal_departure_alert_screen.dart';
import 'package:myapp/screens/opinions_screen.dart';
import 'package:myapp/screens/password_change_screen.dart';
import 'package:myapp/screens/privacy_policy_screen.dart';
import 'package:myapp/screens/profile_edit_screen.dart';
import 'package:myapp/screens/profile_screen.dart';
import 'package:myapp/screens/settings_screen.dart';
import 'package:myapp/screens/class_photo_shares_screen.dart';
import 'package:myapp/screens/splash_screen.dart';
import 'package:myapp/screens/support_screen.dart';
import 'package:myapp/screens/suggestions_chat_screen.dart';
import 'package:myapp/screens/terms_of_service_screen.dart';
import 'package:myapp/screens/terms_screen.dart';
import 'package:myapp/screens/today_classes_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 앱 전체 라우트 경로 열거형.
enum AppRoute {
  splash('/splash'),
  terms('/terms'),
  termsOfService('/legal/terms'),
  login('/login'),
  passwordChange('/password-change'),
  home('/'),
  settings('/settings'),
  mealDepartureAlert('/settings/meal-departure-alert'),
  privacyPolicy('/privacy'),
  bugReport('/bug-report'),
  support('/settings/support'),
  appInfo('/settings/app-info'),
  blockedUsers('/settings/blocked-users'),
  chatList('/chat'),
  chatRoom('/chat/:roomId'),
  suggestionsChat('/suggestions/chat'),
  todayClasses('/today-classes'),
  profile('/profile'),
  profileEdit('/profile/edit'),
  opinions('/opinions'),
  classPhotoShares('/class-photo-shares');

  const AppRoute(this.path);
  final String path;
}

/// SharedPreferences 키: 약관 동의 여부. [TermsScreen]에서 true로 저장한다.
const String kTermsAgreedKey = 'terms_agreed';

/// 알림 탭 등 외부에서 홈 탭 이동 시 사용 (예: 공지사항 알림 → 공지/투표 탭).
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

/// Supabase 세션 변경 시 `redirect`를 다시 평가하기 위한 [GoRouter.refreshListenable].
///
/// go_router v14에서는 `GoRouterRefreshStream`이 제거되어 로컬 Listenable로 연결한다.
final class _SupabaseAuthRefreshListenable extends ChangeNotifier {
  _SupabaseAuthRefreshListenable() {
    _subscription = supabase.auth.onAuthStateChange.listen((_) {
      notifyListeners();
    });
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

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
  final authRefresh = _SupabaseAuthRefreshListenable();
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: AppRoute.splash.path,
    refreshListenable: authRefresh,
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
        path: AppRoute.termsOfService.path,
        pageBuilder: (_, state) =>
            _m3Page(state, const TermsOfServiceScreen()),
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
        path: AppRoute.mealDepartureAlert.path,
        pageBuilder: (_, state) =>
            _m3Page(state, const MealDepartureAlertScreen()),
      ),
      GoRoute(
        path: AppRoute.privacyPolicy.path,
        pageBuilder: (_, state) =>
            _m3Page(state, const PrivacyPolicyScreen()),
      ),
      GoRoute(
        path: AppRoute.support.path,
        pageBuilder: (_, state) => _m3Page(state, const SupportScreen()),
      ),
      GoRoute(
        path: AppRoute.appInfo.path,
        pageBuilder: (_, state) => _m3Page(state, const AppInfoScreen()),
      ),
      GoRoute(
        path: AppRoute.blockedUsers.path,
        pageBuilder: (_, state) =>
            _m3Page(state, const BlockedUsersScreen()),
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
      GoRoute(
        path: AppRoute.profile.path,
        pageBuilder: (_, state) =>
            _m3Page(state, const ProfileScreen()),
        routes: [
          GoRoute(
            path: 'edit',
            pageBuilder: (_, state) =>
                _m3Page(state, const ProfileEditScreen()),
          ),
        ],
      ),
      GoRoute(
        path: AppRoute.opinions.path,
        pageBuilder: (_, state) => _m3Page(state, const OpinionsScreen()),
      ),
      GoRoute(
        path: AppRoute.classPhotoShares.path,
        pageBuilder: (_, state) =>
            _m3Page(state, const ClassPhotoSharesScreen()),
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

    final isOnLogin = location == AppRoute.login.path;
    final loggedIn = await AuthRepository.instance.isLoggedIn();

    if (!loggedIn) {
      return isOnLogin ? null : AppRoute.login.path;
    }

    final profile = await AuthRepository.instance.getCurrentProfile();

    if (profile == null) {
      await AuthRepository.instance.clearLoginState();
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
