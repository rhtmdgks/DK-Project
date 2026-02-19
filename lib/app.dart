import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:myapp/core/routing/app_router.dart';
import 'package:myapp/core/theme/app_theme.dart';
import 'package:myapp/services/weather_notification_service.dart';

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // 알림/타임존 초기화 실패 시에도 앱이 죽지 않도록 (아이콘에서 재실행 시 크래시 방지)
    Future.microtask(() => WeatherNotificationService.initialize())
        .catchError((Object e, StackTrace _) {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      WeatherNotificationService.maybeShowWeatherNotificationIfNeeded()
          .catchError((Object e, StackTrace _) {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoTheme(
      data: buildCupertinoTheme(),
      child: Material(
        type: MaterialType.transparency,
        child: MaterialApp.router(
          title: 'LAON',
          theme: buildAppTheme(),
          routerConfig: createAppRouter(),
        ),
      ),
    );
  }
}
