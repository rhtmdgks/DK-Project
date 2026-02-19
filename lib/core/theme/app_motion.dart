import 'package:flutter/material.dart';

/// Material 3 Motion System 토큰.
///
/// Easing & Duration 스펙:
/// https://m3.material.io/styles/motion/easing-and-duration
/// 페이지 전환, 오버레이, 효과(페이드/스케일) 등 전역 일관된 모션 적용.
abstract final class AppMotion {
  AppMotion._();

  // ── Duration (milliseconds) ──
  /// 매우 짧은 피드백 (예: 터치 리플, 작은 토글)
  static const Duration durationShort1 = Duration(milliseconds: 75);
  /// 짧은 전환 (예: 아이콘 상태 변경, 작은 오버레이)
  static const Duration durationShort2 = Duration(milliseconds: 150);
  /// 중간 전환 1 (예: 스크롤 스냅, 다이얼로그 진입)
  static const Duration durationMedium1 = Duration(milliseconds: 200);
  /// 중간 전환 2 (예: 사이드 시트, 드로어)
  static const Duration durationMedium2 = Duration(milliseconds: 250);
  /// 긴 전환 1 (예: 전체 화면 전환)
  static const Duration durationLong1 = Duration(milliseconds: 300);
  /// 긴 전환 2 (예: 컨테이너 변형, 강조 전환)
  static const Duration durationLong2 = Duration(milliseconds: 350);

  // ── Easing (Curve) ──
  /// Standard: 대부분의 전환. 빠르게 가속 후 천천히 감속.
  /// cubic-bezier(0.4, 0, 0.2, 1)
  static const Curve curveStandard = Cubic(0.4, 0, 0.2, 1);
  /// Decelerated: 진입 시 자연스럽게 감속. 화면 진입, 요소 등장.
  /// cubic-bezier(0, 0, 0.2, 1)
  static const Curve curveDecelerated = Cubic(0, 0, 0.2, 1);
  /// Accelerated: 퇴장 시 가속. 화면 퇴장, 요소 제거.
  /// cubic-bezier(0.4, 0, 1, 1)
  static const Curve curveAccelerated = Cubic(0.4, 0, 1, 1);
  /// Emphasized: 강조된 진입(약간의 오버슈트 느낌). 스플래시, 강조 요소.
  /// Material path 근사 → Flutter Cubic.
  static const Curve curveEmphasized = Cubic(0.2, 0, 0, 1);
  /// Linear: 균일 속도. 진행 표시 등.
  static const Curve curveLinear = Curves.linear;

  // ── Semantic: 용도별 조합 ──
  /// 페이지/화면 전환 (Shared axis, Fade through)
  static const Duration pageTransitionDuration = durationLong1;
  static const Curve pageTransitionCurve = curveStandard;
  /// 오버레이(다이얼로그, 시트) 진입/퇴장
  static const Duration overlayDuration = durationMedium2;
  static const Curve overlayEnterCurve = curveDecelerated;
  static const Curve overlayExitCurve = curveAccelerated;
  /// 스플래시·강조 애니메이션
  static const Duration emphasisDuration = durationLong2;
  static const Curve emphasisCurve = curveEmphasized;
  /// 스크롤·작은 효과
  static const Duration effectDuration = durationMedium1;
  static const Curve effectCurve = curveDecelerated;

  /// AnimatedContainer, TweenAnimationBuilder 등 암시적 애니메이션에 사용 권장.
  static const Duration implicitDuration = durationMedium1;
  static const Curve implicitCurve = curveStandard;
}
