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
  static const String _homeWidgetAppGroupId = String.fromEnvironment(
    'HOME_WIDGET_APP_GROUP_ID',
    defaultValue: 'group.com.wearegoodwill.laon',
  );

  /// 빌드마다 새 GoRouter를 만들면 네비게이션·세션이 리셋될 수 있으므로 한 번만 생성한다.
  late final GoRouter _router = createAppRouter();

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
      _initializeHomeWidgetBridge().then((_) {
        _handleWidgetLaunch().catchError((Object e, StackTrace _) {
          debugPrint('홈 위젯 실행 라우팅 실패: $e');
        });
      });
    });
    _widgetClickedSubscription = HomeWidget.widgetClicked.listen(
      _onWidgetClicked,
      onError: (Object e, StackTrace _) {
        debugPrint('홈 위젯 클릭 스트림 오류: $e');
      },
    );
  }

  Future<void> _initializeHomeWidgetBridge() async {
    try {
      await HomeWidget.setAppGroupId(_homeWidgetAppGroupId);
    } catch (e) {
      debugPrint('HomeWidget AppGroupId 설정 실패: $e');
    }
  }

  Future<void> _handleWidgetLaunch() async {
    try {
      final uri = await HomeWidget.initiallyLaunchedFromHomeWidget();
      if (uri != null && uri.toString().contains('meal-departure-alert')) {
        final ctx = rootNavigatorKey.currentContext;
        if (ctx != null && ctx.mounted) {
          ctx.go(AppRoute.mealDepartureAlert.path);
        }
      }
    } catch (e) {
      debugPrint('HomeWidget 초기 실행 URI 확인 실패: $e');
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
            routerConfig: _router,
          ),
        ),
      ),
    );
  }
}
