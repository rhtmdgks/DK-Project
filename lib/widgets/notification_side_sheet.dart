import 'package:flutter/material.dart';
import 'package:myapp/core/theme/app_motion.dart';
import 'package:myapp/core/theme/app_theme.dart';
import 'package:myapp/core/theme/responsive.dart';

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(context),
          Divider(height: 1, color: AppColors.borderLight),
          Expanded(
            child: _buildBody(context),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
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
          const Spacer(),
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

  Widget _buildBody(BuildContext context) {
    // 샘플 알림 목록 (추후 API 연동 시 교체)
    const items = [
      _NotificationItem(
        title: '급식 출발 알림',
        body: '오늘 점심 급식이 12시에 출발해요.',
        time: '오전 11:45',
        read: false,
      ),
      _NotificationItem(
        title: '일정 알림',
        body: '내일 09:00 수학 수행평가가 있어요.',
        time: '어제',
        read: true,
      ),
      _NotificationItem(
        title: '공지사항',
        body: '2026학년도 1학기 수강신청 안내가 등록되었어요.',
        time: '2일 전',
        read: true,
      ),
    ];

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
              style: AppFonts.scaled(context, AppFonts.bodyRegular),
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
      separatorBuilder: (_, __) => Divider(height: 1),
      itemBuilder: (context, index) {
        final item = items[index];
        return _NotificationTile(
          title: item.title,
          body: item.body,
          time: item.time,
          read: item.read,
        );
      },
    );
  }
}

class _NotificationItem {
  const _NotificationItem({
    required this.title,
    required this.body,
    required this.time,
    required this.read,
  });

  final String title;
  final String body;
  final String time;
  final bool read;
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.title,
    required this.body,
    required this.time,
    required this.read,
  });

  final String title;
  final String body;
  final String time;
  final bool read;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: read
            ? Theme.of(context).colorScheme.surface
            : Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.4),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () {},
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
                      title,
                      style: AppFonts.scaled(context, AppFonts.smallMedium)
                          .copyWith(
                        color: AppColors.textDark,
                        fontWeight: read ? FontWeight.w500 : FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    time,
                    style: AppFonts.scaled(context, AppFonts.captionRegular),
                  ),
                ],
              ),
              SizedBox(height: context.rh(4)),
              Text(
                body,
                style: AppFonts.scaled(context, AppFonts.smallRegular)
                    .copyWith(color: AppColors.textSecondary),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
