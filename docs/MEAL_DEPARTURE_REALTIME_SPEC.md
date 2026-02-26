# 실시간 급식 출발 알림 연동 명세 (Flutter 앱)

> **전체 백오피스–Flutter 연동 명세**: [BACKOFFICE_FLUTTER_INTEGRATION_SPEC.md](./BACKOFFICE_FLUTTER_INTEGRATION_SPEC.md) 참고.

## 개요

백오피스(웹)에서 **급식 출발 알림**을 보내면, 해당 학년·반 학생이 설치한 Flutter 앱에서 **실시간으로 푸시 알림**을 받을 수 있어야 합니다.  
알림 권한을 허용한 사용자에게만 기기 알림이 표시됩니다.

---

## 1. 백오피스(웹) 동작 요약

- **위치**: 대시보드 카드 + 사이드바 **「급식 출발 알림」** → `/meal-alert` 페이지
- **동작**: 관리자가 **학년(1~3)**·**반(1~10)** 선택 후 **「급식 출발 알림 전송」** 클릭
- **전송 방식**: **Supabase Realtime Broadcast** 사용
  - **채널 이름**: `meal-departure:{학년}:{반}`  
    예: 1학년 3반 → `meal-departure:1:3`
  - **이벤트 이름**: `meal-departure`
  - **페이로드** (JSON):
    ```json
    {
      "message": "급식 출발 알림",
      "body": "1학년 3반 급식이 출발했습니다.",
      "grade": 1,
      "class_number": 3,
      "at": "2026-02-23T12:00:00.000Z"
    }
    ```
- **특징**: WebSocket 기반이라 전송 즉시 구독 클라이언트에 전달됨 (지연 최소화)

---

## 2. Flutter 앱에서 구현할 내용

### 2.1 수신 대상

- **대상**: 로그인한 사용자의 **학년·반**이 알림 전송 시 선택된 학년·반과 일치하는 경우에만 수신
- **학년·반 정보**: `AppProfile`의 `grade`(또는 `gradeOrFromStudentId`), `classNum`(또는 `classNumOrFromStudentId`) 사용
  - DB 컬럼: `profiles.grade`, `profiles.class_num`
  - 학년/반이 없으면 학번(`student_id`) 5자리 규칙으로 추론 가능 (기존 `gradeOrFromStudentId`, `classNumOrFromStudentId` 활용)

### 2.2 Realtime 구독

- **채널 이름 규칙**: `meal-departure:{학년}:{반}`
  - 예: 1학년 3반 → `meal-departure:1:3`
- **구독 시점**: 로그인 후 프로필 로드가 끝난 뒤, 학년·반이 정해지면 해당 채널 1개 구독
- **이벤트**: `broadcast`, 이벤트 이름 `meal-departure`
- **Supabase Flutter (Dart)**:  
  `supabase.channel('meal-departure:$grade:$classNum').onBroadcast(event: 'meal-departure', callback: (payload) { ... }).subscribe()`
- **연결 유지**: 앱이 포그라운드/백그라운드에 있는 동안 구독을 유지해야 실시간 수신 가능 (연결 끊기면 알림 누락 가능)

### 2.3 수신 시 할 일

1. **브로드캐스트 수신** 시 페이로드에서 `message`, `body` (및 필요 시 `at`) 추출
2. **로컬 알림 표시**: `flutter_local_notifications` 등으로 **즉시** 로컬 알림 표시
   - 제목: `payload.message` (예: "급식 출발 알림")
   - 본문: `payload.body` (예: "1학년 3반 급식이 출발했습니다.")
   - 채널: 기존 **급식 출발 알림**용 채널(예: `meal_notification`) 재사용 권장
3. **알림 권한**: 앱 설치 후 설정 또는 첫 구독 전에 **알림 권한** 요청. 권한이 있을 때만 위 로컬 알림이 기기에 표시됨.

### 2.4 기존 코드와의 관계

- **`MealNotificationService`**: 현재는 **정해진 시간(점심/석식)** 스케줄 알림용. 그대로 두고,
- **실시간 급식 출발**은 **별도 서비스/헬퍼**로 구현 권장:
  - 예: `MealDepartureRealtimeService` (또는 기존 `MealNotificationService`에 실시간 수신 로직 추가)
  - 로그인/프로필 변경 시 구독 채널 갱신(학년·반 바뀌면 이전 채널 해제, 새 채널 구독)
  - 수신 콜백에서 `FlutterLocalNotificationsPlugin().show(...)` 호출로 로컬 알림 표시

### 2.5 알림 권한

- 학생이 **설정에서 알림 권한을 허용**한 경우에만 기기 알림이 뜨도록 구현
- 권한 요청 시점: 앱 최초 실행, 또는 설정 화면의 「급식 출발 알림」 ON 시점 등 정책에 맞게 선택

---

## 3. 데이터 형식 정리

| 항목 | 타입 | 설명 |
|------|------|------|
| `message` | string | 알림 제목 (예: "급식 출발 알림") |
| `body` | string | 알림 본문 (예: "1학년 3반 급식이 출발했습니다.") |
| `grade` | number | 대상 학년 (1, 2, 3) |
| `class_number` | number | 대상 반 (1~10) |
| `at` | string (ISO 8601) | 전송 시각 |

Flutter에서 수신 시 `message`를 제목, `body`를 본문으로 사용하면 됨.

---

## 4. 구현 체크리스트 (Flutter 에이전트용)

- [ ] 로그인 후 `AppProfile`에서 `grade`(또는 `gradeOrFromStudentId`), `classNum`(또는 `classNumOrFromStudentId`) 확보
- [ ] 학년·반이 있을 때만 `meal-departure:{grade}:{classNum}` 채널 구독
- [ ] `broadcast` 이벤트 `meal-departure` 수신 시 페이로드 파싱
- [ ] 수신 시 `flutter_local_notifications`로 로컬 알림 즉시 표시 (제목/본문 위 형식 사용)
- [ ] 알림 권한 요청 및 거부 시에도 앱은 동작하되, 알림만 표시하지 않도록 처리
- [ ] 로그아웃 또는 프로필 변경 시 기존 Realtime 채널 구독 해제
- [ ] (선택) 앱이 백그라운드일 때도 수신되도록 Realtime 연결 유지 정책 확인

---

## 5. 참고: 백오피스 전송 코드 위치

- **페이지**: `DK-Project_Backoffice`  
  - 대시보드: `components/dashboard/meal-alert-card.tsx` (알림 보내기 카드)  
  - 전송 페이지: `app/meal-alert/page.tsx`, `components/meal-alert/meal-alert-content.tsx`
- **채널 전송**: `meal-alert-content.tsx` 내 `channel.send({ type: 'broadcast', event: 'meal-departure', payload: { message, body, grade, class_number, at } })`

Flutter 앱은 **동일 Supabase 프로젝트**의 Realtime을 사용하며, 위와 **같은 채널 이름·이벤트·페이로드**로 수신하면 됩니다.

---

## 6. 휴대폰에 알림이 안 올 때 점검 (백오피스 vs Flutter)

| 구분 | 점검 항목 |
|------|-----------|
| **백오피스** | 학년·반 선택 후 전송 시 채널 `meal-departure:{학년}:{반}` 으로 브로드캐스트됨. 전송 완료 토스트가 뜨면 전송 자체는 정상. |
| **Flutter** | ① **설정 → 급식 출발 알림** 토글이 **ON** 인지 확인. ② 해당 사용자 **프로필(학년·반/학번)** 이 전송한 학년·반과 일치하는지 확인 (예: 1학년 2반 전송 시 학번 102XX). ③ **알림 권한**이 허용되어 있는지 (설정에서 알림 켤 때 권한 요청됨). ④ **로그인 후** 또는 **홈 화면 진입 시** 앱이 Realtime 채널을 구독함. 앱을 완전 종료했다가 다시 켜고 로그인한 뒤 한 번 홈까지 들어온 다음 테스트할 것. |

원인은 대부분 **Flutter 쪽**입니다. 백오피스는 동일 채널명·이벤트로 전송하면 되며, 구독자가 없어도 전송은 성공합니다. Flutter에서 해당 학년·반 채널을 구독하지 않으면(설정 OFF, 프로필 없음, 구독 시점 누락) 메시지를 받지 못합니다.

---

## 7. 앱이 꺼져 있을 때 알림 (FCM 푸시)

**현재 방식(Realtime)** 은 WebSocket 연결이 있어야 메시지를 받습니다. 앱을 **완전히 종료**하면 연결이 끊기므로 **알림이 가지 않습니다**.

**앱이 꺼진 상태에서도 알림**을 받으려면 **FCM(Firebase Cloud Messaging)** 푸시를 추가해야 합니다.

| 구분 | Realtime (현재) | FCM 푸시 (추가 시) |
|------|------------------|---------------------|
| 앱 켜져 있음 | ✅ 수신 가능 | ✅ 수신 가능 |
| 앱 백그라운드 | ⚠️ 연결 유지 시 수신 | ✅ 수신 가능 |
| 앱 완전 종료 | ❌ 수신 불가 | ✅ 수신 가능 |

### FCM 도입 시 필요한 작업 (요약)

1. **Firebase 프로젝트** 생성, Android(iOS) 앱 등록, `google-services.json`(Android) / `GoogleService-Info.plist`(iOS) 설정.
2. **Flutter**: `firebase_core`, `firebase_messaging` 추가 → FCM 토큰 발급 → 로그인 후 **Supabase 테이블**에 `(user_id, fcm_token, grade, class_number)` 저장 (급식 알림 ON인 사용자만).
3. **Supabase**:  
   - 테이블 예: `fcm_tokens (user_id, token, grade, class_number, updated_at)`.  
   - **Edge Function**: 백오피스 또는 Realtime 이벤트에 의해 호출되면, 해당 학년·반의 토큰 목록을 조회 후 **FCM HTTP v1 API**로 푸시 전송.
4. **백오피스**: 급식 출발 알림 전송 시 **Realtime 브로드캐스트**(기존 유지) + **Edge Function 호출**(학년, 반 전달)하여 FCM 푸시도 함께 보냄.

이렇게 하면 앱이 꺼져 있어도 OS가 FCM 푸시를 받아 알림을 표시합니다.
