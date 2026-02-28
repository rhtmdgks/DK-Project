import 'dart:io';

import 'package:myapp/core/supabase_client.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 채팅방·메시지 데이터 접근 레이어.
class ChatRepository {
  ChatRepository();

  final _client = supabase;

  /// 사용자가 참여 중인 채팅방 목록 (RPC).
  Future<List<Map<String, dynamic>>> getUserChatRooms(String userId) async {
    final roomsResult = await _client.rpc(
      'get_user_chat_rooms',
      params: {'p_user_id': userId},
    );
    return List<Map<String, dynamic>>.from(roomsResult as List);
  }

  /// 채팅방 정보 조회 (RPC).
  Future<Map<String, dynamic>> getChatRoom(String roomId, String userId) async {
    final roomResult = await _client.rpc(
      'get_chat_room',
      params: {
        'p_room_id': roomId,
        'p_user_id': userId,
      },
    );
    return roomResult as Map<String, dynamic>;
  }

  /// 채팅 메시지 목록 (RPC).
  Future<List<Map<String, dynamic>>> getChatMessages(
    String roomId,
    String userId,
  ) async {
    final result = await _client.rpc(
      'get_chat_messages',
      params: {
        'p_room_id': roomId,
        'p_user_id': userId,
      },
    );
    return List<Map<String, dynamic>>.from(result as List);
  }

  /// 메시지 전송 (RPC insert_chat_message).
  Future<void> sendMessage({
    required String roomId,
    required String senderId,
    required String content,
    String? attachmentUrl,
    String? attachmentType,
  }) async {
    await _client.rpc(
      'insert_chat_message',
      params: {
        'p_room_id': roomId,
        'p_sender_id': senderId,
        'p_content': content,
        'p_attachment_url': attachmentUrl,
        'p_attachment_type': attachmentType,
      },
    );
  }

  /// 1:1 채팅 상대방 표시 정보 (RPC get_direct_chat_other_user).
  Future<Map<String, dynamic>?> getDirectChatOtherUser(
    String roomId,
    String userId,
  ) async {
    final otherUserResult = await _client.rpc(
      'get_direct_chat_other_user',
      params: {
        'p_room_id': roomId,
        'p_user_id': userId,
      },
    );
    return otherUserResult as Map<String, dynamic>?;
  }

  /// 채팅 첨부 파일 업로드 (이미지). jpg, png, gif, webp만 허용. 반환: public URL 또는 형식 오류 시 null.
  Future<String?> uploadImage(
    File file, {
    String? roomId,
    String? userId,
  }) async {
    final ext = file.path.split('.').last.toLowerCase();
    if (ext.isEmpty || !['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(ext)) {
      return null;
    }
    final prefix = '${roomId ?? 'chat'}/${userId ?? 'anon'}';
    final path = '$prefix/${DateTime.now().millisecondsSinceEpoch}.$ext';
    await _client.storage.from('chat-attachments').upload(
          path,
          file,
          fileOptions: const FileOptions(upsert: true),
        );
    return _client.storage.from('chat-attachments').getPublicUrl(path);
  }

  /// 채팅 첨부 파일 업로드 (동영상). mp4, mov, webm, m4v만 허용. 반환: public URL 또는 형식 오류 시 null.
  Future<String?> uploadVideo(
    File file, {
    String? roomId,
    String? userId,
  }) async {
    final ext = file.path.split('.').last.toLowerCase();
    if (ext.isEmpty || !['mp4', 'mov', 'webm', 'm4v'].contains(ext)) {
      return null;
    }
    final prefix = '${roomId ?? 'chat'}/${userId ?? 'anon'}';
    final path = '$prefix/${DateTime.now().millisecondsSinceEpoch}.$ext';
    await _client.storage.from('chat-attachments').upload(
          path,
          file,
          fileOptions: const FileOptions(upsert: true),
        );
    return _client.storage.from('chat-attachments').getPublicUrl(path);
  }
}
