# 멀티스쿨(멀티테넌트) 전환 — 1단계 마이그레이션 기록

> 작성일: 2026-07-18 · 상태: **1단계 원격 적용 완료** (2단계 컷오버는 staged 파일로 대기)

## 1. 개요·목표

LAON은 대덕고등학교 1개교 전용 앱으로 시작했다. 이 전환의 목표는 하나의 Supabase
프로젝트에서 **여러 학교를 서비스하는 플랫폼**으로 만드는 것이다. 백오피스에서
Super Admin이 학교를 추가하면 DB에 테넌트(학교)가 생기는 구조가 최종 목표.

핵심 원칙은 **무중단**이다. 원격 DB는 실사용 중(profiles 약 501명: 학생 495 /
council 3 / teacher 2 / admin 1)이므로:

- 마이그레이션은 **가산적(additive)으로만** 작성한다. 기존 오브젝트 삭제·시그니처
  변경·데이터 파괴 금지.
- 배포된 구앱(v1.0.5)은 마이그레이션 적용 후에도 **무변경으로 동작**해야 한다.
- 파괴적 변경(role 값 플립, unique 제약 교체, 레거시 RPC 제거 등)은 전부
  **2단계(staged)** 로 격리한다. → §7

## 2. 확정 결정사항

| 항목 | 결정 |
|---|---|
| 아이디(username) | **학교별 유일** (`unique(school_id, lower(username))`). 글로벌 유일 아님 |
| 로그인 플로우 | 학교 선택 → 아이디 + 비밀번호. 비밀번호 검증은 Supabase Auth(`signInWithPassword`)가 단일 진실 |
| 역할 체계 | 신규 5종 `super_admin / school_admin / teacher / parent / student`. 레거시 `admin`(≒school_admin)·`council`과 **공존** — 1단계에서는 신·구 값 모두 CHECK 허용, 헬퍼 함수·앱이 동등 취급. role 값 플립은 2단계 |
| 학생회(council) | 별도 role이 아니라 학생의 보직 → `profiles.org_roles text[]`에 `'council'` 플래그. 레거시 `role='council'`도 계속 학생회로 인정 |
| auth email 규칙 | 신규 계정 `{username}@{slug}.laon.local`. 기존 사용자의 `{학번}@school.local`은 **불변** |
| 마이그레이션 방식 | additive-only, 원격에 바로 적용. 컬럼은 NULL 허용 + DEFAULT 없음(테이블 rewrite 회피) → backfill UPDATE → 인덱스 |
| 회원가입·이메일 인증 | 스키마만 준비(`recovery_email`, `parent_student_links`). UI/플로우는 다음 단계 |

시드 학교: `slug='daedeok'`, 대덕고등학교, NEIS `G10`/`7430030`, `is_default=true`.
slug는 신규 계정 auth email 도메인에 박제되므로 변경 금지.

## 3. DB 변경 요약

적용된 마이그레이션: `supabase/migrations/20260718100000` ~ `20260718107000` 8개
+ 원격 이력에만 있는 후속 권한 정리 1건(§3.8). 미적용 staged 1개(§7).

### 3.1 `schools` 테이블 (1/8: `20260718100000_schools_table_and_seed.sql`)

테넌트 루트. `id(uuid)`, `slug`(unique, `^[a-z0-9][a-z0-9-]{1,30}[a-z0-9]$`),
`name`, `name_en`, `status(active|inactive|preparing)`, `is_default`(partial
unique — 정확히 1행만 true), NEIS 코드(`atpt_ofcdc_sc_code`, `sd_schul_code`),
`timezone`, `settings jsonb`, timestamps.

- 노출 제어: RLS는 컬럼 단위 제한이 불가하므로 **컬럼 GRANT + 정책 조합**.
  anon은 `SELECT (id, slug, name, name_en, status)` GRANT + `status='active'`
  정책(로그인 화면 학교 선택용 최소 노출), authenticated는 전체 SELECT.
- 쓰기 정책 없음 → 학교 생성/수정은 service_role(백오피스)만 가능.
- 대덕고 시드 INSERT는 `ON CONFLICT (slug) DO NOTHING`으로 멱등.

### 3.2 profiles 확장 (2/8: `20260718101000_profiles_multitenant_columns.sql`)

- 컬럼 추가: `school_id`(FK schools), `username`, `org_roles text[] NOT NULL
  DEFAULT '{}'`, `recovery_email`, `recovery_email_verified_at`.
- `profiles_role_check`를 레거시 4값 + 신규 3값(**7값**) 허용으로 교체 — 기존 행의
  role 값은 변경하지 않음.
- backfill: `school_id`=기본 학교, `username`=`student_id`(기존 사용자는 학번이 곧
  아이디), `role='council'`인 행의 `org_roles`에 `'council'` append.
- `profiles_school_username_key`: `(school_id, lower(username))` partial unique.
  username 형식 CHECK `^[a-zA-Z0-9._-]{2,32}$`.
- **기존 `profiles_student_id_key`(글로벌 unique)는 유지** — 구앱의
  `login_from_profiles`가 의존. `(school_id, student_id)` 교체는 2단계.
- `parent_student_links` 테이블 신설(학부모 기능 준비): RLS on + 정책 없음 =
  service_role 외 전면 차단.

### 3.3 school_id 스코프 테이블 (4/8: `20260718103000_school_id_columns_backfill.sql`)

`school_id uuid REFERENCES schools(id)` 컬럼 추가(NULL 허용, DEFAULT 없음) 후
기본 학교로 backfill, 인덱스 생성. 대상 30개:

- **콘텐츠 루트**: announcements, polls, suggestions, schedule_items,
  class_events, class_photo_shares, opinion_campaigns, greeting_messages
- **시간표/학사**: class_timetable, timetable_master, timetable_entries,
  subjects, subject_divisions, assignments, student_enrollments,
  timetable_swap_requests, timetable_makeup_requests
- **채팅/개인/운영**: chat_rooms, personal_events, bug_reports,
  backoffice_accounts, fcm_tokens, meal_departure_schedules, meal_departure_logs
- **모더레이션**: content_reports, moderation_actions, banned_users,
  content_tombstones, account_deletion_logs, moderation_keywords
  (moderation_keywords만 backfill 제외 — **NULL = 전역 금칙어** 의미론)

의도적 제외:

- **자식 테이블**(poll_votes/poll_likes/poll_comments, suggestion_comments,
  chat_room_members/chat_messages, personal_event_attachments,
  opinion_submissions, timetable_*_reason_logs): 부모 FK 경유로 격리가 전이되므로
  컬럼 불필요.
- **public_holidays**: 대한민국 공휴일 전역 공통.

핫패스 복합 인덱스: `class_timetable(school_id, grade, class_number,
week_offset)`, `fcm_tokens(school_id, grade, class_number)`,
`announcements(school_id, target_grade, target_class_number)`,
`timetable_entries(school_id, user_id)`.

주의: `class_timetable`의 기존 unique 제약은 교체하지 않았다 —
`sync_timetable_entries_from_class_fn`의 `ON CONFLICT`가 제약 컬럼에 바인딩되어
있어 분리 교체 시 RPC가 즉시 파손된다(2단계에서 동시 재작성).

### 3.4 school_id 자동 채움 트리거 (5/8: `20260718104000_set_school_id_triggers.sql`)

구앱·기존 백오피스·edge function은 INSERT 시 school_id를 넣지 않는다. 이를 위한
핵심 호환 장치로 `set_school_id_from_profile()` BEFORE INSERT 트리거를 29개
테이블(§3.3에서 moderation_keywords 제외) + **profiles**에 설치:

```
NEW.school_id가 NULL이면 → current_school_id()   (요청자 프로필의 학교)
                 그래도 NULL → default_school_id() (service_role/백오피스/edge fn 폴백)
```

RLS `WITH CHECK`는 BEFORE ROW 트리거 **이후**의 최종 행에 대해 평가되므로 §3.6의
RESTRICTIVE 정책과 순서 문제가 없다. `default_school_id()` 폴백은 2단계에서
RAISE로 교체 예정(신규 학교 시대의 오귀속 방지).

### 3.5 헬퍼 함수 (3/8: `20260718102000_tenant_helper_functions.sql`)

전부 `SECURITY DEFINER + STABLE + SET search_path=public,pg_temp`(profiles RLS
우회 조회). **레거시·신규 role 값을 동등 취급**하므로 2단계 role 플립 전후 동작이
동일하다. RLS 정책에서는 `(SELECT fn())` initplan 형태로 호출해 행별 재평가 방지.

| 함수 | 의미 |
|---|---|
| `default_school_id()` | `is_default=true`인 학교 id (전환기 폴백) |
| `current_school_id()` | `auth.uid()` 프로필의 school_id |
| `is_super_admin()` | role = 'super_admin' |
| `is_school_admin()` | role ∈ {'admin', 'school_admin', 'super_admin'} |
| `is_teacher_v2()` | role = 'teacher' (기존 함수명 충돌 여지 회피용 `_v2`) |
| `is_staff()` | role ∈ {'admin', 'school_admin', 'teacher', 'super_admin'} |
| `has_council()` | role = 'council' **또는** `'council' = ANY(org_roles)` |
| `is_council_or_staff()` | staff ∪ council |
| `same_school(uuid)` | 대상 school_id가 NOT NULL이고 (내 학교와 일치 **또는** 내가 super_admin) |

### 3.6 정책 헬퍼화 + RESTRICTIVE 테넌트 격리 (8/8: `20260718107000_policy_helperize_and_restrictive.sql`)

① **서두 가드**: 대상 테이블·profiles에 school_id NULL 행이 남아 있으면 RAISE로
트랜잭션 전체 실패(RESTRICTIVE 정책에 의한 "행 증발" 사고 방지).

② **permissive 정책 헬퍼화**: role 문자열을 직접 비교하던 정책 약 20개(라이브
`pg_policy` 덤프 기준)를 이름/커맨드/TO 대상은 그대로 두고 표현식만 헬퍼 함수로
교체 — 레거시·신규 role이 모두 통과하게 됨. 대상: announcements(3), polls(3),
assignments(4), bug_reports(2), chat_rooms/chat_room_members(2), class_events(2),
moderation_keywords(1), opinion_campaigns/opinion_submissions(3),
schedule_items(3), student_enrollments(2), subject_divisions(1), subjects(1),
suggestion_comments(1), timetable_entries(3).
**class_photo_shares 3개 정책은 의도적 유보**(학번 파싱 로직이 얽혀 있어 2단계에서
(school_id, grade, class_number) 컬럼 기반으로 재작성).

③ **`tenant_isolation_<table>` RESTRICTIVE 정책** (기존 permissive와 AND 결합,
`FOR ALL`, `USING/WITH CHECK (SELECT same_school(school_id))`)을 22개 테이블에
추가: announcements, polls, suggestions, schedule_items, class_events,
class_photo_shares, opinion_campaigns, greeting_messages, class_timetable,
timetable_master, timetable_entries, subjects, subject_divisions, assignments,
student_enrollments, timetable_swap_requests, timetable_makeup_requests,
chat_rooms, personal_events, bug_reports, fcm_tokens, meal_departure_schedules.
moderation_keywords는 `school_id IS NULL OR same_school(...)` 변형(전역 금칙어
허용).

**TO authenticated로 한정한 이유**: anon 세션에서는 `current_school_id()`가
NULL → `same_school()`이 항상 false → anon에 걸면 로그인 전 조회(announcements·
poll_votes의 기존 anon SELECT 정책)가 전면 차단되어 구앱이 깨진다. anon 정책
축소·스코프화는 2단계.

**유보(2단계)**: profiles, 모더레이션 로그류(content_reports,
moderation_actions, banned_users, content_tombstones, account_deletion_logs),
backoffice_accounts, meal_departure_logs, 자식 테이블(부모 경유 격리).

### 3.7 신규 로그인 RPC 3종 (6/8: `20260718105000_login_rpcs_v2.sql`)

| RPC | 권한 | 역할 |
|---|---|---|
| `login_with_username(p_school_slug, p_username) → jsonb` | anon, authenticated | (학교 slug, 아이디) → **auth email 반환**. 비밀번호는 검증하지 않음(`signInWithPassword`가 단일 진실 — 기존 `login_from_profiles`와 동일 계약). 학교 미존재·아이디 미존재 모두 `invalid_credentials`로 통일(계정 열거 방지). auth email이 비어 있으면 `{username}@{slug}.laon.local` 규칙으로 유도 |
| `check_username_available(p_school_slug, p_username) → boolean` | **authenticated만** | 백오피스 계정 생성 시 아이디 형식·중복 확인. anon에 열지 않아 계정 열거 방지 |
| `list_active_schools() → TABLE(id, slug, name, name_en)` | anon, authenticated | 로그인 화면 학교 선택 목록 |

레거시 `login_from_profiles`는 **동작 불변**으로 유지하고 DEPRECATED 코멘트만
추가(구앱 v1.0.5 호환, 2단계에서 제거).

### 3.8 role 참조 함수 재작성 (7/8: `20260718106000_role_functions_rewrite.sql`) + 권한 정리

라이브 `pg_get_functiondef` 원본을 마이그레이션 파일 주석에 백업한 뒤 재작성:

- **`get_staff_chat_contact()`**: 기존 `role IN ('admin','council')` →
  `admin/school_admin` 우선 + `council`(role 또는 org_roles) 순으로 확장하고
  **호출자 학교 스코프**(`current_school_id()`) 필터 추가. backfill 완료 상태라
  1개교 시점의 결과는 불변.
- **`backoffice_create_account(...)`**: `backoffice_accounts.school_id`를
  `default_school_id()`로 자동 세팅. **시그니처 불변** — 파라미터를 추가하면
  오버로드가 생겨 기존 3~4인자 호출이 모호해지므로 금지. 멀티스쿨 백오피스가
  생기면 2단계에서 school 파라미터를 받는 신규 함수로 대체.
- **`backoffice_login_from_profiles`는 의도적 미변경**: 라이브 원본이
  `20260331130000_remove_plaintext_profile_password`에서 삭제된
  `profiles.password` 컬럼을 참조해 호출 즉시 오류가 나는 **죽은 함수**임을 확인.
  수정하지 않고 두었으며 멀티스쿨 백오피스 인증은 2단계에서 재설계.

**후속 권한 정리** (원격 마이그레이션 이력
`20260718144039_revoke_public_execute_on_new_rpcs` — MCP로 직접 적용되어 레포에
파일은 없음): 신규 함수의 기본 PUBLIC EXECUTE를 회수. 현재 원격 ACL 기준
`check_username_available`은 authenticated(+service_role)만,
`set_school_id_from_profile` 트리거 함수는 service_role만 EXECUTE 보유.

## 4. Flutter 변경 요약

- **역할 추상화** — `lib/core/auth/app_role.dart`(신규): `AppRole` enum
  (superAdmin/schoolAdmin/teacher/parent/student) + `appRoleFromString`
  (레거시 `'admin'`→schoolAdmin, `'council'`→student, null/unknown→student 폴백)
  + `kOrgRoleCouncil`. `lib/core/auth/app_profile.dart`:
  `schoolId/username/orgRoles/recoveryEmail` 필드(구버전 서버 응답에서 컬럼 부재
  시 null/빈 리스트로 안전), `hasCouncilRole`(org_roles ∪ 레거시 role='council'),
  `isSchoolAdmin`, `isPrivileged` 등 getter를 추상화 경유로 재정의(기존 동작
  동일 집합), `copyWith` 추가. role 문자열 직접 비교 call-site들을 getter 호출로
  치환. 단위 테스트: `test/app_role_test.dart`.
- **학교 인프라** — `lib/models/school.dart`(id/slug/name/name_en/NEIS 코드,
  JSON 왕복), `lib/repositories/school_repository.dart`(`list_active_schools`
  RPC + 실패 시 schools 테이블 직접 조회 폴백, `fetchSchoolById`,
  SharedPreferences 마지막 학교 캐시), `lib/core/school/school_context.dart`
  (싱글턴; `ensureLoaded` 하이드레이션 순서: 메모리 → profiles.school_id →
  prefs 캐시 → 전부 실패 시 null 유지 = 서버 env 폴백).
- **로그인 개편** — `lib/screens/login_screen.dart`: 학교 선택 필드(마지막 학교
  복원·유일 학교 자동 선택) + '아이디' 입력. `_submit` 이메일 후보 결정:
  ① `login_with_username` RPC 성공 시 1순위 → ② 5자리 숫자면 레거시
  `login_from_profiles` + `legacyEmailCandidates`(`@school.local`,
  `@laon.local`, `lib/core/supabase_client.dart`에 집약) → ③ 후보가 없으면
  `{username}@{slug}.laon.local` 규칙 폴백 → 후보 순회로 `signInWithPassword`
  (기존 timeout/retry 유지) → 성공 시 `SchoolContext.set`. 로그아웃 시
  `SchoolContext.clear()`. 서버·클라 배포 순서가 역전돼도 폴백으로 로그인 유지.
- **NEIS 소비자** — `lib/features/meal/meal_tab.dart`,
  `lib/repositories/schedule_repository.dart`: edge function 호출 시
  `SchoolContext.currentSchoolId`가 있으면 `school_id` 파라미터 전달, 없으면
  생략(서버 env 폴백).

## 5. Edge Function 변경 요약

**하위호환 규칙: `school_id`는 항상 선택 파라미터.** 없으면 기존(단일 학교/env)
동작을 그대로 수행한다 — 구앱·기존 스케줄러 호출이 무변경으로 동작.

| 함수 | 변경 |
|---|---|
| `neis_meal`, `neis_academic_calendar` | NEIS 코드 결정 우선순위: ① 명시 `ATPT_OFCDC_SC_CODE`/`SD_SCHUL_CODE` 쿼리 파라미터(레거시 호환) → ② `school_id`로 schools 테이블 조회(service role, best-effort — 실패 시 통과) → ③ env `NEIS_ATPT_OFCDC_SC_CODE`/`NEIS_SD_SCHUL_CODE` |
| `register-fcm-token` | fcm_tokens upsert에 `profile.school_id` 포함(null이면 DB 트리거가 기본 학교로 채움) |
| `send-meal-push` | body의 `school_id`가 있을 때만 fcm_tokens를 학교로 필터(레거시 호출은 생략) |
| `dispatch-meal-schedules` | 레포에 소스가 없어 원격에서 받아 **레포 편입** 후 수정: 스케줄 행의 `school_id`를 send-meal-push 호출에 전달 |
| `moderation-delete-content` | actor·대상의 school_id가 **둘 다 알려진 경우에만** 타학교 차단 가드(레거시 행은 기존 동작 유지) |
| `moderation-ban-user` | 소스는 동일 가드로 수정됨. **원격 미배포 상태** → §8 |

## 6. 신규 학교 추가 절차 (현재 스키마 기준)

백오피스 UI가 생기기 전까지는 service_role(SQL/MCP)로 수행한다.

1. **schools INSERT**
   ```sql
   INSERT INTO public.schools (slug, name, name_en, status, atpt_ofcdc_sc_code, sd_schul_code)
   VALUES ('<slug>', '<학교명>', '<영문명>', 'active', '<시도교육청코드>', '<NEIS학교코드>');
   ```
   - slug 형식: `^[a-z0-9][a-z0-9-]{1,30}[a-z0-9]$`. **auth email 도메인에 박제되므로
     생성 후 변경 금지.** `is_default`는 절대 true로 만들지 않는다(기존 학교 전용).
   - `status='active'`여야 로그인 화면 목록(`list_active_schools`)에 노출된다.
2. **계정 생성** (사용자별)
   - username 결정: 학교 내 유일(대소문자 무시), 형식 `^[a-zA-Z0-9._-]{2,32}$`.
     중복 확인은 `check_username_available('<slug>', '<username>')`.
   - Auth 사용자 생성: email = `{username}@{slug}.laon.local` + 초기 비밀번호.
   - profiles 행: `user_id`(auth uid), `username`, **`school_id`=신규 학교 id를
     명시 세팅**(생략 시 INSERT 트리거가 기본 학교=대덕고로 폴백해 오귀속되므로
     주의), `role`은 신규 값(student/teacher/school_admin/parent) 사용,
     학생회는 `org_roles`에 `'council'` 추가. `must_change_password=true` 권장.
3. **NEIS 코드 확인**: `atpt_ofcdc_sc_code`/`sd_schul_code`가 세팅되어 있으면
   앱이 `school_id`를 전달할 때 급식·학사일정이 해당 학교로 조회된다. 미세팅 시
   env 폴백(=대덕고 데이터)이 내려가므로 개교 전 반드시 채울 것.

## 7. 2단계(staged) 컷오버 체크리스트

파일: `supabase/migrations_staged/20991231000000_STAGED_role_cutover.sql` —
`supabase/migrations/` 밖에 있어 `db push` 대상이 아니며, **아래 전제조건을 전부
충족한 뒤 블록별로 독립 검토·수동 적용**한다.

**적용 전제조건**
- [ ] 앱 v2(학교 선택 로그인 + 신규 role 인지) **강제 업데이트 완료** — v1.0.5
      세션 잔존 0에 근접 (구앱은 role 문자열을 직접 비교하므로 플립 시 파손)
- [ ] `login_from_profiles` 호출 로그 0 확인 (`get_logs`)
- [ ] 백오피스가 `school_admin`/`super_admin`/`org_roles`를 인지

**파일 내용 요약 (적용 순서대로)**
1. 가드: `role='council'`인데 `org_roles`에 'council'이 없는 행 존재 시 RAISE.
2. role 값 플립: `council→student`, `admin→school_admin` + role CHECK에서 레거시
   값 제거(5값만 허용).
3. `profiles_student_id_key`(글로벌 unique) → `(school_id, student_id)` partial
   unique로 교체 (`login_from_profiles` 완전 폐기 이후에만).
4. `class_timetable` unique를 school_id 포함으로 교체 — ⚠️
   `sync_timetable_entries_from_class_fn`의 `ON CONFLICT` 컬럼 목록을 **같은
   트랜잭션에서 함께 재작성**(분리 시 RPC 즉시 파손). 파일에는 주석 스켈레톤만
   있음.
5. 잔여 하드닝(파일 말미 주석 목록): `set_school_id_from_profile()`의
   `default_school_id()` 폴백을 RAISE로 교체, profiles RESTRICTIVE 격리 추가,
   announcements/poll_votes anon 정책 축소·스코프화, class_photo_shares 정책
   3종을 (school_id, grade, class_number) 기반으로 재작성, 헬퍼 함수에서 레거시
   값 제거, `login_from_profiles`/`backoffice_login_from_profiles` DROP,
   moderation-ban-user 배포 상태 정리.

## 8. 남은 작업 / 알려진 리스크

| 항목 | 상태·리스크 | 대응 시점 |
|---|---|---|
| profiles 테넌트 격리 | RESTRICTIVE 정책 유보 — 현재 authenticated는 타학교 프로필 행도 기존 정책 범위 내에서 조회 가능 | 2단계 |
| anon 정책 축소 | announcements·poll_votes의 anon SELECT가 학교 스코프 없이 유지(구앱 로그인 전 조회 보호) | 2단계 |
| class_photo_shares 정책 | role 문자열·학번 파싱 로직이 남은 정책 3종 유보. RESTRICTIVE 격리는 적용되어 있어 타학교 노출은 차단됨 | 2단계 |
| 회원가입·이메일 인증 | `recovery_email`/`parent_student_links` 스키마만 존재. 인증·아이디/비번 찾기 플로우 미구현 | 다음 단계 |
| `moderation-ban-user` | 소스는 학교 가드 포함으로 수정됐으나 **원격 미배포**(원격 함수 목록에 없음). 배포 또는 소스 제거로 정리 필요 | 2단계 전 |
| `suggestion_comments.password` | 평문 저장 여부 점검 권고(멀티스쿨 이전부터의 이슈). 확인 후 해시화/제거 검토 | 별도 |
| 신규 학교 계정 생성 시 school_id 누락 | INSERT 트리거의 `default_school_id()` 폴백 때문에 **기본 학교로 오귀속**될 수 있음 — §6 절차에서 명시 세팅 필수 | 2단계에서 폴백을 RAISE로 교체 |
| 백오피스 멀티스쿨 미지원 | `backoffice_create_account`는 기본 학교 고정, `backoffice_login_from_profiles`는 죽은 함수. 멀티스쿨 백오피스 인증·계정 생성 재설계 필요 | 2단계 |

## 관련 파일

- 마이그레이션: `supabase/migrations/20260718100000` ~ `20260718107000`
- Staged: `supabase/migrations_staged/20991231000000_STAGED_role_cutover.sql`
- Flutter: `lib/core/auth/app_role.dart`, `lib/core/auth/app_profile.dart`,
  `lib/models/school.dart`, `lib/repositories/school_repository.dart`,
  `lib/core/school/school_context.dart`, `lib/screens/login_screen.dart`
- 테스트: `test/app_role_test.dart`
- 설계 원문(승인된 계획): 멀티스쿨 1단계 계획 문서
