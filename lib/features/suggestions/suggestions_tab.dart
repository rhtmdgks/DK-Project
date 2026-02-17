import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:myapp/core/auth/auth_state.dart';
import 'package:myapp/core/supabase_client.dart';
import 'package:myapp/core/theme/app_theme.dart';
import 'package:myapp/core/theme/responsive.dart';
import 'package:myapp/core/widgets/async_body.dart';

/// 건의함 탭. 반응형 대응.
///
/// 건의 목록을 표시하고 새 건의를 등록할 수 있다.
class SuggestionsTab extends StatefulWidget {
  const SuggestionsTab({super.key});

  @override
  State<SuggestionsTab> createState() => _SuggestionsTabState();
}

class _SuggestionsTabState extends State<SuggestionsTab> {
  bool _loading = false;
  String? _error;
  List<Map<String, dynamic>> _list = [];
  AppProfile? _profile;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _fetch();
  }

  Future<void> _loadProfile() async {
    final p = await getCurrentProfile();
    if (mounted) setState(() => _profile = p);
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final res = await supabase
          .from('suggestions')
          .select()
          .order('created_at', ascending: false);

      if (!mounted) return;
      setState(() {
        _list = List<Map<String, dynamic>>.from(res as List);
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
    return CupertinoPageScaffold(
      backgroundColor: AppColors.background,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: AppColors.white,
        border: null,
        middle: Text(
          '건의함',
          style: AppFonts.scaled(context, AppFonts.titleSemiBold)
              .copyWith(color: AppColors.textDark),
        ),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _showAddDialog,
          child: const Icon(CupertinoIcons.add),
        ),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: AsyncBody(
        loading: _loading,
        error: _error,
        isEmpty: _list.isEmpty,
        onRetry: _fetch,
        emptyMessage: '등록된 건의가 없습니다.',
        child: RefreshIndicator(
          onRefresh: _fetch,
          child: ListView.builder(
            padding: context.horizontalPadding.copyWith(
              top: context.rh(16),
              bottom: context.rh(16),
            ),
            itemCount: _list.length,
            itemBuilder: (context, i) => _buildSuggestionItem(_list[i]),
          ),
        ),
      ),
    ),
    );
  }

  Widget _buildSuggestionItem(Map<String, dynamic> item) {
    final title = item['title'] as String? ?? '';
    final body = item['body'] as String? ?? '';
    final status = item['status'] as String? ?? 'pending';

    final statusLabel = switch (status) {
      'pending' => '대기 중',
      'reviewed' => '검토 완료',
      'resolved' => '해결됨',
      _ => status,
    };

    return Container(
      margin: EdgeInsets.only(bottom: context.rh(8)),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderLight),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: context.rs(16),
        vertical: context.rh(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: AppFonts.scaled(context, AppFonts.bodyMedium),
          ),
          if (body.isNotEmpty) ...[
            SizedBox(height: context.rh(4)),
            Text(
              body,
              style: AppFonts.scaled(context, AppFonts.smallRegular),
            ),
          ],
          SizedBox(height: context.rh(4)),
          Text(
            '상태: $statusLabel',
            style: AppFonts.scaled(context, AppFonts.captionRegular),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddDialog() async {
    if (_profile == null) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => _AddSuggestionDialogContent(
        profile: _profile!,
        onSubmitted: () {
          if (dialogContext.mounted) Navigator.pop(dialogContext, true);
        },
        onCancel: () => Navigator.pop(dialogContext, false),
      ),
    );

    if (ok == true) _fetch();
  }
}

/// 새 건의 다이얼로그 본문. 컨트롤러 생명주기를 State에서 관리하여
/// dispose 후 사용 오류를 방지한다.
class _AddSuggestionDialogContent extends StatefulWidget {
  const _AddSuggestionDialogContent({
    required this.profile,
    required this.onSubmitted,
    required this.onCancel,
  });

  final AppProfile profile;
  final VoidCallback onSubmitted;
  final VoidCallback onCancel;

  @override
  State<_AddSuggestionDialogContent> createState() =>
      _AddSuggestionDialogContentState();
}

class _AddSuggestionDialogContentState extends State<_AddSuggestionDialogContent> {
  late final TextEditingController _titleController;
  late final TextEditingController _bodyController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _bodyController = TextEditingController();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    await supabase.from('suggestions').insert({
      'author_id': widget.profile.id,
      'title': _titleController.text,
      'body': _bodyController.text.isEmpty ? null : _bodyController.text,
    });
    if (mounted) widget.onSubmitted();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('새 건의'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CupertinoTextField(
            controller: _titleController,
            placeholder: '제목',
            padding: EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.border),
            ),
          ),
          SizedBox(height: 12),
          CupertinoTextField(
            controller: _bodyController,
            placeholder: '내용',
            maxLines: 3,
            padding: EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.border),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: widget.onCancel,
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('등록'),
        ),
      ],
    );
  }
}
