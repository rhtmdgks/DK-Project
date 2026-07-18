import 'package:flutter/foundation.dart';
import 'package:myapp/core/supabase_client.dart';
import 'package:myapp/models/school.dart';
import 'package:myapp/repositories/school_repository.dart';

/// 현재 선택된 학교 상태의 단일 진입점.
///
/// [AuthRepository]와 동일한 철학의 싱글턴으로, Provider 없이 어디서든
/// `SchoolContext.instance.currentSchool`로 접근한다.
///
/// 하이드레이션 순서([ensureLoaded]):
/// 1. 메모리에 이미 있으면 즉시 반환
/// 2. 로그인 세션이 있으면 profiles.school_id → 학교 상세 조회
/// 3. 실패/없으면 SharedPreferences 캐시([SchoolRepository.getLastSelectedSchool])
/// 4. 전부 실패면 null 유지 → 호출부는 school_id 파라미터 생략(서버 env 폴백)
class SchoolContext {
  SchoolContext._();

  static final SchoolContext instance = SchoolContext._();

  School? _current;

  /// 동시 [ensureLoaded] 호출 중복 방지용 in-flight Future.
  Future<void>? _loading;

  /// 현재 선택된 학교. 아직 로드되지 않았으면 null.
  School? get currentSchool => _current;

  /// 현재 학교 id. 서버 호출 시 school_id 파라미터로 사용한다.
  String? get currentSchoolId => _current?.id;

  /// 학교를 메모리에 저장하고 로컬 캐시에도 영속화한다.
  void set(School school) {
    _current = school;
    // 영속화 실패는 앱 흐름에 영향을 주지 않는다.
    SchoolRepository.instance.setLastSelectedSchool(school).catchError((e) {
      debugPrint('SchoolContext: 학교 캐시 저장 실패: $e');
    });
  }

  /// 현재 학교를 lazy 하이드레이션한다. 이미 로드됐으면 즉시 반환.
  ///
  /// 모든 네트워크 예외는 삼켜서 앱 흐름을 막지 않는다.
  Future<void> ensureLoaded() {
    if (_current != null) return Future.value();
    return _loading ??= _load().whenComplete(() => _loading = null);
  }

  Future<void> _load() async {
    // (1) 로그인 세션이 있으면 profiles.school_id 기반 조회.
    try {
      final uid = supabase.auth.currentSession?.user.id;
      if (uid != null) {
        final row = await supabase
            .from('profiles')
            .select('school_id')
            .eq('user_id', uid)
            .maybeSingle();
        // 구버전 서버에는 school_id 컬럼이 없을 수 있음 → null-safe.
        final schoolId = row?['school_id'] as String?;
        if (schoolId != null && schoolId.isNotEmpty) {
          final school = await SchoolRepository.instance.fetchSchoolById(
            schoolId,
          );
          if (school != null) {
            _current = school;
            return;
          }
        }
      }
    } catch (e) {
      debugPrint('SchoolContext: profiles 기반 학교 조회 실패: $e');
    }

    // (2) 로컬 캐시 폴백.
    try {
      _current ??= await SchoolRepository.instance.getLastSelectedSchool();
    } catch (e) {
      debugPrint('SchoolContext: 학교 캐시 조회 실패: $e');
    }
    // (3) 전부 실패면 null 유지 → 서버 env 폴백 동작.
  }

  /// 로그아웃 시 메모리 상태만 클리어한다(프리퍼런스 캐시는 유지).
  void clear() {
    _current = null;
    _loading = null;
  }
}
