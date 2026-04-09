# 공통 데이터 계약 (백오피스 · 플러터 앱)

동일 Supabase 프로젝트를 사용하는 백오피스와 플러터 앱이 같은 테이블·의미·에러 규칙을 따르기 위한 문서입니다.

## 테이블 목록 및 역할

| 테이블 | 설명 | 앱 쓰기 | 백오피스 |
|--------|------|---------|----------|
| profiles | 사용자(학생/교사/관리자) | 읽기 전용(본인) | CRUD, 계정 생성 |
| announcements | 공지사항 | 읽기 | CRUD |
| polls, poll_votes | 투표·투표 참여 | 읽기, 투표 | CRUD |
| suggestions, suggestion_comments | 건의함·댓글 | 건의/댓글 등록, 읽기, 신고 | CRUD, 상태 변경 |
| chat_rooms, chat_room_members, chat_messages | 채팅 | 방 참여, 메시지 전송, 읽기, 신고 | 방 생성/삭제, 읽기 |
| schedule_items | 학교 일정 | 읽기 | CRUD |
| personal_events | 개인 일정 | 본인 CRUD | 읽기(선택) |
| timetable_entries | 개인 시간표 | 본인 CRUD(또는 API) | CRUD |
| bug_reports | 버그 신고 | 등록 | 조회·상태 변경 |
| content_reports | 커뮤니티 신고 내역 | 앱에서 신고 생성 | 신고 검토·상태 변경 |
| greetings | 응원 문구 | 읽기 | CRUD |
| meal_departure_* | 급식 출발 관련 | 읽기/알림 | 설정·전송 |

NEIS 학사일정: 백오피스 /api/neis-academic-sync 로 DB 동기화. 앱은 동기화된 테이블만 조회.

## 인증

- **계정 생성**: 백오피스에서만 (profiles + auth.users). 이메일 형식: `학번@school.local` 또는 `학번-profileId@laon.local`.
- **앱 로그인**: Supabase Auth (signInWithPassword). user_id = profiles.user_id. `login_from_profiles` RPC는 학번으로 `auth.users` 이메일을 알려 주며, `profiles.password`가 채워져 있을 때만 DB에서 비밀번호 문자열을 검증하고, 비어 있으면 이메일만 반환한 뒤 최종 검증은 Auth에 맡긴다(관리자 등 Auth만 맞춘 계정도 앱 로그인 가능).
- **백오피스 로그인**: POST /api/auth (학번, 비밀번호) → 쿠키 세션. 다음 중 하나면 허용: `profiles.can_access_backoffice = true` **또는** `profiles.role` 이 `admin` / `council` / `teacher` (동일 기준으로 세션 검증). 세션에 노출하는 역할은 `backoffice_role` 우선, 없으면 위 app 역할. 학생 계정에만 백오피스를 열어야 할 때는 `can_access_backoffice`만 켜는 방식으로 구분.
- **전체 비밀번호 리셋(백오피스)**: 설정 화면에서 관리자(admin)만 실행. 확인 대화상자 → 관리자 본인 비밀번호(step-up) → POST `/api/admin/bulk-reset-passwords`. **실행한 관리자 본인(`user_id`)은 리셋에서 제외**되고, 나머지 사용자는 임시 비밀번호 기본값 `12345678`(선택적으로 환경 변수 `BULK_RESET_DEFAULT_PASSWORD`로 덮어쓰기)로 Auth·`profiles`를 맞추며 `must_change_password = true`. 앱은 첫 로그인 시 비밀번호 변경 화면으로 유도.

## 에러/결과 코드 (공통 키워드)

- `network_error`: 통신 실패
- `auth_error` / `unauthorized`: 인증 실패
- `not_found`: 리소스 없음
- `validation_error`: 입력 검증 실패
- `forbidden`: 권한 없음

앱·백오피스 모두 사용자에게 노출할 메시지는 이 코드 또는 동일한 문구로 통일할 수 있음.
