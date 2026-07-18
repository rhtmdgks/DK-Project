import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:myapp/components/apple_button.dart';
import 'package:myapp/components/apple_list_tile.dart';
import 'package:myapp/components/apple_modal.dart';
import 'package:myapp/core/auth/auth_repository.dart';
import 'package:myapp/core/routing/app_router.dart';
import 'package:myapp/core/school/school_context.dart';
import 'package:myapp/core/supabase_client.dart';
import 'package:myapp/core/theme/app_theme.dart';
import 'package:myapp/core/theme/responsive.dart';
import 'package:myapp/core/widgets/app_feedback.dart';
import 'package:myapp/core/widgets/laon_icon.dart';
import 'package:myapp/models/school.dart';
import 'package:myapp/repositories/school_repository.dart';
import 'package:myapp/services/notification_service.dart';

/// 로그인 화면. Figma DK-Project node 653:4736 기준.
///
/// 배경 #F8FAFF, LAON 아이콘 + 환영 문구, 학번/비밀번호 입력 카드, 로그인 버튼.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _usernameFocus = FocusNode();
  final _passwordFocus = FocusNode();

  bool _loading = false;
  bool _obscurePassword = true;
  String? _error;

  /// 선택된 학교. 미선택 시 로그인 불가.
  School? _selectedSchool;

  /// 백그라운드에서 로드한 활성 학교 목록 캐시. 실패 시 null 유지(시트에서 재시도).
  List<School>? _schools;

  bool get _canSubmit =>
      _selectedSchool != null &&
      _usernameController.text.trim().isNotEmpty &&
      _passwordController.text.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _usernameController.addListener(() => setState(() {}));
    _passwordController.addListener(() => setState(() {}));
    _restoreLastSchool();
    _loadSchools();
  }

  /// 마지막으로 선택했던 학교를 로컬 캐시에서 복원한다.
  Future<void> _restoreLastSchool() async {
    try {
      final last = await SchoolRepository.instance.getLastSelectedSchool();
      if (!mounted || last == null) return;
      if (_selectedSchool == null) {
        setState(() => _selectedSchool = last);
      }
    } catch (_) {
      // 복원 실패는 조용히 무시
    }
  }

  /// 활성 학교 목록을 백그라운드 로드한다. 정확히 1개면 자동 선택(전환기 대응).
  Future<void> _loadSchools() async {
    try {
      final schools = await SchoolRepository.instance.fetchActiveSchools();
      if (!mounted) return;
      setState(() {
        _schools = schools;
        if (schools.length == 1) {
          _selectedSchool = schools.first;
        }
      });
    } catch (_) {
      // 실패는 조용히 무시 — 시트를 열 때 재시도한다.
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _usernameFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  static const _loginStepTimeout = Duration(seconds: 30);

  Future<T> _withLoginTimeout<T>(Future<T> future, String step) {
    return future.timeout(
      _loginStepTimeout,
      onTimeout: () =>
          throw TimeoutException('로그인 단계 시간 초과 ($step)', _loginStepTimeout),
    );
  }

  /// Supabase 로그인 예외를 사용자용 문구로 변환한다.
  String _mapLoginError(Object e) {
    if (e is TimeoutException) {
      return '서버 응답이 너무 오래 걸립니다. 네트워크 연결을 확인한 뒤 다시 시도해 주세요.';
    }
    final message = e.toString();
    if (message.contains('Invalid login credentials')) {
      return '아이디, 비밀번호가 맞지 않습니다. 다시 확인해주세요.';
    }
    if (message.contains('Database error querying schema')) {
      return '로그인 처리 중 서버 오류가 발생했습니다. 잠시 후 다시 시도하거나 '
          '학생회장·관리자에게 문의해 주세요.';
    }
    return '로그인에 실패했습니다: $message';
  }

  bool _isTransientAuthError(Object e) {
    final m = e.toString().toLowerCase();
    return m.contains('502') ||
        m.contains('500') ||
        m.contains('bad gateway') ||
        m.contains('database error querying schema') ||
        m.contains('timeout') ||
        m.contains('context canceled');
  }

  Future<String> _resolveLoginEmail({
    required String studentId,
    required String password,
  }) async {
    try {
      final rpc = await supabase.rpc(
        'login_from_profiles',
        params: {'p_student_id': studentId, 'p_password': password},
      );
      if (rpc is Map<String, dynamic>) {
        final email = rpc['email']?.toString().trim();
        if (email != null && email.isNotEmpty) return email;
      }
    } catch (_) {
      // RPC 실패 시 레거시 이메일 포맷으로 폴백
    }
    return '$studentId@school.local';
  }

  /// 신규 RPC `login_with_username`으로 auth 이메일을 조회한다.
  ///
  /// 서버 미배포/실패 시 null을 반환하고 조용히 폴백한다.
  Future<String?> _resolveEmailFromUsername({
    required String schoolSlug,
    required String username,
  }) async {
    try {
      final rpc = await _withLoginTimeout(
        supabase.rpc(
          'login_with_username',
          params: {'p_school_slug': schoolSlug, 'p_username': username},
        ),
        'login_with_username',
      );
      if (rpc is Map<String, dynamic>) {
        final email = rpc['email']?.toString().trim();
        if (email != null && email.isNotEmpty) return email;
      }
    } catch (e) {
      // 서버에 아직 RPC가 없거나 실패한 경우 → 레거시 경로로 폴백.
      if (kDebugMode) {
        debugPrint('[login] login_with_username 실패(무시): $e');
      }
    }
    return null;
  }

  Future<void> _submit() async {
    if (!_canSubmit || _loading) return;
    final school = _selectedSchool;
    if (school == null) return;

    setState(() {
      _error = null;
      _loading = true;
    });

    try {
      final username = _usernameController.text.trim();
      final password = _passwordController.text;

      final candidateSet = <String>{};

      // ① 신규 RPC: 학교 슬러그 + 아이디 → auth 이메일 (성공 시 1순위 후보)
      if (kDebugMode) {
        debugPrint('[login] RPC login_with_username 시작');
      }
      final rpcEmail = await _resolveEmailFromUsername(
        schoolSlug: school.slug,
        username: username,
      );
      if (rpcEmail != null) {
        candidateSet.add(rpcEmail);
      }

      // ② 5자리 학번이면 레거시 경로(login_from_profiles + 레거시 이메일 포맷)
      if (RegExp(r'^\d{5}$').hasMatch(username)) {
        if (kDebugMode) {
          debugPrint('[login] RPC login_from_profiles 시작');
        }
        final resolvedEmail = await _withLoginTimeout(
          _resolveLoginEmail(studentId: username, password: password),
          'login_from_profiles',
        );
        candidateSet.add(resolvedEmail);
        candidateSet.addAll(legacyEmailCandidates(username));
      }

      // ③ 후보가 하나도 없으면(비5자리 + 신규 RPC 실패) 신규 이메일 규칙 폴백
      if (candidateSet.isEmpty) {
        candidateSet.add('$username@${school.slug}.laon.local');
      }

      final emailCandidates = candidateSet
          .where((e) => e.trim().isNotEmpty)
          .toList();
      if (kDebugMode) {
        debugPrint('[login] 후보 이메일: $emailCandidates');
      }

      dynamic authResponse;
      Object? lastError;
      for (final email in emailCandidates) {
        for (int attempt = 0; attempt < 2; attempt++) {
          try {
            if (kDebugMode) {
              debugPrint('[login] signInWithPassword 시도: $email');
            }
            authResponse = await _withLoginTimeout(
              supabase.auth.signInWithPassword(
                email: email,
                password: password,
              ),
              'signInWithPassword($email)',
            );
            if (authResponse.session != null && authResponse.user != null) {
              break;
            }
          } catch (e) {
            lastError = e;
            if (!_isTransientAuthError(e) || attempt == 1) {
              break;
            }
            await Future<void>.delayed(const Duration(milliseconds: 400));
          }
        }
        if (authResponse?.session != null && authResponse?.user != null) {
          break;
        }
      }

      if (authResponse == null ||
          authResponse.session == null ||
          authResponse.user == null) {
        if (lastError != null) throw lastError;
        throw Exception('세션을 생성하지 못했습니다.');
      }

      if (kDebugMode) {
        debugPrint('[login] 세션 수립됨 → 프로필 조회');
      }
      SchoolContext.instance.set(school);
      final profile = await _withLoginTimeout(
        AuthRepository.instance.getCurrentProfile(),
        'getCurrentProfile',
      );
      if (!mounted) return;

      if (profile == null) {
        setState(() {
          _error = '프로필을 찾을 수 없습니다. 관리자에게 문의해 주세요.';
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
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _showPasswordFindFeedback() {
    AppFeedback.showToast(
      context,
      '비밀번호 재설정은 추후 이메일 인증으로 제공될 예정입니다. '
      '당분간은 학생회장에게 문의해 주세요.',
      duration: const Duration(seconds: 4),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hPad = context.rs(20);
    final iconSize = context.rmin(80);

    return CupertinoPageScaffold(
      backgroundColor: AppColors.background,
      child: GestureDetector(
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
          '학교',
          style: TextStyle(
            fontFamily: AppFonts.fontFamily,
            fontSize: 16,
            fontWeight: FontWeight.w500,
            height: 24 / 16,
            color: AppColors.textPrimary,
          ),
        ),
        SizedBox(height: context.rh(8)),
        _buildSchoolField(context),
        SizedBox(height: context.rh(20)),
        Text(
          '아이디',
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
          controller: _usernameController,
          focusNode: _usernameFocus,
          hint: '학번 또는 아이디',
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
            onPressed: _loading ? null : _showPasswordFindFeedback,
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

  /// 학교 선택 필드. [_buildInput]과 동일한 컨테이너 스타일의 탭 가능한 필드.
  Widget _buildSchoolField(BuildContext context) {
    final school = _selectedSchool;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _loading ? null : _showSchoolPicker,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(
          horizontal: context.rs(20),
          vertical: context.rh(14),
        ),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(AppShapes.radiusMedium),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                school?.name ?? '학교를 선택하세요',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: AppFonts.fontFamily,
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  color: school != null
                      ? AppColors.textPrimary
                      : AppColors.hint,
                ),
              ),
            ),
            SizedBox(width: context.rs(8)),
            const Icon(
              CupertinoIcons.chevron_down,
              size: 18,
              color: AppColors.hint,
            ),
          ],
        ),
      ),
    );
  }

  /// 학교 목록 바텀시트를 열고 선택 결과를 반영한다.
  Future<void> _showSchoolPicker() async {
    FocusScope.of(context).unfocus();
    final selected = await AppleModal.showBottomSheetPage<School>(
      context: context,
      heightFactor: 0.5,
      child: _SchoolPickerSheet(
        initialSchools: _schools,
        selectedSchoolId: _selectedSchool?.id,
        onLoaded: (schools) => _schools = schools,
      ),
    );
    if (selected != null && mounted) {
      setState(() => _selectedSchool = selected);
    }
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
              decoration: const BoxDecoration(color: Color(0x00000000)),
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
      height: context.rh(50),
      child: AppleButton(
        label: '로그인하기',
        icon: CupertinoIcons.chevron_right,
        fullWidth: true,
        loading: _loading,
        onPressed: active ? _submit : null,
      ),
    );
  }
}

/// 학교 선택 바텀시트 콘텐츠.
///
/// [initialSchools]가 있으면 즉시 표시하고, 없으면 직접 로드한다.
/// 로드 실패 시 에러 문구와 재시도 버튼을 보여준다.
/// 항목 선택 시 [Navigator.pop]으로 선택한 [School]을 반환한다.
class _SchoolPickerSheet extends StatefulWidget {
  const _SchoolPickerSheet({
    this.initialSchools,
    this.selectedSchoolId,
    this.onLoaded,
  });

  final List<School>? initialSchools;
  final String? selectedSchoolId;

  /// 시트 내부에서 목록 로드에 성공했을 때 부모 캐시 갱신용 콜백.
  final ValueChanged<List<School>>? onLoaded;

  @override
  State<_SchoolPickerSheet> createState() => _SchoolPickerSheetState();
}

class _SchoolPickerSheetState extends State<_SchoolPickerSheet> {
  List<School>? _schools;
  bool _loading = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialSchools;
    if (initial != null && initial.isNotEmpty) {
      _schools = initial;
    } else {
      _fetch();
    }
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final schools = await SchoolRepository.instance.fetchActiveSchools();
      if (!mounted) return;
      setState(() {
        _schools = schools;
        _loading = false;
      });
      widget.onLoaded?.call(schools);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              context.rs(20),
              context.rh(16),
              context.rs(20),
              context.rh(8),
            ),
            child: Text(
              '학교 선택',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppFonts.fontFamily,
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          Expanded(child: _buildBody(context)),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) {
      return const Center(child: CupertinoActivityIndicator(radius: 12));
    }
    final schools = _schools;
    if (_failed || schools == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '학교 목록을 불러오지 못했습니다.',
              style: TextStyle(
                fontFamily: AppFonts.fontFamily,
                fontSize: 15,
                fontWeight: FontWeight.w400,
                color: AppColors.textSecondary,
              ),
            ),
            SizedBox(height: context.rh(12)),
            CupertinoButton(
              onPressed: _fetch,
              child: Text(
                '다시 시도',
                style: TextStyle(
                  fontFamily: AppFonts.fontFamily,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: AppColors.primaryBlue,
                ),
              ),
            ),
          ],
        ),
      );
    }
    if (schools.isEmpty) {
      return Center(
        child: Text(
          '등록된 학교가 없습니다.',
          style: TextStyle(
            fontFamily: AppFonts.fontFamily,
            fontSize: 15,
            fontWeight: FontWeight.w400,
            color: AppColors.textSecondary,
          ),
        ),
      );
    }
    return ListView.builder(
      padding: EdgeInsets.only(bottom: context.rh(16)),
      itemCount: schools.length,
      itemBuilder: (ctx, index) {
        final school = schools[index];
        final selected = school.id == widget.selectedSchoolId;
        return AppleListTile(
          title: school.name,
          subtitle: school.nameEn,
          trailing: selected
              ? const Icon(
                  CupertinoIcons.check_mark,
                  size: 18,
                  color: AppColors.primaryBlue,
                )
              : null,
          onTap: () => Navigator.of(context).pop(school),
        );
      },
    );
  }
}
