class ModerationResult {
  const ModerationResult({
    required this.hasAbuse,
    required this.matchedKeywords,
  });

  final bool hasAbuse;
  final List<String> matchedKeywords;
}

/// 단순 키워드 기반 욕설/불건전 표현 필터.
class ContentModerationService {
  ContentModerationService._();

  static const List<String> _koreanAbuseKeywords = [
    '욕',
    '바보',
    '멍청이',
    '죽어',
    '꺼져',
    '미친',
    '개같',
    '지랄',
    '병신',
  ];

  static const List<String> _englishAbuseKeywords = [
    'fuck',
    'shit',
    'bitch',
    'asshole',
    'idiot',
    'stupid',
    'kill you',
  ];

  static ModerationResult checkText(String text) {
    final normalized = text.toLowerCase();
    final matched = <String>[];

    for (final k in _koreanAbuseKeywords) {
      if (k.isEmpty) continue;
      if (text.contains(k)) {
        matched.add(k);
      }
    }

    for (final k in _englishAbuseKeywords) {
      if (k.isEmpty) continue;
      if (normalized.contains(k)) {
        matched.add(k);
      }
    }

    return ModerationResult(
      hasAbuse: matched.isNotEmpty,
      matchedKeywords: matched,
    );
  }
}

