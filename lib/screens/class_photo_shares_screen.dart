import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:myapp/core/auth/auth_repository.dart';
import 'package:myapp/core/theme/app_theme.dart';
import 'package:myapp/core/theme/responsive.dart';
import 'package:myapp/core/routing/app_router.dart';
import 'package:myapp/core/widgets/tab_page_header.dart';
import 'package:myapp/core/supabase_client.dart';

class ClassPhotoSharesScreen extends StatefulWidget {
  const ClassPhotoSharesScreen({super.key});

  @override
  State<ClassPhotoSharesScreen> createState() => _ClassPhotoSharesScreenState();
}

class _ClassPhotoSharesScreenState extends State<ClassPhotoSharesScreen> {
  static const _grades = [1, 2, 3];
  static const _classes = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10];

  final _picker = ImagePicker();
  bool _loading = false;
  bool _uploading = false;
  String? _error;
  List<Map<String, dynamic>> _items = [];
  String? _userId;
  String? _profileId;
  String? _role;
  int? _profileGrade;
  int? _profileClassNumber;
  int _pickedGrade = 1;
  int _pickedClassNumber = 1;
  bool _canManage = false;

  @override
  void initState() {
    super.initState();
    _loadProfileAndFetch();
  }

  bool _isValidGradeClass(int? grade, int? classNumber) {
    return grade != null &&
        classNumber != null &&
        grade >= 1 &&
        grade <= 3 &&
        classNumber >= 1 &&
        classNumber <= 10;
  }

  bool get _isStaff => _role == 'admin' || _role == 'teacher';

  bool get _usesProfileGradeClass =>
      _isValidGradeClass(_profileGrade, _profileClassNumber);

  int? get _activeGrade =>
      _usesProfileGradeClass ? _profileGrade : (_isStaff ? _pickedGrade : null);

  int? get _activeClassNumber => _usesProfileGradeClass
      ? _profileClassNumber
      : (_isStaff ? _pickedClassNumber : null);

  bool get _canUseClassPhotos =>
      _isValidGradeClass(_activeGrade, _activeClassNumber);

  Future<void> _loadProfileAndFetch() async {
    final profile = await AuthRepository.instance.getCurrentProfile();
    final userId = await AuthRepository.instance.getUserId();
    if (!mounted) return;
    setState(() {
      _userId = userId;
      _profileId = profile?.id;
      _role = profile?.role;
      _profileGrade = profile?.gradeOrFromStudentId;
      _profileClassNumber = profile?.classNumOrFromStudentId;
      _canManage = profile?.canManageClassResources ?? false;
      if (_isStaff) _canManage = true;
    });
    await _fetch();
  }

  Future<void> _fetch() async {
    if (!_canUseClassPhotos) {
      setState(() {
        _items = [];
        _loading = false;
        _error = null;
      });
      return;
    }
    final g = _activeGrade!;
    final c = _activeClassNumber!;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await supabase
          .from('class_photo_shares')
          .select()
          .eq('grade', g)
          .eq('class_number', c)
          .isFilter('deleted_at', null)
          .order('created_at', ascending: false);
      if (!mounted) return;
      setState(() {
        _items = List<Map<String, dynamic>>.from(res as List);
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

  void _onStaffGradeClassChanged(int grade, int classNumber) {
    setState(() {
      _pickedGrade = grade;
      _pickedClassNumber = classNumber;
    });
    _fetch();
  }

  Future<void> _pickAndUploadPhoto() async {
    if (_uploading || _loading) return;

    final profileId = _profileId;
    final userId = _userId;
    if (profileId == null ||
        userId == null ||
        !_canUseClassPhotos) {
      _showSnack('학년/반 정보를 확인할 수 없습니다.');
      return;
    }
    final g = _activeGrade!;
    final c = _activeClassNumber!;

    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 80,
    );
    if (picked == null || !mounted) return;

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              context.rs(20),
              context.rh(8),
              context.rs(20),
              context.rh(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(
                    File(picked.path),
                    width: double.infinity,
                    height: context.rh(240),
                    fit: BoxFit.cover,
                  ),
                ),
                SizedBox(height: context.rh(16)),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => Navigator.pop(context, true),
                    icon: const Icon(Icons.cloud_upload_outlined),
                    label: const Text('업로드'),
                  ),
                ),
                SizedBox(height: context.rh(8)),
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('취소'),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (confirmed != true || !mounted) return;

    setState(() => _uploading = true);
    try {
      final file = File(picked.path);
      final fileName =
          '${DateTime.now().millisecondsSinceEpoch}_${userId.substring(0, 8)}.jpg';
      final path = 'grade-$g/class-$c/uploader-$profileId/$fileName';
      final now = DateTime.now();
      final title = '학급 사진 ${now.year}.${now.month}.${now.day}';
      final sizeBytes = await file.length();

      await supabase.storage.from('class-photo-shares').upload(
            path,
            file,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              upsert: false,
            ),
          );
      await supabase.from('class_photo_shares').insert({
        'uploader_profile_id': profileId,
        'grade': g,
        'class_number': c,
        'title': title,
        'storage_bucket': 'class-photo-shares',
        'storage_path': path,
        'original_file_name': picked.name,
        'mime_type': 'image/jpeg',
        'size_bytes': sizeBytes,
      });
      _showSnack('학급 사진이 업로드되었습니다.');
      await _fetch();
    } catch (e) {
      _showSnack('업로드 실패: ${e.toString().split('\n').first}');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _deleteItem(Map<String, dynamic> item) async {
    final id = item['id'] as String?;
    final path = item['storage_path'] as String?;
    final uploaderProfileId = item['uploader_profile_id'] as String?;
    if (id == null || path == null) return;
    if (!_canManage && uploaderProfileId != _profileId) {
      _showSnack('삭제 권한이 없습니다.');
      return;
    }

    try {
      await supabase.from('class_photo_shares').delete().eq('id', id);
      await supabase.storage.from('class-photo-shares').remove([path]);
      _showSnack('삭제되었습니다.');
      await _fetch();
    } catch (e) {
      _showSnack('삭제 실패: ${e.toString().split('\n').first}');
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  Widget _buildGradeClassUnavailableCard() {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        context.rs(16),
        context.rh(8),
        context.rs(16),
        context.rh(12),
      ),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(context.rs(16)),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.error.withValues(alpha: 0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '학년/반 정보가 없어요',
              style: AppFonts.scaled(context, AppFonts.titleMedium)
                  .copyWith(color: AppColors.error),
            ),
            SizedBox(height: context.rh(6)),
            Text(
              '반별 사진은 학년·반이 등록된 학생 계정에서 이용할 수 있어요.',
              style: AppFonts.scaled(context, AppFonts.captionRegular),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStaffGradeClassPicker() {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        context.rs(16),
        context.rh(8),
        context.rs(16),
        context.rh(4),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildPickerTile(
              label: '학년',
              value: _pickedGrade,
              items: _grades,
              onChanged: (v) => _onStaffGradeClassChanged(v, _pickedClassNumber),
            ),
          ),
          SizedBox(width: context.rs(12)),
          Expanded(
            child: _buildPickerTile(
              label: '반',
              value: _pickedClassNumber,
              items: _classes,
              onChanged: (v) => _onStaffGradeClassChanged(_pickedGrade, v),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPickerTile({
    required String label,
    required int value,
    required List<int> items,
    required ValueChanged<int> onChanged,
  }) {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          final selected = await showModalBottomSheet<int>(
            context: context,
            showDragHandle: true,
            builder: (ctx) => SafeArea(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final item in items)
                    ListTile(
                      title: Text('$label $item'),
                      trailing: item == value ? const Icon(Icons.check) : null,
                      onTap: () => Navigator.pop(ctx, item),
                    ),
                ],
              ),
            ),
          );
          if (selected != null) onChanged(selected);
        },
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: context.rs(14),
            vertical: context.rh(12),
          ),
          child: Row(
            children: [
              Text(label, style: AppFonts.scaled(context, AppFonts.captionRegular)),
              const Spacer(),
              Text('$value', style: AppFonts.scaled(context, AppFonts.titleMedium)),
              Icon(Icons.expand_more, size: context.rs(20), color: AppColors.hint),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUploadZone() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        context.rs(16),
        context.rh(8),
        context.rs(16),
        context.rh(12),
      ),
      child: Material(
        color: theme.cardTheme.color ?? theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: _uploading ? null : _pickAndUploadPhoto,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(
              vertical: context.rh(28),
              horizontal: context.rs(16),
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? AppDarkColors.border : AppColors.border,
                width: 1.5,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_uploading)
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: context.rh(8)),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: theme.colorScheme.primary,
                    ),
                  )
                else ...[
                  Icon(
                    Icons.add_photo_alternate_outlined,
                    size: context.rs(48),
                    color: AppColors.primaryBlue,
                  ),
                  SizedBox(height: context.rh(10)),
                  Text(
                    '탭해서 사진 선택',
                    style: AppFonts.scaled(context, AppFonts.titleMedium),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            TabPageHeader(
              leading: IconButton(
                icon: const Icon(CupertinoIcons.back),
                color: AppColors.primaryBlue,
                onPressed: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go(AppRoute.home.path);
                  }
                },
                tooltip: '뒤로',
              ),
              title: '학급 사진 공유',
              subtitle: '같은 반 친구들과 사진을 공유해요.',
            ),
            if (_isStaff && !_usesProfileGradeClass) _buildStaffGradeClassPicker(),
            if (_canUseClassPhotos)
              _buildUploadZone()
            else if (!_loading)
              _buildGradeClassUnavailableCard(),
            Expanded(child: _buildListArea()),
          ],
        ),
      ),
    );
  }

  Widget _buildListArea() {
    if (_loading) {
      return Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: Theme.of(context).colorScheme.primary,
        ),
      );
    }

    if (!_canUseClassPhotos) {
      return const SizedBox.shrink();
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(context.rs(24)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _error!,
                style: AppFonts.scaled(context, AppFonts.smallRegular)
                    .copyWith(color: AppColors.error),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: context.rh(16)),
              CupertinoButton(onPressed: _fetch, child: const Text('다시 시도')),
            ],
          ),
        ),
      );
    }

    if (_items.isEmpty) {
      return const SizedBox.shrink();
    }

    return ListView.separated(
      padding: EdgeInsets.fromLTRB(
        context.rs(16),
        0,
        context.rs(16),
        context.rh(16),
      ),
      itemCount: _items.length,
      separatorBuilder: (_, __) => SizedBox(height: context.rh(12)),
      itemBuilder: (context, index) {
        final item = _items[index];
        final title = (item['title'] as String?)?.trim();
        final path = item['storage_path'] as String?;
        final imageUrl = path == null
            ? null
            : supabase.storage.from('class-photo-shares').getPublicUrl(path);
        final canDelete =
            _canManage || item['uploader_profile_id'] == _profileId;

        return Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (imageUrl != null)
                Image.network(
                  imageUrl,
                  width: double.infinity,
                  height: context.rh(220),
                  fit: BoxFit.cover,
                ),
              Padding(
                padding: EdgeInsets.all(context.rs(12)),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        title?.isNotEmpty == true ? title! : '(제목 없음)',
                        style: AppFonts.scaled(context, AppFonts.titleSemiBold),
                      ),
                    ),
                    if (canDelete)
                      IconButton(
                        onPressed: () => _deleteItem(item),
                        icon: const Icon(Icons.delete_outline),
                        color: AppColors.error,
                        tooltip: '삭제',
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
