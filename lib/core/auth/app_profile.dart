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
    this.teacherSubjects,
    this.teacherRoles,
    this.classLeaderRole,
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
  /// 교사 담당 과목 리스트.
  final List<String>? teacherSubjects;
  /// 교사 담당 역할 리스트 (소속 반, 교무부장 등).
  final List<String>? teacherRoles;
  /// 학급 리더 역할 (정반장/부반장).
  final String? classLeaderRole;

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
      classNum: _intOrNull(json['class_number']) ?? _intOrNull(json['class_num']),
      numberInClass: _intOrNull(json['number_in_class']) ??
          _intOrNull(json['student_number']),
      teacherSubjects: _stringListFromJson(json['teacher_subjects']),
      teacherRoles: _stringListFromJson(json['teacher_roles']),
      classLeaderRole: (json['class_leader_role'] as String?)?.trim().isEmpty == true
          ? null
          : (json['class_leader_role'] as String?),
    );
  }

  static List<String>? _stringListFromJson(dynamic v) {
    if (v == null) return null;
    if (v is List) {
      final list = v.map((e) => e?.toString().trim()).where((e) => e != null && e.isNotEmpty).cast<String>().toList();
      return list.isEmpty ? null : list;
    }
    return null;
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
  bool get hasGradeClass =>
      gradeOrFromStudentId != null && classNumOrFromStudentId != null;

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

  bool get isTeacher => role == 'teacher';
  bool get isClassPresident => classLeaderRole == 'president';
  bool get isClassVicePresident => classLeaderRole == 'vice_president';
  bool get canManageClassResources => isClassPresident || isClassVicePresident || role == 'admin' || role == 'teacher';
}
