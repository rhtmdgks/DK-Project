import 'package:flutter/cupertino.dart';
import 'package:myapp/design/app_colors.dart';

/// 그룹 리스트 행. [CupertinoListTile] 기반.
class AppleListTile extends StatelessWidget {
  const AppleListTile({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.showChevron = false,
    this.onTap,
    this.destructive = false,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final bool showChevron;
  final VoidCallback? onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final titleStyle = destructive
        ? TextStyle(color: AppDesignColors.destructive(context))
        : null;

    return CupertinoListTile(
      leading: leading,
      title: Text(title, style: titleStyle),
      subtitle: subtitle != null ? Text(subtitle!) : null,
      trailing: showChevron
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (trailing != null) trailing!,
                Icon(
                  CupertinoIcons.chevron_right,
                  size: 18,
                  color: CupertinoColors.tertiaryLabel.resolveFrom(context),
                ),
              ],
            )
          : trailing,
      onTap: onTap,
    );
  }
}
