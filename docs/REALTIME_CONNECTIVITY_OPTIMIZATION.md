# 앱-백오피스 실시간 연결성 진단/최적화 기준

## 1) 관측성 기준선 (Baseline Observability)

### 공통 로그 키
- 앱: `[RT][service] ...`
- 백오피스: `[RT][hook] status=...`

### 필수 관측 이벤트
- 구독 시작 (`subscribe`)
- 구독 상태 변경 (`status`)
- 이벤트 수신 카운트 (`event count`)
- 구독 해제 (`unsubscribe`)

### KPI
- 도달 지연: `emit_at -> local_notify_at` p95
- 누락률: `expected - received / expected`
- 중복률: `duplicate_events / received`
- 재구독 성공률: `rebind_success / rebind_attempt`

## 2) 세션 생명주기 매트릭스

| 시나리오 | 기대 동작 | 검증 포인트 |
|---|---|---|
| 앱 첫 실행 + 로그인 | 공지/건의/급식 채널 구독 | 각 서비스 `subscribe` 로그 |
| 로그아웃 | 모든 채널 해제 | `unsubscribe` 로그, 채널 핸들 null |
| 로그아웃 후 재로그인 | 채널 재바인딩 | `refreshSubscription` 호출 및 `status` |
| 프로필 변경(학년/반) | 급식 채널 재구독 | 채널명이 새 학년/반으로 바뀜 |
| 계정 전환(A -> B) | A의 채널 잔존 없음 | 건의 알림에서 sender/self 필터 정상 |

## 3) unread 의미 정합성

### 건의함
- 기존: `suggestions INSERT` 중심
- 통합 기준: 아래 중 하나라도 발생하면 unread
  - `suggestions INSERT`
  - `suggestion_comments INSERT`
  - 건의 전용 방 `chat_messages INSERT`

### 공지/일정
- `announcements INSERT` 또는 `schedule_items INSERT` 시 unread
- 타깃 필터(학년/반)와 앱 알림 필터 정책 일치 유지

## 4) DB Realtime 점검 체크리스트

배포 전/장애 대응 시 아래 SQL을 실행:

```sql
-- publication 대상 확인
SELECT * FROM pg_publication_tables WHERE pubname = 'supabase_realtime';

-- 정책 확인
SELECT schemaname, tablename, policyname, roles, cmd
FROM pg_policies
WHERE tablename IN (
  'announcements', 'schedule_items', 'chat_messages',
  'suggestions', 'suggestion_comments'
);

-- anon/authenticated RPC 실행 권한 확인
SELECT routine_name, grantee, privilege_type
FROM information_schema.routine_privileges
WHERE routine_schema = 'public'
  AND grantee IN ('anon', 'authenticated');
```

## 5) 우선순위 백로그 + Acceptance

### Quick Win
1. 세션 전환 시 알림 채널 재바인딩 표준화
2. 건의 unread 기준 통합(suggestions + comments + chat)
3. 실시간 로그 포맷 통일

### Structural
1. 경로별 지표 수집 자동화(도달지연, 누락률)
2. 배포 파이프라인에 DB 실시간 점검 SQL 포함
3. 제품 기준으로 unread 의미 문서화

### Acceptance Criteria
- 로그아웃 후 재로그인 시 공지/건의/급식 알림이 1분 내 정상 수신된다.
- 계정 전환 시 이전 계정 이벤트를 새 계정에서 수신하지 않는다.
- 건의 unread 배지가 댓글/건의 채팅 활동도 반영한다.
- 배포 점검 SQL 결과가 정책/복제 기준과 불일치가 없음을 보여준다.
