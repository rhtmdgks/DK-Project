import 'package:flutter/cupertino.dart';

/// 과목별 색상, 아이콘, 장식 벡터를 일관되게 관리하는 서비스.
///
/// 과목명을 기반으로 해시값을 생성하여 항상 동일한 색상/아이콘/벡터를 반환합니다.
/// 다른 화면(다음 시간 과목 블럭 등)에서도 동일한 과목에 대해 같은 색상을 사용할 수 있습니다.
class SubjectThemeService {
  SubjectThemeService._();

  /// 과목 카드용 색상 팔레트 (하얀 텍스트 가독성을 위해 어두운 색상 사용)
  /// 각 과목마다 고유한 색상을 보장하기 위해 충분한 색상 제공
  /// 모든 색상은 하얀 텍스트가 잘 보이도록 충분히 어둡게 설정됨
  static const List<Color> _cardColors = [
    Color(0xFFFF7648), // 오렌지 - Mathematics
    Color(0xFF8F98FF), // 라벤더 - Geography
    Color(0xFF4DC591), // 민트 그린
    Color(0xFF6C5CE7), // 보라색
    Color(0xFFE17055), // 코랄 레드
    Color(0xFF5F3DC4), // 진한 보라색
    Color(0xFF2D3436), // 다크 그레이
    Color(0xFF00B894), // 에메랄드 그린
    Color(0xFF0984E3), // 진한 파란색
    Color(0xFFE84393), // 진한 핑크
    Color(0xFFD63031), // 진한 빨간색
    Color(0xFF00A085), // 어두운 청록색 (밝은 청록색 대체)
    Color(0xFF7F8C8D), // 슬레이트 그레이
    Color(0xFFC0392B), // 진한 빨간색 변형
    Color(0xFF8E44AD), // 진한 보라색 변형
    Color(0xFF2980B9), // 진한 파란색 변형
    Color(0xFF27AE60), // 어두운 그린
    Color(0xFFD35400), // 어두운 오렌지
    Color(0xFF16A085), // 어두운 청록색
    Color(0xFF34495E), // 어두운 슬레이트
    Color(0xFFE67E22), // 어두운 오렌지 변형
    Color(0xFF9B59B6), // 보라색 변형
  ];

  /// 과목명 기반 아이콘 매핑
  static final Map<String, IconData> _iconMap = {
    '수학': CupertinoIcons.number,
    '수학Ⅰ': CupertinoIcons.number,
    '수학Ⅱ': CupertinoIcons.number,
    '미적분': CupertinoIcons.number_square,
    '확률과통계': CupertinoIcons.chart_bar,
    '기하': CupertinoIcons.cube_box,
    '생명과학': CupertinoIcons.lab_flask,
    '생명과학Ⅰ': CupertinoIcons.lab_flask,
    '생명과학Ⅱ': CupertinoIcons.lab_flask,
    '화학': CupertinoIcons.lab_flask,
    '화학Ⅰ': CupertinoIcons.lab_flask,
    '화학Ⅱ': CupertinoIcons.lab_flask,
    '물리': CupertinoIcons.bolt,
    '물리학': CupertinoIcons.bolt,
    '물리Ⅰ': CupertinoIcons.bolt,
    '물리Ⅱ': CupertinoIcons.bolt,
    '지구과학': CupertinoIcons.globe,
    '지구과학Ⅰ': CupertinoIcons.globe,
    '지구과학Ⅱ': CupertinoIcons.globe,
    '국어': CupertinoIcons.book,
    '국어Ⅰ': CupertinoIcons.book,
    '국어Ⅱ': CupertinoIcons.book,
    '문학': CupertinoIcons.book_fill,
    '언어와매체': CupertinoIcons.doc_text,
    '영어': CupertinoIcons.textformat,
    '영어Ⅰ': CupertinoIcons.textformat,
    '영어Ⅱ': CupertinoIcons.textformat,
    '영어회화': CupertinoIcons.mic,
    '한국사': CupertinoIcons.time,
    '세계사': CupertinoIcons.globe,
    '동아시아사': CupertinoIcons.map,
    '경제': CupertinoIcons.money_dollar,
    '정치와법': CupertinoIcons.hammer,
    '사회문화': CupertinoIcons.person_2,
    '지리': CupertinoIcons.map,
    '세계지리': CupertinoIcons.globe,
    '한국지리': CupertinoIcons.map,
    '체육': CupertinoIcons.sportscourt,
    '음악': CupertinoIcons.music_note,
    '미술': CupertinoIcons.paintbrush,
    '기술가정': CupertinoIcons.wrench,
    '정보': CupertinoIcons.desktopcomputer,
    '프로그래밍': CupertinoIcons.chevron_left_slash_chevron_right,
  };

  /// 장식 벡터 경로 리스트 (Figma에서 가져온 SVG)
  static const List<String> _decorationPaths = [
    'assets/icons/vec1.svg',
    'assets/icons/vec2.svg',
  ];

  /// 장식 벡터 색상 리스트 (각 벡터 파일의 색상)
  static const List<Color> _decorationColors = [
    Color(0xFFFFC278), // vec1.svg 색상
    Color(0xFF182A88), // vec2.svg 색상
  ];

  /// 과목명을 기반으로 해시값 생성
  static int _hashSubjectName(String subjectName) {
    return subjectName.hashCode;
  }

  /// 과목명으로부터 색상 반환 (항상 동일한 과목은 동일한 색상)
  /// 하얀 텍스트 가독성을 위해 밝은 색은 제외하고 어두운 색상 사용
  static Color getColorForSubject(String subjectName) {
    final hash = _hashSubjectName(subjectName);
    final index = hash.abs() % _cardColors.length;
    return _cardColors[index];
  }

  /// 과목명으로부터 아이콘 반환
  /// 매핑에 없으면 과목명의 첫 글자나 키워드로 추론, 그래도 없으면 기본 아이콘
  static IconData getIconForSubject(String subjectName) {
    // 정확한 매칭 먼저 시도
    if (_iconMap.containsKey(subjectName)) {
      return _iconMap[subjectName]!;
    }

    // 부분 매칭 시도
    for (final entry in _iconMap.entries) {
      if (subjectName.contains(entry.key) || entry.key.contains(subjectName)) {
        return entry.value;
      }
    }

    // 키워드 기반 추론
    final lowerName = subjectName.toLowerCase();
    if (lowerName.contains('수학') || lowerName.contains('math')) {
      return CupertinoIcons.number;
    } else if (lowerName.contains('과학') || lowerName.contains('science')) {
      return CupertinoIcons.lab_flask;
    } else if (lowerName.contains('국어') || lowerName.contains('korean')) {
      return CupertinoIcons.book;
    } else if (lowerName.contains('영어') || lowerName.contains('english')) {
      return CupertinoIcons.textformat;
    } else if (lowerName.contains('역사') || lowerName.contains('history')) {
      return CupertinoIcons.time;
    } else if (lowerName.contains('지리') || lowerName.contains('geography')) {
      return CupertinoIcons.map;
    } else if (lowerName.contains('체육') || lowerName.contains('pe') || lowerName.contains('physical')) {
      return CupertinoIcons.sportscourt;
    } else if (lowerName.contains('음악') || lowerName.contains('music')) {
      return CupertinoIcons.music_note;
    } else if (lowerName.contains('미술') || lowerName.contains('art')) {
      return CupertinoIcons.paintbrush;
    }

    // 기본 아이콘
    return CupertinoIcons.book;
  }

  /// 과목명으로부터 장식 벡터 경로 반환 (없을 수 있음)
  static String? getDecorationPathForSubject(String subjectName) {
    if (_decorationPaths.isEmpty) return null;
    final hash = _hashSubjectName(subjectName);
    final index = hash.abs() % _decorationPaths.length;
    return _decorationPaths[index];
  }

  /// 과목명으로부터 장식 벡터 색상 반환
  static Color getDecorationColorForSubject(String subjectName) {
    if (_decorationColors.isEmpty) return CupertinoColors.white;
    final hash = _hashSubjectName(subjectName);
    final index = hash.abs() % _decorationColors.length;
    return _decorationColors[index];
  }

  /// 과목 테마 정보를 한 번에 반환
  static SubjectTheme getThemeForSubject(String subjectName) {
    return SubjectTheme(
      color: getColorForSubject(subjectName),
      icon: getIconForSubject(subjectName),
      decorationPath: getDecorationPathForSubject(subjectName),
      decorationColor: getDecorationColorForSubject(subjectName),
    );
  }
}

/// 과목 테마 정보를 담는 클래스
class SubjectTheme {
  const SubjectTheme({
    required this.color,
    required this.icon,
    this.decorationPath,
    required this.decorationColor,
  });

  final Color color;
  final IconData icon;
  final String? decorationPath;
  final Color decorationColor;
}
