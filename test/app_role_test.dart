// 멀티스쿨 전환 WP5: 역할 추상화(AppRole)와 AppProfile 모델 단위 테스트.
//
// 검증 범위:
//  * appRoleFromString: 레거시('admin','council')·신규('super_admin','school_admin',
//    'parent') role 문자열 공존 매핑과 null/unknown 폴백
//  * AppProfile.fromJson: 신규 컬럼(school_id/username/org_roles/recovery_email)
//    부재 시 null-safe 동작 (구버전 서버 응답 호환)
//  * hasCouncilRole / isPrivileged: 레거시 role 값과 org_roles 플래그 동등 취급
//  * 학번 5자리 파싱(G+반2+번2)과 DB 컬럼 폴백
//  * copyWith 의 신규 필드 보존
import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/core/auth/app_profile.dart';
import 'package:myapp/core/auth/app_role.dart';

/// 필수 키만 채운 profiles JSON. [overrides]로 컬럼 추가/교체.
Map<String, dynamic> profileJson([Map<String, dynamic> overrides = const {}]) {
  return {
    'id': 'profile-1',
    'user_id': 'user-1',
    'student_id': '10203',
    'role': 'student',
    'must_change_password': false,
    ...overrides,
  };
}

void main() {
  group('appRoleFromString', () {
    test('신규 role 값 매핑', () {
      expect(appRoleFromString('super_admin'), AppRole.superAdmin);
      expect(appRoleFromString('school_admin'), AppRole.schoolAdmin);
      expect(appRoleFromString('teacher'), AppRole.teacher);
      expect(appRoleFromString('parent'), AppRole.parent);
      expect(appRoleFromString('student'), AppRole.student);
    });

    test('레거시 role 값 매핑: admin→schoolAdmin, council→student', () {
      expect(appRoleFromString('admin'), AppRole.schoolAdmin);
      expect(appRoleFromString('council'), AppRole.student);
    });

    test('null·빈 문자열·알 수 없는 값은 student 로 폴백', () {
      expect(appRoleFromString(null), AppRole.student);
      expect(appRoleFromString(''), AppRole.student);
      expect(appRoleFromString('unknown'), AppRole.student);
    });
  });

  group('AppProfile.fromJson — 신규 컬럼 유무', () {
    test('신규 컬럼 부재(구버전 서버 응답) 시 null/빈 리스트로 안전', () {
      final p = AppProfile.fromJson(profileJson());
      expect(p.schoolId, isNull);
      expect(p.username, isNull);
      expect(p.orgRoles, isEmpty);
      expect(p.recoveryEmail, isNull);
    });

    test('신규 컬럼 존재 시 정상 매핑', () {
      final p = AppProfile.fromJson(profileJson({
        'school_id': 'school-uuid-1',
        'username': 'hong.gildong',
        'org_roles': ['council'],
        'recovery_email': 'hong@example.com',
      }));
      expect(p.schoolId, 'school-uuid-1');
      expect(p.username, 'hong.gildong');
      expect(p.orgRoles, ['council']);
      expect(p.recoveryEmail, 'hong@example.com');
    });

    test('org_roles 가 null/빈 배열이면 빈 리스트', () {
      expect(
        AppProfile.fromJson(profileJson({'org_roles': null})).orgRoles,
        isEmpty,
      );
      expect(
        AppProfile.fromJson(profileJson({'org_roles': <dynamic>[]})).orgRoles,
        isEmpty,
      );
    });
  });

  group('hasCouncilRole', () {
    test("레거시 role='council' 이면 true", () {
      final p = AppProfile.fromJson(profileJson({'role': 'council'}));
      expect(p.hasCouncilRole, isTrue);
    });

    test("신규: role='student' + org_roles=['council'] 이면 true", () {
      final p = AppProfile.fromJson(profileJson({
        'role': 'student',
        'org_roles': ['council'],
      }));
      expect(p.hasCouncilRole, isTrue);
    });

    test('그 외(일반 student·admin·teacher)는 false', () {
      expect(
        AppProfile.fromJson(profileJson({'role': 'student'})).hasCouncilRole,
        isFalse,
      );
      expect(
        AppProfile.fromJson(profileJson({'role': 'admin'})).hasCouncilRole,
        isFalse,
      );
      expect(
        AppProfile.fromJson(profileJson({'role': 'teacher'})).hasCouncilRole,
        isFalse,
      );
    });
  });

  group('isPrivileged — 기존(council||admin) 집합과 동일 + 신규 role 확장', () {
    AppProfile withRole(String role) =>
        AppProfile.fromJson(profileJson({'role': role}));

    test('레거시 admin/council 은 true (기존 동작 유지)', () {
      expect(withRole('admin').isPrivileged, isTrue);
      expect(withRole('council').isPrivileged, isTrue);
    });

    test('신규 school_admin/super_admin 은 true', () {
      expect(withRole('school_admin').isPrivileged, isTrue);
      expect(withRole('super_admin').isPrivileged, isTrue);
    });

    test('student/teacher 는 false', () {
      expect(withRole('student').isPrivileged, isFalse);
      expect(withRole('teacher').isPrivileged, isFalse);
    });

    test("org_roles=['council'] 인 student 는 true (플립 후에도 권한 유지)", () {
      final p = AppProfile.fromJson(profileJson({
        'role': 'student',
        'org_roles': ['council'],
      }));
      expect(p.isPrivileged, isTrue);
    });
  });

  group('학번 파싱 (5자리: G + 반2 + 번2)', () {
    test("'10203' → 1학년 2반 3번", () {
      final p = AppProfile.fromJson(profileJson({'student_id': '10203'}));
      expect(p.gradeOrFromStudentId, 1);
      expect(p.classNumOrFromStudentId, 2);
      expect(p.numberInClassOrFromStudentId, 3);
      expect(p.hasGradeClass, isTrue);
    });

    test("'11002' → 1학년 10반 2번", () {
      final p = AppProfile.fromJson(profileJson({'student_id': '11002'}));
      expect(p.gradeOrFromStudentId, 1);
      expect(p.classNumOrFromStudentId, 10);
      expect(p.numberInClassOrFromStudentId, 2);
    });

    test('빈 studentId + 비5자리 username(신규 계정) 이면 null', () {
      final p = AppProfile.fromJson(profileJson({
        'student_id': null,
        'username': 'hong.gildong',
      }));
      expect(p.gradeOrFromStudentId, isNull);
      expect(p.classNumOrFromStudentId, isNull);
      expect(p.numberInClassOrFromStudentId, isNull);
      expect(p.hasGradeClass, isFalse);
      // 화면 표시용 학번은 username 으로 폴백.
      expect(p.displayStudentId, 'hong.gildong');
    });

    test('비5자리 studentId 는 파싱하지 않음', () {
      final p = AppProfile.fromJson(profileJson({'student_id': '123'}));
      expect(p.gradeOrFromStudentId, isNull);
      expect(p.classNumOrFromStudentId, isNull);
      expect(p.numberInClassOrFromStudentId, isNull);
    });

    test('학번 파싱 불가여도 DB 컬럼(grade/class_number/number_in_class) 폴백', () {
      final p = AppProfile.fromJson(profileJson({
        'student_id': null,
        'username': 'hong.gildong',
        'grade': 2,
        'class_number': 7,
        'number_in_class': 15,
      }));
      expect(p.gradeOrFromStudentId, 2);
      expect(p.classNumOrFromStudentId, 7);
      expect(p.numberInClassOrFromStudentId, 15);
      expect(p.hasGradeClass, isTrue);
    });

    test('DB 컬럼이 학번 파싱보다 우선', () {
      final p = AppProfile.fromJson(profileJson({
        'student_id': '10203',
        'grade': 3,
        'class_number': 9,
        'number_in_class': 30,
      }));
      expect(p.gradeOrFromStudentId, 3);
      expect(p.classNumOrFromStudentId, 9);
      expect(p.numberInClassOrFromStudentId, 30);
    });
  });

  group('copyWith — 신규 필드 보존', () {
    final base = AppProfile.fromJson(profileJson({
      'school_id': 'school-uuid-1',
      'username': 'stu10203',
      'org_roles': ['council'],
      'recovery_email': 'me@example.com',
    }));

    test('전달하지 않은 신규 필드는 기존 값 유지', () {
      final copied = base.copyWith(fullName: '홍길동');
      expect(copied.fullName, '홍길동');
      expect(copied.schoolId, 'school-uuid-1');
      expect(copied.username, 'stu10203');
      expect(copied.orgRoles, ['council']);
      expect(copied.recoveryEmail, 'me@example.com');
      // 기존 필드도 유지.
      expect(copied.id, base.id);
      expect(copied.role, base.role);
      expect(copied.studentId, base.studentId);
    });

    test('신규 필드를 명시 전달하면 교체', () {
      final copied = base.copyWith(
        schoolId: 'school-uuid-2',
        username: 'new.name',
        orgRoles: const [],
        recoveryEmail: 'new@example.com',
      );
      expect(copied.schoolId, 'school-uuid-2');
      expect(copied.username, 'new.name');
      expect(copied.orgRoles, isEmpty);
      expect(copied.recoveryEmail, 'new@example.com');
    });
  });
}
