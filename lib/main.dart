import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:myapp/app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 세로 모드만 허용
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  var url = const String.fromEnvironment('SUPABASE_URL', defaultValue: '');
  var anonKey = const String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: '');

  if (url.isEmpty || anonKey.isEmpty) {
    try {
      final json = await rootBundle.loadString('dart_defines.json');
      final map = jsonDecode(json) as Map<String, dynamic>;
      url = (map['SUPABASE_URL'] as String?) ?? '';
      anonKey = (map['SUPABASE_ANON_KEY'] as String?) ?? '';
    } catch (_) {}
  }

  if (url.isEmpty || anonKey.isEmpty) {
    throw Exception(
      'SUPABASE_URL, SUPABASE_ANON_KEY가 필요합니다. '
      'dart_defines.json을 프로젝트 루트에 두거나 --dart-define-from-file로 전달하세요.',
    );
  }

  await Supabase.initialize(url: url, anonKey: anonKey);
  runApp(const App());
}
