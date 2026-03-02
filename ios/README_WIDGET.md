# iOS 급식 출발 알림 위젯 추가 방법

아이폰 홈 화면 위젯은 **Xcode에서 Widget Extension 타깃을 한 번 추가**해야 합니다.  
아래 순서대로 진행한 뒤, 위젯을 빌드하면 됩니다.

## 1. Xcode에서 위젯 타깃 추가

1. **Xcode**로 `ios/Runner.xcworkspace` 를 연다.
2. 메뉴에서 **File → New → Target** 을 선택한다.
3. **Widget Extension** 을 선택하고 **Next** 를 누른다.
4. 다음처럼 입력한다.
   - **Product Name**: `MealDepartureWidgetExtension`
   - **Team**: 본인 개발팀
   - **Include Configuration App Intent**: **체크 해제**
   - **Finish** 를 누른다.
5. "Activate 'MealDepartureWidgetExtension' scheme?" 라고 나오면 **Cancel** 을 누른다 (Runner 스킴 유지).

## 2. 생성된 파일을 우리 쪽으로 교체

Xcode가 위젯용 Swift/Info 파일을 새로 만들었을 수 있으므로, 아래 파일들을 **프로젝트에 이미 만들어 둔 내용으로 교체**한다.

- **MealDepartureWidget** 폴더 안의 **Swift 파일**:  
  내용을 `ios/MealDepartureWidget/MealDepartureWidget.swift` 와 동일하게 맞춘다.  
  (또는 Xcode에서 해당 그룹의 Swift 파일을 지우고, `ios/MealDepartureWidget/MealDepartureWidget.swift` 를 오른쪽 클릭 → **Add Files to "Runner"** 로 추가한다.)
- **MealDepartureWidget** 폴더 안의 **Info.plist**:  
  `ios/MealDepartureWidget/Info.plist` 내용으로 교체한다.
- **MealDepartureWidgetExtension.entitlements** (프로젝트 루트에 있음):  
  `ios/MealDepartureWidgetExtension.entitlements` 내용으로 교체한다.

위젯 타깃의 **Build Phases → Compile Sources** 에 `MealDepartureWidget.swift` 가 포함되어 있는지 확인한다.

## 3. URL 스킴 (이미 적용됨)

`Runner/Info.plist` 에 `laon` URL 스킴이 이미 추가되어 있으면, 위젯 탭 시 앱이 `laon://meal-departure-alert` 로 열린다.  
없다면 CFBundleURLTypes 에 `laon` 스킴을 추가해 준다.

## 4. 빌드 및 실행

1. 스킴을 **Runner** 로 선택한 뒤 **Run** 으로 앱을 빌드/실행한다.
2. 시뮬레이터 또는 실제 기기에서 **홈 화면 길게 누르기 → 좌상단 + → LAON 앱** 에서 위젯을 추가한다. (급식 출발 알림, 이번 시간 남은 시간, 오늘의 시간표, 급식 출발 카운트다운 4종)
3. 위젯을 탭하면 앱이 실행되며 급식 출발 알림 화면으로 이동해야 한다.

## 참고

- 위젯 확장 타깃 이름이 `MealDepartureWidgetExtension` 이 아니어도 되지만, 그럴 경우 entitlements·폴더 이름을 맞춰 주는 것이 좋다.
- 나중에 Flutter에서 위젯 데이터를 갱신하려면 **App Group** 을 설정하고, Runner와 위젯 확장 모두에 같은 그룹을 추가한 뒤 `HomeWidget.setAppGroupId('group.xxx')` 를 호출해야 한다.
