import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:myapp/core/theme/app_motion.dart';
import 'package:myapp/core/theme/app_theme.dart';
import 'package:myapp/core/theme/responsive.dart';
import 'package:myapp/models/notification_item.dart';
import 'package:myapp/providers/notification_provider.dart';
import 'package:provider/provider.dart';

/// 알림 사이드 시트. 메인 페이지 알림 아이콘 탭 시 우측에서 슬라이드 인.
///
/// [showNotificationSideSheet]로 띄우며, 배경 탭 시 또는 닫기 버튼으로 닫힌다.
void showNotificationSideSheet(BuildContext context) {
  final width = context.screenWidth * 0.85;
  final maxWidth = 360.0;
  final sheetWidth = width > maxWidth ? maxWidth : width;

  showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: '알림',
    barrierColor: Colors.black54,
    transitionDuration: AppMotion.overlayDuration,
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curve = CurvedAnimation(
        parent: animation,
        curve: AppMotion.overlayEnterCurve,
        reverseCurve: AppMotion.overlayExitCurve,
      );
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(1, 0),
          end: Offset.zero,
        ).animate(curve),
        child: child,
      );
    },
    pageBuilder: (context, animation, secondaryAnimation) {
      return Align(
        alignment: Alignment.centerRight,
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: sheetWidth,
            height: double.infinity,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(AppShapes.radiusLarge),
                bottomLeft: Radius.circular(AppShapes.radiusLarge),
              ),
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context)
                      .colorScheme
                      .shadow
                      .withValues(alpha: 0.08),
                  offset: const Offset(-2, 0),
                  blurRadius: 12,
                ),
              ],
            ),
            child: const _NotificationSideSheetContent(),
          ),
        ),
      );
    },
  );
}

class _NotificationSideSheetContent extends StatelessWidget {
  const _NotificationSideSheetContent();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      left: false,
      child: Consumer<NotificationProvider>(
        builder: (context, provider, _) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(context, provider),
              Divider(height: 1, color: AppColors.borderLight),
              Expanded(
                child: _buildBody(context, provider),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeader(BuildContext context, NotificationProvider provider) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: context.rs(20),
        vertical: context.rh(16),
      ),
      child: Row(
        children: [
          Text(
            '알림',
            style: AppFonts.scaled(context, AppFonts.titleSemiBold)
                .copyWith(color: AppColors.textDark),
          ),
          if (provider.unreadCount > 0) ...[
            SizedBox(width: context.rs(8)),
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: context.rs(8),
                vertical: context.rh(2),
              ),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${provider.unreadCount}',
                style: AppFonts.scaled(context, AppFonts.captionMedium)
                    .copyWith(color: Colors.white),
              ),
            ),
          ],
          const Spacer(),
          if (provider.notifications.isNotEmpty)
            TextButton(
              onPressed: () => provider.markAllAsRead(),
              child: Text(
                '모두 읽음',
                style: AppFonts.scaled(context, AppFonts.smallRegular)
                    .copyWith(color: Theme.of(context).colorScheme.primary),
              ),
            ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: Icon(
              Icons.close_rounded,
              size: context.rs(24),
              color: AppColors.textPrimary,
            ),
            style: IconButton.styleFrom(
              minimumSize: Size(context.rs(40), context.rs(40)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context, NotificationProvider provider) {
    final items = provider.notifications;

    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.notifications_none_rounded,
              size: context.rs(56),
              color: AppColors.hint,
            ),
            SizedBox(height: context.rh(16)),
            Text(
              '알림이 없습니다',
              style: AppFonts.scaled(context, AppFonts.bodyRegular)
                  .copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: EdgeInsets.symmetric(
        horizontal: context.rs(16),
        vertical: context.rh(12),
      ),
      itemCount: items.length,
      separatorBuilder: (_, __) => SizedBox(height: context.rh(8)),
      itemBuilder: (context, index) {
        final item = items[index];
        return _NotificationTile(
          notification: item,
          onTap: () {
            provider.markAsRead(item.id);
            // payload에 따라 화면 이동 처리 가능
          },
          onDismiss: () => provider.deleteNotification(item.id),
        );
      },
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.notification,
    required this.onTap,
    required this.onDismiss,
  });

  final NotificationItem notification;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  String _formatTime(DateTime timestamp) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);

    if (diff.inMinutes < 1) {
      return '방금 전';
    } else if (diff.inHours < 1) {
      return '${diff.inMinutes}분 전';
    } else if (diff.inDays < 1) {
      return DateFormat('HH:mm').format(timestamp);
    } else if (diff.inDays == 1) {
      return '어제';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}일 전';
    } else {
      return DateFormat('MM/dd').format(timestamp);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(notification.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDismiss(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: EdgeInsets.only(right: context.rs(20)),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          Icons.delete_outline,
          color: Colors.white,
          size: context.rs(24),
        ),
      ),
      child: Material(
        color: notification.read
            ? Theme.of(context).colorScheme.surface
            : Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: EdgeInsets.all(context.rs(14)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        notification.title,
                        style: AppFonts.scaled(context, AppFonts.smallMedium)
                            .copyWith(
                          color: AppColors.textDark,
                          fontWeight: notification.read ? FontWeight.w500 : FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      _formatTime(notification.timestamp),
                      style: AppFonts.scaled(context, AppFonts.captionRegular)
                          .copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ),
                SizedBox(height: context.rh(4)),
                Text(
                  notification.body,
                  style: AppFonts.scaled(context, AppFonts.smallRegular)
                      .copyWith(color: AppColors.textSecondary),
                  // 날씨·급식 등 본문이 긴 알림은 패널에서도 읽을 수 있도록 줄 수 확대 (배너/시스템 알림 한계와 별개)
                  maxLines: notification.type == NotificationType.weather
                      ? 8
                      : notification.type == NotificationType.meal
                          ? 5
                          : 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
