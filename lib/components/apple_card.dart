import 'package:flutter/material.dart';
import 'package:myapp/design/app_colors.dart';
import 'package:myapp/design/app_radius.dart';
import 'package:myapp/design/app_spacing.dart';

/// 인셋 그룹 배경 위에 올리는 부드러운 표면 카드.
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
    final surface = AppDesignColors.surface(context);
    final Widget tile = Container(
      margin: margin,
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(AppRadius.utilityCard),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.utilityCard),
          child: Padding(
            padding: padding ??
                const EdgeInsets.all(AppSpacing.md),
            child: child,
          ),
        ),
      ),
    );
    return tile;
  }
}
