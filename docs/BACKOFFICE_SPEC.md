# 백오피스(어드민) 기능 명세서

## 1. 개요

| 항목 | 내용 |
|------|------|
| 대상 | LAON 서비스 운영·관리용 백오피스(웹) |
| 접근 권한 | `profiles.role` = `admin` 또는 `council` 만 접근 가능 |
| 인증 | Supabase Auth (기존 앱과 동일 계정, 역할로 구분) |

---

## 2. 공통 기능(시스템)

| 기능 ID | 기능명 | 설명 | 필수 |
|--------|--------|------|------|
| SYS-01 | 로그인 | 학번+비밀번호 또는 이메일+비밀번호로 로그인 (기존 `login_sync_password` / `signInWithPassword` 활용) | ○ |
| SYS-02 | 역할 검사 | 로그인 후 `profiles.role` 조회, `admin`/`council` 아니면 접근 거부 및 "권한 없음" 표시 | ○ |
| SYS-03 | 로그아웃 | 세션 종료 후 로그인 화면으로 이동 | ○ |
| SYS-04 | 세션 만료 처리 | 토큰 만료 시 자동 로그아웃 및 로그인 페이지 리다이렉트 | ○ |
| SYS-05 | 레이아웃 | 좌측 고정 사이드바(메뉴) + 우측 메인 영역, 상단에 로그인 사용자(이름/역할) + 로그아웃 | ○ |
| SYS-06 | 대시보드 | 첫 화면: 오늘 일정 수, 미처리 건의 수, 최근 7일 버그 신고 수 등 요약 카드 + 각 항목 해당 관리 페이지 링크 | ○ |

---

## 3. 엔티티별 기능

### 3.1 프로필 (profiles)

| 기능 ID | 기능명 | 설명 | 입력/조건 | 비고 |
|--------|--------|------|-----------|------|
| P-01 | 목록 조회 | 프로필 목록 테이블 표시 | 필터: role(student/council/admin), student_id 검색, 페이지네이션(예: 20개씩) | user_id, student_id, role, full_name, created_at 등 |
| P-02 | 상세 조회 | 한 프로필 상세 정보 표시 | 프로필 id | 수정 화면과 통합 가능 |
| P-03 | 역할 수정 | 프로필의 role 변경 | role: student / council / admin | 본인 role 강등 시 재로그인 등 주의 |
| P-04 | 기타 필드 수정 | full_name 등 수정 가능 필드 변경 | full_name 등 (비밀번호는 별도 플로우) | ○ |

---

### 3.2 일정 (schedule_items)

| 기능 ID | 기능명 | 설명 | 입력/조건 | 비고 |
|--------|--------|------|-----------|------|
| SC-01 | 목록 조회 | 일정 목록 테이블 | 정렬: start_at 기준, 필터: 기간, 페이지네이션 | id, title, start_at, end_at, created_by, created_at |
| SC-02 | 추가 | 새 일정 등록 | title(필수), description(선택), start_at, end_at, created_by(로그인 프로필 id) | ○ |
| SC-03 | 수정 | 기존 일정 제목/설명/시작·종료 시각 변경 | id, title, description, start_at, end_at | ○ |
| SC-04 | 삭제 | 일정 삭제 | id, 삭제 전 확인 다이얼로그 | ○ |

---

### 3.3 건의함 (suggestions)

| 기능 ID | 기능명 | 설명 | 입력/조건 | 비고 |
|--------|--------|------|-----------|------|
| SG-01 | 목록 조회 | 건의 목록 테이블 | 필터: status(pending/reviewed/resolved), 정렬: created_at desc, 페이지네이션 | id, author_id, title, body, status, created_at |
| SG-02 | 상세 조회 | 건의 내용 상세 표시 | id | 작성자(profiles 연동) 표시 |
| SG-03 | 상태 변경 | status 값 변경 | status: pending → reviewed → resolved (또는 프로젝트에 정의된 값) | 드롭다운 또는 버튼 |

---

### 3.4 공지 (announcements)

| 기능 ID | 기능명 | 설명 | 입력/조건 | 비고 |
|--------|--------|------|-----------|------|
| AN-01 | 목록 조회 | 공지 목록 테이블 | 정렬: created_at desc, 페이지네이션 | id, title, body, created_at |
| AN-02 | 추가 | 새 공지 등록 | title(필수), body(선택) | ○ |
| AN-03 | 수정 | 공지 제목/내용 수정 | id, title, body | ○ |
| AN-04 | 삭제 | 공지 삭제 | id, 삭제 전 확인 | ○ |

---

### 3.5 투표 (polls, poll_votes)

| 기능 ID | 기능명 | 설명 | 입력/조건 | 비고 |
|--------|--------|------|-----------|------|
| PV-01 | 목록 조회 | 투표 목록 테이블 | 정렬: created_at desc, 페이지네이션 | id, question, options(jsonb), created_at |
| PV-02 | 추가 | 새 투표 등록 | question(필수), options(선택 목록 배열) | ○ |
| PV-03 | 삭제 | 투표 삭제 | id, 삭제 전 확인 (poll_votes FK 고려) | ○ |
| PV-04 | 투표 현황 조회 | 특정 투표의 선택지별 득표 수 | poll_id, poll_votes 집계 | 읽기 전용 |

---

### 3.6 버그 신고 (bug_reports)

| 기능 ID | 기능명 | 설명 | 입력/조건 | 비고 |
|--------|--------|------|-----------|------|
| BR-01 | 목록 조회 | 버그 신고 목록 테이블 | 필터: status(pending/in_progress/resolved/closed), 정렬: created_at desc, 페이지네이션 | id, user_id, location, description, image_urls, status, created_at |
| BR-02 | 상세 조회 | 신고 내용 + 첨부 이미지 표시 | id | image_urls로 Storage(bug-reports) 이미지 표시 |
| BR-03 | 상태 변경 | status 변경 | status: pending / in_progress / resolved / closed | ○ |

---

### 3.7 채팅방 (chat_rooms, chat_room_members)

| 기능 ID | 기능명 | 설명 | 입력/조건 | 비고 |
|--------|--------|------|-----------|------|
| CH-01 | 방 목록 조회 | 채팅방 목록 테이블 | id, name, created_at | ○ |
| CH-02 | 방 생성 | 새 채팅방 생성 | name(기본값 가능) | ○ |
| CH-03 | 멤버 목록 조회 | 특정 방의 멤버 목록 | room_id, chat_room_members + user_id | ○ |
| CH-04 | 멤버 추가 | 채팅방에 사용자 추가 | room_id, user_id(auth.users id 또는 profiles 연동) | ○ |
| CH-05 | 멤버 제거 | 채팅방에서 멤버 삭제 | room_id, user_id | ○ |
| CH-06 | (선택) 메시지 조회 | 해당 방의 최근 메시지 목록 읽기 전용 | room_id, chat_messages select | 관리 목적 |

---

### 3.8 과목·분반 (subjects, subject_divisions)

| 기능 ID | 기능명 | 설명 | 입력/조건 | 비고 |
|--------|--------|------|-----------|------|
| SB-01 | 과목 목록 | subjects 테이블 목록 | code, name, category, year, semester 등 | ○ |
| SB-02 | 과목 추가/수정/삭제 | 과목 CRUD | code(필수), name, category, year, semester | divisions 참조 시 순서 고려 |
| SD-01 | 분반 목록 | subject_divisions 목록(과목별) | subject_id, division_name, teacher_name, room, max_students | ○ |
| SD-02 | 분반 추가/수정/삭제 | 분반 CRUD | subject_id, division_name, teacher_name, room, max_students | ○ |

---

### 3.9 과제 (assignments)

| 기능 ID | 기능명 | 설명 | 입력/조건 | 비고 |
|--------|--------|------|-----------|------|
| AS-01 | 목록 조회 | 과제 목록(분반별 필터 가능) | division_id, title, description, due_at, created_by, created_at | ○ |
| AS-02 | 추가 | 과제 등록 | division_id, title, description(선택), due_at(선택), attachment_url(선택), created_by | ○ |
| AS-03 | 수정 | 과제 내용/기한 등 수정 | id, title, description, due_at, attachment_url | ○ |
| AS-04 | 삭제 | 과제 삭제 | id, 삭제 전 확인 | ○ |

---

### 3.10 수강 신청 (student_enrollments)

| 기능 ID | 기능명 | 설명 | 입력/조건 | 비고 |
|--------|--------|------|-----------|------|
| EN-01 | 목록 조회 | 프로필별/분반별 수강 목록 | profile_id 또는 division_id 필터 | ○ |
| EN-02 | 추가 | 특정 학생을 분반에 등록 | profile_id, division_id | ○ |
| EN-03 | 삭제 | 수강 취소 | profile_id, division_id 또는 enrollment id | ○ |

---

### 3.11 시간표 (timetable_entries) — 선택

| 기능 ID | 기능명 | 설명 | 입력/조건 | 비고 |
|--------|--------|------|-----------|------|
| TT-01 | 목록 조회 | user_id별 요일·교시별 시간표 | user_id, day_of_week, period, subject, room, teacher | ○ |
| TT-02 | 수정 | 특정 사용자 시간표 셀 수정 | user_id, day_of_week, period, subject, room, teacher | ○ |

---

### 3.12 개인 일정 (personal_events) — 선택

| 기능 ID | 기능명 | 설명 | 입력/조건 | 비고 |
|--------|--------|------|-----------|------|
| PE-01 | 목록 조회 | user_id별 개인 일정 | user_id, title, start_at, end_at, all_day, color | ○ |
| PE-02 | 추가/수정/삭제 | 개인 일정 CRUD | 관리 목적 시에만 구현 | ○ |

---

## 4. 비기능 요구사항

| 구분 | 항목 | 내용 |
|------|------|------|
| 보안 | 접근 제어 | 모든 백오피스 라우트에서 인증 + role(admin/council) 검사 |
| 보안 | RLS | Supabase RLS로 admin/council만 해당 테이블 접근 허용, 또는 Edge Function으로 제한된 작업만 허용 |
| 보안 | 키 관리 | service_role 키는 서버/환경변수만, 클라이언트에는 anon 키 + JWT |
| UI | 반응형 | 데스크톱(1280px+), 태블릿(768px~1279px) 지원 |
| UI | 색상 | 화이트·블루 유지(LAON 브랜드), 삭제 등 위험 작업은 빨간 계열 |
| UI | 로딩/에러 | 로딩 표시, 에러 시 메시지 + 재시도 가능 |
| 데이터 | 삭제 | FK 있는 테이블은 삭제 순서 고려(예: poll_votes → polls, schedule_items 등) |
| 데이터 | 유효성 | 필수 필드·형식(날짜, enum 등) 검사 후 저장 |

---

## 5. 구현 우선순위 제안

| 단계 | 포함 기능 | 목표 |
|------|-----------|------|
| Phase 1 | SYS-01~06, P-01~04, SC-01~04, SG-01~03, AN-01~04, BR-01~03 | 로그인·대시보드·프로필/일정/건의/공지/버그신고 |
| Phase 2 | PV-01~04, CH-01~05(또는 CH-06) | 투표·채팅방·멤버 |
| Phase 3 | SB-01~02, SD-01~02, AS-01~04, EN-01~03 | 과목·분반·과제·수강 |
| Phase 4 | TT-01~02, PE-01~02(선택), 테스트·배포 | 시간표·개인일정·안정화 |

---

## 6. 화면–기능 매핑 (참고)

| 화면(메뉴) | 기능 ID |
|------------|---------|
| 로그인 | SYS-01 |
| 대시보드 | SYS-05, SYS-06 |
| 프로필 관리 | P-01 ~ P-04 |
| 일정 관리 | SC-01 ~ SC-04 |
| 건의함 관리 | SG-01 ~ SG-03 |
| 공지 관리 | AN-01 ~ AN-04 |
| 투표 관리 | PV-01 ~ PV-04 |
| 버그 신고 | BR-01 ~ BR-03 |
| 채팅방 관리 | CH-01 ~ CH-06 |
| 과목/분반 | SB-01~02, SD-01~02 |
| 과제 관리 | AS-01 ~ AS-04 |
| 수강 관리 | EN-01 ~ EN-03 |
| 시간표(선택) | TT-01 ~ TT-02 |
