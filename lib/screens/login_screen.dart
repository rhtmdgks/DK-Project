import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:myapp/core/auth/auth_state.dart';
import 'package:myapp/core/routing/app_router.dart';
import 'package:myapp/core/supabase_client.dart';
import 'package:myapp/core/theme/app_theme.dart';
import 'package:myapp/core/theme/responsive.dart';
import 'package:myapp/core/widgets/laon_icon.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

  Future<void> _submit() async {
    if (!_canSubmit || _loading) return;

    setState(() {
      _error = null;
      _loading = true;
    });

    try {
      final studentId = _studentIdController.text.trim();
      final password = _passwordController.text;

      print('=== LOGIN START ===');
      print('Student ID: $studentId');
      print('Password length: ${password.length}');

      // 1. profiles 테이블에서 직접 인증 확인
      print('Step 1: Calling login_from_profiles RPC...');
      dynamic result;
      try {
        result = await supabase.rpc(
          'login_from_profiles',
          params: {
            'p_student_id': studentId,
            'p_password': password,
          },
        );
        print('RPC call completed');
        print('RPC result: $result');
        print('RPC result type: ${result.runtimeType}');
        print('RPC result toString: ${result.toString()}');
      } catch (rpcError, rpcStack) {
        print('=== RPC CALL ERROR ===');
        print('RPC Error: $rpcError');
        print('RPC Error type: ${rpcError.runtimeType}');
        print('RPC Stack trace: $rpcStack');
        if (rpcError is Exception) {
          print('RPC Exception details: $rpcError');
        }
        setState(() {
          _error = 'RPC 호출 실패: $rpcError';
          _loading = false;
        });
        return;
      }

      // RPC 결과 파싱 (JSONB 반환)
      print('Step 2: Parsing RPC result...');
      Map<String, dynamic>? resultMap;
      try {
        if (result is Map<String, dynamic>) {
          resultMap = result;
          print('Result is already Map<String, dynamic>');
        } else if (result is Map) {
          resultMap = Map<String, dynamic>.from(result);
          print('Result converted from Map');
        } else if (result != null) {
          print('Attempting to convert result...');
          resultMap = Map<String, dynamic>.from(result as Map);
          print('Result converted successfully');
        } else {
          print('Result is null');
        }
        print('Parsed resultMap: $resultMap');
      } catch (parseError, parseStack) {
        print('=== RPC RESULT PARSE ERROR ===');
        print('Parse Error: $parseError');
        print('Parse Error type: ${parseError.runtimeType}');
        print('Parse Stack trace: $parseStack');
        print('Original result: $result');
        setState(() {
          _error = '결과 파싱 실패: $parseError';
          _loading = false;
        });
        return;
      }

      if (resultMap == null) {
        print('=== RPC RESULT IS NULL ===');
        setState(() {
          _error = 'RPC 결과가 null입니다';
          _loading = false;
        });
        return;
      }

      print('Step 3: Checking RPC result success...');
      print('resultMap keys: ${resultMap.keys}');
      print('resultMap values: ${resultMap.values}');
      print('success value: ${resultMap['success']}');
      print('success type: ${resultMap['success'].runtimeType}');

      if (resultMap['success'] != true) {
        print('=== RPC AUTHENTICATION FAILED ===');
        print('Success is not true');
        print('Full resultMap: $resultMap');
        setState(() {
          _error = '학번 또는 비밀번호를 확인하세요 (RPC 실패)';
          _loading = false;
        });
        return;
      }

      print('Step 4: Extracting user_id and email...');
      final userId = resultMap['user_id'] as String?;
      final email = resultMap['email'] as String?;
      print('userId: $userId');
      print('email: $email');
      print('userId type: ${userId.runtimeType}');
      print('email type: ${email.runtimeType}');

      if (userId == null || email == null) {
        print('=== MISSING USER_ID OR EMAIL ===');
        print('userId is null: ${userId == null}');
        print('email is null: ${email == null}');
        print('Full resultMap: $resultMap');
        setState(() {
          _error = '로그인 정보를 가져올 수 없습니다 (userId: $userId, email: $email)';
          _loading = false;
        });
        return;
      }

      print('Step 5: Extracting profile from RPC result...');
      // RPC 결과에서 프로필 정보 추출
      final profileData = resultMap['profile'] as Map<String, dynamic>?;
      print('Profile data from RPC: $profileData');
      
      if (profileData == null) {
        print('=== PROFILE DATA IS NULL IN RPC RESULT ===');
        setState(() {
          _error = '프로필 정보를 가져올 수 없습니다';
          _loading = false;
        });
        return;
      }

      print('Step 6: Creating AppProfile from RPC data...');
      AppProfile? profile;
      try {
        profile = AppProfile.fromJson(profileData);
        print('Profile created successfully');
        print('Profile ID: ${profile.id}');
        print('Profile student_id: ${profile.studentId}');
        print('Profile must_change_password: ${profile.mustChangePassword}');
      } catch (profileError, profileStack) {
        print('=== PROFILE CREATION ERROR ===');
        print('Profile Error: $profileError');
        print('Profile Error type: ${profileError.runtimeType}');
        print('Profile Stack trace: $profileStack');
        print('Profile data: $profileData');
        setState(() {
          _error = '프로필 생성 실패: $profileError';
          _loading = false;
        });
        return;
      }

      print('Step 7: Attempting Supabase auth.signInWithPassword (for session)...');
      print('Email: $email');
      print('Password length: ${password.length}');
      
      // 2. 세션 생성을 위해 signInWithPassword 시도
      // 백오피스 Auth 변경사항: 모든 사용자가 auth.users에 존재하므로 성공해야 함
      bool sessionCreated = false;
      try {
        // 먼저 기본 이메일 형식 시도 (${studentId}@school.local)
        try {
          final authResponse = await supabase.auth.signInWithPassword(
            email: email,
            password: password,
          );
          print('=== SUPABASE AUTH SUCCESS (기본 이메일) ===');
          print('Auth response: $authResponse');
          print('User ID: ${authResponse.user?.id}');
          print('User email: ${authResponse.user?.email}');
          print('Session: ${authResponse.session != null}');
          sessionCreated = true;
        } catch (firstError) {
          // 기본 이메일 실패 시 백오피스 형식 시도 (${username}-${profileId}@laon.local)
          final profileId = profileData['id'] as String?;
          if (profileId != null) {
            final backofficeEmail = '$studentId-$profileId@laon.local';
            print('기본 이메일 실패, 백오피스 형식 시도: $backofficeEmail');
            try {
              final authResponse = await supabase.auth.signInWithPassword(
                email: backofficeEmail,
                password: password,
              );
              print('=== SUPABASE AUTH SUCCESS (백오피스 이메일) ===');
              print('Auth response: $authResponse');
              print('User ID: ${authResponse.user?.id}');
              print('User email: ${authResponse.user?.email}');
              print('Session: ${authResponse.session != null}');
              print('사용된 이메일: $backofficeEmail');
              sessionCreated = true;
            } catch (secondError) {
              // 두 형식 모두 실패
              print('=== SUPABASE AUTH ERROR (모든 형식 실패) ===');
              print('First Error: $firstError');
              print('Second Error: $secondError');
              throw secondError;
            }
          } else {
            throw firstError;
          }
        }
      } catch (authError, authStack) {
        print('=== SUPABASE AUTH ERROR (continuing anyway) ===');
        print('Auth Error: $authError');
        print('Auth Error type: ${authError.runtimeType}');
        print('Auth Stack trace: $authStack');
        
        if (authError is Exception) {
          print('Auth Exception: $authError');
        }
        
        // Supabase Auth 에러 상세 정보
        try {
          if (authError.toString().contains('AuthApiException')) {
            print('AuthApiException detected');
          }
          print('Auth error toString: ${authError.toString()}');
        } catch (_) {}
        
        // 백오피스 변경사항: auth.users에 사용자가 있어야 하므로
        // 세션 생성 실패는 예상치 못한 상황이지만, 프로필 정보가 있으므로 계속 진행
        print('Session creation failed, but continuing with profile data from RPC');
        print('Note: 백오피스에서 auth.users를 생성했어야 하는데 실패했습니다.');
        sessionCreated = false;
      }

      if (!mounted) {
        print('=== WIDGET NOT MOUNTED (after auth attempt) ===');
        return;
      }

      if (profile == null) {
        print('=== PROFILE IS NULL ===');
        setState(() {
          _error = '프로필을 찾을 수 없습니다';
          _loading = false;
        });
        return;
      }

      print('Step 8: Saving login state to SharedPreferences...');
      // 로그인 상태를 SharedPreferences에 저장 (세션 없이도 인증 상태 유지)
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(kLoggedInKey, true);
        await prefs.setString(kLoggedInUserIdKey, userId);
        print('Login state saved successfully');
        print('Saved userId: $userId');
      } catch (prefsError) {
        print('=== SHARED PREFERENCES ERROR ===');
        print('Prefs Error: $prefsError');
        // 에러가 발생해도 계속 진행
      }

      print('Step 9: Navigation...');
      print('mustChangePassword: ${profile.mustChangePassword}');
      if (profile.mustChangePassword) {
        print('Navigating to password change screen');
        context.go(AppRoute.passwordChange.path);
      } else {
        print('Navigating to home screen');
        context.go(AppRoute.home.path);
      }
      print('=== LOGIN SUCCESS ===');
    } catch (e, stackTrace) {
      print('=== UNEXPECTED ERROR ===');
      print('Error: $e');
      print('Error type: ${e.runtimeType}');
      print('Stack trace: $stackTrace');
      
      if (e is Exception) {
        print('Exception: $e');
      }
      
      if (e is Error) {
        print('Error: $e');
      }
      
      try {
        print('Error toString: ${e.toString()}');
      } catch (_) {}
      
      if (!mounted) return;
      setState(() {
        _error = '예상치 못한 오류: $e';
        _loading = false;
      });
    }
  }

  /// Material 3 SnackBar: 비밀번호 문의 안내 + 오른쪽 액션으로 담당자 인스타 연결.
  /// https://api.flutter.dev/flutter/material/SnackBar-class.html
  void _showPasswordFindSnackBar() {
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: const Text(
          '비밀번호 문의는 담당자에게 연락해 주세요.',
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
        ),
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
                minHeight: MediaQuery.of(context).size.height -
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
                        fontSize: 27,
                        fontWeight: FontWeight.w500,
                        height: 32 / 24,
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
            onSubmitted: () => FocusScope.of(context).requestFocus(_passwordFocus),
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
              onTap: () => setState(() => _obscurePassword = !_obscurePassword),
              child: SizedBox(
                width: 14,
                height: 14,
                child: Center(
                  child: _obscurePassword
                      ? SvgPicture.asset(
                          'assets/icons/icon_password_eye.svg',
                          width: 14,
                          height: 14,
                          fit: BoxFit.contain,
                          colorFilter: const ColorFilter.mode(
                            AppColors.hint,
                            BlendMode.srcIn,
                          ),
                        )
                      : SvgPicture.asset(
                          'assets/icons/eye.svg',
                          width: 14,
                          height: 14,
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
              minSize: 0,
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
