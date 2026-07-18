import 'package:flutter/animation.dart';

/// 앱 전역 모션 토큰 (Cupertino 슬라이드 전환 등).
abstract final class AppMotion {
  AppMotion._();

  static const Duration durationShort1 = Duration(milliseconds: 75);
  static const Duration durationShort2 = Duration(milliseconds: 150);
  static const Duration durationMedium1 = Duration(milliseconds: 200);
  static const Duration durationMedium2 = Duration(milliseconds: 250);
  static const Duration durationLong1 = Duration(milliseconds: 300);
  static const Duration durationLong2 = Duration(milliseconds: 350);

  static const Curve curveStandard = Cubic(0.4, 0, 0.2, 1);
  static const Curve curveDecelerated = Cubic(0, 0, 0.2, 1);
  static const Curve curveAccelerated = Cubic(0.4, 0, 1, 1);
  static const Curve curveEmphasized = Cubic(0.2, 0, 0, 1);

  static const Duration pageTransitionDuration = durationLong1;
  static const Curve pageTransitionCurve = curveEmphasized;

  /// 사이드 시트·토스트 등 오버레이
  static const Duration overlayDuration = durationMedium2;
  static const Curve overlayEnterCurve = curveDecelerated;
  static const Curve overlayExitCurve = curveAccelerated;

  /// 카드/캐러셀 등 마이크로 인터랙션
  static const Duration effectDuration = durationMedium1;
  static const Curve effectCurve = curveStandard;
}
