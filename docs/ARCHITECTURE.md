# School Official App — System Architecture Overview

## 1. System Architecture Overview

### High-Level Components

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        Flutter Client (iOS / Android)                    │
│  ┌──────────┬──────────┬──────────────┬─────────────┐                    │
│  │   Meal   │ Schedule │ Suggestions  │ Notice/Poll │  Bottom Nav (4)   │
│  └────┬─────┴────┬─────┴──────┬───────┴──────┬──────┘                    │
│       │          │            │              │                           │
│  ┌────┴──────────┴────────────┴──────────────┴────┐                      │
│  │  AuthGuard → PasswordChangeGate → Home         │                      │
│  │  Supabase Client (anon key only)               │                      │
│  └────────────────────────┬──────────────────────┘                      │
└───────────────────────────┼─────────────────────────────────────────────┘
                            │ HTTPS / WSS
                            ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                         Supabase Project                                 │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────────────┐  │
│  │ Auth (email/pw) │  │ PostgREST API   │  │ Realtime (chat_messages)│  │
│  │ student_id →    │  │ RLS on all      │  │ subscription by room    │  │
│  │ email mapping   │  │ tables          │  │ membership              │  │
│  └────────┬────────┘  └────────┬────────┘  └────────────┬────────────┘  │
│           │                    │                        │                │
│           └────────────────────┼────────────────────────┘                │
│                                ▼                                         │
│  ┌─────────────────────────────────────────────────────────────────────┐ │
│  │ PostgreSQL: profiles, suggestions, chat_rooms, chat_messages,        │ │
│  │ announcements, polls, poll_votes, schedule_items, timetable_entries  │ │
│  └─────────────────────────────────────────────────────────────────────┘ │
│                                                                          │
│  ┌─────────────────────────────────────────────────────────────────────┐ │
│  │ Edge Functions (server-side, service role / env only)                │ │
│  │   • neis_meal           → NEIS 급식 API 프록시, 캐시 옵션             │ │
│  │   • neis_academic_calendar → NEIS 학사일정 API 프록시                 │ │
│  └─────────────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────────┘
                            │
                            ▼
                   NEIS Open API (external)
```

### Design Principles

- **No sign-up**: 계정은 사전 생성(시드 스크립트). 로그인만 지원.
- **Single auth vector**: Student ID + Password → 내부적으로 `student_id@school.local`로 변환 후 `signInWithPassword`.
- **RLS everywhere**: 모든 테이블에 RLS 활성화, 클라이언트는 anon key만 사용.
- **Realtime only for chat**: `chat_messages`에 대해 구독, 채팅방 멤버십으로 접근 제어.
- **NEIS via Edge**: API 키는 Edge Function 환경변수에만 존재, 클라이언트에 노출 안 함.

### Data Flow Summary

| Feature        | Data Source           | Access Control              |
|----------------|-----------------------|-----------------------------|
| Meal           | Edge Function (NEIS)  | Authenticated request       |
| Schedule       | Supabase (schedule_items, timetable_entries) | RLS by user/role |
| Suggestions    | Supabase (suggestions)| RLS (own + council read)    |
| Notice/Poll    | Supabase (announcements, polls, poll_votes) | RLS, 1 vote per user (DB) |
| Chat           | Supabase Realtime     | RLS via chat_room_members   |

---

## 2. Database Schema (Full SQL with RLS + Indexes)

See `supabase/migrations/001_full_schema.sql` for the complete, executable schema. Summary:

- **profiles**: id (uuid, PK), user_id (FK auth.users), student_id (unique), role, must_change_password, full_name, created_at, updated_at. Indexes on user_id, student_id. RLS: own row by auth.uid().
- **suggestions**: id, author_id (FK profiles), title, body, status, created_at, updated_at. RLS: author CRUD; council role can read all.
- **chat_rooms**: id, name, created_at. **chat_room_members**: room_id, user_id, joined_at. PK (room_id, user_id). RLS: members only for room and messages.
- **chat_messages**: id, room_id, sender_id, content, created_at. RLS: members of room can read; sender can insert.
- **announcements**: id, author_id, title, body, created_at. RLS: all authenticated read; author/council write.
- **polls**: id, announcement_id (nullable), question, options (jsonb), ends_at, created_at. **poll_votes**: poll_id, user_id, option_index. UNIQUE(poll_id, user_id). RLS: read polls; insert vote once.
- **schedule_items**: id, title, description, start_at, end_at, created_by. RLS: by role/school scope.
- **timetable_entries**: id, user_id (or class scope), day_of_week, period, subject, room. UNIQUE constraint to prevent overlap per (user_id, day_of_week, period). RLS: own row or council.

All tables have explicit primary keys, foreign keys, and indexes as in the migration file.

---

## 3. Auth Design & Password Flow

### Email Mapping

- **Rule**: `student_id` → `student_id@school.local`.
- Login UI: 사용자는 **학번(student_id)** 과 **비밀번호** 만 입력.
- 클라이언트: `email = '${studentId.trim()}@school.local'`, `password = password` 로 `supabase.auth.signInWithPassword({ email, password })` 호출.

### must_change_password Flow

1. **초기 비밀번호**: 시드 시 `12345678`로 설정 가능. `profiles.must_change_password = true` 로 설정.
2. **첫 로그인 후**: 앱이 `profiles.must_change_password` 를 확인 (로그인 성공 후 프로필 fetch).
3. **true 이면**: 메인 앱 진입 차단, **PasswordChangeScreen** 만 표시. 여기서 `supabase.auth.updateUser({ password: newPassword })` 호출 후, `profiles` 에서 `must_change_password = false` 로 업데이트 (RPC 또는 service role이 시드된 후, 클라이언트는 본인 프로필만 업데이트하도록 RLS/function 제공).
4. **false 이면**: 정상적으로 Home (Bottom Nav) 표시.

### Race Conditions & Edge Cases

- **동시 비밀번호 변경**: 프로필 업데이트는 `auth.uid()` 로 RLS 제한. 비밀번호 변경은 Auth API가 한 번에 하나만 처리하므로, 동일 세션 내 중복 요청만 방지하면 됨 (버튼 비활성화 또는 한 번만 호출).
- **잘못된 자격 증명**: `signInWithPassword` 실패 시 에러 메시지 표시 (예: "학번 또는 비밀번호를 확인하세요"). 구체적인 "이메일 없음" vs "비밀번호 오류" 구분 노출 금지 (보안).
- **세션 만료 후 재진입**: 앱 시작 시 `supabase.auth.getSession()` 또는 리스너로 세션 복구. 세션 있으면 프로필 다시 fetch 후 `must_change_password` 확인하여 PasswordChangeScreen 또는 Home 표시.
- **무한 로그인 루프 방지**: 비밀번호 변경 성공 후 반드시 `must_change_password` 를 false 로 갱신하고, 그 다음에만 Home으로 라우팅. 실패 시 사용자에게 에러만 표시하고 PasswordChangeScreen에 유지.

---

## 4. Security Review Notes

- **RLS**: 모든 테이블에 RLS 활성화, 정책으로 본인/역할/채팅방 멤버십만 허용.
- **Secrets**: 서비스 롤 키는 클라이언트에 없음. NEIS API 키는 Edge Function env only.
- **Auth**: 로그인은 이메일/비밀번호만, 학번은 이메일 prefix로만 사용.
- **Polls**: 1인 1투표는 DB UNIQUE(poll_id, user_id) 및 RLS로 보장.
- **Chat**: 채팅방 접근은 `chat_room_members` 기반 RLS로만 허용.
- **Edge Functions**: 입력 검증, 실패 시 구조화된 JSON 에러, API 키 미노출.

---

## 5. Scalability Notes

- **DB**: 인덱스가 RLS 정책 및 쿼리 패턴(학번, user_id, room_id, poll_id, 시간 범위)에 맞게 정의됨. 필요 시 파티셔닝은 `chat_messages`, `poll_votes` 등 큰 테이블부터 검토.
- **Realtime**: 채팅방별 구독만 허용, 브로드캐스트 채널 수 최소화.
- **Edge Functions**: NEIS 호출은 24시간 캐시(옵션)로 호출 수 감소 가능.
- **동시 접속**: Supabase 기본 연결 풀링 사용. 향후 피크 시 Connection pooler 설정 검토.

---

## 6. Validation Checklist (Self-Audit)

- [x] RLS policies present on all tables (profiles, suggestions, chat_rooms, chat_room_members, chat_messages, announcements, polls, poll_votes, schedule_items, timetable_entries).
- [x] No service role key in client; anon key only.
- [x] Edge Functions validate parameters and do not expose API key.
- [x] No broken foreign keys; all FKs reference existing tables/columns.
- [x] No infinite login loop: password change success path updates must_change_password and then navigates to Home.
- [x] No double voting: UNIQUE(poll_id, user_id) on poll_votes + RLS.
- [x] No unauthorized chat access: RLS enforces chat_room_members for both chat_rooms and chat_messages.
- [x] Timetable overlap prevented: UNIQUE(user_id, day_of_week, period) (or equivalent) on timetable_entries.
- [x] Seed script idempotent (ON CONFLICT / duplicate check).
- [x] Initial password 12345678; first login forces password change via must_change_password.

---

## 7. Flutter Folder Structure

```
lib/
  main.dart                 # Supabase.initialize, runApp(App())
  app.dart                  # MaterialApp.router(routerConfig: createAppRouter())
  core/
    supabase_client.dart     # getter supabase, emailFromStudentId()
    auth/
      auth_state.dart        # AppProfile, getCurrentProfile()
    routing/
      app_router.dart        # GoRouter, redirect (login / password-change / home), routes
  screens/
    login_screen.dart        # Student ID + password, signInWithPassword, then go password-change or home
    password_change_screen.dart  # updateUser(password), RPC set_must_change_password_false, go home
    home_screen.dart         # BottomNavigationBar (4 tabs), IndexedStack
    chat_list_screen.dart    # List chat_rooms (member), push /chat/:roomId
    chat_screen.dart         # Realtime subscription on chat_messages, send message
  features/
    meal/
      meal_tab.dart          # Edge Function neis_meal, date picker, list meals
    schedule/
      schedule_tab.dart     # schedule_items CRUD (council/admin), list + add + delete
    suggestions/
      suggestions_tab.dart  # suggestions list, insert (author_id)
    notice_poll/
      notice_poll_tab.dart  # TabBar Notice / Poll, announcements list, PollCard with vote (disabled after vote)
```

---

## 8. Feature Implementation Details

- **Meal**: Calls `supabase.functions.invoke('neis_meal', queryParameters: {'date': YYYYMMDD})`. Displays `meals[].DDISH_NM`, `NTR_INFO`. Loading and error states with Retry.
- **Schedule**: Select `schedule_items` ordered by `start_at`. Council/admin: FAB or AppBar action to add (title, description, start_at, end_at, created_by); list tile delete. Constraint `end_at > start_at` in DB.
- **Suggestions**: Select `suggestions`; insert with `author_id` from current profile. RLS gives council read-all.
- **Notice/Poll**: Two tabs. Notice: list `announcements`. Poll: list `polls`; each `PollCard` shows question, options (Radio), Vote button; after insert into `poll_votes` button disabled (and _voted state from DB). UNIQUE(poll_id, user_id) prevents double vote.
- **Chat**: Chat list screen queries `chat_room_members` for current user, then `chat_rooms`. Navigate to ChatScreen(roomId). ChatScreen: fetch `chat_messages` for room; subscribe via `supabase.channel().onPostgresChanges(event: insert, table: chat_messages, filter: room_id = roomId)`; send inserts. Realtime requires `chat_messages` in `supabase_realtime` publication (see migration 002 or Dashboard).

