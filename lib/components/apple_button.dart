import 'package:flutter/cupertino.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:myapp/core/theme/app_theme.dart';
import 'package:myapp/design/app_colors.dart';
import 'package:myapp/design/app_spacing.dart';
import 'package:myapp/design/glass.dart';

enum AppleButtonVariant {
  primary,
  secondary,
  destructive,
  plain,
}

/// Glass / Cupertino 액션 버튼 어댑터.
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
    if (loading) {
      return const SizedBox(
        height: 48,
        child: Center(child: CupertinoActivityIndicator()),
      );
    }

    final content = _content(context);
    final effective = _enabled ? onPressed : null;

    if (variant == AppleButtonVariant.plain) {
      return CupertinoButton(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        onPressed: effective,
        child: content,
      );
    }

    if (variant == AppleButtonVariant.primary) {
      return GlassButton.custom(
        onTap: onPressed ?? () {},
        enabled: _enabled,
        quality: kAppGlassQuality,
        useOwnLayer: true,
        width: fullWidth ? double.infinity : null,
        height: 48,
        child: DefaultTextStyle.merge(
          style: TextStyle(
            color: AppColors.white,
            fontWeight: FontWeight.w600,
          ),
          child: content,
        ),
      );
    }

    final color = variant == AppleButtonVariant.destructive
        ? AppDesignColors.destructive(context)
        : AppDesignColors.primary(context);

    return GlassButton.custom(
      onTap: onPressed ?? () {},
      enabled: _enabled,
      quality: kAppGlassQuality,
      useOwnLayer: true,
      width: fullWidth ? double.infinity : null,
      height: 48,
      child: DefaultTextStyle.merge(
        style: TextStyle(color: color, fontWeight: FontWeight.w600),
        child: content,
      ),
    );
  }

  Widget _content(BuildContext context) {
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
