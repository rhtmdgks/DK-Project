import 'dart:io';

import 'package:myapp/core/supabase_client.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 개인 일정 첨부파일(이미지·PDF) 데이터 접근 레이어.
///
/// 버킷 `personal-event-attachments`(비공개), 경로 `{user_id}/{event_id}/{timestamp}.{ext}`.
/// 읽기는 서명 URL로만 접근한다.
class PersonalEventAttachmentRepository {
  PersonalEventAttachmentRepository._();

  static final PersonalEventAttachmentRepository instance =
      PersonalEventAttachmentRepository._();

  static const _bucket = 'personal-event-attachments';
  static const allowedExtensions = ['jpg', 'jpeg', 'png', 'gif', 'webp', 'pdf'];

  SupabaseClient get _client => supabase;

  /// 파일 업로드 후 메타 저장. 허용 확장자가 아니면 false.
  Future<bool> uploadAttachment({
    required String eventId,
    required File file,
    required String fileName,
  }) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return false;

    final ext = fileName.split('.').last.toLowerCase();
    if (!allowedExtensions.contains(ext)) return false;

    final path = '$uid/$eventId/${DateTime.now().millisecondsSinceEpoch}.$ext';
    await _client.storage.from(_bucket).upload(
          path,
          file,
          fileOptions: const FileOptions(upsert: true),
        );

    await _client.from('personal_event_attachments').insert({
      'event_id': eventId,
      'user_id': uid,
      'file_name': fileName,
      'storage_path': path,
      'mime_type': ext == 'pdf' ? 'application/pdf' : 'image/$ext',
      'file_size': await file.length(),
    });
    return true;
  }

  /// 일정의 첨부파일 메타 목록.
  Future<List<Map<String, dynamic>>> fetchAttachments(String eventId) async {
    final res = await _client
        .from('personal_event_attachments')
        .select()
        .eq('event_id', eventId)
        .order('created_at', ascending: true);
    return List<Map<String, dynamic>>.from(res as List);
  }

  /// 열람용 서명 URL (1시간 유효).
  Future<String> createSignedUrl(String storagePath) {
    return _client.storage.from(_bucket).createSignedUrl(storagePath, 3600);
  }

  /// 일정 삭제 전 Storage 파일 정리. 메타 행은 FK CASCADE로 삭제된다.
  Future<void> deleteStorageFilesForEvent(String eventId) async {
    final attachments = await fetchAttachments(eventId);
    final paths = attachments
        .map((a) => a['storage_path'] as String?)
        .whereType<String>()
        .toList();
    if (paths.isNotEmpty) {
      await _client.storage.from(_bucket).remove(paths);
    }
  }
}
