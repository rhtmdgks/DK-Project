import 'dart:convert';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:myapp/core/auth/auth_state.dart';
import 'package:myapp/core/supabase_client.dart';

/// FCM 토큰을 Supabase fcm_tokens에 등록/해제합니다.
/// 급식 출발 알림 ON + 로그인 + 학년·반 있을 때만 등록합니다.
/// 등록은 Edge Function register-fcm-token (X-FCM-Register-Secret) 사용.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('FCM background: ${message.notification?.title}');
}

class FcmTokenService {
  FcmTokenService._();

  static const _registerSecret = String.fromEnvironment(
    'FCM_REGISTER_SECRET',
    defaultValue: '',
  );

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
      return token;
    } catch (e) {
      debugPrint('FcmTokenService: getToken failed $e');
      return null;
    }
  }

  /// 급식 출발 알림용 FCM 토큰 등록. (호출 측에서 알림 ON일 때만 호출)
  static Future<void> registerIfNeeded() async {
    if (_registerSecret.isEmpty) {
      debugPrint('FcmTokenService: FCM_REGISTER_SECRET 없음. 토큰 등록 스킵.');
      return;
    }

    final profile = await getCurrentProfile();
    if (profile == null) return;

    final grade = profile.gradeOrFromStudentId;
    final classNum = profile.classNumOrFromStudentId;
    if (grade == null || classNum == null) return;

    final token = await getToken();
    if (token == null || token.isEmpty) return;

    await _callRegister(
      action: 'register',
      userId: profile.userId,
      token: token,
      grade: grade,
      classNumber: classNum,
    );
  }

  /// 급식 출발 알림 OFF 또는 로그아웃 시 토큰 해제.
  static Future<void> unregisterIfNeeded() async {
    if (_registerSecret.isEmpty) return;

    final profile = await getCurrentProfile();
    if (profile == null) return;

    await _callRegister(action: 'unregister', userId: profile.userId);
  }

  static Future<void> _callRegister({
    required String action,
    required String userId,
    String? token,
    int? grade,
    int? classNumber,
  }) async {
    final baseUrl = supabaseBaseUrl;
    final anonKey = supabaseAnonKey;
    if (baseUrl == null || baseUrl.isEmpty || anonKey == null || anonKey.isEmpty) return;

    final url = baseUrl.endsWith('/')
        ? '${baseUrl}functions/v1/register-fcm-token'
        : '$baseUrl/functions/v1/register-fcm-token';

    final body = <String, dynamic>{
      'action': action,
      'user_id': userId,
    };
    if (action == 'register' && token != null && grade != null && classNumber != null) {
      body['token'] = token;
      body['grade'] = grade;
      body['class_number'] = classNumber;
    }

    try {
      final client = HttpClient();
      try {
        final request = await client.postUrl(Uri.parse(url));
        request.headers.set('Content-Type', 'application/json');
        request.headers.set('Authorization', 'Bearer $anonKey');
        request.headers.set('X-FCM-Register-Secret', _registerSecret);
        request.write(jsonEncode(body));
        final response = await request.close();
        await response.drain();
        if (response.statusCode >= 200 && response.statusCode < 300) {
          debugPrint('FcmTokenService: $action ok');
        } else {
          debugPrint('FcmTokenService: $action failed ${response.statusCode}');
        }
      } finally {
        client.close();
      }
    } catch (e) {
      debugPrint('FcmTokenService: _callRegister failed $e');
    }
  }
}
