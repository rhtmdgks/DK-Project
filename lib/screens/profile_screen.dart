import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:myapp/core/auth/auth_state.dart';
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
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(CupertinoIcons.back),
          color: AppColors.textDark,
          onPressed: () => context.pop(),
        ),
        title: Text(
          '내 정보',
          style: AppFonts.scaled(context, AppFonts.titleSemiBold)
              .copyWith(color: AppColors.textDark),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        top: false,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
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
                          FilledButton(
                            onPressed: _loadProfile,
                            child: const Text('다시 시도'),
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

    return Center(
      child: Column(
        children: [
          CircleAvatar(
            radius: context.rs(48),
            backgroundColor: AppColors.primaryBlue.withValues(alpha: 0.15),
            backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                ? NetworkImage(avatarUrl)
                : null,
            child: avatarUrl == null || avatarUrl.isEmpty
                ? Text(
                    initials,
                    style: AppFonts.scaled(context, AppFonts.heading1Medium)
                        .copyWith(
                            color: AppColors.primaryBlue,
                            fontWeight: FontWeight.w600),
                  )
                : null,
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

    return Container(
      padding: EdgeInsets.all(context.rs(20)),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppShapes.radiusLarge),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            offset: const Offset(0, 2),
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildInfoRow('학번', p.studentId.isEmpty ? '-' : p.studentId),
          _buildInfoRow('이름', p.fullName ?? '-'),
          _buildInfoRow(
            '학년',
            grade != null ? '$grade학년' : '-',
          ),
          _buildInfoRow(
            '반',
            classNum != null ? '$classNum반' : '-',
          ),
          _buildInfoRow(
            '번호',
            numberInClass != null ? '$numberInClass번' : '-',
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
