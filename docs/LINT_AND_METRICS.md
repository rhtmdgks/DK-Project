# Lint 및 메트릭스

## analysis_options.yaml

- **avoid_print**: `print` 대신 `lib/core/utils/app_logger.dart` (logInfo, logWarn, logError) 사용.
- **prefer_final_locals**, **prefer_final_in_overrides**: 불변성 권장.
- `package:flutter_lints/flutter.yaml` 기반 권장 규칙 유지.

## 메트릭스 우선순위 (수동/도구)

아키텍처·품질 논문에서 효과가 큰 스멜 위주로 관리:

- **Large Class / Long Method**: 파일·클래스·메서드 길이 관리 (예: 파일 300줄 이하, 메서드 50줄 이하 목표).
- **복잡도**: 과도한 분기/중첩 줄이기.
- **의존성 사이클**: 레이어(UI → ViewModel → Repository → Infra) 방향 준수.

선택 사항: `dart_code_metrics` 패키지로 클래스/함수 길이·복잡도·중복 수치화 후 CI에서 경고.

## Healthy carrier

정적 분석 경고 중 상당수는 아키텍처 스멜과 무관할 수 있음.  
프로젝트 성격에 맞지 않는 규칙은 `// ignore: rule_name` 또는 analysis_options에서 예외 처리.
