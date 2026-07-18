import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:myapp/components/apple_button.dart';
import 'package:myapp/core/supabase_client.dart';
import 'package:myapp/core/widgets/app_feedback.dart';
import 'package:myapp/core/widgets/dismiss_keyboard.dart';
import 'package:myapp/core/theme/app_theme.dart';
import 'package:myapp/core/theme/responsive.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Figma "마이페이지-버그 신고" (node 670:4754)
///
/// 구성:
/// 1. 앱바: < + "버그 신고"
/// 2. 어디서 버그가 발생했나요? (텍스트 입력)
/// 3. 버그에 대해 설명해주세요. (텍스트 입력)
/// 4. 버그 사진을 첨부해주세요. (이미지 선택 영역)
/// 5. 신고하기 → 버튼
///
/// 신고 데이터는 Supabase `bug_reports` 테이블에 저장되며,
/// 이미지는 `bug-reports` 스토리지 버킷에 업로드된다.
class BugReportScreen extends StatefulWidget {
  const BugReportScreen({super.key});

  @override
  State<BugReportScreen> createState() => _BugReportScreenState();
}

class _BugReportScreenState extends State<BugReportScreen> {
  final _locationController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _imagePicker = ImagePicker();
  final List<XFile> _selectedImages = [];
  bool _submitting = false;

  @override
  void dispose() {
    _locationController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DismissKeyboard(
      child: CupertinoPageScaffold(
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
            '버그 신고',
            style: AppFonts.scaled(context, _Styles.pageTitle),
          ),
        ),
      child: SafeArea(
          child: ListView(
          padding: EdgeInsets.symmetric(horizontal: context.rs(32)),
          children: [
                  SizedBox(height: context.rh(16)),
                  _buildInputSection(
                    title: '어디서 버그가 발생했나요?',
                    controller: _locationController,
                    hint: 'ex. 공지사항 표시, 급식 메뉴 표시',
                    maxLines: 1,
                  ),
                  SizedBox(height: context.rh(24)),
                  _buildInputSection(
                    title: '버그에 대해 설명해주세요.',
                    controller: _descriptionController,
                    hint: '자세히 입력해주세요.',
                    maxLines: 3,
                  ),
                  SizedBox(height: context.rh(24)),
                  _buildImageSection(),
                  SizedBox(height: context.rh(32)),
                  _buildSubmitButton(),
            SizedBox(height: context.rh(32)),
          ],
        ),
      ),
    ),
    );
  }

  // ── 텍스트 입력 섹션 ──

  Widget _buildInputSection({
    required String title,
    required TextEditingController controller,
    required String hint,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppFonts.scaled(context, _Styles.fieldTitle),
        ),
        SizedBox(height: context.rh(12)),
        CupertinoTextField(
          controller: controller,
          maxLines: maxLines,
          style: AppFonts.scaled(context, _Styles.inputText),
          placeholder: hint,
          placeholderStyle: AppFonts.scaled(context, _Styles.inputHint),
          padding: EdgeInsets.symmetric(
            horizontal: context.rs(20),
            vertical: context.rh(14),
          ),
          decoration: BoxDecoration(
            color: AppColors.white,
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(context.rs(12)),
          ),
        ),
      ],
    );
  }

  // ── 이미지 첨부 섹션 ──

  Widget _buildImageSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '버그 사진을 첨부해주세요.',
          style: AppFonts.scaled(context, _Styles.fieldTitle),
        ),
        SizedBox(height: context.rh(12)),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: AppColors.white,
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(context.rs(15)),
          ),
          padding: EdgeInsets.all(context.rs(12)),
          child: Column(
            children: [
              if (_selectedImages.isEmpty) ...[
                SizedBox(height: context.rh(12)),
                Text(
                  '첨부할 파일을 여기에 끌어다 놓거나,\n파일 선택 버튼을 직접 선택해주세요.',
                  textAlign: TextAlign.center,
                  style: AppFonts.scaled(context, _Styles.uploadHint),
                ),
                SizedBox(height: context.rh(12)),
              ] else ...[
                _buildImagePreviewGrid(),
                SizedBox(height: context.rh(8)),
              ],
              _buildPhotoSelectButton(),
              SizedBox(height: context.rh(4)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildImagePreviewGrid() {
    final size = context.rs(72);
    return Wrap(
      spacing: context.rs(8),
      runSpacing: context.rh(8),
      children: _selectedImages.asMap().entries.map((entry) {
        return Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(context.rs(8)),
              child: Image.file(
                File(entry.value.path),
                width: size,
                height: size,
                fit: BoxFit.cover,
              ),
            ),
            Positioned(
              top: 0,
              right: 0,
              child: GestureDetector(
                onTap: () {
                  setState(() => _selectedImages.removeAt(entry.key));
                },
                child: Container(
                  width: context.rs(20),
                  height: context.rs(20),
                  decoration: const BoxDecoration(
                    color: AppColors.textPrimary,
                    shape: BoxShape.circle,
                  ),
                child: Icon(
                  CupertinoIcons.xmark,
                  size: context.rs(14),
                  color: AppColors.white,
                ),
                ),
              ),
            ),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildPhotoSelectButton() {
    return GestureDetector(
      onTap: _pickImages,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: context.rs(12),
          vertical: context.rh(6),
        ),
        decoration: BoxDecoration(
          color: AppColors.primaryBlue,
          borderRadius: BorderRadius.circular(context.rs(6)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              CupertinoIcons.photo_on_rectangle,
              size: context.rs(14),
              color: AppColors.white,
            ),
            SizedBox(width: context.rs(4)),
            Text(
              '사진선택',
              style: TextStyle(
                fontFamily: AppFonts.fontFamily,
                fontSize: context.rs(9),
                fontWeight: FontWeight.w400,
                color: AppColors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImages() async {
    try {
      final images = await _imagePicker.pickMultiImage(
        imageQuality: 80,
        maxWidth: 1920,
      );
      if (images.isNotEmpty && mounted) {
        setState(() => _selectedImages.addAll(images));
      }
    } catch (e) {
      if (!mounted) return;
      AppFeedback.showError(context, '이미지를 선택할 수 없습니다: $e');
    }
  }

  // ── 신고하기 버튼 ──

  Widget _buildSubmitButton() {
    return SizedBox(
      height: context.rh(50),
      child: AppleButton(
        label: '신고하기',
        icon: CupertinoIcons.arrow_right,
        fullWidth: true,
        loading: _submitting,
        onPressed: _submitting ? null : _submit,
      ),
    );
  }

  Future<void> _submit() async {
    final location = _locationController.text.trim();
    final description = _descriptionController.text.trim();

    if (location.isEmpty) {
      _showError('버그 발생 위치를 입력해주세요.');
      return;
    }
    if (description.isEmpty) {
      _showError('버그에 대한 설명을 입력해주세요.');
      return;
    }

    setState(() => _submitting = true);

    try {
      final uid = supabase.auth.currentUser!.id;
      final imageUrls = <String>[];

      // 이미지 업로드
      for (final image in _selectedImages) {
        final bytes = await image.readAsBytes();
        final ext = image.name.split('.').last;
        final path = '$uid/${DateTime.now().millisecondsSinceEpoch}_${imageUrls.length}.$ext';

        await supabase.storage.from('bug-reports').uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            contentType: 'image/$ext',
            upsert: true,
          ),
        );

        final url = supabase.storage.from('bug-reports').getPublicUrl(path);
        imageUrls.add(url);
      }

      // bug_reports 테이블에 삽입
      await supabase.from('bug_reports').insert({
        'user_id': uid,
        'location': location,
        'description': description,
        'image_urls': imageUrls,
      });

      if (!mounted) return;

      AppFeedback.showSuccess(context, '버그 신고가 완료되었습니다. 감사합니다!');

      context.pop();
    } catch (e) {
      if (!mounted) return;
      _showError('신고 중 오류가 발생했습니다: $e');
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  void _showError(String message) {
    AppFeedback.showError(context, message);
  }
}

/// 버그 신고 화면 전용 텍스트 스타일 상수.
abstract final class _Styles {
  /// 페이지 타이틀 "버그 신고" – 24px, w600, #19213D
  static const pageTitle = TextStyle(
    fontFamily: AppFonts.fontFamily,
    fontSize: 24,
    fontWeight: FontWeight.w600,
    height: 32 / 24,
    color: Color(0xFF19213D),
  );

  /// 필드 타이틀 – 20px, w600, #353E5C
  static const fieldTitle = TextStyle(
    fontFamily: AppFonts.fontFamily,
    fontSize: 20,
    fontWeight: FontWeight.w600,
    height: 28 / 20,
    color: AppColors.textPrimary,
  );

  /// 입력 텍스트 – 14px, w400, #353E5C
  static const inputText = TextStyle(
    fontFamily: AppFonts.fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.4,
    color: AppColors.textPrimary,
  );

  /// 입력 힌트 – 14px, w400, #B4B9C9
  static const inputHint = TextStyle(
    fontFamily: AppFonts.fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.4,
    color: AppColors.hint,
  );

  /// 업로드 영역 힌트 – 12px, w400, #B4B9C9
  static const uploadHint = TextStyle(
    fontFamily: AppFonts.fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.4,
    color: AppColors.hint,
  );
}
