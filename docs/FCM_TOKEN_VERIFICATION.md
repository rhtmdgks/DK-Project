# FCM 토큰 등록 및 Android 확인 가이드

## 1. Flutter 앱에서 토큰 저장 흐름

- **위치**: `lib/services/fcm_token_service.dart`
- **토큰 발급**: `FirebaseMessaging.instance.getToken()` (iOS는 그 전에 `requestPermission()` 호출)
- **저장 경로**: Supabase 직접 저장이 아니라 **Edge Function `register-fcm-token`** 호출
  - URL: `{SUPABASE_URL}/functions/v1/register-fcm-token`
  - 헤더: `Authorization: Bearer <Supabase access token>` (로그인 세션 기반)
  - Body: `action`, `token`, `platform`(ios|android)
  - `user_id`, `grade`, `class_number`는 서버가 JWT 사용자 기준으로 계산/검증
- **호출 시점**: `MealDepartureRealtimeService.startListening()` → 급식 출발 알림 ON + 로그인 + 학년·반 있을 때 `FcmTokenService.registerIfNeeded()` 호출

## 2. Android에서 실행 여부 로그로 확인

Android 빌드 후 앱에서 **급식 출발 알림을 ON** 하고, 해당 학년·반이 설정된 계정으로 로그인하면 아래 로그가 나와야 합니다.

- `FcmTokenService: getToken success (platform=android)`
- `FcmTokenService: registerIfNeeded calling Edge Function (platform=android)`
- `FcmTokenService: register ok (platform=android)`

실패 시 예:

- `FcmTokenService: getToken failed ...`
- `FcmTokenService: register failed 401` (세션 만료/토큰 검증 실패)
- `FcmTokenService: register failed 4xx/5xx`

**확인 방법**: Android Studio / `adb logcat` 에서 `FcmTokenService` 또는 `flutter` 태그로 필터.

## 3. Supabase `fcm_tokens` 테이블

- **스키마**: `user_id`, `token`, `grade`, `class_number`, `created_at`, `updated_at`, `platform`(마이그레이션 031 적용 시)
- **platform**: Flutter에서 `ios` / `android` 로 보냄. Edge Function이 그대로 저장.

### Android 토큰 행 확인 (Supabase MCP 또는 Dashboard)

**마이그레이션 031 적용 후** Supabase SQL Editor 또는 MCP `execute_sql`로:

```sql
SELECT user_id, platform, grade, class_number, updated_at
FROM public.fcm_tokens
ORDER BY updated_at DESC;
```

- `platform = 'android'` 인 행이 있으면 Android 앱에서 토큰이 정상 등록된 것.

현재(마이그레이션 031 적용 전) DB에는 `platform` 컬럼이 없고, 적용 후 앱/Edge Function 배포를 하면 새로 등록되는 토큰부터 `platform` 이 채워집니다.

## 4. Edge Function 푸시 전송 위치

- **함수**: `send-meal-push` (Supabase Edge Function)
- **호출**: 백오피스 등에서 `grade`, `class_number`(및 선택 시 `message`, `body`)를 POST.
- **전송 대상 조회**:  
  `fcm_tokens` 테이블에서 `grade`, `class_number` 로 `SELECT token` → 해당 학년·반에 등록된 **모든 FCM 토큰**.
- **실제 전송**: FCM HTTP v1 API  
  `https://fcm.googleapis.com/v1/projects/{project_id}/messages:send`  
  각 `token`에 대해 한 번씩 요청 (notification + android channel `meal_notification`).
- **플랫폼 구분**: 현재 `send-meal-push`는 플랫폼별 필터 없이 해당 학년·반의 모든 토큰에 전송합니다. `platform` 컬럼은 통계/디버깅용으로만 사용 가능.

## 5. 적용 순서 요약

1. **Supabase**: 마이그레이션 `031_fcm_tokens_platform.sql` 적용 (`supabase db push` 또는 Dashboard SQL).
2. **Edge Function**: `register-fcm-token` 재배포 (platform 수신·저장 반영).
3. **Flutter**: 로그/플랫폼 전송 반영된 앱 빌드 후 Android에서 급식 출발 알림 ON → 로그 및 `fcm_tokens` 에 `platform='android'` 행 확인.
