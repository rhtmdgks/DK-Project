/// 시간표 교시별 시작/종료 시간 공용 상수.
/// 이동 수업 알림, 홈 "오늘의 수업", 오늘의 수업 더보기 화면에서 동일한 값을 사용합니다.
class TimetableUtils {
  TimetableUtils._();

  /// 월~목 기본 시간표 시작 시간 [시, 분]. 인덱스 0 = 1교시.
  static const List<List<int>> _regularPeriodStartTimes = [
    [8, 10],  // 1교시: 08:10 ~ 09:00
    [9, 10],  // 2교시: 09:10 ~ 10:00
    [10, 10], // 3교시: 10:10 ~ 11:00
    [11, 10], // 4교시: 11:10 ~ 12:00
    [13, 0],  // 5교시: 13:00 ~ 13:50
    [14, 0],  // 6교시: 14:00 ~ 14:50
    [15, 10], // 7교시: 15:10 ~ 16:00
  ];

  /// 금요일 시간표 시작 시간 [시, 분]. 인덱스 0 = 1교시.
  /// 청소시간(13:00~13:20) 이후 5교시가 시작되며 6교시까지 운영.
  static const List<List<int>> _fridayPeriodStartTimes = [
    [8, 10],  // 1교시: 08:10 ~ 09:00
    [9, 10],  // 2교시: 09:10 ~ 10:00
    [10, 10], // 3교시: 10:10 ~ 11:00
    [11, 10], // 4교시: 11:10 ~ 12:00
    [13, 20], // 5교시: 13:20 ~ 14:10
    [14, 20], // 6교시: 14:20 ~ 15:10
  ];

  /// 하위 호환용(기존 사용처 유지). 월~목 기본 시간표를 반환한다.
  static const List<List<int>> periodStartTimes = _regularPeriodStartTimes;

  /// 수업 시간(분). 종료 = 시작 + [durationMinutes].
  static const int durationMinutes = 50;

  /// 날짜별 적용되는 교시 시작 시간표.
  static List<List<int>> periodStartTimesForDate(DateTime date) {
    if (!isWeekday(date)) return const <List<int>>[];
    if (date.weekday == DateTime.friday) return _fridayPeriodStartTimes;
    return _regularPeriodStartTimes;
  }

  /// 날짜별 운영 교시 번호 목록(1-based).
  static List<int> periodNumbersForDate(DateTime date) {
    final length = periodStartTimesForDate(date).length;
    return List<int>.generate(length, (i) => i + 1);
  }

  /// 교시(1-based)에 대한 시작 시간 "HH:mm" 문자열.
  static String startTimeString(int period, {DateTime? date}) {
    final table = periodStartTimesForDate(date ?? DateTime.now());
    final idx = period - 1;
    if (idx < 0 || idx >= table.length) return '--:--';
    final t = table[idx];
    return '${t[0].toString().padLeft(2, '0')}:${t[1].toString().padLeft(2, '0')}';
  }

  /// 교시(1-based)에 대한 종료 시간 "HH:mm" 문자열.
  static String endTimeString(int period, {DateTime? date}) {
    final table = periodStartTimesForDate(date ?? DateTime.now());
    final idx = period - 1;
    if (idx < 0 || idx >= table.length) return '--:--';
    var h = table[idx][0];
    var m = table[idx][1] + durationMinutes;
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

  /// 현재 시각이 어떤 교시의 수업 시간대 안에 있으면 해당 교시 번호(1-based)와
  /// 종료까지 남은 분을 반환. 해당 없으면 period == null.
  static ({int? period, int? minutesLeft}) currentPeriodAndMinutesLeft(DateTime now) {
    final table = periodStartTimesForDate(now);
    final nowMinutes = now.hour * 60 + now.minute;
    for (var i = 0; i < table.length; i++) {
      final t = table[i];
      final startMinutes = t[0] * 60 + t[1];
      final endMinutes = startMinutes + durationMinutes;
      if (nowMinutes >= startMinutes && nowMinutes < endMinutes) {
        final minutesLeft = endMinutes - nowMinutes;
        return (period: i + 1, minutesLeft: minutesLeft);
      }
    }
    return (period: null, minutesLeft: null);
  }

  /// 현재 시각이 수업 시간대 안에 있으면 해당 교시(1-based)와 종료까지 남은 초를 반환.
  /// 1초 단위 갱신으로 원·숫자가 자연스럽게 줄어들게 할 때 사용.
  static ({int? period, int? secondsLeft}) currentPeriodAndSecondsLeft(DateTime now) {
    final table = periodStartTimesForDate(now);
    final nowTotalSeconds = now.hour * 3600 + now.minute * 60 + now.second;
    for (var i = 0; i < table.length; i++) {
      final t = table[i];
      final startMinutes = t[0] * 60 + t[1];
      final endTotalSeconds = (startMinutes + durationMinutes) * 60;
      if (nowTotalSeconds >= startMinutes * 60 && nowTotalSeconds < endTotalSeconds) {
        final secondsLeft = endTotalSeconds - nowTotalSeconds;
        return (period: i + 1, secondsLeft: secondsLeft);
      }
    }
    return (period: null, secondsLeft: null);
  }
}
