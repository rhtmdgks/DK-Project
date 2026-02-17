import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:myapp/core/auth/auth_state.dart';
import 'package:myapp/core/routing/app_router.dart';
import 'package:myapp/core/supabase_client.dart';
import 'package:myapp/core/theme/app_theme.dart';
import 'package:myapp/core/theme/responsive.dart';
import 'package:myapp/core/widgets/laon_icon.dart';

/// Figma "로그인 화면"에 맞춘 로그인 페이지.
///
/// 반응형: compact(폰) / medium(폴드) / expanded(태블릿)에 대응.
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
    _studentIdController.addListener(_onFieldChanged);
    _passwordController.addListener(_onFieldChanged);
  }

  void _onFieldChanged() => setState(() {});

  @override
  void dispose() {
    _studentIdController.dispose();
    _passwordController.dispose();
    _studentIdFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
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

      await supabase.rpc(
        'login_sync_password',
        params: {'p_student_id': studentId, 'p_password': password},
      );

      final email = emailFromStudentId(studentId);
      await supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (!mounted) return;

      final profile = await getCurrentProfile();
      if (!mounted) return;

      if (profile == null) {
        await supabase.auth.signOut();
        if (!mounted) return;
        setState(() {
          _error = '프로필을 찾을 수 없습니다';
          _loading = false;
        });
        return;
      }

      if (profile.mustChangePassword) {
        context.go(AppRoute.passwordChange.path);
      } else {
        context.go(AppRoute.home.path);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = '학번 또는 비밀번호를 확인하세요';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final hPad = context.rs(32);
    final iconSize = context.rmin(80);

    return CupertinoPageScaffold(
      backgroundColor: AppColors.background,
      child: Material(
        type: MaterialType.transparency,
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: hPad),
              child: ResponsiveConstraint(
                maxWidth: 480,
                child: Column(
                  children: [
                    SizedBox(height: context.rh(40)),
                    LaonIcon(size: iconSize),
                    SizedBox(height: context.rh(28)),
                    Text(
                      'LAON에 오신걸 환영합니다!',
                      textAlign: TextAlign.center,
                      style: AppFonts.scaled(context, AppFonts.heading1Medium)
                          .copyWith(height: 1.3),
                    ),
                    SizedBox(height: context.rh(6)),
                    Text(
                      '회원 서비스 이용을 위해 로그인 해주세요.',
                      textAlign: TextAlign.center,
                      style: AppFonts.scaled(context, AppFonts.bodyRegular)
                          .copyWith(color: AppColors.textSecondary),
                    ),
                    SizedBox(height: context.rh(32)),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: context.rs(24),
                        vertical: context.rh(28),
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.borderLight),
                        boxShadow: const [
                          BoxShadow(
                            color: AppColors.cardShadow,
                            offset: Offset(0, 4),
                            blurRadius: 12,
                            spreadRadius: 0,
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildLabel('학번'),
                          SizedBox(height: context.rh(6)),
                          _buildInputField(
                            controller: _studentIdController,
                            focusNode: _studentIdFocus,
                            hint: 'ex. 10101',
                            keyboardType: TextInputType.number,
                            textInputAction: TextInputAction.next,
                            onSubmitted: (_) => FocusScope.of(context)
                                .requestFocus(_passwordFocus),
                          ),
                          SizedBox(height: context.rh(20)),
                          _buildLabel('비밀번호'),
                          SizedBox(height: context.rh(6)),
                          _buildInputField(
                            controller: _passwordController,
                            focusNode: _passwordFocus,
                            obscureText: _obscurePassword,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => _submit(),
                            suffixIcon: GestureDetector(
                              onTap: () => setState(
                                  () => _obscurePassword = !_obscurePassword),
                              child: Icon(
                                _obscurePassword
                                    ? CupertinoIcons.eye_slash
                                    : CupertinoIcons.eye,
                                size: context.rs(20),
                                color: AppColors.hint,
                              ),
                            ),
                          ),
                          SizedBox(height: context.rh(6)),
                          Align(
                            alignment: Alignment.centerRight,
                            child: CupertinoButton(
                              padding: EdgeInsets.symmetric(
                                  horizontal: context.rs(8),
                                  vertical: context.rh(4)),
                              minSize: 0,
                              onPressed: () {},
                              child: Text(
                                '비밀번호 찾기',
                                style: AppFonts.scaled(context, AppFonts.smallRegular)
                                    .copyWith(color: AppColors.primaryBlue500),
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
                                color: AppColors.error.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                _error!,
                                style: AppFonts.scaled(
                                  context,
                                  AppFonts.smallRegular,
                                ).copyWith(color: AppColors.error),
                              ),
                            ),
                          ],
                          SizedBox(height: context.rh(24)),
                          _buildLoginButton(),
                        ],
                      ),
                    ),
                    SizedBox(height: context.rh(32)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
    );
  }

  Widget _buildLabel(String text) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        style: AppFonts.scaled(context, AppFonts.bodyMedium),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required FocusNode focusNode,
    String hint = '',
    bool obscureText = false,
    TextInputType? keyboardType,
    TextInputAction? textInputAction,
    ValueChanged<String>? onSubmitted,
    Widget? suffixIcon,
  }) {
    final radius = context.rs(14);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: AppColors.cardShadow,
            offset: Offset(0, 1),
            blurRadius: 3,
          ),
        ],
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
              onSubmitted: onSubmitted,
              enabled: !_loading,
              style: AppFonts.scaled(context, AppFonts.bodyRegular).copyWith(
                color: AppColors.textPrimary,
              ),
              placeholder: hint,
              placeholderStyle:
                  AppFonts.scaled(context, AppFonts.bodyRegular).copyWith(
                color: AppColors.hint,
              ),
              padding: EdgeInsets.symmetric(
                horizontal: context.rs(20),
                vertical: context.rh(14),
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(radius),
                color: AppColors.background,
              ),
            ),
          ),
          if (suffixIcon != null)
            Padding(
              padding: EdgeInsets.only(right: context.rs(16)),
              child: suffixIcon,
            ),
        ],
      ),
    );
  }

  Widget _buildLoginButton() {
    final active = _canSubmit && !_loading;

    return Container(
      width: double.infinity,
      height: context.rh(52),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        boxShadow: active
            ? const [
                BoxShadow(
                  color: AppColors.buttonShadow,
                  offset: Offset(0, 4),
                  blurRadius: 12,
                  spreadRadius: 0,
                ),
              ]
            : null,
      ),
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        borderRadius: BorderRadius.circular(14),
        color: active ? AppColors.primaryBlue : AppColors.textSecondary,
        disabledColor: AppColors.textSecondary,
        onPressed: active ? _submit : null,
        child: _loading
            ? const CupertinoActivityIndicator(color: AppColors.white)
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '로그인하기',
                    style: AppFonts.scaled(context, AppFonts.bodyMedium)
                        .copyWith(
                      color: AppColors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(width: context.rs(6)),
                  Icon(
                    CupertinoIcons.arrow_right,
                    size: context.rs(18),
                    color: AppColors.white,
                  ),
                ],
              ),
      ),
    );
  }
}
