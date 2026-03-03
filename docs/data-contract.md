# 공통 데이터 계약 (백오피스 · 플러터 앱)

동일 Supabase 프로젝트를 사용하는 백오피스와 플러터 앱이 같은 테이블·의미·에러 규칙을 따르기 위한 문서입니다.

## 테이블 목록 및 역할

| 테이블 | 설명 | 앱 쓰기 | 백오피스 |
|--------|------|---------|----------|
| profiles | 사용자(학생/교사/관리자) | 읽기 전용(본인) | CRUD, 계정 생성 |
| announcements | 공지사항 | 읽기 | CRUD |
| polls, poll_votes | 투표·투표 참여 | 읽기, 투표 | CRUD |
| suggestions, suggestion_comments | 건의함·댓글 | 건의/댓글 등록, 읽기 | CRUD, 상태 변경 |
| chat_rooms, chat_room_members, chat_messages | 채팅 | 방 참여, 메시지 전송, 읽기 | 방 생성/삭제, 읽기 |
| schedule_items | 학교 일정 | 읽기 | CRUD |
| personal_events | 개인 일정 | 본인 CRUD | 읽기(선택) |
| timetable_entries | 개인 시간표 | 본인 CRUD(또는 API) | CRUD |
| bug_reports | 버그 신고 | 등록 | 조회·상태 변경 |
| greetings | 응원 문구 | 읽기 | CRUD |
| meal_departure_* | 급식 출발 관련 | 읽기/알림 | 설정·전송 |

NEIS 학사일정: 백오피스 /api/neis-academic-sync 로 DB 동기화. 앱은 동기화된 테이블만 조회.

## 인증

- **계정 생성**: 백오피스에서만 (profiles + auth.users). 이메일 형식: `학번@school.local` 또는 `학번-profileId@laon.local`.
- **앱 로그인**: Supabase Auth (signInWithPassword). user_id = profiles.user_id.
- **백오피스 로그인**: POST /api/auth (학번, 비밀번호) → 쿠키 세션. can_access_backoffice 필요.

## 에러/결과 코드 (공통 키워드)

- `network_error`: 통신 실패
- `auth_error` / `unauthorized`: 인증 실패
- `not_found`: 리소스 없음
- `validation_error`: 입력 검증 실패
- `forbidden`: 권한 없음

앱·백오피스 모두 사용자에게 노출할 메시지는 이 코드 또는 동일한 문구로 통일할 수 있음.
