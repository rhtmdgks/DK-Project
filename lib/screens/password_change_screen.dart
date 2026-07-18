import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:myapp/components/apple_button.dart';
import 'package:myapp/components/apple_text_field.dart';
import 'package:myapp/core/auth/auth_repository.dart';
import 'package:myapp/core/routing/app_router.dart';
import 'package:myapp/core/supabase_client.dart';
import 'package:myapp/core/widgets/dismiss_keyboard.dart';
import 'package:myapp/core/theme/app_theme.dart';
import 'package:myapp/core/theme/responsive.dart';

/// 첫 로그인 시 비밀번호 변경 화면. 반응형 대응.
class PasswordChangeScreen extends StatefulWidget {
  const PasswordChangeScreen({super.key});

  @override
  State<PasswordChangeScreen> createState() => _PasswordChangeScreenState();
}

class _PasswordChangeScreenState extends State<PasswordChangeScreen> {
  final _newPasswordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _loading = false;
  bool _submitted = false;
  String? _error;

  @override
  void dispose() {
    _newPasswordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  /// Supabase Auth·기타 예외를 화면용 문구로 변환한다.
  String _mapPasswordChangeError(Object e) {
    if (e is AuthException) {
      if (e.code == 'same_password') {
        return '새 비밀번호는 기존 비밀번호와 달라야 합니다.';
      }
      final m = e.message;
      if (m.contains('different from the old') || m.contains('same_password')) {
        return '새 비밀번호는 기존 비밀번호와 달라야 합니다.';
      }
    }
    final s = e.toString();
    if (s.contains('same_password') || s.contains('different from the old')) {
      return '새 비밀번호는 기존 비밀번호와 달라야 합니다.';
    }
    return '비밀번호 변경에 실패했습니다: $s';
  }

  Future<void> _submit() async {
    if (_submitted) return;

    final newPw = _newPasswordController.text;
    final confirm = _confirmController.text;

    if (newPw.length < 8) {
      setState(() => _error = '비밀번호는 8자 이상이어야 합니다');
      return;
    }
    if (newPw != confirm) {
      setState(() => _error = '비밀번호가 일치하지 않습니다');
      return;
    }

    setState(() {
      _loading = true;
      _submitted = true;
      _error = null;
    });

    try {
      final userId = await AuthRepository.instance.getUserId();
      if (userId == null) {
        throw Exception('사용자 ID를 가져올 수 없습니다');
      }

      if (supabase.auth.currentSession == null) {
        throw Exception('세션이 없습니다');
      }
      await supabase.auth.updateUser(UserAttributes(password: newPw));

      await supabase.rpc('set_must_change_password_false');

      if (!mounted) return;
      context.go(AppRoute.home.path);
    } catch (e) {
      debugPrint('Password change error: $e');
      if (!mounted) return;
      setState(() {
        _error = _mapPasswordChangeError(e);
        _loading = false;
        _submitted = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final pad = context.rs(24);

    return DismissKeyboard(
      child: CupertinoPageScaffold(
        backgroundColor: AppColors.background,
        navigationBar: CupertinoNavigationBar(
          backgroundColor: AppColors.white,
          border: null,
          middle: Text(
            '비밀번호 변경',
            style: AppFonts.scaled(context, AppFonts.titleSemiBold)
                .copyWith(color: AppColors.textDark),
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(pad),
              child: ResponsiveConstraint(
                maxWidth: 480,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '첫 로그인 시 비밀번호를 변경해야 합니다.',
                      style: AppFonts.scaled(context, AppFonts.bodyRegular),
                    ),
                    SizedBox(height: context.rh(24)),
                    AppleTextField(
                      controller: _newPasswordController,
                      placeholder: '새 비밀번호 (8자 이상)',
                      obscureText: true,
                      enabled: !_loading,
                    ),
                    SizedBox(height: context.rh(16)),
                    AppleTextField(
                      controller: _confirmController,
                      placeholder: '새 비밀번호 확인',
                      obscureText: true,
                      enabled: !_loading,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _submit(),
                    ),
                    if (_error != null) ...[
                      SizedBox(height: context.rh(16)),
                      Text(
                        _error!,
                        style: AppFonts.scaled(context, AppFonts.smallRegular)
                            .copyWith(color: AppColors.error),
                      ),
                    ],
                    SizedBox(height: context.rh(24)),
                    AppleButton(
                      label: '변경 후 로그인',
                      fullWidth: true,
                      loading: _loading,
                      onPressed: _loading ? null : _submit,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
