/// `.cursor/rules/Design-System-inspired-by-Apple.mdc`에서 발췌한 라운드 토큰.
///
/// 색상은 [AppColors]를 그대로 사용하므로 이 파일은 Apple HIG 패턴 적용에 필요한
/// 반경(rounded) 값만 노출한다.
abstract final class AppleShape {
  /// `{rounded.lg}` — 스토어 유틸리티 카드/액세서리 그리드 카드.
  static const double radiusUtilityCard = 18;

  /// `{rounded.sm}` — 컴팩트 유틸리티 컨트롤(다크 유틸리티 버튼, 인라인 카드 이미지).
  static const double radiusSmHairline = 8;
}
