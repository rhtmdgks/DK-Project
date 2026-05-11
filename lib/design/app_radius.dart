/// LAON 디자인 시스템 — 코너 반경 (iOS 스타일 카드·필드와 일치).
abstract final class AppRadius {
  AppRadius._();

  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;

  /// 유틸리티 카드·큰 패널 (기존 Apple HIG 18pt 근사와 호환).
  static const double utilityCard = 18;
}
