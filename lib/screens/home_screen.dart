import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:myapp/core/theme/app_theme.dart';
import 'package:myapp/core/widgets/app_bottom_nav_bar.dart';
import 'package:myapp/features/home/home_tab.dart';
import 'package:myapp/features/meal/meal_tab.dart';
import 'package:myapp/features/notice_poll/notice_poll_tab.dart';
import 'package:myapp/features/schedule/schedule_tab.dart';
import 'package:myapp/features/suggestions/suggestions_tab.dart';

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

  static const _tabs = <Widget>[
    HomeTab(),
    MealTab(),
    ScheduleTab(),
    SuggestionsTab(),
    NoticePollTab(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
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
