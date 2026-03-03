# 라온 백오피스 ↔ Flutter 앱 연동 최종 명세서

이 문서는 **백오피스(DK-Project_Backoffice)** 와 **Flutter 학생 앱(DK-Project)** 간 데이터·동작 연동을 위한 최종 명세입니다. Flutter 에이전트는 이 명세에 맞춰 구현·수정하면 됩니다.

**백오피스 프로젝트 경로:** `/Users/edmond104/Documents/GitHub/DK-Project_Backoffice`

---

## 목차

1. [실시간 급식 출발 알림](#1-실시간-급식-출발-알림)
2. [시간표](#2-시간표)
3. [공지사항·알림](#3-공지사항알림)
4. [학사일정 (NEIS)](#4-학사일정-neis)
5. [프로필(profiles) 필드 통일](#5-프로필profiles-필드-통일)
6. [일정(schedule_items)](#6-일정schedule_items)
7. [투표 (polls)](#7-투표-polls)
8. [기타 테이블·API](#8-기타-테이블api)
9. [Flutter 수정 체크리스트](#9-flutter-수정-체크리스트)

---

## 1. 실시간 급식 출발 알림

### 백오피스 동작

- **페이지**: 대시보드 카드 + 사이드바 「급식 출발 알림」 → `/meal-alert`
- **전송**: 학년(1~3)·반(1~10) 선택 후 「급식 출발 알림 전송」 클릭
- **방식**: Supabase Realtime Broadcast
  - **채널**: `meal-departure:{학년}:{반}` (예: 1학년 3반 → `meal-departure:1:3`)
  - **이벤트**: `meal-departure`
  - **페이로드**: `{ message, body, grade, class_number, at }` (ISO 8601)

### Flutter 구현 지시

- 로그인 후 `AppProfile`의 `grade`(또는 `gradeOrFromStudentId`), `classNum`(또는 `classNumOrFromStudentId`)로 **해당 1개 채널만** 구독.
- `supabase.channel('meal-departure:$grade:$classNum').onBroadcast(event: 'meal-departure', callback: ...).subscribe()`
- 수신 시 `message`를 제목, `body`를 본문으로 `flutter_local_notifications`로 즉시 표시. 기존 `meal_notification` 채널 재사용 권장.
- 알림 권한 요청·확인 후 표시. 로그아웃/프로필 변경 시 구독 해제.
- 상세: `docs/MEAL_DEPARTURE_REALTIME_SPEC.md` 참고.

---

## 2. 시간표

### 백오피스 동작

- **timetable_master**: NEIS에서 불러온 **반·교시·과목**만 저장 (학년·반별). 학생별로 자동 부여하지 않음.
- **timetable_entries**: **학생별** 시간표. 백오피스에서 학생 선택 후 요일·교시별로 과목(및 교실·선생님)을 **직접 추가/수정**. 과목 선택 리스트는 해당 학생 학년(·반)의 `timetable_master` 기준으로 노출.
- **저장 시 user_id 필수 규칙**: 학생별 시간표를 저장할 때 `timetable_entries.user_id`에는 **반드시** 해당 학생의 **auth.users.id**(즉 `profiles.user_id`)를 넣어야 한다. 학생 선택 시 UI에는 `profiles.student_id`(예: 10312) 또는 `profiles.id`로 조회할 수 있으나, INSERT/UPDATE 시에는 `profiles.user_id`를 조회해 `user_id` 컬럼에 사용해야 앱에서 해당 학생 로그인 시 시간표가 보인다. `profiles.id`를 `user_id`로 넣으면 안 된다.

### Flutter 구현 지시

- **읽기**: `timetable_entries` 테이블을 `user_id` = 현재 사용자로 조회. 구조 변경 없음.
- **day_of_week**: 백오피스는 **1=월 ~ 5=금**만 사용. Flutter에서 이동 수업 등 요일별 처리 시 1=월, 2=화, …, 5=금으로 맞추면 됨 (일요일 0 등은 백오피스에 없음).
- NEIS는 “마스터만 반영”이므로, Flutter는 계속 `timetable_entries`만 읽으면 됨.

---

## 3. 공지사항·알림

### 백오피스 동작

- **announcements** 테이블: `id`, `title`, `body`, `created_at`, **target_grade**, **target_class_number**
- 공지 작성 시 대상 학년·반 선택. **컬럼명은 반드시 `target_class_number`** (반). `target_class` 아님.

### Flutter 구현 지시

- **Realtime 공지 알림**: `announcements` INSERT 구독 시 새 행의 **target_grade**, **target_class_number** 로 현재 사용자 학년·반과 비교.
- **target_class_number** 사용 필수. (과거 `target_class` 사용 시 백오피스와 불일치하므로 `target_class_number` 우선, 없을 때만 `target_class` fallback 권장.)
- 공지 목록 조회: `announcements` select 시 컬럼 `target_grade`, `target_class_number` 로 필터/표시하면 됨.

---

## 4. 학사일정 (NEIS)

### 백오피스 동작

- **neis_academic_events** 테이블: 백오피스가 NEIS 학사일정 API로 주기 동기화. `aa_ymd`, `event_nm`, `event_cntnt`, `synced_at` 등.
- 공지 관리 화면에서 “NEIS 학사일정 동기화” 버튼 및 6시간마다 자동 동기화.

### Flutter 구현 지시

- **현재**: Edge Function `neis_academic_calendar` 호출로 학사일정 표시 가능. 그대로 두어도 됨.
- **선택**: 동일 데이터 소스로 통일하려면 `neis_academic_events` 테이블을 select 해서 `aa_ymd` → 날짜, `event_nm` → 제목, `event_cntnt` → 내용으로 매핑해 표시할 수 있음. (Edge Function 유지 시 백오피스와 별도 소스라도 내용은 NEIS 기준으로 동일.)

---

## 5. 프로필(profiles) 필드 통일

### 백오피스·DB

- **profiles**: `grade`, `class_num`, `student_number` (학년, 반, 번호). 학번 `student_id`는 G+반(2자리)+번호(2자리) 등 규칙으로 생성.

### 프로필 사진(avatar_url) 연동 규칙

- **avatar_url 저장 규칙**: `profiles.avatar_url`에는 **표시용 전체 공개 URL(https)** 만 저장한다. Storage 경로만 저장하지 않는다. (Flutter는 과거 경로 데이터 하위 호환을 위해 경로 → URL 해석을 적용하지만, 신규 저장은 항상 전체 URL 권장.)
- **Storage 버킷**: 프로필 사진 업로드 시 Supabase Storage 버킷 이름은 **`avatars`** 를 사용한다. (마이그레이션 `029_avatars_bucket_and_avatar_png.sql`에서 생성.)
- **백오피스 구현**: 프로필 사진 업로드 시 `avatars` 버킷에 업로드한 뒤, `profiles.avatar_url`에는 반드시 **공개 전체 URL**을 저장한다 (예: `getPublicUrl(path)` 결과). 경로만 저장하지 않기.
- (선택) 백오피스 공용 유틸: "경로 → 공개 URL" 변환 시 `avatars` 버킷을 사용해 동일 규칙 적용.

### Flutter 구현 지시

- **grade**: `profiles.grade` (없으면 학번 추론).
- **반**: `profiles.class_num` → `AppProfile.classNum` (DB 컬럼명이 `class_num`이면 그대로 매핑).
- **번호**: DB에 `student_number`만 있을 수 있음. `AppProfile.numberInClass` 매핑 시 **`number_in_class` 없으면 `student_number` fallback** 권장. (`profiles.student_number` 와 호환)

---

## 6. 일정(schedule_items)

### 백오피스·Flutter

- **schedule_items**: 학교 일정. 백오피스에서 별도 관리하는 경우 구조 동일 유지.
- Flutter: `schedule_items` select 및 Realtime 구독 등 기존 방식 유지.

---

## 7. 투표 (polls)

### 백오피스 동작

- **경로**: `DK-Project_Backoffice/app/polls/page.tsx`, `components/polls/polls-content.tsx`
- **CRUD**: 투표 생성(question, options), 수정, 삭제. `polls` 테이블에 직접 INSERT/UPDATE/DELETE (council/admin RLS).
- **DB 컬럼**: `id`, `announcement_id`(선택), `question`, `options`(jsonb 배열), `ends_at`(선택), `created_at`
- **ends_at** 설정 시 Flutter 앱에서 "N일 남음" 등 종료 시각 표시. 백오피스에서 투표 만들기/수정 시 종료일 입력 권장.

### Flutter 구현 지시

- **목록**: `polls` select + `poll_votes(option_index)` 로 득표율 계산. optional: `announcements(author_id, profiles(full_name))` 조인 시 게시자명 표시.
- **Realtime**: `polls` 테이블 INSERT/UPDATE/DELETE 구독 시 목록 자동 갱신(백오피스에서 생성/수정/삭제 반영).
- **투표 참여**: `poll_votes` INSERT (1인 1투표, DB UNIQUE 제약).

---

## 8. 기타 테이블·API

| 항목 | 백오피스 | Flutter |
|------|----------|---------|
| **polls / poll_votes** | [투표 관리](#7-투표-polls) (위 섹션 참고) | 조회·투표·Realtime 구독 |
| **suggestions** | 건의함 | 기존 연동 유지 |
| **chat_rooms / chat_messages** | 채팅방 관리 | 기존 연동 유지 |
| **bug_reports** | 버그 신고 | 기존 연동 유지 |

---

## 9. Flutter 수정 체크리스트

- [ ] **급식 출발 알림**: `meal-departure:{grade}:{classNum}` Realtime 구독 및 로컬 알림 표시 (명세 1 참고).
- [ ] **공지 알림**: `announcements` INSERT 구독 시 **target_class_number** 사용 (target_class fallback 가능). (명세 3)
- [ ] **프로필**: `number_in_class` 없을 때 **student_number** 로 번호 매핑. (명세 5)
- [ ] **시간표**: `timetable_entries` 조회, day_of_week 1=월~5=금 의미 유지. (명세 2)
- [x] **투표**: `polls` Realtime 구독(INSERT/UPDATE/DELETE) 시 목록 갱신, 작성자명(author_name) 표시. (명세 7)
- [ ] (선택) 학사일정: `neis_academic_events` 테이블 조회로 전환 또는 Edge Function 유지. (명세 4)

---

## 참고: 백오피스 쪽 코드 위치

- **프로젝트 경로**: `/Users/edmond104/Documents/GitHub/DK-Project_Backoffice`
- 급식 출발: `components/meal-alert/meal-alert-content.tsx`
- 시간표: `components/timetables/timetables-content.tsx`, `app/api/neis-timetable/route.ts` (NEIS → timetable_master)
- 공지: `components/announcements/announcements-content.tsx` (target_grade, target_class_number)
- **투표**: `app/polls/page.tsx`, `components/polls/polls-content.tsx`
- 학사일정 동기화: `app/api/neis-academic-sync/route.ts`, 테이블 `neis_academic_events`

Flutter 앱은 **동일 Supabase 프로젝트**를 사용하므로, 위 테이블·컬럼·Realtime 채널 규칙에 맞추면 됩니다.
