import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:myapp/core/auth/auth_state.dart';
import 'package:myapp/core/supabase_client.dart';

/// FCM 토큰을 Supabase fcm_tokens에 등록/해제합니다.
/// 급식 출발 알림 ON + 로그인 + 학년·반 있을 때만 등록합니다.
/// 등록은 Edge Function register-fcm-token (JWT 기반 식별) 사용.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('FCM background: ${message.notification?.title}');
}

class FcmTokenService {
  FcmTokenService._();

  static bool _firebaseInitialized = false;

  static Future<void> ensureFirebaseInitialized() async {
    if (_firebaseInitialized) return;
    try {
      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
      _firebaseInitialized = true;
    } catch (e) {
      debugPrint('FcmTokenService: Firebase init failed ($e). FCM 푸시 비활성.');
    }
  }

  static Future<String?> getToken() async {
    try {
      await ensureFirebaseInitialized();
      if (Platform.isIOS) {
        final settings = await FirebaseMessaging.instance.requestPermission(
          alert: true,
          badge: true,
          sound: true,
        );
        if (settings.authorizationStatus != AuthorizationStatus.authorized &&
            settings.authorizationStatus != AuthorizationStatus.provisional) {
          return null;
        }
      }
      final token = await FirebaseMessaging.instance.getToken();
      final platform = Platform.isIOS ? 'ios' : 'android';
      debugPrint('FcmTokenService: getToken success (platform=$platform)');
      return token;
    } catch (e) {
      debugPrint('FcmTokenService: getToken failed $e');
      return null;
    }
  }

  /// 급식 출발 알림용 FCM 토큰 등록. (호출 측에서 알림 ON일 때만 호출)
  static Future<void> registerIfNeeded() async {
    if (await getCurrentProfile() == null) return;

    final token = await getToken();
    if (token == null || token.isEmpty) return;

    final platform = Platform.isIOS ? 'ios' : 'android';
    debugPrint('FcmTokenService: registerIfNeeded calling Edge Function (platform=$platform)');

    await _callRegister(
      action: 'register',
      token: token,
    );
  }

  /// 급식 출발 알림 OFF 또는 로그아웃 시 토큰 해제.
  static Future<void> unregisterIfNeeded() async {
    if (await getCurrentProfile() == null) return;

    await _callRegister(action: 'unregister');
  }

  static Future<void> _callRegister({
    required String action,
    String? token,
  }) async {
    final body = <String, dynamic>{
      'action': action,
    };
    if (action == 'register' && token != null) {
      body['token'] = token;
      body['platform'] = Platform.isIOS ? 'ios' : 'android';
    }

    try {
      if (supabase.auth.currentSession?.accessToken == null) {
        debugPrint('FcmTokenService: session accessToken 없음. $action 스킵.');
        return;
      }
      final res = await supabase.functions.invoke(
        'register-fcm-token',
        body: body,
      );
      if (res.status >= 200 && res.status < 300) {
        debugPrint('FcmTokenService: $action ok (platform=${action == 'register' ? (Platform.isIOS ? 'ios' : 'android') : '-'})');
      } else {
        debugPrint('FcmTokenService: $action failed ${res.status}');
      }
    } catch (e) {
      debugPrint('FcmTokenService: _callRegister failed $e');
    }
  }
}
