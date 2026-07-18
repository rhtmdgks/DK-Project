import 'dart:math' as math;

import 'package:flutter/widgets.dart';

// ────────────────────────────────────────────────────────────
// 반응형 유틸리티
//
// 모든 하드코딩 수치를 화면 비율에 맞게 스케일링한다.
// Figma 기준 디자인 폭 375pt (iPhone SE~15 계열)를 레퍼런스로 사용.
//
// 지원 기기 범위:
//   compact  : < 600dp  (일반 폰, Galaxy Flip 접힌 상태)
//   medium   : 600-840dp (Galaxy Fold 펼친 상태, 소형 태블릿)
//   expanded : > 840dp  (iPad, 태블릿)
// ────────────────────────────────────────────────────────────

/// 기준 디자인 폭 (Figma에서 사용한 아트보드 폭)
const double _designWidth = 375.0;

/// 기준 디자인 높이
const double _designHeight = 812.0;

/// 화면 크기 분류.
enum ScreenSize { compact, medium, expanded }

/// [BuildContext]에 반응형 헬퍼를 추가하는 확장.
///
/// 사용법:
/// ```dart
/// final padding = context.rs(24);   // 비례 스케일
/// final font = context.rs(16);      // 폰트도 동일 비례
/// final h = context.rh(56);         // 높이 기준 스케일
/// ```
extension ResponsiveExtension on BuildContext {
  MediaQueryData get _mq => MediaQuery.of(this);

  /// 화면의 논리적 너비 (safe area 제외 전).
  double get screenWidth => _mq.size.width;

  /// 화면의 논리적 높이 (safe area 제외 전).
  double get screenHeight => _mq.size.height;

  /// safe area insets.
  EdgeInsets get safeArea => _mq.padding;

  /// 현재 화면 크기 분류.
  ScreenSize get screenSize {
    final w = screenWidth;
    if (w < 600) return ScreenSize.compact;
    if (w < 840) return ScreenSize.medium;
    return ScreenSize.expanded;
  }

  /// 너비 기준 스케일 팩터.
  ///
  /// 디자인 폭 375에서 1.0, 화면이 넓을수록 비례 증가.
  /// 최소 0.8 (극소 화면), 최대 1.6 (대형 태블릿) 클램프.
  double get _widthScale {
    final raw = screenWidth / _designWidth;
    return raw.clamp(0.8, 1.6);
  }

  /// 높이 기준 스케일 팩터 (Galaxy Flip 같은 짧은 화면 대응).
  double get _heightScale {
    final raw = screenHeight / _designHeight;
    return raw.clamp(0.75, 1.5);
  }

  /// **너비 기준 반응형 스케일** - padding, margin, icon size, font size 등.
  ///
  /// `context.rs(24)` → 375 기준에서 24, iPhone 15 Pro Max(430)에서 ~27.5
  double rs(double value) => value * _widthScale;

  /// **높이 기준 반응형 스케일** - 수직 간격, 컴포넌트 높이 등.
  ///
  /// Galaxy Flip 접힌 상태(짧은 화면)에서 요소가 잘리지 않도록 한다.
  double rh(double value) => value * _heightScale;

  /// 너비/높이 중 **작은 쪽** 기준 스케일.
  ///
  /// 정사각형 요소(아바타, 아이콘 컨테이너 등)에 적합하다.
  double rmin(double value) => value * math.min(_widthScale, _heightScale);

  /// 반응형 대칭 수평 패딩.
  ///
  /// compact: 기본값 그대로, medium/expanded: 콘텐츠 최대 폭 제한.
  EdgeInsets get horizontalPadding {
    switch (screenSize) {
      case ScreenSize.compact:
        return EdgeInsets.symmetric(horizontal: rs(22));
      case ScreenSize.medium:
        return EdgeInsets.symmetric(horizontal: rs(40));
      case ScreenSize.expanded:
        // 태블릿에서는 콘텐츠 폭을 제한하고 가운데 정렬
        final side = (screenWidth - 600) / 2;
        return EdgeInsets.symmetric(horizontal: side.clamp(48.0, 200.0));
    }
  }

  /// 화면 크기별 조건 값 선택.
  T responsive<T>({
    required T compact,
    T? medium,
    T? expanded,
  }) {
    return switch (screenSize) {
      ScreenSize.expanded => expanded ?? medium ?? compact,
      ScreenSize.medium => medium ?? compact,
      ScreenSize.compact => compact,
    };
  }
}

/// 콘텐츠 최대 폭을 제한하는 래퍼 위젯.
///
/// 태블릿/iPad에서 콘텐츠가 화면 전체로 펼쳐지지 않도록 한다.
class ResponsiveConstraint extends StatelessWidget {
  const ResponsiveConstraint({
    super.key,
    this.maxWidth = 600,
    this.alignment = Alignment.topCenter,
    required this.child,
  });

  final double maxWidth;
  final Alignment alignment;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
