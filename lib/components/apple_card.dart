import 'package:flutter/cupertino.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:myapp/design/app_spacing.dart';
import 'package:myapp/design/glass.dart';

/// Glass 표면 카드.
class AppleCard extends StatelessWidget {
  const AppleCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.margin,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    final card = GlassCard(
      quality: kAppGlassQuality,
      useOwnLayer: true,
      padding: padding ?? const EdgeInsets.all(AppSpacing.md),
      child: child,
    );
    final wrapped = onTap == null
        ? card
        : GestureDetector(
            onTap: onTap,
            behavior: HitTestBehavior.opaque,
            child: card,
          );
    if (margin == null) return wrapped;
    return Padding(padding: margin!, child: wrapped);
  }
}
