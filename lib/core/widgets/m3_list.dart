import 'package:flutter/cupertino.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:myapp/core/theme/app_resolved_colors.dart';
import 'package:myapp/core/theme/app_theme.dart';
import 'package:myapp/core/theme/apple_design_tokens.dart' show AppleShape;
import 'package:myapp/core/theme/ios_system_text.dart';
import 'package:myapp/core/theme/responsive.dart';
import 'package:myapp/design/glass.dart';

/// Cupertino 스타일 인박스 리스트 타일.
class M3ListTileInbox extends StatelessWidget {
  const M3ListTileInbox({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.leading,
    this.onTap,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget? leading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: ColoredBox(
        color: colors.surface,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: context.rs(16),
            vertical: context.rh(12),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (leading != null) ...[
                leading!,
                SizedBox(width: context.rs(12)),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: AppFonts.scaled(context, AppFonts.bodyMedium)
                          .copyWith(color: colors.onSurface),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (subtitle != null && subtitle!.isNotEmpty) ...[
                      SizedBox(height: context.rh(4)),
                      Text(
                        subtitle!,
                        style: AppFonts.scaled(context, AppFonts.smallRegular)
                            .copyWith(color: colors.onSurfaceVariant),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[
                SizedBox(width: context.rs(8)),
                trailing!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// 상세 내용을 Glass 시트로 표시한다.
void showM3DetailSheet(
  BuildContext context, {
  required String title,
  required String body,
  String? secondary,
  List<Widget>? actions,
  Widget? bodyWidget,
}) {
  GlassSheet.show<void>(
    context: context,
    quality: kAppGlassQuality,
    builder: (ctx) {
      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        builder: (sheetContext, scrollController) {
          return _M3DetailSheetContent(
            title: title,
            body: body,
            secondary: secondary,
            actions: actions,
            bodyWidget: bodyWidget,
            scrollController: scrollController,
          );
        },
      );
    },
  );
}

class _M3DetailSheetContent extends StatelessWidget {
  const _M3DetailSheetContent({
    required this.title,
    required this.body,
    this.secondary,
    this.actions,
    this.bodyWidget,
    required this.scrollController,
  });

  final String title;
  final String body;
  final String? secondary;
  final List<Widget>? actions;
  final Widget? bodyWidget;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final radius = BorderRadius.vertical(
      top: Radius.circular(AppleShape.radiusUtilityCard),
    );

    return SafeArea(
      top: false,
      child: ClipRRect(
        borderRadius: radius,
        child: ColoredBox(
          color: colors.surface,
          child: Column(
            children: [
              SizedBox(height: context.rh(8)),
              Center(
                child: Container(
                  width: context.rs(36),
                  height: 5,
                  decoration: BoxDecoration(
                    color: colors.onSurfaceVariant.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(2.5),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  context.rs(12),
                  context.rh(12),
                  context.rs(8),
                  context.rh(4),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(
                          left: context.rs(8),
                          top: context.rh(2),
                        ),
                        child: Text(
                          title,
                          style: IosSystemText.title2(
                            context,
                            color: colors.onSurface,
                          ),
                        ),
                      ),
                    ),
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(44, 44),
                      onPressed: () => Navigator.of(context).pop(),
                      child: Icon(
                        CupertinoIcons.xmark_circle_fill,
                        size: context.rs(28),
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (secondary != null && secondary!.isNotEmpty)
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    context.rs(20),
                    0,
                    context.rs(20),
                    context.rh(8),
                  ),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      secondary!,
                      style: IosSystemText.footnote(
                        context,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              Container(
                height: 1,
                color: colors.border.withValues(alpha: 0.75),
              ),
              Expanded(
                child: CupertinoScrollbar(
                  controller: scrollController,
                  child: SingleChildScrollView(
                    controller: scrollController,
                    physics: const BouncingScrollPhysics(
                      parent: AlwaysScrollableScrollPhysics(),
                    ),
                    padding: EdgeInsets.fromLTRB(
                      context.rs(20),
                      context.rh(16),
                      context.rs(20),
                      context.rh(28),
                    ),
                    child: DefaultTextStyle(
                      style: IosSystemText.body(
                        context,
                        color: colors.onSurface,
                      ),
                      child: bodyWidget ??
                          Text(
                            body,
                            style: IosSystemText.body(
                              context,
                              color: colors.onSurface,
                            ),
                          ),
                    ),
                  ),
                ),
              ),
              if (actions != null && actions!.isNotEmpty) ...[
                Container(
                  height: 1,
                  color: colors.border.withValues(alpha: 0.75),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: context.rs(16),
                    vertical: context.rh(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: actions!,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
