import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase client access. Initialize in main() with Supabase.initialize().
SupabaseClient get supabase => Supabase.instance.client;

/// Email mapping: student_id -> student_id@school.local
String emailFromStudentId(String studentId) {
  return '${studentId.trim()}@school.local';
}
