import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:myapp/core/auth/auth_state.dart';
import 'package:myapp/core/supabase_client.dart';
import 'package:myapp/core/theme/app_theme.dart';
import 'package:myapp/core/theme/responsive.dart';
import 'package:myapp/core/widgets/async_body.dart';

/// 일정 관리 탭. 반응형 대응.
///
/// 전체 일정 목록을 표시하며, council / admin 역할에게 추가/삭제 기능을 제공한다.
class ScheduleTab extends StatefulWidget {
  const ScheduleTab({super.key});

  @override
  State<ScheduleTab> createState() => _ScheduleTabState();
}

class _ScheduleTabState extends State<ScheduleTab> {
  bool _loading = false;
  String? _error;
  List<Map<String, dynamic>> _items = [];
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
          .from('schedule_items')
          .select()
          .order('start_at', ascending: true);

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

  bool get _canEdit => _profile?.isPrivileged ?? false;

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppColors.background,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: AppColors.white,
        border: null,
        middle: Text(
          '일정',
          style: AppFonts.scaled(context, AppFonts.titleSemiBold)
              .copyWith(color: AppColors.textDark),
        ),
        trailing: _canEdit
            ? CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: _showAddDialog,
                child: const Icon(CupertinoIcons.add),
              )
            : null,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: AsyncBody(
        loading: _loading,
        error: _error,
        isEmpty: _items.isEmpty,
        onRetry: _fetch,
        emptyMessage: '등록된 일정이 없습니다.',
        child: RefreshIndicator(
          onRefresh: _fetch,
          child: ListView.builder(
            padding: context.horizontalPadding.copyWith(
              top: context.rh(16),
              bottom: context.rh(16),
            ),
            itemCount: _items.length,
            itemBuilder: (context, i) => _buildScheduleItem(_items[i]),
          ),
        ),
      ),
    ),
    );
  }

  Widget _buildScheduleItem(Map<String, dynamic> item) {
    final id = item['id'] as String?;
    final title = item['title'] as String? ?? '';
    final start = item['start_at'] as String?;
    final end = item['end_at'] as String?;

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
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: AppFonts.scaled(context, AppFonts.bodyMedium),
                ),
                SizedBox(height: context.rh(2)),
                Text(
                  '$start - $end',
                  style: AppFonts.scaled(context, AppFonts.smallRegular),
                ),
              ],
            ),
          ),
          if (_canEdit && id != null)
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () => _delete(id),
              child: const Icon(CupertinoIcons.delete, color: AppColors.error),
            ),
        ],
      ),
    );
  }

  Future<void> _showAddDialog() async {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    var start = DateTime.now();
    var end = DateTime.now().add(const Duration(hours: 1));

    try {
      final added = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (dialogContext, setDialogState) {
              return AlertDialog(
                title: const Text('일정 추가'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CupertinoTextField(
                        controller: titleController,
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
                      SizedBox(height: 8),
                      CupertinoTextField(
                        controller: descController,
                        placeholder: '설명',
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
                      const SizedBox(height: 8),
                      _buildDateTimeTile(
                        dialogContext: dialogContext,
                        label: '시작',
                        dateTime: start,
                        onChanged: (dt) => setDialogState(() => start = dt),
                      ),
                      _buildDateTimeTile(
                        dialogContext: dialogContext,
                        label: '종료',
                        dateTime: end,
                        onChanged: (dt) => setDialogState(() => end = dt),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(false),
                    child: const Text('취소'),
                  ),
                  FilledButton(
                    onPressed: () async {
                      final profile = _profile;
                      if (profile == null) return;
                      await supabase.from('schedule_items').insert({
                        'title': titleController.text,
                        'description': descController.text.isEmpty
                            ? null
                            : descController.text,
                        'start_at': start.toIso8601String(),
                        'end_at': end.toIso8601String(),
                        'created_by': profile.id,
                      });
                      if (dialogContext.mounted) {
                        Navigator.of(dialogContext).pop(true);
                      }
                    },
                    child: const Text('추가'),
                  ),
                ],
              );
            },
          );
        },
      );

      if (added == true) _fetch();
    } finally {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        titleController.dispose();
        descController.dispose();
      });
    }
  }

  Widget _buildDateTimeTile({
    required BuildContext dialogContext,
    required String label,
    required DateTime dateTime,
    required ValueChanged<DateTime> onChanged,
  }) {
    return ListTile(
      title: Text(label),
      subtitle: Text(dateTime.toIso8601String()),
      onTap: () async {
        final d = await showDatePicker(
          context: dialogContext,
          initialDate: dateTime,
          firstDate: DateTime(2020),
          lastDate: DateTime(2030),
        );
        if (d == null) return;
        if (!dialogContext.mounted) return;

        final t = await showTimePicker(
          context: dialogContext,
          initialTime: TimeOfDay.fromDateTime(dateTime),
        );
        if (t != null) {
          onChanged(DateTime(d.year, d.month, d.day, t.hour, t.minute));
        }
      },
    );
  }

  Future<void> _delete(String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            child: const Text('삭제'),
          ),
        ],
      ),
    );

    if (ok == true) {
      await supabase.from('schedule_items').delete().eq('id', id);
      _fetch();
    }
  }
}
