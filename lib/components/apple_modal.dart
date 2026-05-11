import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Cupertino 다이얼로그·액션 시트 헬퍼.
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
    return showCupertinoDialog<T>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: title != null ? Text(title) : null,
        content: message != null ? Text(message) : null,
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(cancelLabel),
          ),
          CupertinoDialogAction(
            isDestructiveAction: isDestructiveConfirm,
            isDefaultAction: !isDestructiveConfirm,
            onPressed: () {
              Navigator.of(ctx).pop();
              onConfirm?.call();
            },
            child: Text(confirmLabel),
          ),
        ],
      ),
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

  /// 하단에서 올라오는 페이지 시트 (모달 라우트).
  static Future<T?> showBottomSheetPage<T>({
    required BuildContext context,
    required Widget child,
    double? heightFactor,
  }) {
    return showCupertinoModalPopup<T>(
      context: context,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: heightFactor ?? 0.45,
        minChildSize: 0.25,
        maxChildSize: 0.92,
        builder: (context, scrollController) => Material(
          type: MaterialType.transparency,
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            child: ColoredBox(
              color: CupertinoColors.systemBackground.resolveFrom(context),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
