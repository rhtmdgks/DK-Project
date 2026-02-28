import 'package:myapp/core/auth/app_profile.dart';
import 'package:myapp/core/auth/auth_repository.dart';

export 'package:myapp/core/auth/app_profile.dart';

/// 현재 로그인한 사용자의 프로필을 조회한다.
///
/// 1) Supabase Auth 세션이 있으면 user_id로 프로필 조회
/// 2) 세션이 없으면 SharedPreferences의 logged_in_user_id로 조회 (RPC 로그인 등)
/// 프로필 행이 없으면 `null`을 반환한다.
/// avatar_url이 없으면 DiceBear API로 생성하여 저장한다.
///
/// 구현은 [AuthRepository]에 위임한다.
Future<AppProfile?> getCurrentProfile() =>
    AuthRepository.instance.getCurrentProfile();
