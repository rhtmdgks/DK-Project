import 'package:flutter/cupertino.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:myapp/design/glass.dart';

/// Glass 단일 줄 입력 어댑터.
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
    if (obscureText) {
      return GlassPasswordField(
        controller: controller,
        placeholder: placeholder ?? '',
        enabled: enabled,
        autofocus: autofocus,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        textInputAction: textInputAction,
        quality: kAppGlassQuality,
      );
    }
    return GlassTextField(
      controller: controller,
      placeholder: placeholder ?? '',
      keyboardType: keyboardType,
      enabled: enabled,
      autofocus: autofocus,
      maxLines: maxLines,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      textInputAction: textInputAction,
      quality: kAppGlassQuality,
      prefixIcon: prefix,
    );
  }
}
