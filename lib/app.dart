import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:home_widget/home_widget.dart';
import 'package:myapp/core/routing/app_router.dart';
import 'package:myapp/core/theme/app_theme.dart';
import 'package:myapp/providers/notification_provider.dart';
import 'package:myapp/services/notification_service.dart';
import 'package:provider/provider.dart';

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> with WidgetsBindingObserver {
  late final NotificationProvider _notificationProvider;
  StreamSubscription<Uri?>? _widgetClickedSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // NotificationProvider 초기화
    _notificationProvider = NotificationProvider();

    // 통합 알림 서비스 초기화
    Future.microtask(() => NotificationService.initialize(_notificationProvider))
        .catchError((Object e, StackTrace _) {
      debugPrint('알림 서비스 초기화 실패: $e');
    });

    // 홈 위젯에서 앱 실행 시 급식 출발 알림 화면으로 이동
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handleWidgetLaunch();
    });
    _widgetClickedSubscription = HomeWidget.widgetClicked.listen(_onWidgetClicked);
  }

  Future<void> _handleWidgetLaunch() async {
    final uri = await HomeWidget.initiallyLaunchedFromHomeWidget();
    if (uri != null && uri.toString().contains('meal-departure-alert')) {
      final ctx = rootNavigatorKey.currentContext;
      if (ctx != null && ctx.mounted) {
        ctx.go(AppRoute.mealDepartureAlert.path);
      }
    }
  }

  void _onWidgetClicked(Uri? uri) {
    if (uri != null && uri.toString().contains('meal-departure-alert')) {
      final ctx = rootNavigatorKey.currentContext;
      if (ctx != null && ctx.mounted) {
        ctx.go(AppRoute.mealDepartureAlert.path);
      }
    }
  }

  @override
  void dispose() {
    _widgetClickedSubscription?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    NotificationService.dispose().catchError((Object e, StackTrace _) {
      debugPrint('알림 서비스 종료 실패: $e');
    });
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // 앱이 포그라운드로 돌아왔을 때
      NotificationService.onAppResumed().catchError((Object e, StackTrace _) {
        debugPrint('앱 재개 시 알림 확인 실패: $e');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _notificationProvider,
      child: CupertinoTheme(
        data: buildCupertinoTheme(),
        child: Material(
          type: MaterialType.transparency,
          child: MaterialApp.router(
            title: 'LAON',
            theme: buildAppTheme(),
            routerConfig: createAppRouter(),
          ),
        ),
      ),
    );
  }
}
