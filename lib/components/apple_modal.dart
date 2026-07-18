import 'package:flutter/cupertino.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:myapp/design/glass.dart';

/// Cupertino / Glass 다이얼로그·시트 헬퍼.
abstract final class AppleModal {
  AppleModal._();

  static Future<T?> showAlert<T>({
    required BuildContext context,
    String? title,
    String? message,
    String cancelLabel = '취소',
    String confirmLabel = '확인',
    VoidCallback? onConfirm,
    bool isDestructiveConfirm = false,
  }) {
    return GlassDialog.show<T>(
      context: context,
      quality: kAppGlassQuality,
      title: title,
      message: message,
      actions: [
        GlassDialogAction(
          label: cancelLabel,
          onPressed: () => Navigator.of(context).pop(),
        ),
        GlassDialogAction(
          label: confirmLabel,
          isDestructive: isDestructiveConfirm,
          isPrimary: !isDestructiveConfirm,
          onPressed: () {
            Navigator.of(context).pop();
            onConfirm?.call();
          },
        ),
      ],
    );
  }

  static Future<T?> showActionSheet<T>({
    required BuildContext context,
    required List<CupertinoActionSheetAction> actions,
    String? title,
    String? message,
    String cancelLabel = '취소',
  }) {
    return showCupertinoModalPopup<T>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: title != null ? Text(title) : null,
        message: message != null ? Text(message) : null,
        actions: actions,
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text(cancelLabel),
        ),
      ),
    );
  }

  /// 하단에서 올라오는 Glass 시트.
  static Future<T?> showBottomSheetPage<T>({
    required BuildContext context,
    required Widget child,
    double? heightFactor,
  }) {
    return GlassSheet.show<T>(
      context: context,
      quality: kAppGlassQuality,
      builder: (ctx) {
        final h = MediaQuery.sizeOf(ctx).height * (heightFactor ?? 0.45);
        return SizedBox(height: h, child: child);
      },
    );
  }
}
