# iOS App Store 출시 가이드

LAON 앱을 App Store에 올리기 위한 준비 사항과 절차입니다.

## 현재 프로젝트 설정 요약

| 항목 | 값 |
|------|-----|
| 앱 이름 (표시) | LAON |
| Bundle ID | `com.wearegoodwill.laon` |
| 위젯 Bundle ID | `com.wearegoodwill.laon.MealDepartureWidgetExtension` |
| 버전 (pubspec.yaml) | 예: `1.0.2+5` → CFBundleShortVersionString **1.0.2**, CFBundleVersion **5** |
| iOS 최소 버전 | 14.0 |
| 개발팀 (Xcode) | G62875F3M4 |

---

## 1. 사전 준비 (Apple 개발자 계정·인증서)

### 1.1 Apple Developer Program 가입

- [Apple Developer](https://developer.apple.com) 에서 **Apple Developer Program** 가입 (유료, 연회비 적용).
- 가입 후 **App Store Connect** 접속 가능해짐.

### 1.2 Xcode에서 팀·서명 설정 확인

1. **Xcode**로 `ios/Runner.xcworkspace` 를 연다.
2. 왼쪽에서 **Runner** 프로젝트 선택 → **Signing & Capabilities** 탭.
3. **Team** 이 본인/조직 팀으로 되어 있는지 확인 (현재: G62875F3M4).
4. **Automatically manage signing** 이 켜져 있으면 인증서·프로비저닝 프로필을 자동 생성/갱신함.
5. **MealDepartureWidgetExtension** 타깃도 동일하게 Team·서명 확인.

### 1.3 App Store Connect에 앱 등록 (최초 1회)

1. [App Store Connect](https://appstoreconnect.apple.com) 로그인.
2. **앱** → **+** → **새로운 앱**.
3. 플랫폼 **iOS**, 앱 이름 **LAON**, 기본 언어, Bundle ID **com.wearegoodwill.laon** 선택 후 생성.
4. 나중에 필요한 **개인정보 처리방침 URL** 은 `docs/privacy_policy.md` 기반으로 웹에 올린 URL을 넣으면 됨.

---

## 2. 출시 전 체크리스트

### 2.1 버전·빌드 번호

- `pubspec.yaml` 의 `version` 을 배포할 값으로 수정.

  ```yaml
  version: 1.0.0+2   # 1.0.0 = 사용자에게 보이는 버전, 2 = 빌드 번호 (제출 시마다 증가)
  ```

- **같은 버전(1.0.0)으로 재제출할 때는 빌드 번호만 반드시 이전보다 크게** 올려야 함 (예: 2 → 3).

- **Xcode로만 아카이브할 때 필수:** `ios/Flutter/Generated.xcconfig` 는 `.gitignore` 로 저장소에 없고, **`pubspec.yaml` 의 버전은 `flutter build ios --config-only`**(또는 `flutter build ipa`) 실행 시에만 반영된다. 이걸 생략하면 **이전 버전(예: 1.0.1)으로 IPA가 만들어져** App Store Connect에서 `CFBundleShortVersionString` 오류(90062)·트레인 오류(90186)가 난다. **항상 프로젝트 루트에서 아래를 먼저 실행한 뒤** Xcode → Product → Archive 한다.

  ```bash
  cd /path/to/DK-Project && flutter pub get && flutter build ios --config-only
  ```

### 2.2 아이콘·스플래시

- **Assets.xcassets → AppIcon** 에 필요한 모든 크기의 앱 아이콘이 있는지 확인 (Xcode에서 비어 있으면 경고됨).
- LaunchScreen / 스플래시가 의도대로 보이는지 시뮬레이터·실기기에서 확인.

### 2.3 권한 문구 (이미 설정됨)

- `ios/Runner/Info.plist` 에 다음 사용 목적 설명이 있음:
  - 카메라: 버그 신고 시 사진 촬영
  - 위치: 날씨 알림
  - 사진 라이브러리: 버그 신고 시 스크린샷 첨부

### 2.4 기타

- **GoogleService-Info.plist** 가 프로젝트에 포함되어 있고, Firebase 프로젝트가 프로덕션용으로 설정되어 있는지 확인.
- 위젯 확장(MealDepartureWidgetExtension)이 Runner와 같은 Team·서명으로 빌드되는지 확인.

---

## 3. 아카이브 및 IPA 생성 (Xcode)

### 3.1 Release 빌드로 아카이브

1. Xcode에서 스킴 **Runner** 선택.
2. 대상 기기를 **Any iOS Device (arm64)** 로 선택 (시뮬레이터 선택 시 아카이브 비활성화됨).
3. 메뉴 **Product** → **Archive**.
4. 빌드가 끝나면 **Organizer** 창이 열림.

### 3.2 App Store에 업로드

1. Organizer에서 방금 만든 아카이브 선택 후 **Distribute App**.
2. **App Store Connect** → **Upload** 선택 후 Next.
3. 옵션: **Upload your app’s symbols** (크래시 리포트용) 권장. 프로젝트에 **Generate dSYM for embedded frameworks** Run Script가 있어 `objective_c.framework`·Flutter.framework 등 임베디드 프레임워크 dSYM을 자동 생성하므로, 심볼 업로드를 켜도 됨. (이전에 "Upload Symbols Failed"가 났다면 이 스크립트가 해결함.)
4. 서명은 **Automatically manage signing** 사용 중이면 **Automatically sign** 선택 후 Next.
5. 업로드 완료 후 **Done**.

### 3.3 (대안) 터미널에서 빌드만 하고 업로드는 Xcode에서

IPA까지 로컬에서 만들고 싶다면:

```bash
# 프로젝트 루트에서
flutter clean
flutter pub get
flutter build ios --release
```

이후 **Xcode**에서 `ios/Runner.xcworkspace` 를 열고, **Product → Archive** 로 아카이브한 뒤 위 3.2와 같이 **Distribute App** 으로 업로드하면 됨.

### 3.4 Symbol(dSYM) 업로드 오류가 났을 때

- **"The archive did not include a dSYM for the objective_c.framework..."** 같은 오류가 나면, Runner 타깃에 **Generate dSYM for embedded frameworks** Run Script가 있는지 확인하세요. 이 스크립트는 Release 빌드 시 앱에 포함된 모든 `.framework`에 대해 dSYM을 생성해 아카이브에 넣습니다.
- 그래도 실패하면: Distribute App 단계에서 **Upload your app's symbols** 를 **체크 해제**하고 업로드하면 앱 제출은 가능합니다. (크래시 리포트에서 해당 프레임워크 스택만 덜 읽기 좋을 수 있음.)

---

## 4. App Store Connect에서 제출 절차

### 4.1 빌드 처리 대기

- 업로드한 빌드는 **처리 중** 상태가 되었다가 보통 5~30분 내에 **사용 가능**으로 바뀜.
- App Store Connect → 해당 앱 → **TestFlight** 또는 **앱 스토어** 탭에서 빌드가 나타나는지 확인.

### 4.2 버전 정보 입력

1. **앱 스토어** 탭 → **iOS 앱** → 새 버전(예: 1.0.0) 추가 또는 기존 버전 선택.
2. **빌드**에서 방금 업로드한 빌드를 선택.
3. **앱 미리보기 및 스크린샷** (필수):  
   - 6.7", 6.5", 5.5" 등 요구되는 기기별 스크린샷 업로드.  
   - 스크린샷 가이드는 `docs/graphic-prompts-for-release.md` 등 참고.
4. **프로모otional 텍스트**(선택), **설명**, **키워드**, **지원 URL**, **마케팅 URL**(선택) 입력.
5. **개인정보 처리방침 URL** 입력 (앱별로 설정한 URL).
6. **카테고리** (예: 교육), **연령 등급** 설정.
7. **가격 및 판매 가능 여부**: 무료인지 유료인지, 판매 국가 선택.

### 4.3 심사 제출

- **심사용 메모**에 로그인 테스트 계정이 필요하면 입력.
- **제출하여 검토** 버튼으로 제출.
- 심사는 보통 24~48시간 소요되며, 거절 시 해결 사항 수정 후 같은 버전에서 빌드만 올리거나 버전 정보 수정 후 재제출.

---

## 5. 제출 후·업데이트 시 할 일

| 할 일 | 설명 |
|--------|------|
| 빌드 번호 올리기 | 같은 버전 재제출 시 `pubspec.yaml` 의 `+N` 만 증가 (예: 1.0.0+3). |
| 버전명 올리기 | 새 마이너/메이저 배포 시 `version: 1.0.1+4` 처럼 변경. |
| TestFlight | 내부/외부 테스트용으로 동일 빌드를 TestFlight에 배포 가능. |

---

## 6. 요약: 당신이 할 절차

1. **Apple Developer Program** 가입 및 App Store Connect 접속 가능한지 확인.
2. **Xcode**에서 `ios/Runner.xcworkspace` 열고 **Signing & Capabilities** 로 Team·서명 확인 (Runner + MealDepartureWidgetExtension).
3. **App Store Connect**에서 앱 생성(최초 1회), Bundle ID `com.wearegoodwill.laon` 일치 확인.
4. **버전 확인**: `pubspec.yaml` 의 `version` (예: 1.0.0+2)을 배포할 값으로 수정.
5. **아이콘·스플래시** 확인 후 Xcode에서 **Product → Archive**.
6. **Distribute App** → App Store Connect 업로드.
7. App Store Connect에서 **빌드 선택**, **스크린샷·설명·개인정보처리방침·카테고리·가격** 입력 후 **제출하여 검토**.

문서 기준: Flutter iOS 빌드 + Xcode Archive + App Store Connect 제출 흐름.
