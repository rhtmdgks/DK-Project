import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:myapp/core/auth/auth_repository.dart';
import 'package:myapp/core/theme/app_theme.dart';
import 'package:myapp/core/theme/responsive.dart';
import 'package:myapp/core/routing/app_router.dart';
import 'package:myapp/core/widgets/async_body.dart';
import 'package:myapp/core/widgets/tab_page_header.dart';
import 'package:myapp/core/supabase_client.dart';

class ClassPhotoSharesScreen extends StatefulWidget {
  const ClassPhotoSharesScreen({super.key});

  @override
  State<ClassPhotoSharesScreen> createState() => _ClassPhotoSharesScreenState();
}

class _ClassPhotoSharesScreenState extends State<ClassPhotoSharesScreen> {
  final _picker = ImagePicker();
  bool _loading = false;
  String? _error;
  List<Map<String, dynamic>> _items = [];
  String? _userId;
  String? _profileId;
  int? _grade;
  int? _classNumber;
  bool _canManage = false;

  @override
  void initState() {
    super.initState();
    _loadProfileAndFetch();
  }

  Future<void> _loadProfileAndFetch() async {
    final profile = await AuthRepository.instance.getCurrentProfile();
    final userId = await AuthRepository.instance.getUserId();
    if (!mounted) return;
    setState(() {
      _userId = userId;
      _profileId = profile?.id;
      _grade = profile?.gradeOrFromStudentId;
      _classNumber = profile?.classNumOrFromStudentId;
      _canManage = profile?.canManageClassResources ?? false;
    });
    await _fetch();
  }

  Future<void> _fetch() async {
    final grade = _grade;
    final classNumber = _classNumber;
    if (grade == null || classNumber == null) {
      setState(() {
        _items = [];
        _error = '학년/반 정보를 확인할 수 없습니다.';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await supabase
          .from('class_photo_shares')
          .select()
          .eq('grade', grade)
          .eq('class_number', classNumber)
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

  Future<void> _uploadPhoto() async {
    final profileId = _profileId;
    final userId = _userId;
    final grade = _grade;
    final classNumber = _classNumber;
    if (profileId == null || userId == null || grade == null || classNumber == null) return;

    final titleController = TextEditingController();
    final subjectController = TextEditingController();
    final descriptionController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('학급 사진 업로드'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: titleController, decoration: const InputDecoration(labelText: '제목 *')),
            TextField(controller: subjectController, decoration: const InputDecoration(labelText: '과목 (선택)')),
            TextField(controller: descriptionController, decoration: const InputDecoration(labelText: '설명 (선택)')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('다음')),
        ],
      ),
    );
    if (confirmed != true) return;
    final title = titleController.text.trim();
    if (title.isEmpty) {
      _showSnack('제목을 입력해 주세요.');
      return;
    }

    final picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    final ext = picked.name.contains('.') ? picked.name.split('.').last.toLowerCase() : 'jpg';
    final fileName = '${DateTime.now().millisecondsSinceEpoch}_${userId.substring(0, 8)}.$ext';
    final path = 'grade-$grade/class-$classNumber/uploader-$profileId/$fileName';

    try {
      await supabase.storage.from('class-photo-shares').uploadBinary(
        path,
        Uint8List.fromList(bytes),
        fileOptions: FileOptions(contentType: picked.mimeType ?? 'image/jpeg', upsert: false),
      );
      await supabase.from('class_photo_shares').insert({
        'uploader_profile_id': profileId,
        'grade': grade,
        'class_number': classNumber,
        'title': title,
        'subject': subjectController.text.trim().isEmpty ? null : subjectController.text.trim(),
        'description': descriptionController.text.trim().isEmpty ? null : descriptionController.text.trim(),
        'storage_bucket': 'class-photo-shares',
        'storage_path': path,
        'original_file_name': picked.name,
        'mime_type': picked.mimeType,
        'size_bytes': bytes.length,
      });
      _showSnack('학급 사진이 업로드되었습니다.');
      await _fetch();
    } catch (e) {
      _showSnack('업로드 실패: ${e.toString().split('\n').first}');
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
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
              subtitle: '학년·반별로 사진을 올려 공유할 수 있습니다.',
            ),
            Expanded(
              child: AsyncBody(
                loading: _loading,
                error: _error,
                isEmpty: _items.isEmpty,
                onRetry: _fetch,
                emptyMessage: '등록된 학급 사진이 없습니다.',
                child: ListView.separated(
                        padding: EdgeInsets.all(context.rs(16)),
                        itemCount: _items.length,
                        separatorBuilder: (_, __) => SizedBox(height: context.rh(12)),
                        itemBuilder: (context, index) {
                          final item = _items[index];
                          final title = (item['title'] as String?)?.trim();
                          final subject = (item['subject'] as String?)?.trim();
                          final description = (item['description'] as String?)?.trim();
                          final path = item['storage_path'] as String?;
                          final imageUrl = path == null ? null : supabase.storage.from('class-photo-shares').getPublicUrl(path);
                          final canDelete = _canManage || item['uploader_profile_id'] == _profileId;

                          return Card(
                            child: Padding(
                              padding: EdgeInsets.all(context.rs(12)),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (imageUrl != null)
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: Image.network(
                                        imageUrl,
                                        width: double.infinity,
                                        height: context.rh(220),
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  SizedBox(height: context.rh(10)),
                                  Text(title?.isEmpty == false ? title! : '(제목 없음)', style: AppFonts.scaled(context, AppFonts.titleSemiBold)),
                                  if (subject?.isNotEmpty == true) Text('과목: $subject'),
                                  if (description?.isNotEmpty == true) Text(description!),
                                  if (canDelete)
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: TextButton(
                                        onPressed: () => _deleteItem(item),
                                        child: const Text('삭제'),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _uploadPhoto,
        child: const Icon(Icons.add_a_photo_outlined),
      ),
    );
  }
}
