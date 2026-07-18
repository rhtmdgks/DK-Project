import 'dart:convert';

import 'package:myapp/core/supabase_client.dart';
import 'package:myapp/models/school.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 학교 목록/상세 조회 및 마지막 선택 학교 캐시의 단일 저장소.
///
/// 로그인 전(anon)에는 `list_active_schools()` RPC로 목록을 조회하고,
/// 로그인 후에는 `schools` 테이블에서 NEIS 코드를 포함한 상세를 조회한다.
class SchoolRepository {
  SchoolRepository._();

  static final SchoolRepository instance = SchoolRepository._();

  /// 마지막 선택 학교 캐시 키 (jsonEncode된 [School.toJson]).
  static const String keyLastSchool = 'pref_last_school';

  Future<SharedPreferences> _prefs() => SharedPreferences.getInstance();

  /// 활성(active) 학교 목록 조회. 로그인 전(anon)에도 호출 가능하다.
  ///
  /// 1차: `list_active_schools()` RPC.
  /// RPC 실패 시 폴백: `schools` 테이블 직접 조회.
  /// 폴백까지 실패하면 rethrow.
  Future<List<School>> fetchActiveSchools() async {
    try {
      final res = await supabase
          .rpc('list_active_schools')
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () => throw Exception('학교 목록 요청 시간 초과'),
          );
      if (res is List) {
        return res
            .whereType<Map<String, dynamic>>()
            .map(School.fromJson)
            .toList();
      }
      return [];
    } catch (_) {
      // 구버전 서버에 RPC가 없는 등 실패 시 테이블 직접 조회로 폴백.
      final res = await supabase
          .from('schools')
          .select('id, slug, name, name_en')
          .eq('status', 'active')
          .order('name')
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () => throw Exception('학교 목록 요청 시간 초과'),
          );
      return (res as List)
          .whereType<Map<String, dynamic>>()
          .map(School.fromJson)
          .toList();
    }
  }

  /// 학교 상세 조회 (NEIS 코드 포함). 로그인 세션이 필요하다.
  ///
  /// 행이 없거나 조회 실패 시 `null`을 반환한다.
  Future<School?> fetchSchoolById(String id) async {
    try {
      final row = await supabase
          .from('schools')
          .select('id, slug, name, name_en, atpt_ofcdc_sc_code, sd_schul_code')
          .eq('id', id)
          .maybeSingle()
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () => throw Exception('학교 조회 시간 초과'),
          );
      if (row == null) return null;
      return School.fromJson(row);
    } catch (_) {
      return null;
    }
  }

  /// 마지막으로 선택한 학교를 로컬 캐시에서 읽는다. 파싱 실패 시 `null`.
  Future<School?> getLastSelectedSchool() async {
    final raw = (await _prefs()).getString(keyLastSchool);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      return School.fromJson(decoded);
    } catch (_) {
      return null;
    }
  }

  /// 마지막으로 선택한 학교를 로컬 캐시에 저장한다.
  Future<void> setLastSelectedSchool(School school) async {
    await (await _prefs()).setString(keyLastSchool, jsonEncode(school.toJson()));
  }
}
