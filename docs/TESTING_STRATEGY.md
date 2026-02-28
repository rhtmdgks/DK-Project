# 테스트 전략

리팩터링 안전망으로, 다음 우선순위로 테스트를 확장한다.

## 1. 단위 테스트 우선 대상

- **AuthRepository** (`lib/core/auth/auth_repository.dart`)
  - `getUserId`, `isLoggedIn`, `setLoggedIn`, `logout`, `clearLoginState`
  - Supabase·SharedPreferences는 mock/stub
- **NotificationSettingsRepository** (`lib/repositories/notification_settings_repository.dart`)
  - `getXEnabled` / `setXEnabled` (meal, schedule, class_move, notice, weather)
  - SharedPreferences mock
- **ScheduleRepository** (`lib/repositories/schedule_repository.dart`)
  - `fetchScheduleItems`, `fetchPersonalEvents`, `addPersonalEvent`, `deletePersonalEvent`
  - Supabase mock
- **SuggestionsRepository**, **ChatRepository**, **AnnouncementRepository**
  - 공개 메서드별 성공/실패 시나리오, Supabase mock

## 2. 위젯/통합 테스트 우선 대상

- **LoginScreen**: 정상 로그인 플로우, 비밀번호 변경 리다이렉트, 실패 시 에러 메시지 표시
- **NoticePollTab** (또는 NoticePollViewModel): 공지·투표 목록 로딩, 투표 참여 후 갱신
- **ScheduleTab**: 일정 추가/삭제 후 리스트 갱신, NEIS 실패 시 에러 UI
- **SuggestionsTab**: 건의 등록, 댓글, 권한 에러 처리
- **ChatScreen**: 메시지 로딩, 새 메시지 전송 UI 반응

## 3. 리팩터링 방식

- 큰 변경 전 해당 Repository/Service/화면에 대한 **최소한의 테스트**를 먼저 작성
- **한 번에 한 단계**: Supabase 호출만 Repository로 이동 → ViewModel 분리 → 파일 분할
- 각 단계마다 `flutter test` 통과 후 다음 단계 진행

## 4. 실행

```bash
flutter test
```

신규 테스트 파일은 `test/` 아래에 `*_test.dart` 패턴으로 추가한다.
