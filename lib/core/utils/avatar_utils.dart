/// DiceBear API를 사용한 아바타 생성 유틸리티
/// 공식 문서: https://www.dicebear.com/how-to-use/http-api/
library;

/// 사용자 식별자를 기반으로 일관된 notionists 스타일 아바타 URL 생성
/// 
/// [seed] - 사용자 식별자 (user_id, student_id 등)
/// 
/// Returns: 아바타 이미지 URL (SVG)
String generateAvatarUrl(String seed) {
  // DiceBear HTTP API v9.x 사용
  // 스타일: notionists (라인아트 캐릭터)
  const baseUrl = 'https://api.dicebear.com/9.x/notionists/svg';
  
  return Uri.parse(baseUrl).replace(queryParameters: {
    'seed': seed,
  }).toString();
}

/// Image.network 등에서 바로 쓸 수 있는 PNG 아바타 URL (Flutter에서는 SVG 미지원 시 사용).
String generateAvatarUrlPng(String seed) {
  const baseUrl = 'https://api.dicebear.com/9.x/notionists/png';
  return Uri.parse(baseUrl).replace(queryParameters: {'seed': seed}).toString();
}

/// 사용자 이름의 이니셜 추출
/// 
/// [name] - 사용자 이름
/// 
/// Returns: 이니셜 (최대 2글자)
String getInitials(String? name) {
  if (name == null || name.trim().isEmpty) return 'U';
  
  final parts = name.trim().split(RegExp(r'\s+'));
  
  if (parts.length == 1) {
    return parts[0]
        .substring(0, parts[0].length > 2 ? 2 : parts[0].length)
        .toUpperCase();
  }
  
  return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase();
}

