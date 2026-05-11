import 'package:flutter/painting.dart';

/// Apple 계열 UI는 대부분 평면(무그림자). 카드 강조가 필요할 때만 사용.
abstract final class AppShadows {
  AppShadows._();

  /// 미세한 구분용 (남용 금지).
  static const List<BoxShadow> subtleCard = [
        BoxShadow(
          color: Color(0x0D000000),
          offset: Offset(0, 1),
          blurRadius: 3,
        ),
      ];
}
