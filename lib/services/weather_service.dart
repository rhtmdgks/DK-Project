import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

/// 아침 날씨 알림용 제목·본문(iOS 부제목 포함).
class MorningWeatherNotificationCopy {
  const MorningWeatherNotificationCopy({
    required this.title,
    required this.body,
    this.subtitle,
  });

  final String title;
  final String body;
  /// iOS 알림 부제목(잠금 화면·배너 요약).
  final String? subtitle;
}

/// Open-Meteo 기반 현지 날씨 조회. 비/눈/구름/맑음 메시지 생성.
///
/// WMO weather code: 0=맑음, 1-3=대체로 맑음/흐림/구름많음, 45,48=안개,
/// 51-67=비, 71-77=눈, 80-82=소나기, 85-86=눈소나기, 95=뇌우.
class WeatherService {
  WeatherService._();

  static const _baseUrl = 'https://api.open-meteo.com/v1/forecast';
  static const MethodChannel _weatherKitChannel = MethodChannel(
    'weatherkit_channel',
  );

  /// 기본 위치 (서울). 위치 권한 또는 설정에서 변경 가능.
  static const defaultLat = 37.57;
  static const defaultLon = 126.98;
  static const defaultTimezone = 'Asia/Seoul';

  static bool _isRainCode(int c) =>
      c >= 51 && c <= 67 || c >= 80 && c <= 82 || c == 95;

  static bool _isSnowCode(int c) => c >= 71 && c <= 77 || c >= 85 && c <= 86;

  static int? _hourFromTime(String t) {
    if (t.length >= 13) return int.tryParse(t.substring(11, 13));
    return null;
  }

  static String _formatTemp(double? v) {
    if (v == null || v.isNaN) return '—';
    return v.round().toString();
  }

  static String _limitText(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength - 1)}…';
  }

  /// 알림 부제목: 기온 한 줄 (iOS).
  static String _weatherSubtitle(String mStr, String maxStr, String minStr) {
    return _limitText('오전 약 $mStr° · 최고 $maxStr° / 최저 $minStr°', 48);
  }

  /// 하루 중 시간대 힌트 (첫 강수 시각 등).
  static String _dayPartFromHour(int hour) {
    if (hour >= 6 && hour < 12) return '오전';
    if (hour < 18) return '오후';
    if (hour < 22) return '저녁';
    return '밤';
  }

  /// [latitude], [longitude]로 해당 지역 오늘 00:00~18:00 예보를 조회해
  /// 알림 제목·본문을 반환한다.
  static Future<MorningWeatherNotificationCopy> getMorningNotificationCopy({
    double? latitude,
    double? longitude,
    String timezone = defaultTimezone,
  }) async {
    final lat = latitude ?? defaultLat;
    final lon = longitude ?? defaultLon;

    // iOS 16+에서는 WeatherKit 우선 시도, 실패 시 Open-Meteo로 fallback.
    if (Platform.isIOS) {
      try {
        final payload = await _weatherKitChannel
            .invokeMethod<Map<dynamic, dynamic>>('getMorningForecast', {
              'latitude': lat,
              'longitude': lon,
              'timezone': timezone,
            });
        if (payload != null) {
          final copy = _buildCopyFromMappedWeather(
            weatherType: (payload['weatherType'] as String? ?? 'clear')
                .toLowerCase(),
            morningTemp: (payload['morningTemp'] as num?)?.toDouble(),
            maxTemp: (payload['maxTemp'] as num?)?.toDouble(),
            minTemp: (payload['minTemp'] as num?)?.toDouble(),
            timeHint: payload['timeHint'] as String?,
          );
          return copy;
        }
      } catch (_) {
        // fallback
      }
    }

    return _getMorningNotificationCopyFromOpenMeteo(
      latitude: lat,
      longitude: lon,
      timezone: timezone,
    );
  }

  static MorningWeatherNotificationCopy _buildCopyFromMappedWeather({
    required String weatherType,
    required double? morningTemp,
    required double? maxTemp,
    required double? minTemp,
    String? timeHint,
  }) {
    final mStr = _formatTemp(morningTemp);
    final maxStr = _formatTemp(maxTemp);
    final minStr = _formatTemp(minTemp);
    final spread = (maxTemp != null && minTemp != null)
        ? (maxTemp - minTemp)
        : null;
    final spreadLarge = spread != null && spread >= 10;
    final hint = (timeHint ?? '').trim();

    if (weatherType == 'rain') {
      final title = _limitText('비 소식 있어요, 우산 챙겨요', 18);
      final body = _limitText(
        '${hint.isEmpty ? '출발 시간대에 비가 예상돼요.' : '$hint 비가 예상돼요.'} 오전 약 $mStr°, 최고 $maxStr°/최저 $minStr°예요. 접이식 우산을 챙겨주세요.',
        520,
      );
      return MorningWeatherNotificationCopy(
        title: title,
        body: body,
        subtitle: _weatherSubtitle(mStr, maxStr, minStr),
      );
    }

    if (weatherType == 'snow') {
      final title = _limitText('눈길 주의, 따뜻하게 입어요', 18);
      final body = _limitText(
        '${hint.isEmpty ? '눈 또는 진눈깨비 가능성이 있어요.' : '$hint 눈 가능성이 있어요.'} 오전 약 $mStr°, 체감은 더 낮을 수 있어요. 미끄럼에 주의해 주세요.',
        520,
      );
      return MorningWeatherNotificationCopy(
        title: title,
        body: body,
        subtitle: _weatherSubtitle(mStr, maxStr, minStr),
      );
    }

    if (weatherType == 'cloudy') {
      final title = _limitText('흐리지만 활동하기 괜찮아요', 18);
      final body = _limitText(
        '구름이 많은 날씨예요. 오전 약 $mStr°, 최고 $maxStr°/최저 $minStr°예요. ${spreadLarge ? '일교차가 커 얇은 겉옷을 추천해요.' : '가벼운 외투 정도면 충분해요.'}',
        520,
      );
      return MorningWeatherNotificationCopy(
        title: title,
        body: body,
        subtitle: _weatherSubtitle(mStr, maxStr, minStr),
      );
    }

    if (spreadLarge) {
      final title = _limitText('일교차 커요, 겉옷 챙겨요', 18);
      final body = _limitText(
        '대체로 맑지만 기온 차가 커요. 오전 약 $mStr°, 최고 $maxStr°/최저 $minStr°예요. 얇은 겉옷을 챙기면 좋아요.',
        520,
      );
      return MorningWeatherNotificationCopy(
        title: title,
        body: body,
        subtitle: _weatherSubtitle(mStr, maxStr, minStr),
      );
    }

    final title = _limitText('맑은 아침이에요', 18);
    final body = _limitText(
      '대체로 맑은 날씨예요. 오전 약 $mStr°, 최고 $maxStr°/최저 $minStr°예요. 가볍게 준비해도 좋아요.',
      520,
    );
    return MorningWeatherNotificationCopy(
      title: title,
      body: body,
      subtitle: _weatherSubtitle(mStr, maxStr, minStr),
    );
  }

  static Future<MorningWeatherNotificationCopy>
  _getMorningNotificationCopyFromOpenMeteo({
    required double latitude,
    required double longitude,
    required String timezone,
  }) async {
    final uri = Uri.parse(_baseUrl).replace(
      queryParameters: {
        'latitude': '$latitude',
        'longitude': '$longitude',
        'hourly': 'weathercode,precipitation,temperature_2m',
        'daily': 'temperature_2m_max,temperature_2m_min',
        'timezone': timezone,
        'forecast_days': '1',
      },
    );

    final response = await http
        .get(uri)
        .timeout(
          const Duration(seconds: 10),
          onTimeout: () => throw Exception('날씨 요청 시간 초과'),
        );

    if (response.statusCode != 200) {
      throw Exception('날씨 조회 실패: ${response.statusCode}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final hourly = data['hourly'] as Map<String, dynamic>?;
    if (hourly == null) throw Exception('날씨 데이터 없음');

    final codes =
        (hourly['weathercode'] as List<dynamic>?)
            ?.map((e) => (e as num).toInt())
            .toList() ??
        [];
    final precip =
        (hourly['precipitation'] as List<dynamic>?)
            ?.map((e) => e.toDouble())
            .toList() ??
        [];
    final temps =
        (hourly['temperature_2m'] as List<dynamic>?)
            ?.map((e) => e.toDouble())
            .toList() ??
        [];
    final times = (hourly['time'] as List<dynamic>?)?.cast<String>() ?? [];

    final now = DateTime.now();
    final today =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    int endIndex = 0;
    for (int i = 0; i < times.length; i++) {
      final t = times[i];
      if (t.startsWith(today)) {
        final hour = _hourFromTime(t) ?? 0;
        if (hour < 18) endIndex = i + 1;
      }
    }
    if (endIndex == 0) endIndex = 1;
    if (endIndex > times.length) endIndex = times.length;

    final codeSlice = codes.take(endIndex).toList();
    final precipSlice = precip.take(endIndex).toList();
    final tempSlice = temps.take(endIndex).toList();

    double? tMax;
    double? tMin;
    final daily = data['daily'] as Map<String, dynamic>?;
    if (daily != null) {
      final dTimes = (daily['time'] as List<dynamic>?)?.cast<String>() ?? [];
      final maxList = (daily['temperature_2m_max'] as List<dynamic>?)
          ?.map((e) => e.toDouble())
          .toList();
      final minList = (daily['temperature_2m_min'] as List<dynamic>?)
          ?.map((e) => e.toDouble())
          .toList();
      for (int i = 0; i < dTimes.length; i++) {
        if (dTimes[i] == today) {
          if (maxList != null && i < maxList.length) tMax = maxList[i];
          if (minList != null && i < minList.length) tMin = minList[i];
          break;
        }
      }
    }
    if (tMax == null || tMin == null) {
      final inSlice = tempSlice.where((e) => !e.isNaN).toList();
      if (inSlice.isNotEmpty) {
        tMax ??= inSlice.reduce((a, b) => a > b ? a : b);
        tMin ??= inSlice.reduce((a, b) => a < b ? a : b);
      }
    }

    double? morningTemp;
    final morningVals = <double>[];
    for (int i = 0; i < endIndex && i < times.length; i++) {
      if (!times[i].startsWith(today)) continue;
      final h = _hourFromTime(times[i]) ?? 0;
      if (h >= 6 && h <= 9 && i < tempSlice.length) {
        morningVals.add(tempSlice[i]);
      }
    }
    if (morningVals.isNotEmpty) {
      morningTemp = morningVals.reduce((a, b) => a + b) / morningVals.length;
    } else {
      for (int i = 0; i < endIndex && i < times.length; i++) {
        if (!times[i].startsWith(today)) continue;
        final h = _hourFromTime(times[i]) ?? 0;
        if (h >= 6 && i < tempSlice.length) {
          morningTemp = tempSlice[i];
          break;
        }
      }
      morningTemp ??= tempSlice.isNotEmpty ? tempSlice.first : null;
    }

    final maxStr = _formatTemp(tMax);
    final minStr = _formatTemp(tMin);
    final mStr = _formatTemp(morningTemp);
    final spread = (tMax != null && tMin != null) ? (tMax - tMin) : null;

    bool hasRain = false;
    bool hasSnow = false;
    for (int i = 0; i < codeSlice.length; i++) {
      final c = codeSlice[i];
      final p = i < precipSlice.length ? precipSlice[i] : 0.0;
      if (_isRainCode(c)) hasRain = true;
      if (_isSnowCode(c)) hasSnow = true;
      if (p > 0 && _isRainCode(c)) hasRain = true;
    }

    int? firstRainIndex;
    if (hasRain) {
      for (int i = 0; i < codeSlice.length; i++) {
        final c = codeSlice[i];
        final p = i < precipSlice.length ? precipSlice[i] : 0.0;
        if (_isRainCode(c) || (p > 0 && _isRainCode(c))) {
          firstRainIndex = i;
          break;
        }
      }
    }

    int? firstSnowIndex;
    if (hasSnow) {
      for (int i = 0; i < codeSlice.length; i++) {
        if (_isSnowCode(codeSlice[i])) {
          firstSnowIndex = i;
          break;
        }
      }
    }

    String? rainTimeHint;
    if (firstRainIndex != null && firstRainIndex < times.length) {
      final h = _hourFromTime(times[firstRainIndex]);
      if (h != null) {
        rainTimeHint = '${_dayPartFromHour(h)}에 비가 올 수 있어요';
      }
    }

    String? snowTimeHint;
    if (firstSnowIndex != null && firstSnowIndex < times.length) {
      final h = _hourFromTime(times[firstSnowIndex]);
      if (h != null) {
        snowTimeHint = '${_dayPartFromHour(h)}에 눈이 올 수 있어요';
      }
    }

    if (hasRain) {
      final buf = StringBuffer()
        ..write('비가 올 수 있어요. 오전 기준 약 $mStr°, 오늘 최고 $maxStr° · 최저 $minStr°예요.');
      if (rainTimeHint != null) {
        buf.write(' $rainTimeHint.');
      }
      buf.write(' 접이식 우산을 챙겨주세요.');
      return MorningWeatherNotificationCopy(
        title: _limitText('비 소식 있어요, 우산 챙겨요', 18),
        body: _limitText(buf.toString(), 520),
        subtitle: _weatherSubtitle(mStr, maxStr, minStr),
      );
    }

    if (hasSnow) {
      final buf = StringBuffer()
        ..write('눈이 올 수 있어요. 오전 기준 약 $mStr°, 오늘 최고 $maxStr° · 최저 $minStr°예요.');
      if (snowTimeHint != null) {
        buf.write(' $snowTimeHint.');
      }
      buf.write(' 길이 미끄러울 수 있어 천천히 이동해 주세요.');
      return MorningWeatherNotificationCopy(
        title: _limitText('눈길 주의, 따뜻하게 입어요', 18),
        body: _limitText(buf.toString(), 520),
        subtitle: _weatherSubtitle(mStr, maxStr, minStr),
      );
    }

    final cloudy = codeSlice.any((c) => c >= 1 && c <= 3 || c == 45 || c == 48);
    if (cloudy) {
      final buf = StringBuffer()
        ..write('구름이 많은 날씨예요. 오전 기준 약 $mStr°, 최고 $maxStr° · 최저 $minStr°예요.');
      if (spread != null && spread >= 8) {
        buf.write(' 일교차가 커서 겉옷을 준비해 보세요.');
      } else {
        buf.write(' 바깥 활동하기 무난해요.');
      }
      return MorningWeatherNotificationCopy(
        title: _limitText('흐리지만 활동하기 괜찮아요', 18),
        body: _limitText(buf.toString(), 520),
        subtitle: _weatherSubtitle(mStr, maxStr, minStr),
      );
    }

    final clearBuf = StringBuffer()
      ..write('대체로 맑은 날씨예요. 오전 기준 약 $mStr°, 최고 $maxStr° · 최저 $minStr°예요.');
    if (spread != null && spread >= 10) {
      clearBuf.write(' 낮과 밤 기온 차가 커서 얇은 겉옷 하나가 도움이 돼요.');
    } else {
      clearBuf.write(' 가볍게 입고 나가기 좋아요.');
    }
    return MorningWeatherNotificationCopy(
      title: _limitText('맑은 아침이에요', 18),
      body: _limitText(clearBuf.toString(), 520),
      subtitle: _weatherSubtitle(mStr, maxStr, minStr),
    );
  }
}
