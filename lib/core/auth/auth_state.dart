import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:myapp/core/utils/avatar_utils.dart';

/// `public.profiles` 테이블의 한 행을 나타내는 불변 모델.
/// 학번 5자리 규칙: G(1) + 반(2) + 번(2) → 10102 = 1학년 1반 2번, 11002 = 1학년 10반 2번.
class AppProfile {
  const AppProfile({
    required this.id,
    required this.userId,
    required this.studentId,
    required this.role,
    required this.mustChangePassword,
    this.fullName,
    this.avatarUrl,
    this.grade,
    this.classNum,
    this.numberInClass,
  });

  final String id;
  final String userId;
  final String studentId;
  final String role;
  final bool mustChangePassword;
  final String? fullName;
  final String? avatarUrl;
  /// 학년(1-3). DB에 없으면 학번 첫 자리로 추론 가능.
  final int? grade;
  /// 반. DB에 없으면 학번 2~3자리로 추론 가능.
  final int? classNum;
  /// 번. DB에 없으면 학번 4~5자리로 추론 가능.
  final int? numberInClass;

  factory AppProfile.fromJson(Map<String, dynamic> json) {
    return AppProfile(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      studentId: (json['student_id'] ?? '').toString().trim(),
      role: json['role'] as String? ?? 'student',
      mustChangePassword: json['must_change_password'] as bool? ?? true,
      fullName: json['full_name'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      grade: _intOrNull(json['grade']),
      classNum: _intOrNull(json['class_num']),
      numberInClass: _intOrNull(json['number_in_class']) ??
          _intOrNull(json['student_number']),
    );
  }

  static int? _intOrNull(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    return int.tryParse(v.toString());
  }

  /// 학번 5자리 규칙으로 학년·반·번호 추론 (DB 컬럼 없을 때 대비).
  int? get gradeOrFromStudentId =>
      grade ?? _parseGradeClassNumber(studentId).$1;
  int? get classNumOrFromStudentId =>
      classNum ?? _parseGradeClassNumber(studentId).$2;
  int? get numberInClassOrFromStudentId =>
      numberInClass ?? _parseGradeClassNumber(studentId).$3;

  /// 학번 5자리 규칙: G(1) + 반(2) + 번(2) → 10201 = 1학년 2반 1번, 11002 = 1학년 10반 2번.
  static (int?, int?, int?) _parseGradeClassNumber(String s) {
    final t = s.trim();
    if (t.length != 5) return (null, null, null);
    final g = int.tryParse(t.substring(0, 1));
    final c = int.tryParse(t.substring(1, 3));
    final n = int.tryParse(t.substring(3, 5));
    return (g, c, n);
  }

  bool get isPrivileged => role == 'council' || role == 'admin';
}

/// 현재 로그인한 사용자의 프로필을 조회한다.
///
/// 1) Supabase Auth 세션이 있으면 user_id로 프로필 조회
/// 2) 세션이 없으면 SharedPreferences의 logged_in_user_id로 조회 (RPC 로그인 등)
/// 프로필 행이 없으면 `null`을 반환한다.
/// avatar_url이 없으면 DiceBear API로 생성하여 저장한다.
Future<AppProfile?> getCurrentProfile() async {
  var uid = Supabase.instance.client.auth.currentUser?.id;
  if (uid == null) {
    // RPC 로그인 등으로 Auth 세션 없이 로그인된 경우
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('logged_in') != true) return null;
    uid = prefs.getString('logged_in_user_id');
    if (uid == null) return null;
  }

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
