import 'package:myapp/core/supabase_client.dart';

/// 일정(학교 일정·개인 일정·NEIS 학사일정) 데이터 접근 레이어.
/// UI에서는 이 Repository만 사용하고 Supabase를 직접 호출하지 않는다.
class ScheduleRepository {
  ScheduleRepository();

  final _client = supabase;

  /// 학교 전체 일정 목록 (schedule_items, start_at 오름차순).
  Future<List<Map<String, dynamic>>> fetchScheduleItems() async {
    final res = await _client
        .from('schedule_items')
        .select()
        .order('start_at', ascending: true);
    return List<Map<String, dynamic>>.from(res as List);
  }

  /// 특정 사용자의 개인 일정 목록.
  Future<List<Map<String, dynamic>>> fetchPersonalEvents(String userId) async {
    final res = await _client
        .from('personal_events')
        .select()
        .eq('user_id', userId)
        .order('start_at', ascending: true);
    return List<Map<String, dynamic>>.from(res as List);
  }

  /// NEIS 학사일정 Edge Function 호출.
  /// [viewMonth] 해당 월의 1일~말일 범위로 요청한다.
  /// 반환 리스트 항목: { id, title, start_at, end_at, is_neis: true } 형태.
  Future<List<Map<String, dynamic>>> fetchAcademicCalendar(
    DateTime viewMonth,
  ) async {
    final firstDay = DateTime(viewMonth.year, viewMonth.month, 1);
    final lastDay = DateTime(viewMonth.year, viewMonth.month + 1, 0);
    final fromYmd =
        '${firstDay.year}${firstDay.month.toString().padLeft(2, '0')}${firstDay.day.toString().padLeft(2, '0')}';
    final toYmd =
        '${lastDay.year}${lastDay.month.toString().padLeft(2, '0')}${lastDay.day.toString().padLeft(2, '0')}';

    final neisRes = await _client.functions.invoke(
      'neis_academic_calendar',
      queryParameters: {'from': fromYmd, 'to': toYmd},
    ).timeout(
      const Duration(seconds: 15),
      onTimeout: () => throw Exception('학사일정 요청 시간 초과'),
    );

    if (neisRes.status != 200 || neisRes.data is! Map<String, dynamic>) {
      return [];
    }

    final data = neisRes.data as Map<String, dynamic>;
    final schedule = data['schedule'] as List<dynamic>? ?? [];
    final neisList = <Map<String, dynamic>>[];

    for (final row in schedule) {
      final m = row as Map<String, dynamic>;
      final aaYmd = m['AA_YMD'] as String? ?? '';
      if (aaYmd.length != 8) continue;
      final eventNm = m['EVENT_NM'] as String? ?? '';
      final eventCntnt = m['EVENT_CNTNT'] as String? ?? '';
      final y = int.tryParse(aaYmd.substring(0, 4)) ?? 0;
      final mo = int.tryParse(aaYmd.substring(4, 6)) ?? 0;
      final d = int.tryParse(aaYmd.substring(6, 8)) ?? 0;
      final startAt = DateTime.utc(y, mo, d).toIso8601String();
      neisList.add({
        'id': 'neis_$aaYmd',
        'title': eventNm,
        'description': eventCntnt.isEmpty ? null : eventCntnt,
        'start_at': startAt,
        'end_at': startAt,
        'is_neis': true,
      });
    }

    return neisList;
  }

  /// 학교 일정 추가 (council/admin용). [createdBy]는 profiles.id.
  Future<void> addScheduleItem({
    required String title,
    String? description,
    required String startAt,
    required String endAt,
    required String createdBy,
  }) async {
    await _client.from('schedule_items').insert({
      'title': title,
      'description': description,
      'start_at': startAt,
      'end_at': endAt,
      'created_by': createdBy,
    });
  }

  /// 학교 일정 삭제.
  Future<void> deleteScheduleItem(String id) async {
    await _client.from('schedule_items').delete().eq('id', id);
  }

  /// 개인 일정 추가.
  Future<void> addPersonalEvent({
    required String userId,
    required String title,
    String? description,
    required String startAt,
    String? endAt,
    required bool allDay,
  }) async {
    await _client.from('personal_events').insert({
      'user_id': userId,
      'title': title,
      'description': description,
      'start_at': startAt,
      'end_at': endAt,
      'all_day': allDay,
    });
  }

  /// 개인 일정 삭제.
  Future<void> deletePersonalEvent(String id) async {
    await _client.from('personal_events').delete().eq('id', id);
  }
}
