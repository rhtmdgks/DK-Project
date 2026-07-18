import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase client access. Initialize in main() with Supabase.initialize().
SupabaseClient get supabase => Supabase.instance.client;

/// Base URL (e.g. https://xxx.supabase.co) for DNS fallback. Set in main() before Supabase.initialize().
String? supabaseBaseUrl;
void setSupabaseBaseUrl(String u) => supabaseBaseUrl = u;

/// Anon key for DNS fallback RPC. Set in main() before Supabase.initialize().
String? supabaseAnonKey;
void setSupabaseAnonKey(String k) => supabaseAnonKey = k;

/// Email mapping: student_id -> student_id@school.local
String emailFromStudentId(String studentId) {
  return '${studentId.trim()}@school.local';
}

/// 레거시 가상 이메일 후보 (기존 학번 계정 호환용). 포맷 변경 금지.
List<String> legacyEmailCandidates(String username) =>
    ['$username@school.local', '$username@laon.local'];
