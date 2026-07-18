import 'package:myapp/core/auth/app_role.dart';

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
    this.targetUniversity,
    this.schoolId,
    this.username,
    this.orgRoles = const [],
    this.recoveryEmail,
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
  /// 목표 대학 (프로필 편집에서 본인이 설정).
  final String? targetUniversity;
  /// 소속 학교 ID (멀티스쿨). 컬럼 부재/미배정 시 null.
  final String? schoolId;
  /// 로그인용 username (멀티스쿨 신규 컬럼). 컬럼 부재 시 null.
  final String? username;
  /// 조직 내 보직 리스트 (예: 'council'). 컬럼 부재 시 빈 리스트.
  final List<String> orgRoles;
  /// 복구용 이메일 (멀티스쿨 신규 컬럼). 컬럼 부재 시 null.
  final String? recoveryEmail;

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
      targetUniversity: (json['target_university'] as String?)?.trim().isEmpty == true
          ? null
          : (json['target_university'] as String?),
      schoolId: json['school_id'] as String?,
      username: (json['username'] as String?)?.trim(),
      orgRoles: _stringListFromJson(json['org_roles']) ?? const [],
      recoveryEmail: json['recovery_email'] as String?,
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

  static int? _validGrade(int? v) =>
      v != null && v >= 1 && v <= 3 ? v : null;

  static int? _validClassNum(int? v) =>
      v != null && v >= 1 && v <= 10 ? v : null;

  /// 학년(1-3). DB에 없으면 학번 첫 자리로 추론 가능.
  int? get gradeOrFromStudentId =>
      _validGrade(grade) ??
      _validGrade(_parseGradeClassNumber(studentId).$1);
  /// 반(1-10). DB에 없으면 학번 2~3자리로 추론 가능.
  int? get classNumOrFromStudentId =>
      _validClassNum(classNum) ??
      _validClassNum(_parseGradeClassNumber(studentId).$2);
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

  /// role 문자열을 [AppRole]로 변환한 값. 레거시/신규 role 공존 매핑은 [appRoleFromString] 참고.
  AppRole get appRole => appRoleFromString(role);

  /// 학생회 보직 여부: 신규 `org_roles`에 [kOrgRoleCouncil] 포함 또는 레거시 `role == 'council'`.
  bool get hasCouncilRole => orgRoles.contains(kOrgRoleCouncil) || role == 'council';

  /// 학교 관리자 이상 (school_admin·레거시 admin·super_admin).
  bool get isSchoolAdmin => appRole == AppRole.schoolAdmin || appRole == AppRole.superAdmin;

  /// 전체 시스템 관리자 여부.
  bool get isSuperAdmin => appRole == AppRole.superAdmin;

  /// 학부모 여부.
  bool get isParent => appRole == AppRole.parent;

  /// 화면 표시용 학번: 학번이 있으면 학번, 없으면 username (멀티스쿨 신규 계정 대응).
  String get displayStudentId => studentId.isNotEmpty ? studentId : (username ?? '');

  bool get isPrivileged => hasCouncilRole || isSchoolAdmin;

  bool get isTeacher => appRole == AppRole.teacher;
  bool get isClassPresident => classLeaderRole == 'president';
  bool get isClassVicePresident => classLeaderRole == 'vice_president';
  bool get canManageClassResources => isClassPresident || isClassVicePresident || isSchoolAdmin || isTeacher;

  /// 일부 필드만 변경한 복사본을 반환한다. 전달하지 않은 필드는 기존 값을 유지한다.
  AppProfile copyWith({
    String? id,
    String? userId,
    String? studentId,
    String? role,
    bool? mustChangePassword,
    String? fullName,
    String? avatarUrl,
    int? grade,
    int? classNum,
    int? numberInClass,
    List<String>? teacherSubjects,
    List<String>? teacherRoles,
    String? classLeaderRole,
    String? targetUniversity,
    String? schoolId,
    String? username,
    List<String>? orgRoles,
    String? recoveryEmail,
  }) {
    return AppProfile(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      studentId: studentId ?? this.studentId,
      role: role ?? this.role,
      mustChangePassword: mustChangePassword ?? this.mustChangePassword,
      fullName: fullName ?? this.fullName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      grade: grade ?? this.grade,
      classNum: classNum ?? this.classNum,
      numberInClass: numberInClass ?? this.numberInClass,
      teacherSubjects: teacherSubjects ?? this.teacherSubjects,
      teacherRoles: teacherRoles ?? this.teacherRoles,
      classLeaderRole: classLeaderRole ?? this.classLeaderRole,
      targetUniversity: targetUniversity ?? this.targetUniversity,
      schoolId: schoolId ?? this.schoolId,
      username: username ?? this.username,
      orgRoles: orgRoles ?? this.orgRoles,
      recoveryEmail: recoveryEmail ?? this.recoveryEmail,
    );
  }
}
