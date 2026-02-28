/// 시간표 교시별 시작/종료 시간 공용 상수.
/// 이동 수업 알림, 홈 "오늘의 수업", 오늘의 수업 더보기 화면에서 동일한 값을 사용합니다.
class TimetableUtils {
  TimetableUtils._();

  /// 교시별 시작 시간 [시, 분]. 인덱스 0 = 1교시.
  static const List<List<int>> periodStartTimes = [
    [9, 0],   // 1교시: 09:00
    [10, 0],  // 2교시: 10:00
    [11, 0],  // 3교시: 11:00
    [12, 0],  // 4교시: 12:00
    [13, 30], // 5교시: 13:30
    [14, 30], // 6교시: 14:30
    [15, 30], // 7교시: 15:30
    [16, 30], // 8교시: 16:30
    [17, 30], // 9교시: 17:30
    [18, 30], // 10교시: 18:30
  ];

  /// 수업 시간(분). 종료 = 시작 + [durationMinutes].
  static const int durationMinutes = 50;

  /// 교시(1-based)에 대한 시작 시간 "HH:mm" 문자열.
  static String startTimeString(int period) {
    final idx = period - 1;
    if (idx < 0 || idx >= periodStartTimes.length) return '--:--';
    final t = periodStartTimes[idx];
    return '${t[0].toString().padLeft(2, '0')}:${t[1].toString().padLeft(2, '0')}';
  }

  /// 교시(1-based)에 대한 종료 시간 "HH:mm" 문자열.
  static String endTimeString(int period) {
    final idx = period - 1;
    if (idx < 0 || idx >= periodStartTimes.length) return '--:--';
    var h = periodStartTimes[idx][0];
    var m = periodStartTimes[idx][1] + durationMinutes;
    if (m >= 60) {
      h += m ~/ 60;
      m = m % 60;
    }
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  /// 오늘 요일이 평일(월~금)인지. DB의 day_of_week는 1=월 ~ 5=금.
  static bool isWeekday(DateTime date) {
    final w = date.weekday;
    return w >= DateTime.monday && w <= DateTime.friday;
  }

  /// [date]의 요일을 DB day_of_week 값으로. 1=월 ~ 5=금, 주말이면 null.
  static int? dayOfWeekForDb(DateTime date) {
    if (!isWeekday(date)) return null;
    return date.weekday;
  }
}
