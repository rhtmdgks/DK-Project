import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:home_widget/home_widget.dart';
import 'package:myapp/core/auth/auth_state.dart';
import 'package:myapp/core/theme/app_theme.dart';
import 'package:myapp/core/theme/responsive.dart';
import 'package:myapp/services/meal_departure_alert_sender_service.dart';

/// 급식 출발 알림 전송 화면.
///
/// 학생회(council)·교사(teacher)만 사용 가능. 학년·반 선택 후 발송.
/// 백오피스 급식 출발 알림과 동일하게 Realtime Broadcast + FCM 푸시.
class MealDepartureAlertScreen extends StatefulWidget {
  const MealDepartureAlertScreen({super.key});

  @override
  State<MealDepartureAlertScreen> createState() => _MealDepartureAlertScreenState();
}

class _MealDepartureAlertScreenState extends State<MealDepartureAlertScreen> {
  int _grade = 1;
  int _classNumber = 1;
  bool _sending = false;
  String? _lastResult;
  bool _loading = true;
  bool _allowed = false;

  @override
  void initState() {
    super.initState();
    _checkRole();
  }

  Future<void> _checkRole() async {
    final profile = await getCurrentProfile();
    if (!mounted) return;
    final role = profile?.role;
    setState(() {
      _loading = false;
      _allowed = role == 'council' || role == 'teacher';
    });
  }

  static const _grades = [1, 2, 3];
  static const _classes = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10];

  Future<void> _send() async {
    setState(() {
      _sending = true;
      _lastResult = null;
    });

    try {
      final result = await MealDepartureAlertSenderService.send(
        grade: _grade,
        classNumber: _classNumber,
      );

      if (!mounted) return;
      final fcmText = result.fcmSent != null
          ? ' FCM 푸시 ${result.fcmSent}건 전송.'
          : '';
      setState(() {
        _sending = false;
        _lastResult = '$_grade학년 $_classNumber반 급식 출발 알림이 전송되었습니다.$fcmText';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_lastResult!),
          backgroundColor: AppColors.success,
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _lastResult = '전송 실패: $e';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_lastResult!),
          backgroundColor: AppColors.error,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () => Navigator.of(context).pop(),
            child: SvgPicture.asset(
              'assets/images/icon_back_arrow.svg',
              width: context.rs(12),
              height: context.rs(22),
              fit: BoxFit.contain,
            ),
          ),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (!_allowed) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () => Navigator.of(context).pop(),
            child: SvgPicture.asset(
              'assets/images/icon_back_arrow.svg',
              width: context.rs(12),
              height: context.rs(22),
              fit: BoxFit.contain,
            ),
          ),
        ),
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(context.rs(24)),
            child: Text(
              '이 기능은 학생회·교사만 사용할 수 있습니다.',
              style: AppFonts.scaled(context, AppFonts.bodyRegular),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.of(context).pop(),
          child: SvgPicture.asset(
            'assets/images/icon_back_arrow.svg',
            width: context.rs(12),
            height: context.rs(22),
            fit: BoxFit.contain,
          ),
        ),
        title: Text(
          '급식 출발 알림',
          style: AppFonts.scaled(context, _Styles.pageTitle),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.symmetric(horizontal: context.rs(24)),
          children: [
            SizedBox(height: context.rh(24)),
            Text(
              '학년과 반을 선택한 뒤 발송하면, 해당 반 학생들에게 급식 출발 알림이 전송됩니다.',
              style: AppFonts.scaled(context, AppFonts.bodyRegular).copyWith(
                color: AppColors.textSecondary,
                fontSize: context.rs(14),
              ),
            ),
            SizedBox(height: context.rh(24)),
            Container(
              padding: EdgeInsets.all(context.rs(20)),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(context.rs(24)),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildSelectRow('학년', _grade, _grades, (v) => setState(() => _grade = v)),
                  SizedBox(height: context.rh(16)),
                  _buildSelectRow('반', _classNumber, _classes, (v) => setState(() => _classNumber = v)),
                  SizedBox(height: context.rh(24)),
                  SizedBox(
                    height: context.rh(52),
                    child: FilledButton(
                      onPressed: _sending ? null : _send,
                      style: FilledButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(context.rs(16)),
                        ),
                      ),
                      child: _sending
                          ? SizedBox(
                              width: context.rs(24),
                              height: context.rs(24),
                              child: const CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              '급식 출발 알림 보내기',
                              style: AppFonts.scaled(context, AppFonts.titleSemiBold).copyWith(
                                color: Colors.white,
                                fontSize: context.rs(16),
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
            if (_lastResult != null) ...[
              SizedBox(height: context.rh(16)),
              Text(
                _lastResult!,
                style: AppFonts.scaled(context, AppFonts.bodyRegular).copyWith(
                  color: AppColors.textSecondary,
                  fontSize: context.rs(13),
                ),
              ),
            ],
            if (_allowed && Platform.isAndroid) ...[
              SizedBox(height: context.rh(24)),
              _buildWidgetCard(context),
            ],
          ],
        ),
      ),
    );
  }

  /// 학생회·교사 전용: 홈 화면 위젯 추가 카드 (Android만 지원)
  Widget _buildWidgetCard(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(context.rs(16)),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(context.rs(16)),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '홈 화면 위젯',
            style: AppFonts.scaled(context, AppFonts.titleSemiBold).copyWith(
              fontSize: context.rs(15),
            ),
          ),
          SizedBox(height: context.rh(8)),
          Text(
            '위젯을 추가하면 홈 화면에서 탭 한 번으로 이 화면을 열 수 있어요.',
            style: AppFonts.scaled(context, AppFonts.bodyRegular).copyWith(
              color: AppColors.textSecondary,
              fontSize: context.rs(13),
            ),
          ),
          SizedBox(height: context.rh(12)),
          SizedBox(
            height: context.rh(44),
            child: FilledButton(
              onPressed: () async {
                final supported = await HomeWidget.isRequestPinWidgetSupported();
                if (supported != true) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('이 기기에서는 위젯 추가를 지원하지 않아요.'),
                      ),
                    );
                  }
                  return;
                }
                try {
                  await HomeWidget.requestPinWidget(
                    qualifiedAndroidName:
                        'com.wearegoodwill.laon.glance.MealDepartureWidgetReceiver',
                  );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('위젯을 추가할 수 있는 화면으로 이동했어요.'),
                        backgroundColor: AppColors.success,
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('위젯 추가 실패: $e'),
                        backgroundColor: AppColors.error,
                      ),
                    );
                  }
                }
              },
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(context.rs(12)),
                ),
              ),
              child: Text(
                '위젯 추가',
                style: AppFonts.scaled(context, AppFonts.titleMedium).copyWith(
                  color: Colors.white,
                  fontSize: context.rs(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectRow(
    String label,
    int value,
    List<int> options,
    ValueChanged<int> onChanged,
  ) {
    return Row(
      children: [
        SizedBox(
          width: context.rs(56),
          child: Text(
            label,
            style: AppFonts.scaled(context, AppFonts.titleMedium).copyWith(
              fontSize: context.rs(15),
            ),
          ),
        ),
        Expanded(
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: context.rs(12)),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(context.rs(12)),
              border: Border.all(color: AppColors.border),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: value,
                isExpanded: true,
                items: options
                    .map((v) => DropdownMenuItem(
                          value: v,
                          child: Text('$v'),
                        ))
                    .toList(),
                onChanged: (v) {
                  if (v != null) onChanged(v);
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}

abstract final class _Styles {
  static const pageTitle = TextStyle(
    fontFamily: AppFonts.fontFamily,
    fontSize: 24,
    fontWeight: FontWeight.w600,
    height: 32 / 24,
    color: Color(0xFF19213D),
  );
}
