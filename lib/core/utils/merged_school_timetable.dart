import 'package:myapp/core/auth/app_profile.dart';
import 'package:myapp/core/supabase_client.dart';
import 'package:myapp/core/utils/timetable_utils.dart';

/// 반 시간표(`class_timetable`)와 개인 수정분(`timetable_entries`)을 합쳐 표시용 목록을 만든다.
/// 개인 행이 있으면 해당 교시는 개인 값이 우선한다.
class MergedSchoolTimetable {
  MergedSchoolTimetable._();

  /// 백엔드 `class_timetable.week_offset` (0=이번 주, 1=다음 주)와 맞춘다.
  static int weekOffsetForDate(DateTime date) {
    final today = DateTime.now();
    final d = DateTime(date.year, date.month, date.day);
    final n = DateTime(today.year, today.month, today.day);
    final mondayD = d.subtract(Duration(days: d.weekday - DateTime.monday));
    final mondayN = n.subtract(Duration(days: n.weekday - DateTime.monday));
    final days =
        mondayD.difference(mondayN).inDays; // 다음 주 월요일이면 대략 +7
    if (days >= 7) return 1;
    return 0;
  }

  /// 병합된 교시별 과목·교실. `period` 오름차순.
  static Future<List<Map<String, dynamic>>> fetchRowsForDate({
    required DateTime date,
    required String userId,
    AppProfile? profile,
  }) async {
    final dayOfWeek = TimetableUtils.dayOfWeekForDb(date);
    if (dayOfWeek == null) return [];

    final periods = TimetableUtils.periodNumbersForDate(date);

    final entriesRes = await supabase
        .from('timetable_entries')
        .select('period, subject, room, is_moving_class')
        .eq('user_id', userId)
        .eq('day_of_week', dayOfWeek)
        .order('period', ascending: true);

    final entries = List<Map<String, dynamic>>.from(entriesRes as List);
    final byPeriod = <int, Map<String, dynamic>>{};
    for (final row in entries) {
      final p = (row['period'] as num?)?.toInt();
      if (p != null) byPeriod[p] = row;
    }

    final grade = profile?.gradeOrFromStudentId;
    final classNum = profile?.classNumOrFromStudentId;
    final classByPeriod = <int, Map<String, dynamic>>{};

    if (grade != null && classNum != null) {
      final wo = weekOffsetForDate(date);
      final ctRes = await supabase
          .from('class_timetable')
          .select('period, subject, room')
          .eq('grade', grade)
          .eq('class_number', classNum)
          .eq('week_offset', wo)
          .eq('day_of_week', dayOfWeek)
          .order('period', ascending: true);

      for (final row in List<Map<String, dynamic>>.from(ctRes as List)) {
        final p = (row['period'] as num?)?.toInt();
        if (p != null) classByPeriod[p] = row;
      }
    }

    final out = <Map<String, dynamic>>[];
    for (final p in periods) {
      if (byPeriod.containsKey(p)) {
        final e = byPeriod[p]!;
        out.add({
          'period': p,
          'subject': (e['subject'] as String?)?.trim() ?? '',
          'room': (e['room'] as String?)?.trim(),
          'source': 'personal',
          'is_moving_class': e['is_moving_class'] == true,
        });
      } else if (classByPeriod.containsKey(p)) {
        final c = classByPeriod[p]!;
        final sub = (c['subject'] as String?)?.trim() ?? '';
        if (sub.isEmpty) continue;
        out.add({
          'period': p,
          'subject': sub,
          'room': (c['room'] as String?)?.trim(),
          'source': 'class',
          'is_moving_class': false,
        });
      }
    }
    return out;
  }
}
