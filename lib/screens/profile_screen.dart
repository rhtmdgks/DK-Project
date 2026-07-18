import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import 'package:myapp/components/apple_button.dart';
import 'package:myapp/components/apple_card.dart';
import 'package:myapp/components/apple_navigation_bar.dart';
import 'package:myapp/core/auth/auth_state.dart';
import 'package:myapp/core/routing/app_router.dart';
import 'package:myapp/core/theme/app_resolved_colors.dart';
import 'package:myapp/core/theme/app_theme.dart';
import 'package:myapp/core/theme/responsive.dart';

/// 내 정보(프로필) 화면. 학번, 이름, 학년, 반, 번호 등을 한눈에 표시.
/// 어드민 여부는 노출하지 않음.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  AppProfile? _profile;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final profile = await getCurrentProfile();
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return GlassScaffold(
      backgroundColor: colors.background,
      appBar: AppleNavigationBar(
        title: '내 정보',
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => context.pop(),
          child: Icon(
            CupertinoIcons.back,
            color: AppColors.textDark,
          ),
        ),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () async {
            final changed =
                await context.push<bool>(AppRoute.profileEdit.path);
            if (changed == true) _loadProfile();
          },
          child: Icon(
            CupertinoIcons.pencil,
            color: AppColors.textDark,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: _loading
            ? const Center(child: CupertinoActivityIndicator(radius: 12))
            : _error != null
                ? Center(
                    child: Padding(
                      padding: EdgeInsets.all(context.rs(24)),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '정보를 불러올 수 없습니다.',
                            style: AppFonts.scaled(
                              context,
                              AppFonts.bodyRegular,
                            ).copyWith(color: AppColors.textSecondary),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: context.rh(16)),
                          AppleButton(
                            label: '다시 시도',
                            onPressed: _loadProfile,
                          ),
                        ],
                      ),
                    ),
                  )
                : _profile == null
                    ? Center(
                        child: Text(
                          '로그인된 사용자 정보가 없습니다.',
                          style: AppFonts.scaled(
                            context,
                            AppFonts.bodyRegular,
                          ).copyWith(color: AppColors.textSecondary),
                        ),
                      )
                    : SingleChildScrollView(
                        padding: EdgeInsets.symmetric(
                          horizontal: context.rs(24),
                          vertical: context.rh(24),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildHeader(),
                            SizedBox(height: context.rh(32)),
                            _buildInfoCard(),
                            SizedBox(height: context.rh(16)),
                            _buildTimetableEditCard(context),
                          ],
                        ),
                      ),
      ),
    );
  }

  Widget _buildHeader() {
    final p = _profile!;
    final avatarUrl = p.avatarUrl;
    final name = p.fullName ?? '이름 없음';
    final initials = name.isNotEmpty ? name[0] : '?';
    final radius = context.rs(48);

    return Center(
      child: Column(
        children: [
          ClipOval(
            child: Container(
              width: radius * 2,
              height: radius * 2,
              color: AppColors.primaryBlue.withValues(alpha: 0.15),
              child: avatarUrl != null && avatarUrl.isNotEmpty
                  ? Image.network(avatarUrl, fit: BoxFit.cover)
                  : Center(
                      child: Text(
                        initials,
                        style: AppFonts.scaled(context, AppFonts.heading1Medium)
                            .copyWith(
                          color: AppColors.primaryBlue,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
            ),
          ),
          SizedBox(height: context.rh(16)),
          Text(
            name,
            style: AppFonts.scaled(context, AppFonts.titleBold)
                .copyWith(color: AppColors.textDark),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    final p = _profile!;
    final grade = p.gradeOrFromStudentId;
    final classNum = p.classNumOrFromStudentId;
    final numberInClass = p.numberInClassOrFromStudentId;
    final isTeacher = p.isTeacher;

    final rows = <Widget>[
      _buildInfoRow('학번', p.displayStudentId.isEmpty ? '-' : p.displayStudentId),
      _buildInfoRow('이름', p.fullName ?? '-'),
    ];

    if (isTeacher) {
      rows.add(_buildInfoRow(
        '담당 과목',
        (p.teacherSubjects != null && p.teacherSubjects!.isNotEmpty)
            ? p.teacherSubjects!.join(', ')
            : '-',
      ));
      rows.add(_buildInfoRow(
        '담당 역할',
        (p.teacherRoles != null && p.teacherRoles!.isNotEmpty)
            ? p.teacherRoles!.join(', ')
            : '-',
      ));
    } else {
      rows.add(_buildInfoRow(
        '학년',
        grade != null ? '$grade학년' : '-',
      ));
      rows.add(_buildInfoRow(
        '반',
        classNum != null ? '$classNum반' : '-',
      ));
      rows.add(_buildInfoRow(
        '번호',
        numberInClass != null ? '$numberInClass번' : '-',
      ));
      rows.add(_buildInfoRow('목표 대학', p.targetUniversity ?? '-'));
    }

    return AppleCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: rows,
      ),
    );
  }

  /// 개인 시간표는 [TodayClassesScreen]에서 수정한다.
  Widget _buildTimetableEditCard(BuildContext context) {
    return AppleCard(
      onTap: () => context.push(AppRoute.todayClasses.path),
      child: Row(
        children: [
          Icon(
            CupertinoIcons.calendar,
            size: context.rs(26),
            color: AppColors.primaryBlue,
          ),
          SizedBox(width: context.rs(16)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '시간표 수정',
                  style: AppFonts.scaled(context, AppFonts.titleSemiBold)
                      .copyWith(color: AppColors.textDark),
                ),
                SizedBox(height: context.rh(4)),
                Text(
                  '월~금 요일별 과목·교실을 바꾸고, 이동 수업 표시도 할 수 있어요.',
                  style: AppFonts.scaled(context, AppFonts.captionMedium)
                      .copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          Icon(
            CupertinoIcons.chevron_forward,
            size: context.rs(18),
            color: AppColors.textSecondary,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: context.rh(12)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: context.rs(72),
            child: Text(
              label,
              style: AppFonts.scaled(context, AppFonts.captionMedium)
                  .copyWith(color: AppColors.textSecondary),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppFonts.scaled(context, AppFonts.bodyMedium)
                  .copyWith(color: AppColors.textDark),
            ),
          ),
        ],
      ),
    );
  }
}
