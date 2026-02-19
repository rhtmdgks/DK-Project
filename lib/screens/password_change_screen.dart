import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:myapp/core/routing/app_router.dart';
import 'package:myapp/core/supabase_client.dart';
import 'package:myapp/core/widgets/dismiss_keyboard.dart';
import 'package:myapp/core/theme/app_theme.dart';
import 'package:myapp/core/theme/responsive.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 첫 로그인 시 비밀번호 변경 화면. 반응형 대응.
class PasswordChangeScreen extends StatefulWidget {
  const PasswordChangeScreen({super.key});

  @override
  State<PasswordChangeScreen> createState() => _PasswordChangeScreenState();
}

class _PasswordChangeScreenState extends State<PasswordChangeScreen> {
  final _formKey = GlobalKey<FormState>();
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
      // 현재 사용자 ID 가져오기 (세션이 있으면 사용, 없으면 SharedPreferences에서)
      String? userId = supabase.auth.currentUser?.id;
      if (userId == null) {
        final prefs = await SharedPreferences.getInstance();
        userId = prefs.getString('logged_in_user_id');
      }
      
      if (userId == null) {
        throw Exception('사용자 ID를 가져올 수 없습니다');
      }
      
      // 세션이 있으면 auth.users의 비밀번호도 업데이트 시도
      if (supabase.auth.currentSession != null) {
        try {
          await supabase.auth.updateUser(UserAttributes(password: newPw));
        } catch (authError) {
          // auth.users 업데이트 실패해도 profiles 테이블 업데이트는 계속 진행
          print('Auth password update failed (continuing): $authError');
        }
      }
      
      // profiles 테이블의 password와 must_change_password 업데이트
      await supabase.rpc(
        'set_password_and_must_change_false',
        params: {
          'p_new_password': newPw,
          'p_user_id': userId,
        },
      );
      
      if (!mounted) return;
      context.go(AppRoute.home.path);
    } catch (e) {
      print('Password change error: $e');
      if (!mounted) return;
      setState(() {
        _error = '비밀번호 변경에 실패했습니다: ${e.toString()}';
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
      child: Material(
        type: MaterialType.transparency,
        child: SafeArea(
          child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(pad),
            child: ResponsiveConstraint(
              maxWidth: 480,
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '첫 로그인 시 비밀번호를 변경해야 합니다.',
                      style: AppFonts.scaled(context, AppFonts.bodyRegular),
                    ),
                    SizedBox(height: context.rh(24)),
                    CupertinoTextField(
                      controller: _newPasswordController,
                      placeholder: '새 비밀번호 (8자 이상)',
                      obscureText: true,
                      enabled: !_loading,
                      padding: EdgeInsets.symmetric(
                        horizontal: context.rs(16),
                        vertical: context.rh(12),
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                    ),
                    SizedBox(height: context.rh(16)),
                    CupertinoTextField(
                      controller: _confirmController,
                      placeholder: '새 비밀번호 확인',
                      obscureText: true,
                      enabled: !_loading,
                      onSubmitted: (_) => _submit(),
                      padding: EdgeInsets.symmetric(
                        horizontal: context.rs(16),
                        vertical: context.rh(12),
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
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
                    SizedBox(
                      width: double.infinity,
                      height: context.rh(50),
                      child: CupertinoButton(
                        padding: EdgeInsets.zero,
                        borderRadius: BorderRadius.circular(12),
                        color: AppColors.primaryBlue,
                        onPressed: _loading ? null : _submit,
                        child: _loading
                            ? const CupertinoActivityIndicator(
                                color: AppColors.white,
                              )
                            : const Text('변경 후 로그인'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
    ),
    );
  }
}
