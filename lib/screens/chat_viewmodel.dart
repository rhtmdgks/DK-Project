import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:myapp/repositories/chat_repository.dart';

/// 채팅 화면의 메시지/방 정보 및 전송 담당.
class ChatViewModel extends ChangeNotifier {
  ChatViewModel({ChatRepository? repository})
      : _repo = repository ?? ChatRepository();

  final ChatRepository _repo;

  List<Map<String, dynamic>> _messages = [];
  Map<String, dynamic>? _room;
  String? _otherUserDisplayName;
  bool _loading = true;
  String? _error;
  String? _currentUserId;

  List<Map<String, dynamic>> get messages => _messages;
  Map<String, dynamic>? get room => _room;
  String? get otherUserDisplayName => _otherUserDisplayName;
  bool get loading => _loading;
  String? get error => _error;
  String? get currentUserId => _currentUserId;

  void setUserId(String? uid) {
    _currentUserId = uid;
    notifyListeners();
  }

  Future<void> loadRoomInfo(String roomId) async {
    final uid = _currentUserId;
    if (uid == null) return;
    try {
      _room = await _repo.getChatRoom(roomId, uid);
      final other = await _repo.getDirectChatOtherUser(roomId, uid);
      _otherUserDisplayName = other?['full_name'] as String?;
      notifyListeners();
    } catch (_) {}
  }

  Future<void> fetchMessages(String roomId) async {
    final uid = _currentUserId;
    if (uid == null) return;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _messages = await _repo.getChatMessages(roomId, uid);
      _error = null;
    } catch (e) {
      _error = e.toString();
    }
    _loading = false;
    notifyListeners();
  }

  Future<void> sendMessage({
    required String roomId,
    required String content,
    String? attachmentUrl,
    String? attachmentType,
  }) async {
    final uid = _currentUserId;
    if (uid == null) return;
    await _repo.sendMessage(
      roomId: roomId,
      senderId: uid,
      content: content,
      attachmentUrl: attachmentUrl,
      attachmentType: attachmentType,
    );
  }

  Future<String?> uploadImage(File file, {String? roomId, String? userId}) async {
    return _repo.uploadImage(file, roomId: roomId, userId: userId);
  }

  Future<String?> uploadVideo(File file, {String? roomId, String? userId}) async {
    return _repo.uploadVideo(file, roomId: roomId, userId: userId);
  }
}
