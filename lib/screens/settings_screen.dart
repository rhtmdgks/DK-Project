import 'package:flutter/cupertino.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';

import 'package:myapp/components/apple_list_tile.dart';
import 'package:myapp/components/apple_modal.dart';
import 'package:myapp/core/auth/auth_repository.dart';
import 'package:myapp/core/auth/auth_state.dart';
import 'package:myapp/core/routing/app_router.dart';
import 'package:myapp/core/theme/app_theme_mode.dart';
import 'package:myapp/core/widgets/app_feedback.dart';
import 'package:myapp/providers/user_preferences_provider.dart';
import 'package:myapp/repositories/account_repository.dart';
import 'package:myapp/repositories/notification_settings_repository.dart';
import 'package:myapp/repositories/user_preferences_repository.dart';
import 'package:provider/provider.dart';
import 'package:myapp/core/theme/app_theme.dart';
import 'package:myapp/core/theme/responsive.dart';
import 'package:myapp/services/announcement_notification_service.dart';
import 'package:myapp/services/class_move_notification_service.dart';
import 'package:myapp/services/meal_departure_realtime_service.dart';
import 'package:myapp/services/meal_notification_service.dart';
import 'package:myapp/services/notification_service.dart';
import 'package:myapp/services/schedule_notification_service.dart';
import 'package:myapp/services/weather_notification_service.dart';

/// Figma "마이페이지-설정" (node 670:3801 / 670:4463 / 657:7709)
///
/// 구성:
/// 1. 커스텀 앱바 (뒤로가기 + "설정")
/// 2. 알림 설정 섹션 (5개 토글)
/// 3. 기타 설정 섹션 (버그 신고, 개인정보 처리방침)
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  /// 알림 설정 토글 상태 (키: 설정 ID). SharedPreferences에서 로드.
  final Map<String, bool> _toggles = {
    'meal': false,
    'schedule': false,
    'class_move': false,
    'notice': false,
    'weather': false,
  };

  /// 학생회(council)·교사(teacher)만 급식 출발 알림 발송 메뉴 노출 및 일부 메뉴 제어
  AppProfile? _profile;

  /// 급식 출발 알림 발송 메뉴 노출 여부 (학생회 보직·교사, admin 미포함 — 기존 동작 유지).
  bool get _canSendMealDeparture =>
      (_profile?.hasCouncilRole ?? false) || (_profile?.isTeacher ?? false);

  bool _deletingAccount = false;

  @override
  void initState() {
    super.initState();
    _loadToggles();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final profile = await getCurrentProfile();
    if (!mounted) return;
    setState(() => _profile = profile);
  }

  Future<void> _loadToggles() async {
    final repo = NotificationSettingsRepository.instance;
    final mealOn = await repo.getMealEnabled();
    final scheduleOn = await repo.getScheduleEnabled();
    final classMoveOn = await repo.getClassMoveEnabled();
    final noticeOn = await repo.getNoticeEnabled();
    final weatherOn = await repo.getWeatherEnabled();
    if (!mounted) return;
    setState(() {
      _toggles['meal'] = mealOn;
      _toggles['schedule'] = scheduleOn;
      _toggles['class_move'] = classMoveOn;
      _toggles['notice'] = noticeOn;
      _toggles['weather'] = weatherOn;
    });
  }

  Future<void> _onToggle(String key, bool newValue) async {
    setState(() => _toggles[key] = newValue);

    // 알림을 켤 때는 알림 권한 확인 및 요청 (모든 알림 타입에 공통)
    if (newValue) {
      final hasNotificationPermission = await WeatherNotificationService.isNotificationPermissionGranted();
      if (!hasNotificationPermission) {
        final notificationGranted = await WeatherNotificationService.requestNotificationPermission();
        if (!notificationGranted) {
          if (mounted) {
            setState(() => _toggles[key] = false);
            AppFeedback.showError(
              context,
              '알림 권한이 필요합니다. 앱이 꺼져있어도 알림을 받으려면 설정에서 알림 권한을 허용해주세요.',
            );
          }
          return;
        }
      }
    }

    // 각 알림 타입별 서비스 시작/중지 (서비스가 NotificationSettingsRepository에 저장)
    if (key == 'meal') {
      MealNotificationService.setMealEnabled(newValue)
          .catchError((Object e, StackTrace _) {});
      MealDepartureRealtimeService.refreshSubscription()
          .catchError((Object e, StackTrace _) {});
    } else if (key == 'schedule') {
      ScheduleNotificationService.setScheduleEnabled(newValue)
          .catchError((Object e, StackTrace _) {});
    } else if (key == 'class_move') {
      ClassMoveNotificationService.setClassMoveEnabled(newValue)
          .catchError((Object e, StackTrace _) {});
    } else if (key == 'notice') {
      AnnouncementNotificationService.refreshSubscription()
          .catchError((Object e, StackTrace _) {});
    } else if (key == 'weather') {
      if (newValue) {
        try {
          await _updateWeatherLocation();
          await WeatherNotificationService.setWeatherEnabled(true, skipPermissionCheck: true);
        } catch (e) {
          if (mounted) setState(() => _toggles[key] = false);
          await NotificationSettingsRepository.instance.setWeatherEnabled(false);
          if (!mounted) return;
          AppFeedback.showError(
            context,
            e.toString().replaceAll('Exception: ', ''),
          );
        }
      } else {
        // 날씨 알림을 끌 때
        await WeatherNotificationService.setWeatherEnabled(false);
      }
    }
  }

  Future<void> _updateWeatherLocation() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;
    final denied = await Geolocator.checkPermission() == LocationPermission.denied;
    if (denied) {
      final status = await Geolocator.requestPermission();
      if (status == LocationPermission.denied || status == LocationPermission.deniedForever) return;
    }
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
        ),
      );
      await WeatherNotificationService.saveLocation(pos.latitude, pos.longitude);
    } catch (_) {}
  }

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
      ),
      child: SafeArea(
          child: ListView(
            padding: EdgeInsets.symmetric(horizontal: context.rs(16)),
            children: [
              SizedBox(height: context.rh(12)),
              _buildNotificationSection(),
              SizedBox(height: context.rh(24)),
              _buildDisplaySection(),
              SizedBox(height: context.rh(24)),
              _buildAccountSection(),
              SizedBox(height: context.rh(24)),
              _buildCommunitySection(),
              SizedBox(height: context.rh(24)),
              _buildLegalSection(),
              SizedBox(height: context.rh(24)),
              _buildSupportSection(),
              SizedBox(height: context.rh(32)),
              _buildLogoutButton(),
              SizedBox(height: context.rh(32)),
            ],
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
                icon: CupertinoIcons.cart,
                iconColor: const Color(0xFFFF9F43),
                title: '급식 출발 알림',
                description: '내 반 급식 출발 시간에 알림이 가요!',
              ),
              _buildItemDivider(),
              _buildNotificationItem(
                key: 'schedule',
                icon: CupertinoIcons.calendar,
                iconColor: const Color(0xFF4A90D9),
                title: '일정 알림',
                description: '캘린더에 추가된 일정이 아침 8시에 알림이 가요!',
              ),
              _buildItemDivider(),
              _buildNotificationItem(
                key: 'class_move',
                icon: CupertinoIcons.book,
                iconColor: const Color(0xFF4CAF50),
                title: '이동 수업 알림',
                description: '시간표에 설정한 이동 수업 5분 전에 알림이 가요!',
              ),
              _buildItemDivider(),
              _buildNotificationItem(
                key: 'notice',
                icon: CupertinoIcons.bell,
                iconColor: const Color(0xFFFFC107),
                title: '공지사항 알림',
                description: '공지사항에 추가된 내용에 알림이 가요!',
              ),
              _buildItemDivider(),
              _buildNotificationItem(
                key: 'weather',
                icon: CupertinoIcons.cloud,
                iconColor: const Color(0xFF9C7CDB),
                title: '날씨 알림',
                description:
                    '매일 6시 30분에 알려 드려요. 기온·최고/최저와 비·눈·맑음 안내를 받을 수 있어요.',
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
          _buildToggle(isOn, () => _onToggle(key, !isOn)),
        ],
      ),
    );
  }

  Widget _buildToggle(bool isOn, VoidCallback onTap) {
    return CupertinoSwitch(
      value: isOn,
      onChanged: (_) => onTap(),
      activeTrackColor: AppColors.primaryBlue,
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

  // ── 표시 설정 섹션 (다크모드·글자 크기) ──

  static const _themeModeLabels = {
    AppThemeMode.system: '시스템 설정',
    AppThemeMode.light: '라이트',
    AppThemeMode.dark: '다크',
  };

  static const _fontScaleLabels = ['작게', '기본', '크게', '아주 크게'];

  Widget _buildDisplaySection() {
    final prefs = context.watch<UserPreferencesProvider>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(left: context.rs(10)),
          child: Text(
            '표시 설정',
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
                icon: CupertinoIcons.moon,
                iconColor: const Color(0xFF5C6BC0),
                title: '다크 모드 · ${_themeModeLabels[prefs.themeMode]}',
                onTap: () => _showThemeModeSheet(prefs),
              ),
              _buildItemDivider(),
              _buildLinkItem(
                icon: CupertinoIcons.textformat_size,
                iconColor: const Color(0xFF26A69A),
                title:
                    '글자 크기 · ${_fontScaleLabelFor(prefs.fontScale)}',
                onTap: () => _showFontScaleSheet(prefs),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _fontScaleLabelFor(double scale) {
    final idx = UserPreferencesRepository.fontScaleSteps.indexOf(scale);
    return idx >= 0 ? _fontScaleLabels[idx] : '기본';
  }

  void _showThemeModeSheet(UserPreferencesProvider prefs) {
    AppleModal.showBottomSheetPage<void>(
      context: context,
      heightFactor: 0.35,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final mode in AppThemeMode.values)
              AppleListTile(
                title: _themeModeLabels[mode]!,
                trailing: prefs.themeMode == mode
                    ? const Icon(
                        CupertinoIcons.check_mark,
                        size: 18,
                        color: AppColors.primaryBlue,
                      )
                    : null,
                onTap: () {
                  prefs.setThemeMode(mode);
                  Navigator.of(context).pop();
                },
              ),
          ],
        ),
      ),
    );
  }

  void _showFontScaleSheet(UserPreferencesProvider prefs) {
    AppleModal.showBottomSheetPage<void>(
      context: context,
      heightFactor: 0.45,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0;
                i < UserPreferencesRepository.fontScaleSteps.length;
                i++)
              AppleListTile(
                title: _fontScaleLabels[i],
                trailing: prefs.fontScale ==
                        UserPreferencesRepository.fontScaleSteps[i]
                    ? const Icon(
                        CupertinoIcons.check_mark,
                        size: 18,
                        color: AppColors.primaryBlue,
                      )
                    : null,
                onTap: () {
                  prefs.setFontScale(
                    UserPreferencesRepository.fontScaleSteps[i],
                  );
                  Navigator.of(context).pop();
                },
              ),
          ],
        ),
      ),
    );
  }

  // ── Account 섹션 ──

  Widget _buildAccountSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(left: context.rs(10)),
          child: Text(
            '계정',
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
                icon: CupertinoIcons.person,
                iconColor: AppColors.primaryBlue,
                title: '내 정보',
                onTap: () => context.push(AppRoute.profile.path),
              ),
              _buildItemDivider(),
              _buildLinkItem(
                icon: CupertinoIcons.delete,
                iconColor: AppColors.error,
                title: '계정 삭제',
                onTap: _handleDeleteAccount,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Community 섹션 ──

  Widget _buildCommunitySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(left: context.rs(10)),
          child: Text(
            '커뮤니티',
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
                icon: CupertinoIcons.nosign,
                iconColor: AppColors.textSecondary,
                title: '차단한 사용자',
                onTap: () => context.push(AppRoute.blockedUsers.path),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Legal 섹션 ──

  Widget _buildLegalSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(left: context.rs(10)),
          child: Text(
            '법적 고지',
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
                icon: CupertinoIcons.doc_text,
                iconColor: const Color(0xFFFF8A65),
                title: '개인정보 처리방침',
                onTap: () => context.push(AppRoute.privacyPolicy.path),
              ),
              _buildItemDivider(),
              _buildLinkItem(
                icon: CupertinoIcons.checkmark_shield,
                iconColor: AppColors.primaryBlue,
                title: '서비스 이용약관',
                onTap: () => context.push(AppRoute.termsOfService.path),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Support 섹션 ──

  Widget _buildSupportSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(left: context.rs(10)),
          child: Text(
            '지원',
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
                icon: CupertinoIcons.chat_bubble_2,
                iconColor: AppColors.primaryBlue,
                title: '문의하기',
                onTap: () => context.push(AppRoute.support.path),
              ),
              _buildItemDivider(),
              _buildLinkItem(
                icon: CupertinoIcons.info,
                iconColor: AppColors.textSecondary,
                title: '앱 정보',
                onTap: () => context.push(AppRoute.appInfo.path),
              ),
              _buildItemDivider(),
              _buildLinkItem(
                icon: CupertinoIcons.ant,
                iconColor: const Color(0xFF66BB6A),
                title: '버그 신고',
                onTap: () => context.push(AppRoute.bugReport.path),
              ),
              if (_canSendMealDeparture) ...[
                _buildItemDivider(),
                _buildLinkItem(
                  icon: CupertinoIcons.square_favorites,
                  iconColor: const Color(0xFFFF9F43),
                  title: '급식 출발 알림',
                  onTap: () => context.push(AppRoute.mealDepartureAlert.path),
                ),
              ],
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

  // ── 로그아웃 버튼 ──

  Widget _buildLogoutButton() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: context.rs(10)),
      child: CupertinoButton(
        padding: EdgeInsets.symmetric(
          horizontal: context.rs(16),
          vertical: context.rh(14),
        ),
        color: AppColors.error,
        borderRadius: BorderRadius.circular(context.rs(24)),
        onPressed: _handleLogout,
        child: Text(
          '로그아웃',
          style: AppFonts.scaled(
            context,
            TextStyle(
              fontFamily: AppFonts.fontFamily,
              fontSize: 16,
              fontWeight: FontWeight.w600,
              height: 22 / 16,
              color: AppColors.white,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleDeleteAccount() async {
    if (_deletingAccount) return;

    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('계정 삭제'),
        content: const Text(
          '정말 계정을 영구적으로 삭제하시겠습니까?\n'
          '삭제 후에는 계정과 프로필, 게시글 등 모든 데이터가 복구되지 않습니다.',
        ),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('계정 삭제'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      _deletingAccount = true;
    });

    try {
      await AccountRepository.instance.deleteCurrentAccount();

      // 계정이 삭제되면 알림 구독 정리 및 로컬 세션 로그아웃
      await NotificationService.onLogout();
      await AuthRepository.instance.logout();

      if (!mounted) return;

      AppFeedback.showSuccess(context, '계정이 삭제되었습니다. 이용해 주셔서 감사합니다.');

      context.go(AppRoute.login.path);
    } catch (e) {
      if (!mounted) return;
      await showCupertinoDialog<void>(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('계정 삭제 실패'),
          content: Text(
            e.toString().replaceFirst('Exception: ', ''),
          ),
          actions: [
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('확인'),
            ),
          ],
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _deletingAccount = false;
        });
      }
    }
  }

  Future<void> _handleLogout() async {
    final shouldLogout = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('로그아웃'),
        content: const Text('정말 로그아웃하시겠습니까?'),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('로그아웃'),
          ),
        ],
      ),
    );

    if (shouldLogout != true) return;

    try {
      // 실시간 알림 구독 해제
      await NotificationService.onLogout();

      await AuthRepository.instance.logout();

      if (!mounted) return;
      
      // 로그인 페이지로 이동
      context.go(AppRoute.login.path);
    } catch (e) {
      if (!mounted) return;
      await showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('오류'),
          content: Text('로그아웃 중 오류가 발생했습니다: $e'),
          actions: [
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('확인'),
            ),
          ],
        ),
      );
    }
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
