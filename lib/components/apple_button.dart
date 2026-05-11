import 'package:flutter/cupertino.dart';
import 'package:myapp/design/app_colors.dart';
import 'package:myapp/design/app_spacing.dart';

enum AppleButtonVariant {
  primary,
  secondary,
  destructive,
  plain,
}

/// iOS 스타일 액션 버튼. [MaterialApp] + [CupertinoTheme] 하이브리드 앱용.
class AppleButton extends StatelessWidget {
  const AppleButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.fullWidth = false,
    this.loading = false,
    this.variant = AppleButtonVariant.primary,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool fullWidth;
  final bool loading;
  final AppleButtonVariant variant;

  bool get _enabled => onPressed != null && !loading;

  @override
  Widget build(BuildContext context) {
    final child = _buildChild(context);
    if (!fullWidth) return child;
    return SizedBox(
      width: double.infinity,
      child: child,
    );
  }

  Widget _buildChild(BuildContext context) {
    final effective = _enabled ? onPressed : null;
    final content = _content(context);

    switch (variant) {
      case AppleButtonVariant.primary:
        return CupertinoButton.filled(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
          onPressed: effective,
          child: content,
        );
      case AppleButtonVariant.secondary:
        return CupertinoButton(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
          onPressed: effective,
          child: DefaultTextStyle.merge(
            style: TextStyle(color: AppDesignColors.primary(context)),
            child: _borderedPill(context, content),
          ),
        );
      case AppleButtonVariant.destructive:
        return CupertinoButton(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
          onPressed: effective,
          child: DefaultTextStyle.merge(
            style: TextStyle(color: AppDesignColors.destructive(context)),
            child: content,
          ),
        );
      case AppleButtonVariant.plain:
        return CupertinoButton(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs,
          ),
          onPressed: effective,
          child: content,
        );
    }
  }

  Widget _borderedPill(BuildContext context, Widget inner) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: AppDesignColors.primary(context)),
        borderRadius: BorderRadius.circular(1e6),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.xs,
        ),
        child: inner,
      ),
    );
  }

  Widget _content(BuildContext context) {
    if (loading) {
      return const CupertinoActivityIndicator();
    }
    if (icon != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: AppSpacing.xs),
          Text(label),
        ],
      );
    }
    return Text(label);
  }
}
