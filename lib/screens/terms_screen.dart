import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:myapp/core/routing/app_router.dart';
import 'package:myapp/core/theme/app_theme.dart';
import 'package:myapp/core/theme/responsive.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Figma Onboarding-3 (653:4561), Onboarding-4 (653:4603) – TalkToFigma 2rt4amvn.
/// 440×956 #F8FAFF, radius 64. 전체동의 체크 시 Term-LAON border+text #0b66ff. [선택] 푸시/마케팅 서브 항목(Onboarding-4).
class TermsScreen extends StatefulWidget {
  const TermsScreen({super.key});

  @override
  State<TermsScreen> createState() => _TermsScreenState();
}

class _TermsScreenState extends State<TermsScreen> {
  bool _allAgreed = false;
  bool _termService = false;
  // [필수] 개인정보 수집 및 이용 동의 세부
  bool _privacySubExpanded = false;
  bool _privacyPurposeService = false;
  bool _privacyPurposeMember = false;
  bool _privacyPurposeSupport = false;
  bool get _termPrivacy =>
      _privacyPurposeService && _privacyPurposeMember && _privacyPurposeSupport;
  // [선택] 푸시 서브 – 상세 모두 체크 시 상위 체크
  bool _pushDevice = false;
  bool _pushNight = false;
  bool get _termPush => _pushDevice && _pushNight;
  // [선택] 마케팅 서브 – 상세 모두 체크 시 상위 체크
  bool _marketingEvent = false;
  bool _marketingInfo = false;
  bool get _termMarketing => _marketingEvent && _marketingInfo;
  // 서브 항목 펼침/접힘
  bool _pushSubExpanded = false;
  bool _marketingSubExpanded = false;

  bool get _requiredAgreed => _termService && _termPrivacy;
  bool get _canProceed => _requiredAgreed;

  void _toggleAll(bool value) {
    setState(() {
      _allAgreed = value;
      _termService = value;
      _privacyPurposeService = value;
      _privacyPurposeMember = value;
      _privacyPurposeSupport = value;
      _pushDevice = value;
      _pushNight = value;
      _marketingEvent = value;
      _marketingInfo = value;
    });
    // 전체 동의 시 다음 버튼 등 UI 즉시 반영
    _syncAllAgree();
  }

  void _syncAllAgree() {
    final all = _termService &&
        _termPrivacy &&
        _termPush &&
        _termMarketing;
    if (_allAgreed != all) setState(() => _allAgreed = all);
  }

  void _togglePrivacyAll(bool value) {
    setState(() {
      _privacyPurposeService = value;
      _privacyPurposeMember = value;
      _privacyPurposeSupport = value;
      _syncAllAgree();
    });
  }

  void _togglePushAll(bool value) {
    setState(() {
      _pushDevice = value;
      _pushNight = value;
      _syncAllAgree();
    });
  }

  void _toggleMarketingAll(bool value) {
    setState(() {
      _marketingEvent = value;
      _marketingInfo = value;
      _syncAllAgree();
    });
  }

  Future<void> _onNext() async {
    if (!_canProceed) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kTermsAgreedKey, true);
    if (!mounted) return;
    context.go(AppRoute.splash.path);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  context.rs(20),
                  context.rh(30),
                  context.rs(20),
                  context.rh(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '라온을 시작하려면',
                  style: TextStyle(
                    fontFamily: AppFonts.fontFamily,
                    fontSize: 24,
                    fontWeight: FontWeight.w500,
                    height: 32 / 24,
                    color: const Color(0xFF353E5C),
                  ),
                ),
                RichText(
                  text: TextSpan(
                    style: TextStyle(
                      fontFamily: AppFonts.fontFamily,
                      fontSize: 24,
                      height: 32 / 24,
                    ),
                    children: [
                      TextSpan(
                        text: '약관 동의',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF0B66FF),
                        ),
                      ),
                      TextSpan(
                        text: '가 필요해요',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF353E5C),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: context.rh(24)),
                _buildAllAgreeBox(context),
                SizedBox(height: context.rh(20)),
                Text(
                  '라온은 우리 학교 학생들과 선생님들을 위한 앱이에요',
                  style: TextStyle(
                    fontFamily: AppFonts.fontFamily,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    height: 24 / 16,
                    color: const Color(0xFF353E5C),
                  ),
                ),
                SizedBox(height: context.rh(2)),
                Text(
                  '라온 서비스는 대덕고등학교 학생과 교직원분들만 이용할 수 있어요. 학교 구성원이 맞는지 확인 후 이용해주세요.',
                  style: TextStyle(
                    fontFamily: AppFonts.fontFamily,
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    height: 18 / 12,
                    color: AppColors.navInactive,
                  ),
                ),
                SizedBox(height: context.rh(20)),
                Text(
                  '라온에서는 욕설, 괴롭힘, 불법 행위를 포함한 게시물·채팅을 허용하지 않아요. '
                  '위반 시 게시물 삭제 및 계정 제한 등 조치가 이루어질 수 있습니다. '
                  '자세한 내용은 서비스 이용약관을 확인해 주세요.',
                  style: TextStyle(
                    fontFamily: AppFonts.fontFamily,
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    height: 18 / 12,
                    color: AppColors.navInactive,
                  ),
                ),
                SizedBox(height: context.rh(20)),
                _buildTermRow(
                  context,
                  '[필수] 라온 서비스 이용약관',
                  _termService,
                  () {
                    setState(() => _termService = !_termService);
                    _syncAllAgree();
                  },
                  () => context.push(AppRoute.termsOfService.path),
                ),
                SizedBox(height: context.rh(24)),
                _buildTermRow(
                  context,
                  '[필수] 개인정보 수집 및 이용 동의',
                  _termPrivacy,
                  () => _togglePrivacyAll(!_termPrivacy),
                  null,
                  onExpandTap: () => setState(() => _privacySubExpanded = !_privacySubExpanded),
                  isExpanded: _privacySubExpanded,
                ),
                if (_privacySubExpanded) _buildPrivacySubRows(context),
                SizedBox(height: context.rh(24)),
                _buildTermRow(
                  context,
                  '[선택] 앱 푸시 알림 수신 동의',
                  _termPush,
                  () => _togglePushAll(!_termPush),
                  null,
                  onExpandTap: () => setState(() => _pushSubExpanded = !_pushSubExpanded),
                  isExpanded: _pushSubExpanded,
                ),
                if (_pushSubExpanded) _buildPushSubRows(context),
                SizedBox(height: context.rh(24)),
                _buildTermRow(
                  context,
                  '[선택] 마케팅 이용에 관한 동의',
                  _termMarketing,
                  () => _toggleMarketingAll(!_termMarketing),
                  null,
                  onExpandTap: () => setState(() => _marketingSubExpanded = !_marketingSubExpanded),
                  isExpanded: _marketingSubExpanded,
                ),
                if (_marketingSubExpanded) _buildMarketingSubRows(context),
                  ],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.only(
                left: context.rs(20),
                right: context.rs(20),
                bottom: MediaQuery.of(context).padding.bottom,
              ),
              child: _buildNextButton(context),
            ),
          ],
        ),
      ),
    );
  }

  /// Term-LAON: Line Square/Checkmark 20×20 – 네모 테두리, 체크 시 파란 채움 + 흰색 체크
  Widget _buildAllAgreeBox(BuildContext context) {
    final isChecked = _allAgreed;
    final accentColor = isChecked ? AppColors.primaryBlue : AppColors.navInactive;
    final textColor = isChecked ? AppColors.primaryBlue : AppColors.navInactive;
    return GestureDetector(
      onTap: () => _toggleAll(!_allAgreed),
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: context.rh(48),
        width: double.infinity,
        alignment: Alignment.center,
        padding: EdgeInsets.symmetric(horizontal: context.rs(16)),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: accentColor, width: 1),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildLineSquareCheckmark(20, isChecked, accentColor),
            SizedBox(width: context.rs(9)),
            Text(
              '서비스 이용약관 전체동의',
              style: TextStyle(
                fontFamily: AppFonts.fontFamily,
                fontSize: 16,
                fontWeight: FontWeight.w500,
                height: 24 / 18,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Line Square/Checkmark: 테두리 없음. 선택 전=회색 체크, 선택 시=체크 아이콘만 색상 변경(primary)
  Widget _buildLineSquareCheckmark(double size, bool checked, Color color) {
    final checkColor = checked ? color : AppColors.navInactive;
    return SizedBox(
      width: size,
      height: size,
      child: Icon(Icons.check, size: size, color: checkColor),
    );
  }

  /// Check Circle-LAON: 원형 24×24. 미체크=원 테두리, 체크=원 채움 + 흰색 체크
  Widget _buildCheckCircle(double size, bool checked) {
    final color = checked ? AppColors.primaryBlue : AppColors.navInactive;
    return SizedBox(
      width: size,
      height: size,
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: checked ? color : Colors.transparent,
          border: Border.all(color: color, width: 2),
        ),
        alignment: Alignment.center,
        child: checked
            ? SvgPicture.asset(
                'assets/icons/check_circle_check.svg',
                width: size * 0.5,
                height: size * 0.5,
                colorFilter: const ColorFilter.mode(
                  Colors.white,
                  BlendMode.srcIn,
                ),
              )
            : null,
      ),
    );
  }

  /// Frame 1707486695 개별 약관 행. Check Circle-LAON 24×24 (원형) + 텍스트 18px #353e5c + Chevron (right 또는 펼침 시 down)
  Widget _buildTermRow(
    BuildContext context,
    String title,
    bool checked,
    VoidCallback onToggle,
    VoidCallback? onDetailTap, {
    VoidCallback? onExpandTap,
    bool isExpanded = false,
  }) {
    return SizedBox(
      height: 32,
      child: Row(
        children: [
          GestureDetector(
            onTap: onToggle,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _buildCheckCircle(20, checked),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: onToggle,
              behavior: HitTestBehavior.opaque,
              child: Text(
                title,
                style: TextStyle(
                  fontFamily: AppFonts.fontFamily,
                  fontSize: 17,
                  fontWeight: FontWeight.w500,
                  height: 23 / 17,
                  color: const Color(0xFF353E5C),
                ),
              ),
            ),
          ),
          if (onDetailTap != null)
            CupertinoButton(
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              onPressed: onDetailTap,
              child: Icon(
                CupertinoIcons.chevron_right,
                size: 20,
                color: AppColors.navInactive,
              ),
            )
          else if (onExpandTap != null)
            CupertinoButton(
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              onPressed: onExpandTap,
              child: Icon(
                isExpanded ? CupertinoIcons.chevron_down : CupertinoIcons.chevron_right,
                size: 20,
                color: AppColors.navInactive,
              ),
            )
          else
            // 상세 페이지가 없는 경우 화살표 표시하되 클릭 불가
            IgnorePointer(
              child: Icon(
                CupertinoIcons.chevron_right,
                size: 20,
                color: AppColors.navInactive,
              ),
            ),
        ],
      ),
    );
  }

  /// Onboarding-4: check_LAON (Line Square/Checkmark) 20×20 + 16px #6d758f
  Widget _buildSubCheckRow(
    BuildContext context,
    String label,
    bool checked,
    ValueChanged<bool> onToggle,
  ) {
    final color = checked ? AppColors.primaryBlue : AppColors.navInactive;
    return Padding(
      padding: EdgeInsets.only(
          left: 24 + 10, top: context.rh(8), bottom: context.rh(8)),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => onToggle(!checked),
            behavior: HitTestBehavior.opaque,
            child: _buildLineSquareCheckmark(24, checked, color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              onTap: () => onToggle(!checked),
              behavior: HitTestBehavior.opaque,
              child: Text(
                label,
                style: TextStyle(
                  fontFamily: AppFonts.fontFamily,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  height: 22 / 16,
                  color: AppColors.navInactive,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrivacySubRows(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSubCheckRow(
          context,
          '서비스 이용을 위한 개인정보 수집·이용',
          _privacyPurposeService,
          (v) {
            setState(() => _privacyPurposeService = v);
            _syncAllAgree();
          },
        ),
        _buildSubCheckRow(
          context,
          '회원 식별 및 관리',
          _privacyPurposeMember,
          (v) {
            setState(() => _privacyPurposeMember = v);
            _syncAllAgree();
          },
        ),
        _buildSubCheckRow(
          context,
          '고객 문의 및 불만 처리',
          _privacyPurposeSupport,
          (v) {
            setState(() => _privacyPurposeSupport = v);
            _syncAllAgree();
          },
        ),
        Padding(
          padding: EdgeInsets.only(
            left: 24 + 10,
            top: context.rh(4),
            bottom: context.rh(8),
          ),
          child: GestureDetector(
            onTap: () => context.push(AppRoute.privacyPolicy.path),
            behavior: HitTestBehavior.opaque,
            child: Text(
              '개인정보처리방침 보기',
              style: TextStyle(
                fontFamily: AppFonts.fontFamily,
                fontSize: 14,
                fontWeight: FontWeight.w500,
                height: 20 / 14,
                color: AppColors.primaryBlue,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPushSubRows(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSubCheckRow(
          context,
          '기기 식별정보 처리 동의 (알림 전송 목적)',
          _pushDevice,
          (v) {
            setState(() => _pushDevice = v);
            _syncAllAgree();
          },
        ),
        _buildSubCheckRow(
          context,
          '야간 알림 수신 동의(21:00 ~ 06:00)',
          _pushNight,
          (v) {
            setState(() => _pushNight = v);
            _syncAllAgree();
          },
        ),
      ],
    );
  }

  Widget _buildMarketingSubRows(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSubCheckRow(
          context,
          '혜택 및 이벤트 정보 수신 동의',
          _marketingEvent,
          (v) {
            setState(() => _marketingEvent = v);
            _syncAllAgree();
          },
        ),
        _buildSubCheckRow(
          context,
          '마케팅 정보 안내를 위한 개인정보 수집 및 이용 동의',
          _marketingInfo,
          (v) {
            setState(() => _marketingInfo = v);
            _syncAllAgree();
          },
        ),
      ],
    );
  }

  /// Next-LAON: 맨 아래 고정, 화살표 없음. "다음" 18px #f8faff
  Widget _buildNextButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: context.rh(50),
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
          padding: EdgeInsets.zero,
        ),
        child: Text(
          '다음',
          style: TextStyle(
            fontFamily: AppFonts.fontFamily,
            fontSize: 18,
            fontWeight: FontWeight.w500,
            height: 24 / 18,
            color: AppColors.background,
          ),
        ),
      ),
    );
  }
}
