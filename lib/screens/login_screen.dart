import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:myapp/core/auth/auth_repository.dart';
import 'package:myapp/core/routing/app_router.dart';
import 'package:myapp/core/supabase_client.dart';
import 'package:myapp/core/theme/app_theme.dart';
import 'package:myapp/core/theme/responsive.dart';
import 'package:myapp/core/widgets/laon_icon.dart';
import 'package:myapp/services/notification_service.dart';
import 'package:url_launcher/url_launcher.dart';

/// 로그인 화면. Figma DK-Project node 653:4736 기준.
///
/// 배경 #F8FAFF, LAON 아이콘 + 환영 문구, 학번/비밀번호 입력 카드, 로그인 버튼.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _studentIdController = TextEditingController();
  final _passwordController = TextEditingController();
  final _studentIdFocus = FocusNode();
  final _passwordFocus = FocusNode();

  bool _loading = false;
  bool _obscurePassword = true;
  String? _error;

  bool get _canSubmit =>
      _studentIdController.text.trim().isNotEmpty &&
      _passwordController.text.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _studentIdController.addListener(() => setState(() {}));
    _passwordController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _studentIdController.dispose();
    _passwordController.dispose();
    _studentIdFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  /// Supabase 로그인 예외를 사용자용 문구로 변환한다.
  String _mapLoginError(Object e) {
    final message = e.toString();
    if (message.contains('Invalid login credentials')) {
      return '학번, 비밀번호가 맞지 않습니다. 다시 확인해주세요.';
    }
    if (message.contains('Database error querying schema')) {
      return '로그인 처리 중 서버 오류가 발생했습니다. 잠시 후 다시 시도하거나 '
          '학생회장·관리자에게 문의해 주세요.';
    }
    return '로그인에 실패했습니다: $message';
  }

  Future<void> _submit() async {
    if (!_canSubmit || _loading) return;

    setState(() {
      _error = null;
      _loading = true;
    });

    try {
      final studentId = _studentIdController.text.trim();
      final password = _passwordController.text;
      final email = '$studentId@school.local';

      final authResponse = await supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (authResponse.session == null || authResponse.user == null) {
        throw Exception('세션을 생성하지 못했습니다.');
      }

      final profile = await AuthRepository.instance.getCurrentProfile();
      if (!mounted) return;

      if (profile == null) {
        setState(() {
          _error = '프로필을 찾을 수 없습니다. 관리자에게 문의해 주세요.';
          _loading = false;
        });
        return;
      }

      NotificationService.onProfileChanged().catchError((
        Object e,
        StackTrace _,
      ) {
        debugPrint('프로필 기반 알림 구독 갱신 실패: $e');
      });

      if (profile.mustChangePassword) {
        context.go(AppRoute.passwordChange.path);
      } else {
        context.go(AppRoute.home.path);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _mapLoginError(e);
        _loading = false;
      });
    }
  }

  /// Material 3 SnackBar: 비밀번호 문의 안내 + 오른쪽 액션으로 학생회장 인스타 연결.
  /// https://api.flutter.dev/flutter/material/SnackBar-class.html
  void _showPasswordFindSnackBar() {
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: const Text('비밀번호 문의는 학생회장에게 연락해 주세요.'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: '연락하기',
          onPressed: () async {
            final uri = Uri.parse('https://www.instagram.com/s_jin_611/');
            try {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            } catch (_) {}
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hPad = context.rs(20);
    final iconSize = context.rmin(80);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.opaque,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: hPad * 0.6),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight:
                    MediaQuery.of(context).size.height -
                    MediaQuery.of(context).padding.top -
                    MediaQuery.of(context).padding.bottom,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(height: context.rh(48)),
                  LaonIcon(size: iconSize),
                  SizedBox(height: context.rh(28)),
                  Text(
                    'LAON에 오신걸 환영합니다!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: AppFonts.fontFamily,
                      fontSize: 30,
                      fontWeight: FontWeight.w500,
                      height: 38 / 30,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: context.rh(5)),
                  Text(
                    '회원 서비스 이용을 위해 로그인 해주세요.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: AppFonts.fontFamily,
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                      height: 24 / 16,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  SizedBox(height: context.rh(32)),
                  _buildCard(context),
                  SizedBox(height: context.rh(32)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCard(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '학번',
          style: TextStyle(
            fontFamily: AppFonts.fontFamily,
            fontSize: 16,
            fontWeight: FontWeight.w500,
            height: 24 / 16,
            color: AppColors.textPrimary,
          ),
        ),
        SizedBox(height: context.rh(8)),
        _buildInput(
          controller: _studentIdController,
          focusNode: _studentIdFocus,
          hint: 'ex. 10101',
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.next,
          onSubmitted: () =>
              FocusScope.of(context).requestFocus(_passwordFocus),
        ),
        SizedBox(height: context.rh(20)),
        Text(
          '비밀번호',
          style: TextStyle(
            fontFamily: AppFonts.fontFamily,
            fontSize: 16,
            fontWeight: FontWeight.w500,
            height: 24 / 16,
            color: AppColors.textPrimary,
          ),
        ),
        SizedBox(height: context.rh(8)),
        _buildInput(
          controller: _passwordController,
          focusNode: _passwordFocus,
          hint: '비밀번호를 입력하세요',
          obscureText: _obscurePassword,
          textInputAction: TextInputAction.done,
          onSubmitted: () => _submit(),
          suffix: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _obscurePassword = !_obscurePassword),
            child: SizedBox(
              width: context.rs(36),
              height: context.rs(36),
              child: Center(
                child: _obscurePassword
                    ? SvgPicture.asset(
                        'assets/icons/icon_password_eye.svg',
                        width: context.rs(16),
                        height: context.rs(16),
                        fit: BoxFit.contain,
                        colorFilter: const ColorFilter.mode(
                          AppColors.hint,
                          BlendMode.srcIn,
                        ),
                      )
                    : SvgPicture.asset(
                        'assets/icons/eye.svg',
                        width: context.rs(16),
                        height: context.rs(16),
                        fit: BoxFit.contain,
                        colorFilter: const ColorFilter.mode(
                          AppColors.hint,
                          BlendMode.srcIn,
                        ),
                      ),
              ),
            ),
          ),
        ),
        SizedBox(height: context.rh(8)),
        Align(
          alignment: Alignment.centerRight,
          child: CupertinoButton(
            padding: EdgeInsets.symmetric(
              horizontal: context.rs(8),
              vertical: context.rh(4),
            ),
            minimumSize: Size.zero,
            onPressed: _loading ? null : _showPasswordFindSnackBar,
            child: Text(
              '비밀번호 찾기',
              style: TextStyle(
                fontFamily: AppFonts.fontFamily,
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: AppColors.primaryBlue,
              ),
            ),
          ),
        ),
        if (_error != null) ...[
          SizedBox(height: context.rh(12)),
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: context.rs(12),
              vertical: context.rh(10),
            ),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppShapes.radiusSmall),
            ),
            child: Text(
              _error!,
              style: TextStyle(
                fontFamily: AppFonts.fontFamily,
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: AppColors.error,
              ),
            ),
          ),
        ],
        SizedBox(height: context.rh(40)),
        _buildLoginButton(context),
      ],
    );
  }

  Widget _buildInput({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String hint,
    bool obscureText = false,
    TextInputType? keyboardType,
    TextInputAction? textInputAction,
    VoidCallback? onSubmitted,
    Widget? suffix,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppShapes.radiusMedium),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: CupertinoTextField(
              controller: controller,
              focusNode: focusNode,
              obscureText: obscureText,
              keyboardType: keyboardType,
              textInputAction: textInputAction,
              onSubmitted: onSubmitted != null ? (_) => onSubmitted() : null,
              enabled: !_loading,
              style: TextStyle(
                fontFamily: AppFonts.fontFamily,
                fontSize: 16,
                fontWeight: FontWeight.w400,
                color: AppColors.textPrimary,
              ),
              placeholder: hint,
              placeholderStyle: TextStyle(
                fontFamily: AppFonts.fontFamily,
                fontSize: 16,
                color: AppColors.hint,
              ),
              padding: EdgeInsets.symmetric(
                horizontal: context.rs(20),
                vertical: context.rh(14),
              ),
              decoration: const BoxDecoration(color: Colors.transparent),
            ),
          ),
          if (suffix != null)
            Padding(
              padding: EdgeInsets.only(right: context.rs(16)),
              child: suffix,
            ),
        ],
      ),
    );
  }

  Widget _buildLoginButton(BuildContext context) {
    final active = _canSubmit && !_loading;

    return SizedBox(
      width: double.infinity,
      height: context.rh(50),
      child: FilledButton(
        onPressed: active ? _submit : null,
        style: FilledButton.styleFrom(
          backgroundColor: active ? AppColors.primaryBlue : AppColors.hint,
          disabledBackgroundColor: AppColors.hint,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          elevation: 0,
          padding: EdgeInsets.zero,
        ),
        child: _loading
            ? SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.background,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '로그인하기',
                    style: TextStyle(
                      fontFamily: AppFonts.fontFamily,
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      height: 24 / 18,
                      color: AppColors.background,
                    ),
                  ),
                  SizedBox(width: context.rs(6)),
                  Icon(
                    CupertinoIcons.chevron_right,
                    size: 18,
                    color: AppColors.background,
                  ),
                ],
              ),
      ),
    );
  }
}
