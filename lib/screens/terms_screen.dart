import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:myapp/core/theme/app_theme.dart';
import 'package:myapp/core/theme/responsive.dart';

/// Figma "onboding" 화면 (node-id=653-4497)
/// 약관 동의 온보딩 페이지
class TermsScreen extends StatefulWidget {
  const TermsScreen({super.key});

  @override
  State<TermsScreen> createState() => _TermsScreenState();
}

class _TermsScreenState extends State<TermsScreen> {
  bool _allAgreed = false;
  bool _serviceTerms = false;
  bool _privacyPolicy = false;
  bool _pushNotification = false;
  bool _marketing = false;

  void _toggleAll(bool value) {
    setState(() {
      _allAgreed = value;
      _serviceTerms = value;
      _privacyPolicy = value;
      _pushNotification = value;
      _marketing = value;
    });
  }

  void _updateIndividual() {
    setState(() {
      _allAgreed =
          _serviceTerms && _privacyPolicy && _pushNotification && _marketing;
    });
  }

  bool get _canProceed => _serviceTerms && _privacyPolicy;

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppColors.background,
      child: Material(
        type: MaterialType.transparency,
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(horizontal: context.rs(22)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: context.rh(37)),
                      _buildHeader(),
                      SizedBox(height: context.rh(33)),
                      _buildAllAgreeBox(),
                      SizedBox(height: context.rh(33)),
                      _buildInfoSection(),
                      SizedBox(height: context.rh(33)),
                      _buildTermsList(),
                      SizedBox(height: context.rh(100)),
                    ],
                  ),
                ),
              ),
              _buildBottomButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '라온을 시작하려면',
          style: TextStyle(
            fontFamily: AppFonts.fontFamily,
            fontSize: context.rs(24),
            fontWeight: FontWeight.w500,
            height: 32 / 24,
            color: AppColors.textPrimary,
          ),
        ),
        SizedBox(height: context.rh(5)),
        Text(
          '약관 동의가 필요해요',
          style: TextStyle(
            fontFamily: AppFonts.fontFamily,
            fontSize: context.rs(32),
            fontWeight: FontWeight.w500,
            height: 38.4 / 32,
            letterSpacing: -0.5,
            color: AppColors.textDarkFigma,
          ),
        ),
      ],
    );
  }

  Widget _buildAllAgreeBox() {
    return GestureDetector(
      onTap: () => _toggleAll(!_allAgreed),
      child: Container(
        height: context.rh(63),
        padding: EdgeInsets.symmetric(horizontal: context.rs(20)),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: AppColors.navInactive,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            _buildSquareCheckbox(_allAgreed, size: 20.25),
            SizedBox(width: context.rs(9)),
            Text(
              '서비스 이용약관 전체동의',
              style: TextStyle(
                fontFamily: AppFonts.fontFamily,
                fontSize: context.rs(18),
                fontWeight: FontWeight.w500,
                height: 24 / 18,
                color: AppColors.navInactive,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '라온은 우리 학교 학생들과 선생님들을 위한 앱이에요',
          style: TextStyle(
            fontFamily: AppFonts.fontFamily,
            fontSize: context.rs(18),
            fontWeight: FontWeight.w500,
            height: 24 / 18,
            color: AppColors.textPrimary,
          ),
        ),
        SizedBox(height: context.rh(16)),
        Text(
          '라온 서비스는 대덕고등학교 학생과 교직원분들만 이용할 수 있어요. 학교 구성원이 맞는지 확인 후 이용해주세요.',
          style: TextStyle(
            fontFamily: AppFonts.fontFamily,
            fontSize: context.rs(12),
            fontWeight: FontWeight.w400,
            height: 18 / 12,
            color: AppColors.navInactive,
          ),
        ),
      ],
    );
  }

  Widget _buildTermsList() {
    return Column(
      children: [
        _buildTermItem(
          '[필수] 라온 서비스 이용약관',
          _serviceTerms,
          (value) {
            setState(() {
              _serviceTerms = value;
              _updateIndividual();
            });
          },
        ),
        SizedBox(height: context.rh(23)),
        _buildTermItem(
          '[필수] 개인정보 수집 및 이용 동의',
          _privacyPolicy,
          (value) {
            setState(() {
              _privacyPolicy = value;
              _updateIndividual();
            });
          },
        ),
        SizedBox(height: context.rh(23)),
        _buildTermItem(
          '[선택] 앱 푸시 알림 수신 동의',
          _pushNotification,
          (value) {
            setState(() {
              _pushNotification = value;
              _updateIndividual();
            });
          },
        ),
        SizedBox(height: context.rh(23)),
        _buildTermItem(
          '[선택] 마케팅 이용에 관한 동의',
          _marketing,
          (value) {
            setState(() {
              _marketing = value;
              _updateIndividual();
            });
          },
        ),
      ],
    );
  }

  Widget _buildTermItem(
    String title,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return SizedBox(
      height: context.rh(35),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => onChanged(!value),
            child: _buildCircleCheckbox(value),
          ),
          SizedBox(width: context.rs(10)),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontFamily: AppFonts.fontFamily,
                fontSize: context.rs(18),
                fontWeight: FontWeight.w500,
                height: 24 / 18,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          SizedBox(
            width: context.rs(35),
            height: context.rs(35),
            child: Icon(
              CupertinoIcons.chevron_right,
              size: context.rs(18),
              color: AppColors.navInactive,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSquareCheckbox(bool value, {required double size}) {
    return Container(
      width: context.rs(size),
      height: context.rs(size),
      decoration: BoxDecoration(
        color: value ? AppColors.primaryBlue : Colors.transparent,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: value ? AppColors.primaryBlue : const Color(0xFFB7C0D2),
          width: 1.5,
        ),
      ),
      child: value
          ? Icon(
              Icons.check,
              size: context.rs(size * 0.7),
              color: AppColors.white,
            )
          : null,
    );
  }

  Widget _buildCircleCheckbox(bool value) {
    return Container(
      width: context.rs(24),
      height: context.rs(24),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: value ? AppColors.primaryBlue : Colors.transparent,
        border: Border.all(
          color: value ? AppColors.primaryBlue : const Color(0xFFB7C0D2),
          width: 2,
        ),
      ),
      child: value
          ? Icon(
              Icons.check,
              size: context.rs(14),
              color: AppColors.white,
            )
          : null,
    );
  }

  Widget _buildBottomButton() {
    return Container(
      padding: EdgeInsets.fromLTRB(
        context.rs(32),
        context.rh(12),
        context.rs(32),
        context.rh(16),
      ),
      decoration: const BoxDecoration(
        color: AppColors.background,
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          height: context.rh(56),
          child: FilledButton(
            onPressed: _canProceed ? _onNext : null,
            style: FilledButton.styleFrom(
              backgroundColor:
                  _canProceed ? AppColors.primaryBlue : AppColors.hint,
              disabledBackgroundColor: AppColors.hint,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              elevation: 0,
            ),
            child: Text(
              '다음',
              style: TextStyle(
                fontFamily: AppFonts.fontFamily,
                fontSize: context.rs(18),
                fontWeight: FontWeight.w500,
                height: 24 / 18,
                color: AppColors.background,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _onNext() {
    // Navigate to next screen
    // context.go(AppRoute.nextScreen.path);
  }
}
