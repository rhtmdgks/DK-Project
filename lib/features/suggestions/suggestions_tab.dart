import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:myapp/core/auth/auth_state.dart';
import 'package:myapp/core/routing/app_router.dart';
import 'package:myapp/core/supabase_client.dart';
import 'package:myapp/core/theme/app_theme.dart';
import 'package:myapp/core/theme/responsive.dart';
import 'package:myapp/core/widgets/async_body.dart';
import 'package:myapp/core/widgets/dismiss_keyboard.dart';
import 'package:myapp/core/widgets/tab_page_header.dart';
import 'package:myapp/core/widgets/m3_list.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// FAB를 하단에서 더 가깝게 두기 위한 커스텀 위치.
class _LowerFabLocation extends FloatingActionButtonLocation {
  const _LowerFabLocation();

  @override
  Offset getOffset(ScaffoldPrelayoutGeometry scaffoldGeometry) {
    const double end = 16.0;
    const double bottom = 6.0;
    return Offset(
      scaffoldGeometry.scaffoldSize.width -
          scaffoldGeometry.floatingActionButtonSize.width -
          end,
      scaffoldGeometry.contentBottom -
          scaffoldGeometry.floatingActionButtonSize.height -
          bottom,
    );
  }
}

/// [createdAt] ISO 문자열을 "2월 18일" 형식으로 포맷.
String _formatDate(String? createdAt) {
  if (createdAt == null || createdAt.isEmpty) return '';
  try {
    final dt = DateTime.parse(createdAt);
    const months = [
      '1월', '2월', '3월', '4월', '5월', '6월',
      '7월', '8월', '9월', '10월', '11월', '12월',
    ];
    return '${months[dt.month - 1]} ${dt.day}일';
  } catch (_) {
    return '';
  }
}

/// 건의함 탭. 반응형 대응.
///
/// [건의 목록]과 [질문하기] 세그먼트로 구성되며,
/// 상단 네비게이션에서 [채팅]으로 건의함 전용 채팅 화면으로 이동한다.
class SuggestionsTab extends StatefulWidget {
  const SuggestionsTab({super.key});

  @override
  State<SuggestionsTab> createState() => _SuggestionsTabState();
}

class _SuggestionsTabState extends State<SuggestionsTab>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  bool _loading = false;
  String? _error;
  List<Map<String, dynamic>> _list = [];
  AppProfile? _profile;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadProfile();
    _fetch();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    AppProfile? p;
    
    // 세션이 있으면 기존 로직 사용
    final session = supabase.auth.currentSession;
    if (session != null) {
      p = await getCurrentProfile();
    } else {
      // 세션이 없으면 SharedPreferences에서 user_id를 가져와서 직접 프로필 조회
      final prefs = await SharedPreferences.getInstance();
      final loggedInUserId = prefs.getString('logged_in_user_id');
      
      if (loggedInUserId != null) {
        try {
          final row = await supabase
              .from('profiles')
              .select()
              .eq('user_id', loggedInUserId)
              .maybeSingle();
          if (row != null) {
            p = AppProfile.fromJson(row);
          }
        } catch (_) {
          // 프로필 조회 실패 시 무시
        }
      }
    }
    
    if (mounted) setState(() => _profile = p);
  }

  Future<void> _startDirectChat() async {
    try {
      // 관리자 프로필 찾기 (role이 'admin'인 사용자)
      final adminProfiles = await supabase
          .from('profiles')
          .select('user_id, full_name')
          .eq('role', 'admin')
          .limit(1);

      if (adminProfiles == null || (adminProfiles as List).isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('관리자를 찾을 수 없습니다')),
        );
        return;
      }

      final adminProfile = (adminProfiles as List).first as Map<String, dynamic>;
      final adminUserId = adminProfile['user_id'] as String;

      // 현재 사용자 ID 가져오기 (세션이 없으면 SharedPreferences에서)
      String? currentUserId;
      final session = supabase.auth.currentSession;
      if (session != null) {
        currentUserId = session.user.id;
      } else {
        final prefs = await SharedPreferences.getInstance();
        currentUserId = prefs.getString('logged_in_user_id');
      }

      if (currentUserId == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('로그인이 필요합니다')),
        );
        return;
      }

      // 1:1 채팅방 생성 또는 조회
      final result = await supabase.rpc(
        'create_or_get_direct_chat',
        params: {
          'p_other_user_id': adminUserId,
          'p_user_id': currentUserId,
        },
      );

      if (result == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('채팅방을 생성할 수 없습니다')),
        );
        return;
      }

      final resultMap = result as Map<String, dynamic>;
      final roomId = resultMap['room_id'] as String?;

      if (roomId == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('채팅방 ID를 가져올 수 없습니다')),
        );
        return;
      }

      // 채팅 화면으로 이동
      if (!mounted) return;
      context.push('${AppRoute.chatList.path}/$roomId');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('오류: $e')),
      );
    }
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
    return DismissKeyboard(
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SafeArea(
              top: true,
              bottom: false,
              minimum: EdgeInsets.zero,
              child: Padding(
                padding: EdgeInsets.only(left: context.rs(16)),
                child: TabPageHeader(
                  title: '건의함',
                  subtitle: '건의 목록을 확인하거나 질문을 등록하세요.',
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
            Expanded(
              child: Material(
                type: MaterialType.transparency,
                child: Column(
                  children: [
                    TabBar.secondary(
                      controller: _tabController,
                      indicatorColor: AppColors.primaryBlue500,
                      padding: EdgeInsets.zero,
                      labelPadding: EdgeInsets.zero,
                      tabs: const [
                        Tab(text: '건의 목록'),
                        Tab(text: '채팅하기'),
                      ],
                    ),
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildListBody(),
                          _buildChatSection(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: _showAddSuggestionBottomSheet,
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
          child: const Icon(Icons.add),
        ),
        floatingActionButtonLocation: const _LowerFabLocation(),
      ),
    );
  }

  Widget _buildListBody() {
    return AsyncBody(
      loading: _loading,
      error: _error,
      isEmpty: _list.isEmpty,
      onRetry: _fetch,
      emptyMessage: '등록된 건의가 없습니다.',
      child: RefreshIndicator(
        onRefresh: _fetch,
        child: ListView.separated(
          padding: EdgeInsets.symmetric(vertical: context.rh(16)),
          itemCount: _list.length,
          separatorBuilder: (_, __) => Divider(height: 1),
          itemBuilder: (context, i) => _buildSuggestionTile(_list[i]),
        ),
      ),
    );
  }

  Widget _buildSuggestionTile(Map<String, dynamic> item) {
    final title = item['title'] as String? ?? '';
    final body = item['body'] as String? ?? '';
    final status = item['status'] as String? ?? 'pending';
    final dateStr = _formatDate(item['created_at'] as String?);

    final statusLabel = switch (status) {
      'pending' => '대기 중',
      'approved' => '승인',
      'rejected' => '반려',
      _ => status,
    };

    final statusColor = switch (status) {
      'approved' => AppColors.primaryBlue,
      'rejected' => AppColors.error,
      _ => AppColors.textSecondary,
    };

    return M3ListTileInbox(
      title: title.isEmpty ? '(제목 없음)' : title,
      subtitle: body.isEmpty ? null : body,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dateStr.isNotEmpty)
            Text(
              dateStr,
              style: AppFonts.scaled(context, AppFonts.captionRegular),
            ),
          if (dateStr.isNotEmpty) SizedBox(width: context.rs(8)),
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: context.rs(8),
              vertical: context.rh(2),
            ),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: AppShapes.borderRadiusExtraSmall,
            ),
            child: Text(
              statusLabel,
              style: AppFonts.scaled(context, AppFonts.captionMedium)
                  .copyWith(color: statusColor),
            ),
          ),
          SizedBox(width: context.rs(4)),
          Icon(Icons.chevron_right, size: context.rs(20), color: AppColors.hint),
        ],
      ),
      onTap: () => showM3DetailSheet(
        context,
        title: title.isEmpty ? '(제목 없음)' : title,
        body: body.isEmpty ? '내용 없음' : body,
        secondary: dateStr.isNotEmpty ? '$dateStr · $statusLabel' : statusLabel,
      ),
    );
  }

  Widget _buildChatSection() {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: context.rh(22)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              CupertinoIcons.chat_bubble_2_fill,
              size: context.rs(64),
              color: AppColors.primaryBlue,
            ),
            SizedBox(height: context.rh(24)),
            Text(
              '채팅하기',
              style: AppFonts.scaled(context, AppFonts.titleBold),
            ),
            SizedBox(height: context.rh(12)),
            Text(
              '대덕고등학교 학생회와 직접 소통하여 궁금한 것을 물어보세요!',
              textAlign: TextAlign.center,
              style: AppFonts.scaled(context, AppFonts.bodyRegular),
            ),
            SizedBox(height: context.rh(32)),
            FilledButton.icon(
              onPressed: _startDirectChat,
              icon: const Icon(Icons.chat_bubble_outline),
              label: const Text('채팅 시작하기'),
              style: FilledButton.styleFrom(
                padding: EdgeInsets.symmetric(
                  horizontal: context.rs(24),
                  vertical: context.rh(16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddSuggestionBottomSheet() {
    final titleController = TextEditingController();
    final bodyController = TextEditingController();
    bool submitting = false;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            return Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(AppShapes.radiusLarge),
                ),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 드래그 핸들
                    Padding(
                      padding: EdgeInsets.only(top: context.rh(12)),
                      child: Container(
                        width: context.rs(36),
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.hint.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: context.rs(22),
                        vertical: context.rh(16),
                      ),
                      child: Row(
                        children: [
                          Text(
                            '건의하기',
                            style: AppFonts.scaled(context, AppFonts.titleBold),
                          ),
                          const Spacer(),
                          IconButton(
                            onPressed: () => Navigator.of(sheetContext).pop(),
                            icon: const Icon(Icons.close),
                            style: IconButton.styleFrom(
                              foregroundColor: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Flexible(
                      child: SingleChildScrollView(
                        padding: EdgeInsets.fromLTRB(
                          context.rs(22),
                          0,
                          context.rs(22),
                          context.rh(24),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextField(
                              controller: titleController,
                              decoration: InputDecoration(
                                labelText: '제목',
                                filled: true,
                                fillColor: Theme.of(sheetContext)
                                    .colorScheme
                                    .surfaceContainerHighest
                                    .withValues(alpha: 0.5),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(AppShapes.radiusSmall),
                                  borderSide: BorderSide(color: AppColors.border),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(AppShapes.radiusSmall),
                                  borderSide: BorderSide(color: AppColors.border),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(AppShapes.radiusSmall),
                                  borderSide: BorderSide(
                                    color: Theme.of(sheetContext).colorScheme.primary,
                                    width: 2,
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(height: context.rh(16)),
                            TextField(
                              controller: bodyController,
                              decoration: InputDecoration(
                                labelText: '내용 (선택)',
                                filled: true,
                                fillColor: Theme.of(sheetContext)
                                    .colorScheme
                                    .surfaceContainerHighest
                                    .withValues(alpha: 0.5),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(AppShapes.radiusSmall),
                                  borderSide: BorderSide(color: AppColors.border),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(AppShapes.radiusSmall),
                                  borderSide: BorderSide(color: AppColors.border),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(AppShapes.radiusSmall),
                                  borderSide: BorderSide(
                                    color: Theme.of(sheetContext).colorScheme.primary,
                                    width: 2,
                                  ),
                                ),
                              ),
                              maxLines: 4,
                            ),
                            SizedBox(height: context.rh(24)),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: submitting
                                        ? null
                                        : () => Navigator.of(sheetContext).pop(),
                                    child: const Text('취소'),
                                  ),
                                ),
                                SizedBox(width: context.rs(12)),
                                Expanded(
                                  child: FilledButton(
                                    onPressed: submitting
                                        ? null
                                        : () async {
                                            if (_profile == null) return;

                                            final title = titleController.text.trim();
                                            if (title.isEmpty) {
                                              ScaffoldMessenger.of(sheetContext).showSnackBar(
                                                SnackBar(
                                                  content: const Text('제목을 입력해 주세요.'),
                                                  behavior: SnackBarBehavior.floating,
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.circular(8),
                                                  ),
                                                ),
                                              );
                                              return;
                                            }

                                            setSheetState(() => submitting = true);

                                            try {
                                              await supabase.from('suggestions').insert({
                                                'author_id': _profile!.id,
                                                'title': title,
                                                'body': bodyController.text.trim().isEmpty
                                                    ? null
                                                    : bodyController.text.trim(),
                                              });
                                              if (sheetContext.mounted) {
                                                Navigator.of(sheetContext).pop();
                                                _fetch();
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(
                                                    content: const Text('등록되었습니다.'),
                                                    behavior: SnackBarBehavior.floating,
                                                    backgroundColor: AppColors.success,
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius: BorderRadius.circular(8),
                                                    ),
                                                  ),
                                                );
                                              }
                                            } catch (e) {
                                              if (sheetContext.mounted) {
                                                setSheetState(() => submitting = false);
                                                ScaffoldMessenger.of(sheetContext).showSnackBar(
                                                  SnackBar(
                                                    content: Text('등록 중 오류가 발생했습니다: $e'),
                                                    behavior: SnackBarBehavior.floating,
                                                    backgroundColor: AppColors.error,
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius: BorderRadius.circular(8),
                                                    ),
                                                  ),
                                                );
                                              }
                                            }
                                          },
                                    child: submitting
                                        ? const SizedBox(
                                            height: 20,
                                            width: 20,
                                            child: CircularProgressIndicator(strokeWidth: 2),
                                          )
                                        : const Text('등록하기'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).then((_) {
      titleController.dispose();
      bodyController.dispose();
    });
  }
}

/// 질문하기(건의 등록) 폼. 카드 스타일, Supabase 연동.
class _AddSuggestionForm extends StatefulWidget {
  const _AddSuggestionForm({
    required this.profile,
    required this.onSubmitted,
  });

  final AppProfile? profile;
  final VoidCallback onSubmitted;

  @override
  State<_AddSuggestionForm> createState() => _AddSuggestionFormState();
}

class _AddSuggestionFormState extends State<_AddSuggestionForm> {
  late final TextEditingController _titleController;
  late final TextEditingController _bodyController;
  bool _submitting = false;
  String? _error;

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
    if (widget.profile == null) return;

    final title = _titleController.text.trim();
    if (title.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            '제목을 입력해 주세요.',
            style: TextStyle(color: AppColors.white),
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.error,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          margin: const EdgeInsets.only(
            bottom: 80,
            left: 16,
            right: 16,
          ),
        ),
      );
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      await supabase.from('suggestions').insert({
        'author_id': widget.profile!.id,
        'title': title,
        'body': _bodyController.text.trim().isEmpty
            ? null
            : _bodyController.text.trim(),
      });
      if (!mounted) return;
      _titleController.clear();
      _bodyController.clear();
      widget.onSubmitted();
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            '등록 되었습니다.',
            style: TextStyle(color: AppColors.white),
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.success,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          margin: const EdgeInsets.only(
            bottom: 80,
            left: 16,
            right: 16,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _submitting = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '등록 중 오류가 발생했습니다: $e',
            style: const TextStyle(color: AppColors.white),
          ),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          backgroundColor: AppColors.error,
          margin: const EdgeInsets.only(
            bottom: 80,
            left: 16,
            right: 16,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.profile == null) {
      return Center(
        child: Text(
          '로그인 후 이용해 주세요.',
          style: AppFonts.scaled(context, AppFonts.bodyRegular),
        ),
      );
    }

    return Container(
      padding: EdgeInsets.all(context.rs(20)),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: const [
          BoxShadow(
            color: AppColors.cardShadow,
            offset: Offset(0, 2),
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                CupertinoIcons.pencil_circle_fill,
                color: AppColors.primaryBlue,
                size: context.rs(24),
              ),
              SizedBox(width: context.rs(8)),
              Text(
                '건의 내용',
                style: AppFonts.scaled(context, AppFonts.titleSemiBold),
              ),
            ],
          ),
          SizedBox(height: context.rh(16)),
          CupertinoTextField(
            controller: _titleController,
            placeholder: '제목',
            padding: EdgeInsets.symmetric(
              horizontal: context.rs(16),
              vertical: context.rh(12),
            ),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
          ),
          SizedBox(height: context.rh(12)),
          CupertinoTextField(
            controller: _bodyController,
            placeholder: '내용 (선택)',
            maxLines: 4,
            padding: EdgeInsets.symmetric(
              horizontal: context.rs(16),
              vertical: context.rh(12),
            ),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
          ),
          if (_error != null) ...[
            SizedBox(height: context.rh(8)),
            Text(
              _error!,
              style: AppFonts.scaled(context, AppFonts.smallRegular)
                  .copyWith(color: AppColors.error),
            ),
          ],
          SizedBox(height: context.rh(20)),
          SizedBox(
            width: double.infinity,
            child: CupertinoButton(
              padding: EdgeInsets.symmetric(vertical: context.rh(14)),
              color: AppColors.primaryBlue,
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const CupertinoActivityIndicator(color: AppColors.white)
                  : Text(
                      '등록하기',
                      style: AppFonts.scaled(context, AppFonts.bodyMedium)
                          .copyWith(color: AppColors.white),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
