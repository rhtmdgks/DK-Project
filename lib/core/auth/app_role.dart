/// 앱 전역 역할(Role) 추상화.
///
/// 멀티스쿨 전환에 따라 `profiles.role` 문자열을 직접 비교하지 않고
/// [AppRole] enum을 통해 판별한다.
///
/// 레거시 매핑 근거:
/// - `'admin'` → [AppRole.schoolAdmin]: 기존 단일 학교 체계의 관리자는
///   멀티스쿨 체계에서 "학교 관리자"에 해당한다.
/// - `'council'` → [AppRole.student]: 학생회는 별도 역할이 아니라 학생의
///   보직이므로 기본 역할은 student로 취급한다. 학생회 여부는
///   `org_roles`에 [kOrgRoleCouncil]이 포함되거나(신규),
///   레거시로 `role == 'council'`인 경우 참으로 판별한다.
/// - 알 수 없는 값·null → [AppRole.student]: 가장 낮은 권한으로 폴백.
enum AppRole {
  /// 전체 시스템 관리자 (신규 'super_admin').
  superAdmin,

  /// 학교 관리자 (신규 'school_admin', 레거시 'admin').
  schoolAdmin,

  /// 교사 ('teacher').
  teacher,

  /// 학부모 (신규 'parent').
  parent,

  /// 학생 ('student', 레거시 'council' 포함, 기타/null 폴백).
  student,
}

/// `org_roles` 배열에서 학생회 보직을 나타내는 값.
const kOrgRoleCouncil = 'council';

/// `profiles.role` 문자열을 [AppRole]로 변환한다.
///
/// 레거시('student','council','admin','teacher')와
/// 신규('super_admin','school_admin','parent') 값이 공존하므로
/// 둘 다 안전하게 매핑한다. 알 수 없는 값·null은 [AppRole.student].
AppRole appRoleFromString(String? raw) {
  switch (raw) {
    case 'super_admin':
      return AppRole.superAdmin;
    case 'admin':
    case 'school_admin':
      return AppRole.schoolAdmin;
    case 'teacher':
      return AppRole.teacher;
    case 'parent':
      return AppRole.parent;
    case 'council':
    default:
      return AppRole.student;
  }
}
