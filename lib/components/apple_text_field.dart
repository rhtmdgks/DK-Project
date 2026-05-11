import 'package:flutter/cupertino.dart';
import 'package:myapp/design/app_colors.dart';
import 'package:myapp/design/app_radius.dart';
import 'package:myapp/design/app_spacing.dart';

/// iOS 스타일 단일 줄 입력.
class AppleTextField extends StatelessWidget {
  const AppleTextField({
    super.key,
    this.placeholder,
    this.controller,
    this.obscureText = false,
    this.keyboardType,
    this.prefix,
    this.enabled = true,
    this.onChanged,
    this.onSubmitted,
    this.autofocus = false,
    this.maxLines = 1,
    this.textInputAction,
  });

  final String? placeholder;
  final TextEditingController? controller;
  final bool obscureText;
  final TextInputType? keyboardType;
  final Widget? prefix;
  final bool enabled;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool autofocus;
  final int maxLines;
  final TextInputAction? textInputAction;

  @override
  Widget build(BuildContext context) {
    final bg = AppDesignColors.surface(context);
    return CupertinoTextField(
      controller: controller,
      placeholder: placeholder,
      obscureText: obscureText,
      keyboardType: keyboardType,
      enabled: enabled,
      autofocus: autofocus,
      maxLines: maxLines,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      textInputAction: textInputAction,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      prefix: prefix != null
          ? Padding(
              padding: const EdgeInsets.only(left: AppSpacing.sm),
              child: prefix,
            )
          : null,
      clearButtonMode: OverlayVisibilityMode.editing,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(
          color: CupertinoColors.separator.resolveFrom(context),
        ),
      ),
      style: TextStyle(color: AppDesignColors.label(context)),
      placeholderStyle: TextStyle(
        color: AppDesignColors.secondaryLabel(context),
      ),
    );
  }
}
