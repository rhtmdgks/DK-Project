import 'dart:io';

import 'package:myapp/core/supabase_client.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 프로필 편집(사진·목표 대학) 데이터 접근 레이어.
///
/// 아바타 규칙(BACKOFFICE_FLUTTER_INTEGRATION_SPEC.md):
/// - 버킷 `avatars`, 경로 `{user_id}/{timestamp}.{ext}`
/// - profiles.avatar_url에는 공개 전체 URL만 저장
class ProfileRepository {
  ProfileRepository._();

  static final ProfileRepository instance = ProfileRepository._();

  SupabaseClient get _client => supabase;

  /// 프로필 사진 업로드 후 profiles.avatar_url 갱신. 반환: 공개 URL.
  /// jpg, png, gif, webp만 허용. 형식 오류 시 null.
  Future<String?> uploadAvatar(File file) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return null;

    final ext = file.path.split('.').last.toLowerCase();
    if (!['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(ext)) {
      return null;
    }

    final path = '$uid/${DateTime.now().millisecondsSinceEpoch}.$ext';
    await _client.storage.from('avatars').upload(
          path,
          file,
          fileOptions: const FileOptions(upsert: true),
        );
    final publicUrl = _client.storage.from('avatars').getPublicUrl(path);

    await _client
        .from('profiles')
        .update({'avatar_url': publicUrl})
        .eq('user_id', uid);

    return publicUrl;
  }

  /// 목표 대학 저장. null 또는 빈 문자열이면 초기화.
  Future<void> updateTargetUniversity(String? targetUniversity) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return;

    final value = targetUniversity?.trim();
    await _client
        .from('profiles')
        .update({'target_university': (value == null || value.isEmpty) ? null : value})
        .eq('user_id', uid);
  }
}
