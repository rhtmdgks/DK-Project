import 'package:flutter/cupertino.dart';
import 'package:myapp/design/app_spacing.dart';

/// `CupertinoListSection.insetGrouped` 래퍼 — 헤더·푸터·자식 슬롯.
class AppleListSection extends StatelessWidget {
  const AppleListSection({
    super.key,
    required this.children,
    this.header,
    this.footer,
  });

  final List<Widget> children;
  final String? header;
  final String? footer;

  @override
  Widget build(BuildContext context) {
    return CupertinoListSection.insetGrouped(
      header: header != null
          ? Text(
              header!,
              style: TextStyle(
                fontSize: 13,
                color: CupertinoColors.secondaryLabel.resolveFrom(context),
              ),
            )
          : null,
      footer: footer != null
          ? Padding(
              padding: const EdgeInsets.only(
                top: AppSpacing.xs,
                left: AppSpacing.md,
                right: AppSpacing.md,
              ),
              child: Text(
                footer!,
                style: TextStyle(
                  fontSize: 13,
                  color: CupertinoColors.secondaryLabel.resolveFrom(context),
                ),
              ),
            )
          : null,
      children: children,
    );
  }
}
