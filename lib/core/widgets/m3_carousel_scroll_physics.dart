import 'package:flutter/material.dart';
import 'package:myapp/core/theme/app_motion.dart';

/// M3 Carousel용 스크롤 물리: [AppMotion] duration · curve 기반 스냅 전환.
///
/// Dynamic Motion Physics System, Easing and duration, Transitions 반영.
/// 부모 시뮬레이션의 목표 지점을 유지하면서, 전환만 M3 토큰으로 재적용한다.
class M3CarouselScrollPhysics extends ScrollPhysics {
  const M3CarouselScrollPhysics({super.parent});

  @override
  M3CarouselScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return M3CarouselScrollPhysics(parent: buildParent(ancestor));
  }

  /// 부모 시뮬레이션을 끝까지 진행해 목표 오프셋을 구한다.
  static double _targetOffset(Simulation sim) {
    const double step = 0.016;
    double t = 0;
    while (!sim.isDone(t)) {
      t += step;
      if (t > 30) break;
    }
    return sim.x(t);
  }

  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) {
    final Simulation? parentSim = parent?.createBallisticSimulation(position, velocity);
    if (parentSim == null) return null;

    final double start = position.pixels;
    final double end = _targetOffset(parentSim);
    final double durationSec = AppMotion.effectDuration.inMilliseconds / 1000.0;

    return _CurveDrivenScrollSimulation(
      start: start,
      end: end,
      durationSeconds: durationSec,
      curve: AppMotion.effectCurve,
      tolerance: toleranceFor(position),
    );
  }
}

/// [Curve]와 고정 duration으로 위치를 보간하는 스크롤 시뮬레이션.
class _CurveDrivenScrollSimulation extends Simulation {
  _CurveDrivenScrollSimulation({
    required this.start,
    required this.end,
    required this.durationSeconds,
    required this.curve,
    required Tolerance tolerance,
  }) : _tolerance = tolerance;

  final double start;
  final double end;
  final double durationSeconds;
  final Curve curve;
  final Tolerance _tolerance;

  double _x(double t) {
    if (t >= durationSeconds) return end;
    final tNorm = t / durationSeconds;
    return start + (end - start) * curve.transform(tNorm.clamp(0.0, 1.0));
  }

  @override
  double x(double t) => _x(t);

  @override
  double dx(double t) {
    if (t >= durationSeconds) return 0;
    const dt = 0.016;
    return (_x(t + dt) - _x(t)) / dt;
  }

  @override
  bool isDone(double t) => t >= durationSeconds;

  @override
  Tolerance get tolerance => _tolerance;
}

/// Carousel 전용 [ScrollBehavior]: [M3CarouselScrollPhysics] 적용.
class M3CarouselScrollBehavior extends ScrollBehavior {
  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const M3CarouselScrollPhysics();
  }
}
