import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Figma 원본 LAON 아이콘을 100% 재현하는 위젯.
///
/// `flutter_svg`는 SVG `<filter>` (드롭 셰도우, 블러 등)를 렌더링하지 못하므로,
/// SVG 경로는 [SvgPicture]로 렌더링하고, Figma 원본의 드롭 셰도우는
/// Flutter 네이티브 [CustomPainter]로 정확히 재현한다.
///
/// Figma 원본 필터 사양 (filter0_d_736_5198):
/// - 대상: 가장 진한 파란 점 (#0B66FF)
/// - 효과: drop-shadow, offset 없음
/// - feGaussianBlur stdDeviation=5 (블러 반경 10px)
/// - 색상: rgba(11, 102, 255, 0.25)
///
/// 180도 회전 후 해당 점의 상대 위치: (23.6%, 76.8%).
class LaonIcon extends StatelessWidget {
  const LaonIcon({
    super.key,
    required this.size,
  });

  /// 아이콘의 논리적 너비. 높이는 원본 비율(~1.019)에 따라 자동 산출.
  final double size;

  /// 원본 viewBox 비율: height / width = 91.8193 / 90.1205
  static const _aspectRatio = 91.8193 / 90.1205;

  /// 180도 회전 후 가장 진한 점의 상대 중심 좌표.
  /// 원본 중심 (68.82, 21.29) → 회전 후 (21.30, 70.53).
  static const _glowCenterX = 21.30 / 90.1205; // ≈ 0.236
  static const _glowCenterY = 70.53 / 91.8193; // ≈ 0.768

  /// 점의 반지름 비율 (원본 반지름 ~11.29 / viewBox 폭).
  static const _dotRadiusRatio = 11.29 / 90.1205; // ≈ 0.125

  /// Figma 필터의 Gaussian blur stdDeviation (5) → 블러 시그마.
  static const _blurSigma = 5.0;

  /// Figma 필터의 셰도우 색상: rgba(11, 102, 255, 0.25).
  static const _shadowColor = Color(0x400B66FF);

  @override
  Widget build(BuildContext context) {
    final height = size * _aspectRatio;

    return SizedBox(
      width: size,
      height: height,
      child: CustomPaint(
        painter: _GlowPainter(
          centerX: _glowCenterX,
          centerY: _glowCenterY,
          dotRadius: _dotRadiusRatio,
          blurSigma: _blurSigma,
          shadowColor: _shadowColor,
        ),
        child: SvgPicture.asset(
          'assets/images/laon_icon.svg',
          width: size,
          height: height,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}

/// 가장 진한 파란 점 뒤에 블러 글로우를 그리는 페인터.
///
/// Figma의 `feGaussianBlur` + `feColorMatrix` 드롭 셰도우를
/// Flutter의 [MaskFilter.blur]로 정밀하게 재현한다.
class _GlowPainter extends CustomPainter {
  const _GlowPainter({
    required this.centerX,
    required this.centerY,
    required this.dotRadius,
    required this.blurSigma,
    required this.shadowColor,
  });

  final double centerX;
  final double centerY;
  final double dotRadius;
  final double blurSigma;
  final Color shadowColor;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width * centerX;
    final cy = size.height * centerY;
    final radius = size.width * dotRadius;

    final paint = Paint()
      ..color = shadowColor
      ..maskFilter = MaskFilter.blur(
        ui.BlurStyle.normal,
        blurSigma,
      );

    canvas.drawCircle(Offset(cx, cy), radius, paint);
  }

  @override
  bool shouldRepaint(covariant _GlowPainter oldDelegate) => false;
}
