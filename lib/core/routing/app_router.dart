import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:myapp/core/auth/auth_state.dart';
import 'package:myapp/core/supabase_client.dart';
import 'package:myapp/screens/chat_list_screen.dart';
import 'package:myapp/screens/chat_screen.dart';
import 'package:myapp/screens/home_screen.dart';
import 'package:myapp/screens/login_screen.dart';
import 'package:myapp/screens/password_change_screen.dart';
import 'package:myapp/screens/bug_report_screen.dart';
import 'package:myapp/screens/settings_screen.dart';
import 'package:myapp/screens/splash_screen.dart';

/// 앱 전체 라우트 경로 열거형.
enum AppRoute {
  splash('/splash'),
  login('/login'),
  passwordChange('/password-change'),
  home('/'),
  settings('/settings'),
  bugReport('/bug-report'),
  chatList('/chat'),
  chatRoom('/chat/:roomId');

  const AppRoute(this.path);
  final String path;
}

final GlobalKey<NavigatorState> _rootNavKey = GlobalKey<NavigatorState>();

/// GoRouter 인스턴스를 생성한다.
///
/// 리다이렉트 로직:
/// 1. 스플래시 → 패스스루
/// 2. 미인증 → 로그인
/// 3. 프로필 없음 → 로그인
/// 4. 비밀번호 변경 필요 → 비밀번호 변경
/// 5. 이미 인증된 사용자가 로그인 페이지 접근 → 홈
GoRouter createAppRouter() {
  return GoRouter(
    navigatorKey: _rootNavKey,
    initialLocation: AppRoute.splash.path,
    redirect: _handleRedirect,
    routes: [
      GoRoute(
        path: AppRoute.splash.path,
        builder: (_, __) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoute.login.path,
        builder: (_, __) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoute.passwordChange.path,
        builder: (_, __) => const PasswordChangeScreen(),
      ),
      GoRoute(
        path: AppRoute.home.path,
        builder: (_, __) => const HomeScreen(),
      ),
      GoRoute(
        path: AppRoute.settings.path,
        builder: (_, __) => const SettingsScreen(),
      ),
      GoRoute(
        path: AppRoute.bugReport.path,
        builder: (_, __) => const BugReportScreen(),
      ),
      GoRoute(
        path: AppRoute.chatList.path,
        builder: (_, __) => const ChatListScreen(),
        routes: [
          GoRoute(
            path: ':roomId',
            builder: (_, state) {
              final roomId = state.pathParameters['roomId']!;
              return ChatScreen(roomId: roomId);
            },
          ),
        ],
      ),
    ],
  );
}

Future<String?> _handleRedirect(
  BuildContext context,
  GoRouterState state,
) async {
  final location = state.matchedLocation;

  // 스플래시는 리다이렉트 우회
  if (location == AppRoute.splash.path) return null;

  final session = supabase.auth.currentSession;
  final isOnLogin = location == AppRoute.login.path;

  // 미인증 → 로그인 페이지가 아니면 로그인으로 이동
  if (session == null) {
    return isOnLogin ? null : AppRoute.login.path;
  }

  final profile = await getCurrentProfile();
  if (profile == null) return AppRoute.login.path;

  // 비밀번호 변경 강제
  if (profile.mustChangePassword) {
    return location == AppRoute.passwordChange.path
        ? null
        : AppRoute.passwordChange.path;
  }

  // 이미 인증된 상태에서 로그인 접근 → 홈
  if (isOnLogin) return AppRoute.home.path;

  return null;
}
