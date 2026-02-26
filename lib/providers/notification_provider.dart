import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:myapp/models/notification_item.dart';

/// 앱 내 알림 목록을 관리하는 프로바이더
class NotificationProvider extends ChangeNotifier {
  NotificationProvider() {
    _loadNotifications();
  }

  static const _keyNotifications = 'app_notifications';
  static const _maxNotifications = 50; // 최대 저장 개수

  List<NotificationItem> _notifications = [];

  List<NotificationItem> get notifications => List.unmodifiable(_notifications);

  int get unreadCount => _notifications.where((n) => !n.read).length;

  /// SharedPreferences에서 알림 목록 로드
  Future<void> _loadNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_keyNotifications);
      if (jsonString != null) {
        final List<dynamic> jsonList = jsonDecode(jsonString);
        _notifications = jsonList
            .map((json) => NotificationItem.fromJson(json as Map<String, dynamic>))
            .toList();
        _notifications.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        notifyListeners();
      }
    } catch (e) {
      debugPrint('알림 로드 실패: $e');
    }
  }

  /// SharedPreferences에 알림 목록 저장
  Future<void> _saveNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = jsonEncode(
        _notifications.map((n) => n.toJson()).toList(),
      );
      await prefs.setString(_keyNotifications, jsonString);
    } catch (e) {
      debugPrint('알림 저장 실패: $e');
    }
  }

  /// 새 알림 추가
  Future<void> addNotification(NotificationItem notification) async {
    _notifications.insert(0, notification);
    
    // 최대 개수 초과 시 오래된 알림 제거
    if (_notifications.length > _maxNotifications) {
      _notifications = _notifications.take(_maxNotifications).toList();
    }
    
    notifyListeners();
    await _saveNotifications();
  }

  /// 알림을 읽음 처리
  Future<void> markAsRead(String id) async {
    final index = _notifications.indexWhere((n) => n.id == id);
    if (index != -1 && !_notifications[index].read) {
      _notifications[index] = _notifications[index].copyWith(read: true);
      notifyListeners();
      await _saveNotifications();
    }
  }

  /// 모든 알림을 읽음 처리
  Future<void> markAllAsRead() async {
    bool changed = false;
    for (int i = 0; i < _notifications.length; i++) {
      if (!_notifications[i].read) {
        _notifications[i] = _notifications[i].copyWith(read: true);
        changed = true;
      }
    }
    if (changed) {
      notifyListeners();
      await _saveNotifications();
    }
  }

  /// 특정 알림 삭제
  Future<void> deleteNotification(String id) async {
    _notifications.removeWhere((n) => n.id == id);
    notifyListeners();
    await _saveNotifications();
  }

  /// 모든 알림 삭제
  Future<void> clearAll() async {
    _notifications.clear();
    notifyListeners();
    await _saveNotifications();
  }
}
