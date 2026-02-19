import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:myapp/core/utils/avatar_utils.dart';

/// `public.profiles` 테이블의 한 행을 나타내는 불변 모델.
class AppProfile {
  const AppProfile({
    required this.id,
    required this.userId,
    required this.studentId,
    required this.role,
    required this.mustChangePassword,
    this.fullName,
    this.avatarUrl,
  });

  final String id;
  final String userId;
  final String studentId;
  final String role;
  final bool mustChangePassword;
  final String? fullName;
  final String? avatarUrl;

  factory AppProfile.fromJson(Map<String, dynamic> json) {
    return AppProfile(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      studentId: json['student_id'] as String,
      role: json['role'] as String? ?? 'student',
      mustChangePassword: json['must_change_password'] as bool? ?? true,
      fullName: json['full_name'] as String?,
      avatarUrl: json['avatar_url'] as String?,
    );
  }

  bool get isPrivileged => role == 'council' || role == 'admin';
}

/// 현재 로그인한 사용자의 프로필을 조회한다.
///
/// 세션이 없거나 프로필 행이 없으면 `null`을 반환한다.
/// avatar_url이 없으면 DiceBear API로 생성하여 저장한다.
Future<AppProfile?> getCurrentProfile() async {
  final uid = Supabase.instance.client.auth.currentUser?.id;
  if (uid == null) return null;

  final row = await Supabase.instance.client
      .from('profiles')
      .select()
      .eq('user_id', uid)
      .maybeSingle();

  if (row == null) return null;

  final profile = AppProfile.fromJson(row);
  
  // avatar_url이 없으면 DiceBear API로 생성하여 저장
  if (profile.avatarUrl == null || profile.avatarUrl!.isEmpty) {
    final avatarUrl = generateAvatarUrl(uid);
    try {
      await Supabase.instance.client
          .from('profiles')
          .update({'avatar_url': avatarUrl})
          .eq('id', profile.id);
      
      // 업데이트된 프로필 반환
      final updatedRow = await Supabase.instance.client
          .from('profiles')
          .select()
          .eq('user_id', uid)
          .maybeSingle();
      
      if (updatedRow != null) {
        return AppProfile.fromJson(updatedRow);
      }
    } catch (_) {
      // 저장 실패해도 기존 프로필 반환
    }
  }
  
  return profile;
}
