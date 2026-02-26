# 알림 시스템 구현 가이드

## 개요

LAON 앱의 알림 시스템은 다음과 같은 기능을 제공합니다:
- 실시간 푸시 알림 (flutter_local_notifications)
- 앱 내 알림 목록 관리
- 읽음/안읽음 상태 관리
- 알림 배지 표시 (빨간색 점)
- 알림 탭 시 해당 화면으로 이동

## 알림 타입별 동작

### 1. 날씨 알림 ☀️
- **트리거**: 매일 오전 6시 30분 정확히
- **내용**: 현재 위치의 날씨 정보
- **특징**: 
  - `matchDateTimeComponents.time` 사용으로 매일 반복
  - 앱이 6:30 이후에 열리면 아직 오늘 알림을 안 띄웠을 때 자동 표시
  - 위치 정보 저장 필요

### 2. 공지사항 알림 📢
- **트리거**: 새 공지사항이 Supabase에 INSERT될 때 즉시
- **내용**: 공지사항 제목 및 내용
- **특징**:
  - Supabase Realtime 구독으로 실시간 감지
  - 학년/반 필터링 지원
  - 앱이 실행 중이지 않아도 알림 수신

### 3. 일정 알림 📅
- **트리거**: 
  - 매일 아침 8시에 오늘 일정 요약
  - 새 일정이 추가되면 즉시 (오늘 일정인 경우만)
- **내용**: 오늘의 일정 목록
- **특징**:
  - Supabase Realtime으로 일정 변경 감지
  - 여러 일정이 있으면 "외 N개" 형식으로 표시

### 4. 급식 출발 알림 🍽️
- **트리거**: 설정된 시간 (점심 12시, 저녁 18시 전)
- **내용**: 급식 출발 안내
- **특징**: 예약된 시간에 자동 알림

### 5. 이동 수업 알림 🚶
- **트리거**: 수업 시작 5분 전
- **내용**: 이동할 교실 정보
- **특징**: 시간표 기반 자동 계산

## 주요 특징

### 1. 정확한 시간 알림
- **날씨 알림**: 매일 오전 6시 30분 정확히
  - `matchDateTimeComponents.time` 사용으로 매일 자동 반복
  - Android 12+ 정확한 알람 권한 자동 처리
  - 권한이 없으면 inexact 모드로 폴백

### 2. 실시간 알림
- **공지사항**: Supabase Realtime으로 즉시 알림
- **일정**: 새 일정 추가 시 즉시 알림 (오늘 일정인 경우)

### 3. 앱 생명주기 관리
- 앱이 포그라운드로 돌아올 때 자동으로 놓친 알림 확인
- 백그라운드에서도 예약된 알림 정상 작동

### 4. 시각적 피드백
- 읽지 않은 알림이 있을 때 알림 아이콘에 빨간색 점 표시
- 알림 사이드 시트에서 읽지 않은 알림 개수 표시
- 읽지 않은 알림은 배경색으로 구분

### 1. 모델 (lib/models/notification_item.dart)
```dart
NotificationItem - 알림 아이템 데이터 모델
NotificationType - 알림 타입 (weather, announcement, meal, schedule, classMove, other)
```

### 2. 프로바이더 (lib/providers/notification_provider.dart)
```dart
NotificationProvider - 알림 목록 상태 관리
- notifications: 알림 목록
- unreadCount: 읽지 않은 알림 개수
- addNotification(): 새 알림 추가
- markAsRead(): 알림 읽음 처리
- markAllAsRead(): 모든 알림 읽음 처리
- deleteNotification(): 알림 삭제
- clearAll(): 모든 알림 삭제
```

### 3. 통합 알림 서비스 (lib/services/notification_service.dart)
```dart
NotificationService - 모든 알림 서비스를 통합 관리
- initialize(): 알림 시스템 초기화
- showNotification(): 알림 표시 (로컬 알림 + 앱 내 목록)
```

### 4. 개별 알림 서비스
- `announcement_notification_service.dart` - 공지사항 알림
- `weather_notification_service.dart` - 날씨 알림
- `meal_notification_service.dart` - 급식 알림
- `schedule_notification_service.dart` - 일정 알림
- `class_move_notification_service.dart` - 이동 수업 알림

### 5. UI 컴포넌트
- `notification_side_sheet.dart` - 알림 사이드 시트
- `home_tab.dart` - 알림 배지 표시

## 사용 방법

### 1. 패키지 설치
```bash
flutter pub get
```

필요한 패키지:
- `provider: ^6.1.1` - 상태 관리
- `intl: ^0.19.0` - 날짜/시간 포맷팅
- `flutter_local_notifications: ^17.0.0` - 로컬 알림
- `shared_preferences: ^2.2.2` - 로컬 저장소

### 2. 앱 초기화 (이미 완료됨)
`lib/app.dart`에서 NotificationProvider와 NotificationService가 자동으로 초기화됩니다.

### 3. 알림 표시하기

#### 방법 1: NotificationService 사용 (권장)
```dart
import 'package:myapp/models/notification_item.dart';
import 'package:myapp/services/notification_service.dart';

await NotificationService.showNotification(
  id: 1001,
  title: '알림 제목',
  body: '알림 내용',
  type: NotificationType.announcement,
  payload: 'announcement', // 선택사항: 알림 탭 시 전달될 데이터
);
```

#### 방법 2: Provider 직접 사용
```dart
import 'package:myapp/models/notification_item.dart';
import 'package:myapp/providers/notification_provider.dart';
import 'package:provider/provider.dart';

final provider = context.read<NotificationProvider>();
await provider.addNotification(
  NotificationItem(
    id: 'unique_id',
    type: NotificationType.schedule,
    title: '일정 알림',
    body: '내일 수학 시험이 있습니다',
    timestamp: DateTime.now(),
  ),
);
```

### 4. 알림 목록 표시
알림 아이콘을 탭하면 자동으로 `showNotificationSideSheet(context)`가 호출되어 알림 목록이 표시됩니다.

### 5. 알림 배지
홈 화면의 알림 아이콘에 읽지 않은 알림 개수가 자동으로 표시됩니다.

## 테스트

샘플 알림을 생성하려면:

```dart
import 'package:myapp/utils/notification_test_helper.dart';

// 5개의 샘플 알림 생성
await NotificationTestHelper.createSampleNotifications();
```

## 알림 타입별 사용 예시

### 공지사항 알림
```dart
await NotificationService.showNotification(
  id: 2001,
  title: '새 공지사항',
  body: '2026학년도 1학기 수강신청 안내',
  type: NotificationType.announcement,
  payload: 'announcement',
);
```

### 날씨 알림
```dart
await NotificationService.showNotification(
  id: 1001,
  title: '오늘의 날씨',
  body: '맑음, 최고 기온 15°C',
  type: NotificationType.weather,
  payload: 'weather',
);
```

### 급식 알림
```dart
await NotificationService.showNotification(
  id: 3001,
  title: '급식 출발 알림',
  body: '점심 급식이 12시에 출발합니다',
  type: NotificationType.meal,
  payload: 'meal',
);
```

### 일정 알림
```dart
await NotificationService.showNotification(
  id: 5001,
  title: '일정 알림',
  body: '내일 09:00 수학 수행평가',
  type: NotificationType.schedule,
  payload: 'schedule',
);
```

### 이동 수업 알림
```dart
await NotificationService.showNotification(
  id: 6001,
  title: '이동 수업 알림',
  body: '5분 후 과학실로 이동하세요',
  type: NotificationType.classMove,
);
```

## 주의사항

1. **알림 권한**: Android 13+ 및 iOS에서는 알림 권한이 필요합니다. 앱 초기화 시 자동으로 권한을 요청합니다.

2. **알림 ID**: 각 알림 타입별로 고유한 ID 범위를 사용하세요:
   - 날씨: 1000-1999
   - 공지사항: 2000-2999
   - 급식: 3000-3999
   - 일정: 5000-5999
   - 이동 수업: 6000-6999

3. **저장 용량**: 최대 50개의 알림만 저장됩니다. 오래된 알림은 자동으로 삭제됩니다.

4. **실시간 업데이트**: NotificationProvider는 ChangeNotifier를 사용하므로 Consumer 또는 Provider.of를 통해 자동으로 UI가 업데이트됩니다.

## 기존 알림 서비스 연동

기존 알림 서비스들은 이미 NotificationService와 연동되어 있습니다:
- ✅ AnnouncementNotificationService
- ⏳ WeatherNotificationService (필요시 업데이트)
- ⏳ MealNotificationService (필요시 업데이트)
- ⏳ ScheduleNotificationService (필요시 업데이트)
- ⏳ ClassMoveNotificationService (필요시 업데이트)

다른 서비스들도 동일한 패턴으로 업데이트할 수 있습니다.
