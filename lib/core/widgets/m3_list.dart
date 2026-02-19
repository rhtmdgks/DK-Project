import 'package:flutter/material.dart';
import 'package:myapp/core/theme/app_theme.dart';
import 'package:myapp/core/theme/responsive.dart';

/// Material 3 리스트용 인박스 스타일 타일.
///
/// 제목 + 내용 미리보기(subtitle), trailing(날짜·뱃지 등), 탭 시 [onTap].
/// 리스트에서는 [ListView.separated] + [Divider]와 함께 사용.
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
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surface,
      child: InkWell(
        onTap: onTap,
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
                          .copyWith(color: AppColors.textDark),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (subtitle != null && subtitle!.isNotEmpty) ...[
                      SizedBox(height: context.rh(4)),
                      Text(
                        subtitle!,
                        style: AppFonts.scaled(context, AppFonts.smallRegular)
                            .copyWith(color: AppColors.textSecondary),
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

/// 상세 내용을 Material 3 스타일 모달 바텀 시트로 표시.
void showM3DetailSheet(
  BuildContext context, {
  required String title,
  required String body,
  String? secondary,
  List<Widget>? actions,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _M3DetailSheetContent(
      title: title,
      body: body,
      secondary: secondary,
      actions: actions,
    ),
  );
}

class _M3DetailSheetContent extends StatelessWidget {
  const _M3DetailSheetContent({
    required this.title,
    required this.body,
    this.secondary,
    this.actions,
  });

  final String title;
  final String body;
  final String? secondary;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppShapes.radiusLarge),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(height: context.rh(12)),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              context.rs(20),
              context.rh(16),
              context.rs(20),
              context.rh(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: AppFonts.scaled(context, AppFonts.titleSemiBold)
                            .copyWith(color: AppColors.textDark),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                if (secondary != null && secondary!.isNotEmpty)
                  Padding(
                    padding: EdgeInsets.only(
                      left: 0,
                      right: 0,
                      top: context.rh(4),
                      bottom: 0,
                    ),
                    child: Text(
                      secondary!,
                      style: AppFonts.scaled(context, AppFonts.captionRegular),
                    ),
                  ),
              ],
            ),
          ),
          Divider(height: 1, color: theme.dividerColor),
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(context.rs(20)),
              child: Text(
                body,
                style: AppFonts.scaled(context, AppFonts.bodyRegular)
                    .copyWith(color: AppColors.textPrimary),
              ),
            ),
          ),
          if (actions != null && actions!.isNotEmpty) ...[
            Divider(height: 1, color: theme.dividerColor),
            Padding(
              padding: EdgeInsets.all(context.rs(16)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: actions!,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
