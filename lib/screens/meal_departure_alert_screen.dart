import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:home_widget/home_widget.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:myapp/components/apple_button.dart';
import 'package:myapp/components/apple_navigation_bar.dart';
import 'package:myapp/core/auth/auth_state.dart';
import 'package:myapp/core/theme/app_resolved_colors.dart';
import 'package:myapp/core/theme/app_theme.dart';
import 'package:myapp/core/theme/responsive.dart';
import 'package:myapp/core/widgets/app_feedback.dart';
import 'package:myapp/services/meal_departure_alert_sender_service.dart';

/// 급식 출발 알림 전송 화면.
///
/// 학생회(council)·교사(teacher)만 사용 가능. 학년·반 선택 후 발송.
/// 백오피스 급식 출발 알림과 동일하게 Realtime Broadcast + FCM 푸시.
class MealDepartureAlertScreen extends StatefulWidget {
  const MealDepartureAlertScreen({super.key});

  @override
  State<MealDepartureAlertScreen> createState() =>
      _MealDepartureAlertScreenState();
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
    setState(() {
      _loading = false;
      _allowed =
          profile != null && (profile.hasCouncilRole || profile.isTeacher);
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
      AppFeedback.showSuccess(context, _lastResult!);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _lastResult = '전송 실패: $e';
      });
      AppFeedback.showError(context, _lastResult!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    if (_loading) {
      return GlassScaffold(
        backgroundColor: colors.background,
        appBar: _buildAppBar(context),
        body: const Center(child: CupertinoActivityIndicator(radius: 12)),
      );
    }
    if (!_allowed) {
      return GlassScaffold(
        backgroundColor: colors.background,
        appBar: _buildAppBar(context),
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

    return GlassScaffold(
      backgroundColor: colors.background,
      appBar: _buildAppBar(context),
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
                  _buildSelectRow(
                    '학년',
                    _grade,
                    _grades,
                    (v) => setState(() => _grade = v),
                  ),
                  SizedBox(height: context.rh(16)),
                  _buildSelectRow(
                    '반',
                    _classNumber,
                    _classes,
                    (v) => setState(() => _classNumber = v),
                  ),
                  SizedBox(height: context.rh(24)),
                  AppleButton(
                    label: '급식 출발 알림 보내기',
                    fullWidth: true,
                    loading: _sending,
                    onPressed: _sending ? null : _send,
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

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppleNavigationBar(
      title: '급식 출발 알림',
      middle: Text(
        '급식 출발 알림',
        style: AppFonts.scaled(context, _Styles.pageTitle),
      ),
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
    );
  }

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
          AppleButton(
            label: '위젯 추가',
            fullWidth: true,
            onPressed: () async {
              final supported = await HomeWidget.isRequestPinWidgetSupported();
              if (supported != true) {
                if (context.mounted) {
                  AppFeedback.showToast(
                    context,
                    '이 기기에서는 위젯 추가를 지원하지 않아요.',
                  );
                }
                return;
              }
              try {
                await HomeWidget.requestPinWidget(
                  qualifiedAndroidName:
                      'com.goodwill.laon.glance.MealDepartureWidgetReceiver',
                );
                if (context.mounted) {
                  AppFeedback.showSuccess(
                    context,
                    '위젯을 추가할 수 있는 화면으로 이동했어요.',
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  AppFeedback.showError(context, '위젯 추가 실패: $e');
                }
              }
            },
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
          child: GestureDetector(
            onTap: () => _showPicker(label, value, options, onChanged),
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: context.rs(12),
                vertical: context.rh(12),
              ),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(context.rs(12)),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '$value',
                      style: AppFonts.scaled(context, AppFonts.bodyRegular),
                    ),
                  ),
                  const Icon(
                    CupertinoIcons.chevron_down,
                    size: 16,
                    color: AppColors.hint,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _showPicker(
    String label,
    int currentValue,
    List<int> options,
    ValueChanged<int> onChanged,
  ) async {
    var selectedIndex = options.indexOf(currentValue);
    if (selectedIndex < 0) selectedIndex = 0;

    await showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => Container(
        height: context.rh(260),
        color: AppColors.white,
        child: Column(
          children: [
            SizedBox(
              height: context.rh(44),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CupertinoButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('취소'),
                  ),
                  Text(
                    label,
                    style: AppFonts.scaled(context, AppFonts.titleMedium),
                  ),
                  CupertinoButton(
                    onPressed: () {
                      onChanged(options[selectedIndex]);
                      Navigator.of(ctx).pop();
                    },
                    child: const Text('완료'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: CupertinoPicker(
                scrollController: FixedExtentScrollController(
                  initialItem: selectedIndex,
                ),
                itemExtent: context.rh(36),
                onSelectedItemChanged: (index) => selectedIndex = index,
                children: [
                  for (final option in options)
                    Center(child: Text('$option')),
                ],
              ),
            ),
          ],
        ),
      ),
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
