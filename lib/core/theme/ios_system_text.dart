import 'package:flutter/cupertino.dart';
import 'package:myapp/core/theme/app_theme.dart';

/// Paperlogy 기반 텍스트 스타일 (구 SF Pro 경로 제거).
abstract final class IosSystemText {
  IosSystemText._();

  static TextStyle body(BuildContext context, {required Color color}) {
    return AppFonts.scaled(context, AppFonts.bodyRegular).copyWith(color: color);
  }

  static TextStyle footnote(BuildContext context, {required Color color}) {
    return AppFonts.scaled(context, AppFonts.captionRegular).copyWith(color: color);
  }

  /// 큰 제목 (시트 헤더 등).
  static TextStyle title2(BuildContext context, {required Color color}) {
    return AppFonts.scaled(context, AppFonts.titleSemiBold).copyWith(color: color);
  }
}
