import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:myapp/core/routing/app_router.dart';
import 'package:myapp/core/theme/app_motion.dart';
import 'package:myapp/core/theme/app_theme.dart';
import 'package:myapp/core/theme/responsive.dart';
import 'package:myapp/core/widgets/laon_icon.dart';

/// Figma "Splash" (node 653:4645) 디자인에 맞춘 스플래시 화면.
///
/// 배경색 [AppColors.background] 위에 LAON 아이콘이
/// 페이드/스케일 애니메이션으로 등장한 뒤 로그인으로 전환한다.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  static const _navigationDelay = Duration(milliseconds: 2200);

  late final AnimationController _controller;
  late final Animation<double> _fadeScale;
  Timer? _navTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppMotion.emphasisDuration,
    );
    _fadeScale = CurvedAnimation(
      parent: _controller,
      curve: AppMotion.emphasisCurve,
    );
    _controller.forward();

    _navTimer = Timer(_navigationDelay, _navigateToLogin);
  }

  void _navigateToLogin() {
    if (mounted) context.go(AppRoute.login.path);
  }

  @override
  void dispose() {
    _navTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 아이콘 크기를 화면 비율에 맞게 스케일링
    final iconSize = context.rmin(80);

    return CupertinoPageScaffold(
      backgroundColor: AppColors.background,
      child: Material(
        type: MaterialType.transparency,
        child: Center(
        child: FadeTransition(
          opacity: _fadeScale,
          child: ScaleTransition(
            scale: _fadeScale,
            child: LaonIcon(size: iconSize),
          ),
        ),
      ),
    ),
    );
  }
}
