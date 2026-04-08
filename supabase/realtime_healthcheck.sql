-- Realtime publication / RLS / RPC 권한 점검 스크립트

-- 1) Publication 대상
SELECT pubname, schemaname, tablename
FROM pg_publication_tables
WHERE pubname = 'supabase_realtime'
ORDER BY schemaname, tablename;

-- 2) Realtime 주요 테이블 정책
SELECT schemaname, tablename, policyname, roles, cmd, qual, with_check
FROM pg_policies
WHERE tablename IN (
  'announcements',
  'schedule_items',
  'chat_messages',
  'suggestions',
  'suggestion_comments'
)
ORDER BY tablename, policyname;

-- 3) anon/authenticated 함수 실행 권한
SELECT routine_name, grantee, privilege_type
FROM information_schema.routine_privileges
WHERE routine_schema = 'public'
  AND grantee IN ('anon', 'authenticated')
ORDER BY routine_name, grantee;
