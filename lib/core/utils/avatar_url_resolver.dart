import 'package:myapp/core/supabase_client.dart';

/// 프로필 아바타 Storage 버킷 이름. 백오피스·Flutter 동일 사용.
const String kAvatarBucketName = 'avatars';

/// DB/API에서 받은 avatar_url을 표시용 공개 URL로 변환.
///
/// - null 또는 빈 문자열 → null
/// - 이미 http:// 또는 https:// 로 시작 → 그대로 반환
/// - 그 외 → Storage 경로로 간주하고 [kAvatarBucketName] 버킷의 공개 URL 반환
///   (과거에 경로만 저장된 데이터 하위 호환)
String? resolveAvatarUrl(String? raw) {
  if (raw == null || raw.trim().isEmpty) return null;
  final t = raw.trim();
  if (t.startsWith('http://') || t.startsWith('https://')) return t;
  final path = t.replaceFirst(RegExp(r'^/+'), '');
  if (path.isEmpty) return null;
  return supabase.storage.from(kAvatarBucketName).getPublicUrl(path);
}
