import 'dart:convert';

import 'package:http/http.dart' as http;

/// Open-Meteo 기반 현지 날씨 조회. 비/눈/구름/맑음 메시지 생성.
///
/// WMO weather code: 0=맑음, 1-3=대체로 맑음/흐림/구름많음, 45,48=안개,
/// 51-67=비, 71-77=눈, 80-82=소나기, 85-86=눈소나기, 95=뇌우.
class WeatherService {
  WeatherService._();

  static const _baseUrl = 'https://api.open-meteo.com/v1/forecast';

  /// 기본 위치 (서울). 위치 권한 또는 설정에서 변경 가능.
  static const defaultLat = 37.57;
  static const defaultLon = 126.98;
  static const defaultTimezone = 'Asia/Seoul';

  /// [latitude], [longitude]로 해당 지역 오늘 00:00~18:00 날씨를 조회해
  /// 한 줄 요약 메시지를 반환한다.
  /// - 18시 전 비(또는 강수) 예보/현재 → "비가 올 예정이에요" / "비가 오고 있어요"
  /// - 눈 → "눈이 올 예정이에요" / "눈이 와요"
  /// - 구름 → "구름이 낀다"
  /// - 맑음 → "화창해요"
  static Future<String> getMorningSummary({
    double? latitude,
    double? longitude,
    String timezone = defaultTimezone,
  }) async {
    final lat = latitude ?? defaultLat;
    final lon = longitude ?? defaultLon;

    final uri = Uri.parse(_baseUrl).replace(queryParameters: {
      'latitude': '$lat',
      'longitude': '$lon',
      'hourly': 'weathercode,precipitation',
      'timezone': timezone,
      'forecast_days': '1',
    });

    final response = await http.get(uri).timeout(
      const Duration(seconds: 10),
      onTimeout: () => throw Exception('날씨 요청 시간 초과'),
    );

    if (response.statusCode != 200) {
      throw Exception('날씨 조회 실패: ${response.statusCode}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final hourly = data['hourly'] as Map<String, dynamic>?;
    if (hourly == null) throw Exception('날씨 데이터 없음');

    final codes = (hourly['weathercode'] as List<dynamic>?)?.cast<int>() ?? [];
    final precip =
        (hourly['precipitation'] as List<dynamic>?)?.cast<num>() ?? [];
    final times = (hourly['time'] as List<dynamic>?)?.cast<String>() ?? [];

    // 오늘 00:00 ~ 18:00 (18시 이전 시간만). time 형식: "2026-02-18T00:00" 등
    final now = DateTime.now();
    final today = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    int endIndex = 0;
    for (int i = 0; i < times.length; i++) {
      final t = times[i];
      if (t.startsWith(today)) {
        final hour = t.length >= 13 ? int.tryParse(t.substring(11, 13)) ?? 0 : 0;
        if (hour < 18) endIndex = i + 1;
      }
    }
    if (endIndex == 0) endIndex = 1;
    final codeSlice = codes.take(endIndex).toList();
    final precipSlice = precip.take(endIndex).toList();

    // 1) 18시 전 비(또는 강수) 있음
    bool hasRain = false;
    bool hasSnow = false;
    for (int i = 0; i < codeSlice.length; i++) {
      final c = codeSlice[i];
      final p = i < precipSlice.length ? precipSlice[i].toDouble() : 0.0;
      if (c >= 51 && c <= 67 || c >= 80 && c <= 82 || c == 95) hasRain = true;
      if (c >= 71 && c <= 77 || c >= 85 && c <= 86) hasSnow = true;
      if (p > 0 && (c >= 51 && c <= 67 || c >= 80 && c <= 82 || c == 95)) hasRain = true;
    }
    if (hasRain) return '비가 올 예정이에요. 우산을 챙기세요.';
    if (hasSnow) return '눈이 올 예정이에요.';

    // 2) 구름
    final cloudy = codeSlice.any((c) => c >= 1 && c <= 3 || c == 45 || c == 48);
    if (cloudy) return '구름이 낀다.';

    // 3) 맑음
    return '화창해요.';
  }
}
