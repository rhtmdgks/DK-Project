import 'dart:convert';

import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:myapp/app.dart';
import 'package:myapp/core/supabase_client.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint('Firebase.initializeApp 실패 (FCM 비활성): $e');
  }

  // 세로 모드만 허용
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // 릴리스에서 URL이 빠지지 않으려면: flutter build apk --dart-define-from-file=dart_defines.json
  var url = const String.fromEnvironment('SUPABASE_URL', defaultValue: '');
  var anonKey = const String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: '');
  var fromEnv = url.isNotEmpty && anonKey.isNotEmpty;

  if (url.isEmpty || anonKey.isEmpty) {
    try {
      final json = await rootBundle.loadString('dart_defines.json');
      final map = jsonDecode(json) as Map<String, dynamic>;
      url = (map['SUPABASE_URL'] as String?)?.trim() ?? '';
      anonKey = (map['SUPABASE_ANON_KEY'] as String?)?.trim() ?? '';
    } catch (e) {
      debugPrint('dart_defines.json 로드 실패(릴리스 빌드 시 해당 파일이 번들에 포함되어 있는지 확인): $e');
    }
  }

  if (url.isEmpty || anonKey.isEmpty) {
    throw Exception(
      'SUPABASE_URL, SUPABASE_ANON_KEY가 필요합니다. '
      '릴리스 빌드 권장: flutter build apk --dart-define-from-file=dart_defines.json',
    );
  }

  if (!url.startsWith('https://') || !url.contains('supabase.co')) {
    throw Exception(
      'SUPABASE_URL 형식이 잘못되었습니다. https://xxxxx.supabase.co 형태여야 합니다. '
      '현재 값(앞 30자): ${url.length > 30 ? url.substring(0, 30) : url}...',
    );
  }

  // 릴리스에서 실제 사용 URL 확인용 (1순위 원인: URL/호스트가 비었거나 스킴 누락 시 DNS처럼 보이는 오류 발생)
  debugPrint('SUPABASE_URL=$url');
  debugPrint('HOST=${Uri.tryParse(url)?.host}');
  debugPrint('SUPABASE from env=$fromEnv (false=loaded from dart_defines.json)');
  if (url.isEmpty) {
    debugPrint('SUPABASE_URL is empty - check dart_defines.json in assets or --dart-define-from-file');
  }

  setSupabaseBaseUrl(url);
  setSupabaseAnonKey(anonKey);
  await Supabase.initialize(url: url, anonKey: anonKey);

  // DNS 워밍업: 앱 프로세스에서 호스트 해석이 한 번이라도 되도록 백그라운드 요청
  final warmUpUrl = url.endsWith('/') ? '${url}rest/v1/' : '$url/rest/v1/';
  Future(() async {
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 5);
      final req = await client.getUrl(Uri.parse(warmUpUrl));
      req.headers.set('apikey', anonKey);
      final resp = await req.close();
      await resp.drain();
      client.close();
    } catch (_) {}
  });

  runApp(const App());
}
