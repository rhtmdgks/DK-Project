import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:myapp/core/routing/app_router.dart';
import 'package:myapp/core/theme/app_theme.dart';

class App extends StatelessWidget {
  const App({super.key});

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
