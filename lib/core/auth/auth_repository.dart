import 'package:myapp/core/auth/app_profile.dart';
import 'package:myapp/core/supabase_client.dart';
import 'package:myapp/core/utils/avatar_url_resolver.dart';
import 'package:myapp/core/utils/avatar_utils.dart';

/// 인증/세션/프로필의 단일 진입점.
///
/// Supabase Auth 세션 기반 로그인 상태를 일관되게 관리하며,
/// 리다이렉트·로그인·로그아웃·프로필 조회는 모두 이 레이어를 통해서만 수행한다.

AppProfile _withResolvedAvatar(AppProfile p) {
  return AppProfile(
    id: p.id,
    userId: p.userId,
    studentId: p.studentId,
    role: p.role,
    mustChangePassword: p.mustChangePassword,
    fullName: p.fullName,
    avatarUrl: resolveAvatarUrl(p.avatarUrl),
    grade: p.grade,
    classNum: p.classNum,
    numberInClass: p.numberInClass,
    teacherSubjects: p.teacherSubjects,
    teacherRoles: p.teacherRoles,
    classLeaderRole: p.classLeaderRole,
    targetUniversity: p.targetUniversity,
  );
}

class AuthRepository {
  AuthRepository._();

  static final AuthRepository instance = AuthRepository._();

  /// 현재 로그인한 사용자의 프로필을 조회한다.
  ///
  /// Supabase Auth 세션의 user_id로 프로필 조회한다.
  /// 프로필 행이 없으면 `null`을 반환한다.
  /// avatar_url이 없으면 DiceBear API로 생성하여 저장한다.
  /// 백오피스가 Storage 경로만 저장한 경우 공개 URL로 변환하여 반환한다.
  Future<AppProfile?> getCurrentProfile() async {
    final uid = await getUserId();
    if (uid == null) return null;

    final row = await supabase
        .from('profiles')
        .select()
        .eq('user_id', uid)
        .maybeSingle();

    if (row == null) return null;

    final profile = AppProfile.fromJson(row);

    if (profile.avatarUrl == null || profile.avatarUrl!.isEmpty) {
      final avatarUrl = generateAvatarUrlPng(uid);
      try {
        await supabase
            .from('profiles')
            .update({'avatar_url': avatarUrl})
            .eq('id', profile.id);

        final updatedRow = await supabase
            .from('profiles')
            .select()
            .eq('user_id', uid)
            .maybeSingle();

        if (updatedRow != null) {
          return _withResolvedAvatar(AppProfile.fromJson(updatedRow));
        }
      } catch (_) {
        // RLS 등으로 DB 저장 실패 시(예: 백오피스에서 생성한 계정이 세션 없이 로그인) 무시
      }
      // DB 반영 여부와 관계없이 생성한 아바타 URL로 프로필 반환 → 메인 등에서 프로필 사진 표시
      return AppProfile(
        id: profile.id,
        userId: profile.userId,
        studentId: profile.studentId,
        role: profile.role,
        mustChangePassword: profile.mustChangePassword,
        fullName: profile.fullName,
        avatarUrl: avatarUrl,
        grade: profile.grade,
        classNum: profile.classNum,
        numberInClass: profile.numberInClass,
        teacherSubjects: profile.teacherSubjects,
        teacherRoles: profile.teacherRoles,
        classLeaderRole: profile.classLeaderRole,
        targetUniversity: profile.targetUniversity,
      );
    }

    return _withResolvedAvatar(profile);
  }

  /// 현재 로그인한 사용자의 user_id (Supabase Auth UID). 미로그인 시 null.
  Future<String?> getUserId() async {
    return supabase.auth.currentUser?.id;
  }

  /// 로그인 상태 여부 (Supabase Auth 세션 기반).
  Future<bool> isLoggedIn() async {
    return supabase.auth.currentSession != null;
  }

  /// 로그아웃: Supabase 세션을 만료시킨다.
  Future<void> logout() async {
    try {
      await supabase.auth.signOut();
    } catch (_) {
      // 세션 없을 수 있음
    }
  }

  /// 리다이렉트용: 프로필 조회 실패 시 세션을 초기화한다.
  Future<void> clearLoginState() async {
    try {
      await supabase.auth.signOut();
    } catch (_) {}
  }
}
