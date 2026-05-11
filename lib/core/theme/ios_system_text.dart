import 'dart:io' show Platform;

import 'package:flutter/cupertino.dart';
import 'package:myapp/core/theme/app_theme.dart';

/// 실제 iOS에서는 SF Pro가 시스템 폰트로 제공된다.
/// 건의·채팅·시트 등 **Apple 리소스 스타일 구역**에서만 사용한다.
abstract final class IosSystemText {
  IosSystemText._();

  static TextStyle body(BuildContext context, {required Color color}) {
    if (Platform.isIOS) {
      return TextStyle(
        fontFamily: '.SF Pro Text',
        fontSize: 17,
        height: 1.47,
        letterSpacing: -0.41,
        color: color,
      );
    }
    return AppFonts.scaled(context, AppFonts.bodyRegular).copyWith(color: color);
  }

  static TextStyle footnote(BuildContext context, {required Color color}) {
    if (Platform.isIOS) {
      return TextStyle(
        fontFamily: '.SF Pro Text',
        fontSize: 13,
        height: 1.38,
        letterSpacing: -0.08,
        color: color,
      );
    }
    return AppFonts.scaled(context, AppFonts.captionRegular).copyWith(color: color);
  }

  /// 큰 제목 (시트 헤더 등).
  static TextStyle title2(BuildContext context, {required Color color}) {
    if (Platform.isIOS) {
      return TextStyle(
        fontFamily: '.SF Pro Display',
        fontSize: 22,
        fontWeight: FontWeight.w700,
        height: 1.27,
        letterSpacing: -0.26,
        color: color,
      );
    }
    return AppFonts.scaled(context, AppFonts.titleSemiBold).copyWith(color: color);
  }
}
