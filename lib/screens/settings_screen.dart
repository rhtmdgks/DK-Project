import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:myapp/core/routing/app_router.dart';
import 'package:myapp/core/theme/app_theme.dart';
import 'package:myapp/core/theme/responsive.dart';

/// Figma "마이페이지-설정" (node 670:3801 / 670:4463 / 657:7709)
///
/// 구성:
/// 1. 커스텀 앱바 (뒤로가기 + "설정" + 검색/알림 아이콘)
/// 2. 알림 설정 섹션 (5개 토글)
/// 3. 기타 설정 섹션 (버그 신고, 개인정보 처리방침)
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  /// 알림 설정 토글 상태 (키: 설정 ID)
  final Map<String, bool> _toggles = {
    'meal': false,
    'schedule': false,
    'class_move': false,
    'notice': false,
    'weather': false,
  };

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppColors.background,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: AppColors.white,
        border: null,
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => context.pop(),
          child: SvgPicture.asset(
            'assets/images/icon_back_arrow.svg',
            width: context.rs(12),
            height: context.rs(22),
            fit: BoxFit.contain,
          ),
        ),
        middle: Text(
          '설정',
          style: AppFonts.scaled(context, _Styles.pageTitle),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () {},
              child: SvgPicture.asset(
                'assets/images/icon_search.svg',
                width: context.rs(24),
                height: context.rs(24),
                fit: BoxFit.contain,
              ),
            ),
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () {},
              child: SvgPicture.asset(
                'assets/images/icon_bell.svg',
                width: context.rs(22),
                height: context.rs(22),
                fit: BoxFit.contain,
              ),
            ),
          ],
        ),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: SafeArea(
          child: ListView(
          padding: EdgeInsets.symmetric(horizontal: context.rs(16)),
          children: [
                  SizedBox(height: context.rh(12)),
                  _buildNotificationSection(),
                  SizedBox(height: context.rh(16)),
                  _buildOtherSection(),
            SizedBox(height: context.rh(32)),
          ],
        ),
      ),
    ),
    );
  }

  // ── 알림 설정 섹션 ──

  Widget _buildNotificationSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(left: context.rs(10)),
          child: Text(
            '알림 설정',
            style: AppFonts.scaled(context, _Styles.sectionTitle),
          ),
        ),
        SizedBox(height: context.rh(4)),
        Padding(
          padding: EdgeInsets.only(left: context.rs(11)),
          child: Text(
            '여기서 끄면 비슷한 내용의 알림은 보내지 않아요.',
            style: AppFonts.scaled(context, _Styles.sectionSubtitle),
          ),
        ),
        SizedBox(height: context.rh(16)),
        Container(
          decoration: BoxDecoration(
            color: AppColors.borderLight,
            borderRadius: BorderRadius.circular(context.rs(24)),
          ),
          padding: EdgeInsets.symmetric(vertical: context.rh(8)),
          child: Column(
            children: [
              _buildNotificationItem(
                key: 'meal',
                icon: Icons.shopping_cart_rounded,
                iconColor: const Color(0xFFFF9F43),
                title: '급식 출발 알림',
                description: '내 반 급식 출발 시간에 알림이 가요!',
              ),
              _buildItemDivider(),
              _buildNotificationItem(
                key: 'schedule',
                icon: Icons.event_available_rounded,
                iconColor: const Color(0xFF4A90D9),
                title: '일정 알림',
                description: '캘린더에 추가된 일정이 아침 8시에 알림이 가요!',
              ),
              _buildItemDivider(),
              _buildNotificationItem(
                key: 'class_move',
                icon: Icons.school_rounded,
                iconColor: const Color(0xFF4CAF50),
                title: '이동 수업 알림',
                description: '시간표에 설정한 이동 수업 5분 전에 알림이 가요!',
              ),
              _buildItemDivider(),
              _buildNotificationItem(
                key: 'notice',
                icon: Icons.notifications_rounded,
                iconColor: const Color(0xFFFFC107),
                title: '공지사항 알림',
                description: '공지사항에 추가된 내용에 알림이 가요!',
              ),
              _buildItemDivider(),
              _buildNotificationItem(
                key: 'weather',
                icon: Icons.cloud_rounded,
                iconColor: const Color(0xFF9C7CDB),
                title: '날씨 알림',
                description: '등교 전 비 소식이 있다면 알려드려요!',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNotificationItem({
    required String key,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String description,
  }) {
    final isOn = _toggles[key] ?? false;
    final iconContainerSize = context.rs(40);

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: context.rs(16),
        vertical: context.rh(8),
      ),
      child: Row(
        children: [
          Container(
            width: iconContainerSize,
            height: iconContainerSize,
            decoration: const BoxDecoration(
              color: AppColors.border,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: context.rs(20),
              color: iconColor,
            ),
          ),
          SizedBox(width: context.rs(13)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppFonts.scaled(
                    context,
                    _Styles.itemTitle,
                  ),
                ),
                SizedBox(height: context.rh(2)),
                Text(
                  description,
                  style: AppFonts.scaled(
                    context,
                    _Styles.itemDescription,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: context.rs(8)),
          _buildToggle(isOn, () {
            setState(() => _toggles[key] = !isOn);
          }),
        ],
      ),
    );
  }

  Widget _buildToggle(bool isOn, VoidCallback onTap) {
    return CupertinoSwitch(
      value: isOn,
      onChanged: (_) => onTap(),
      activeColor: AppColors.primaryBlue,
    );
  }

  Widget _buildItemDivider() {
    return Container(
      height: 1,
      margin: EdgeInsets.symmetric(horizontal: context.rs(0)),
      decoration: BoxDecoration(
        color: AppColors.border,
        borderRadius: BorderRadius.circular(80),
      ),
    );
  }

  // ── 기타 설정 섹션 ──

  Widget _buildOtherSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(left: context.rs(10)),
          child: Text(
            '기타 설정',
            style: AppFonts.scaled(context, _Styles.sectionTitle),
          ),
        ),
        SizedBox(height: context.rh(12)),
        Container(
          decoration: BoxDecoration(
            color: AppColors.borderLight,
            borderRadius: BorderRadius.circular(context.rs(24)),
          ),
          padding: EdgeInsets.symmetric(vertical: context.rh(4)),
          child: Column(
            children: [
              _buildLinkItem(
                icon: Icons.bug_report_rounded,
                iconColor: const Color(0xFF66BB6A),
                title: '버그 신고',
                onTap: () => context.push(AppRoute.bugReport.path),
              ),
              _buildItemDivider(),
              _buildLinkItem(
                icon: Icons.description_rounded,
                iconColor: const Color(0xFFFF8A65),
                title: '개인정보 처리방침',
                onTap: () {
                  // TODO: 개인정보 처리방침
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLinkItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    required VoidCallback onTap,
  }) {
    final iconContainerSize = context.rs(40);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: context.rs(16),
          vertical: context.rh(12),
        ),
        child: Row(
          children: [
            Container(
              width: iconContainerSize,
              height: iconContainerSize,
              decoration: const BoxDecoration(
                color: AppColors.border,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: context.rs(20),
                color: iconColor,
              ),
            ),
            SizedBox(width: context.rs(8)),
            Expanded(
              child: Text(
                title,
                style: AppFonts.scaled(
                  context,
                  _Styles.itemTitle,
                ),
              ),
            ),
            RotatedBox(
              quarterTurns: 3,
              child: SvgPicture.asset(
                'assets/images/icon_chevron_right.svg',
                width: context.rs(13),
                height: context.rs(7),
                fit: BoxFit.contain,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 설정 화면 전용 텍스트 스타일 상수.
///
/// [AppFonts]에 없는 설정 화면 고유 스타일만 정의한다.
abstract final class _Styles {
  /// 페이지 타이틀 "설정" – 24px, w600, #19213D
  static const pageTitle = TextStyle(
    fontFamily: AppFonts.fontFamily,
    fontSize: 24,
    fontWeight: FontWeight.w600,
    height: 32 / 24,
    color: Color(0xFF19213D),
  );

  /// 섹션 타이틀 "알림 설정", "기타 설정" – 20px, w600, #353E5C
  static const sectionTitle = TextStyle(
    fontFamily: AppFonts.fontFamily,
    fontSize: 20,
    fontWeight: FontWeight.w600,
    height: 28 / 20,
    color: AppColors.textPrimary,
  );

  /// 섹션 부제 – 16px, w500, #B4B9C9
  static const sectionSubtitle = TextStyle(
    fontFamily: AppFonts.fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w500,
    height: 22 / 16,
    color: AppColors.hint,
  );

  /// 항목 타이틀 – 16px, w600, #868DA6
  static const itemTitle = TextStyle(
    fontFamily: AppFonts.fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 22 / 16,
    color: AppColors.textSecondary,
  );

  /// 항목 설명 – 12px, w400, #868DA6
  static const itemDescription = TextStyle(
    fontFamily: AppFonts.fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 18 / 12,
    color: AppColors.textSecondary,
  );
}
