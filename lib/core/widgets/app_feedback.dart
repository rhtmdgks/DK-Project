import 'package:flutter/cupertino.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:myapp/design/glass.dart';

/// SnackBar 대체. GlassToast + Cupertino 다이얼로그.
abstract final class AppFeedback {
  AppFeedback._();

  static void showToast(
    BuildContext context,
    String message, {
    GlassToastType type = GlassToastType.info,
    Duration duration = const Duration(seconds: 3),
  }) {
    if (!context.mounted) return;
    GlassToast.show(
      context,
      message: message,
      type: type,
      duration: duration,
      quality: kAppGlassQuality,
    );
  }

  static void showSuccess(BuildContext context, String message) =>
      showToast(context, message, type: GlassToastType.success);

  static void showError(BuildContext context, String message) =>
      showToast(context, message, type: GlassToastType.error);

  static Future<void> showAlert(
    BuildContext context, {
    String? title,
    required String message,
    String okLabel = '확인',
  }) {
    return showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: title != null ? Text(title) : null,
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(okLabel),
          ),
        ],
      ),
    );
  }
}
