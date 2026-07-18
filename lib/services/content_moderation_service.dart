class ModerationResult {
  const ModerationResult({
    required this.hasAbuse,
    required this.matchedKeywords,
  });

  final bool hasAbuse;
  final List<String> matchedKeywords;
}

/// 단순 키워드 기반 욕설/불건전 표현 필터.
/// 서버 [contains_blocked_keyword]와 동일하게 공백·특수문자 제거 후 부분 일치.
class ContentModerationService {
  ContentModerationService._();

  static const List<String> _abuseKeywords = [
    '지랄',
    '병신',
    '씨발',
    '시발',
    'ㅅㅂ',
    'ㅂㅅ',
    'ㅆㅂ',
    'ㅈㄹ',
    'ㅄ',
    'ㄱㅅㄲ',
    'ㅁㅊ',
    'ㅂㅆ',
    '개새끼',
    '새끼',
    '좆',
    '죽어',
    '꺼져',
    '미친',
    '개같',
    'fuck',
    'shit',
    'bitch',
    'asshole',
    'idiot',
    'stupid',
    'kill you',
  ];

  /// 서버 정규화와 동일: 비(한글·영숫자) 문자 제거 + 소문자화.
  static String normalizeForModeration(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9가-힣ㄱ-ㅎㅏ-ㅣ]'), '');
  }

  static ModerationResult checkText(String text) {
    final normalized = normalizeForModeration(text);
    if (normalized.isEmpty) {
      return const ModerationResult(hasAbuse: false, matchedKeywords: []);
    }

    final matched = <String>[];
    for (final k in _abuseKeywords) {
      if (k.isEmpty) continue;
      final key = k.toLowerCase().replaceAll(' ', '');
      if (normalized.contains(key)) {
        matched.add(k);
      }
    }

    return ModerationResult(
      hasAbuse: matched.isNotEmpty,
      matchedKeywords: matched,
    );
  }
}
