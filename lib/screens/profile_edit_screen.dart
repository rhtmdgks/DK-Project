import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import 'package:myapp/components/apple_button.dart';
import 'package:myapp/components/apple_navigation_bar.dart';
import 'package:myapp/components/apple_text_field.dart';
import 'package:myapp/core/auth/auth_state.dart';
import 'package:myapp/core/theme/app_resolved_colors.dart';
import 'package:myapp/core/theme/app_theme.dart';
import 'package:myapp/core/theme/responsive.dart';
import 'package:myapp/core/widgets/app_feedback.dart';
import 'package:myapp/repositories/profile_repository.dart';

/// 프로필 편집 화면: 프로필 사진 변경 + 목표 대학 설정.
class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  final _picker = ImagePicker();
  final _targetUniversityController = TextEditingController();

  AppProfile? _profile;
  File? _pickedImage;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _targetUniversityController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final profile = await getCurrentProfile();
    if (!mounted) return;
    setState(() {
      _profile = profile;
      _targetUniversityController.text = profile?.targetUniversity ?? '';
      _loading = false;
    });
  }

  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );
    if (picked == null || !mounted) return;
    setState(() => _pickedImage = File(picked.path));
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);

    try {
      if (_pickedImage != null) {
        final url = await ProfileRepository.instance.uploadAvatar(_pickedImage!);
        if (url == null) {
          throw Exception('지원하지 않는 이미지 형식입니다. (jpg, png, gif, webp)');
        }
      }
      await ProfileRepository.instance
          .updateTargetUniversity(_targetUniversityController.text);

      if (!mounted) return;
      AppFeedback.showSuccess(context, '프로필이 저장되었습니다.');
      context.pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      AppFeedback.showError(context, '저장에 실패했습니다: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return GlassScaffold(
      backgroundColor: colors.background,
      appBar: AppleNavigationBar(
        title: '프로필 편집',
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => context.pop(),
          child: Icon(
            CupertinoIcons.back,
            color: AppColors.textDark,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: _loading
            ? const Center(child: CupertinoActivityIndicator(radius: 12))
            : SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: context.rs(24),
                  vertical: context.rh(24),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildAvatarPicker(),
                    SizedBox(height: context.rh(32)),
                    _buildTargetUniversityField(),
                    SizedBox(height: context.rh(40)),
                    AppleButton(
                      label: '저장',
                      fullWidth: true,
                      loading: _saving,
                      onPressed: _saving ? null : _save,
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildAvatarPicker() {
    final avatarUrl = _profile?.avatarUrl;
    final radius = context.rs(48);

    ImageProvider? image;
    if (_pickedImage != null) {
      image = FileImage(_pickedImage!);
    } else if (avatarUrl != null && avatarUrl.isNotEmpty) {
      image = NetworkImage(avatarUrl);
    }

    return Center(
      child: GestureDetector(
        onTap: _pickImage,
        child: Stack(
          children: [
            ClipOval(
              child: Container(
                width: radius * 2,
                height: radius * 2,
                color: AppColors.primaryBlue.withValues(alpha: 0.15),
                child: image != null
                    ? Image(image: image, fit: BoxFit.cover)
                    : Icon(
                        CupertinoIcons.person_fill,
                        size: radius,
                        color: AppColors.primaryBlue,
                      ),
              ),
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                padding: EdgeInsets.all(context.rs(8)),
                decoration: const BoxDecoration(
                  color: AppColors.primaryBlue,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  CupertinoIcons.camera_fill,
                  size: context.rs(16),
                  color: AppColors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTargetUniversityField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '목표 대학',
          style: AppFonts.scaled(context, AppFonts.smallMedium)
              .copyWith(color: AppColors.textSecondary),
        ),
        SizedBox(height: context.rh(8)),
        AppleTextField(
          controller: _targetUniversityController,
          placeholder: '예: 서울대학교 컴퓨터공학부',
        ),
        SizedBox(height: context.rh(4)),
        Text(
          '홈·프로필 화면에 표시됩니다. 비워두면 표시하지 않습니다.',
          style: AppFonts.scaled(context, AppFonts.captionRegular)
              .copyWith(color: AppColors.hint),
        ),
      ],
    );
  }
}
