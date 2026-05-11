import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:myapp/components/components.dart';
import 'package:myapp/core/auth/auth_repository.dart';
import 'package:myapp/core/auth/auth_state.dart';
import 'package:myapp/core/routing/app_router.dart';
import 'package:myapp/core/supabase_client.dart';
import 'package:myapp/core/theme/app_theme.dart';
import 'package:myapp/core/theme/apple_design_tokens.dart' show AppleShape;
import 'package:myapp/core/theme/responsive.dart';
import 'package:myapp/core/widgets/async_body.dart';
import 'package:myapp/core/widgets/dismiss_keyboard.dart';
import 'package:myapp/core/widgets/m3_list.dart';
import 'package:myapp/design/design.dart';
import 'package:myapp/repositories/content_report_repository.dart';
import 'package:myapp/repositories/suggestions_repository.dart';
import 'package:myapp/repositories/user_block_repository.dart';
import 'package:myapp/services/content_moderation_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// FAB를 하단에서 살짝 위로 둔 커스텀 위치.
class _LowerFabLocation extends FloatingActionButtonLocation {
  const _LowerFabLocation();

  @override
  Offset getOffset(ScaffoldPrelayoutGeometry scaffoldGeometry) {
    const double end = 16.0;
    const double bottom = 28.0; // 위로 올리기 (값이 클수록 더 위)
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
      '1월',
      '2월',
      '3월',
      '4월',
      '5월',
      '6월',
      '7월',
      '8월',
      '9월',
      '10월',
      '11월',
      '12월',
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
  final _contentReportRepo = ContentReportRepository();
  final _blockRepo = UserBlockRepository();
  final _suggestionsRepo = SuggestionsRepository();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    _loadProfile();
    _fetch();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final p = await getCurrentProfile();
    if (mounted) setState(() => _profile = p);
  }

  Future<void> _startDirectChat() async {
    try {
      final staff = await _suggestionsRepo.fetchStaffChatContact();
      final adminUserId = staff?['user_id'] as String?;

      if (adminUserId == null || adminUserId.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('관리자를 찾을 수 없습니다')));
        return;
      }

      final currentUserId = await AuthRepository.instance.getUserId();
      if (currentUserId == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('로그인이 필요합니다')));
        return;
      }

      final result = await supabase.rpc(
        'create_or_get_direct_chat',
        params: {'p_other_user_id': adminUserId, 'p_user_id': currentUserId},
      );

      if (result == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('채팅방을 생성할 수 없습니다')));
        return;
      }

      final resultMap = result as Map<String, dynamic>;
      final roomId = resultMap['room_id'] as String?;
      if (roomId == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('채팅방 ID를 가져올 수 없습니다')));
        return;
      }

      if (!mounted) return;
      context.push('${AppRoute.chatList.path}/$roomId');
    } on PostgrestException catch (e) {
      if (!mounted) return;
      if (e.code == 'P0001' && e.message.contains('cannot_chat_with_self')) {
        // 관리자 계정이 자기 자신에게 채팅을 시도하는 경우 – 친절한 안내로 대체
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('관리자 계정에서는 이 버튼 대신 건의함 채팅 또는 기존 채팅방을 이용해 주세요.'),
            backgroundColor: AppColors.error,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('채팅방을 여는 중 오류가 발생했습니다: ${e.message}')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('채팅방을 여는 중 오류가 발생했습니다: $e')));
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

      final blockedProfileIds = await _blockRepo.fetchBlockedProfileIds();

      if (!mounted) return;
      setState(() {
        final rawList = List<Map<String, dynamic>>.from(res as List);
        if (blockedProfileIds.isEmpty) {
          _list = rawList;
        } else {
          _list = rawList.where((item) {
            final authorId = item['author_id']?.toString();
            if (authorId == null) return true;
            return !blockedProfileIds.contains(authorId);
          }).toList();
        }
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
        backgroundColor: AppDesignColors.groupedBackground(context),
        body: Column(
          children: [
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.xs,
                  AppSpacing.md,
                  AppSpacing.sm,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('건의함', style: AppTypography.largeTitle(context)),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      '학교 운영에 대한 의견을 남기거나 학생회와 바로 채팅하세요.',
                      style: AppTypography.subheadline(context),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    CupertinoSlidingSegmentedControl<int>(
                      groupValue: _tabController.index,
                      children: const <int, Widget>{
                        0: Padding(
                          padding: EdgeInsets.symmetric(vertical: AppSpacing.xs),
                          child: Text('건의 목록'),
                        ),
                        1: Padding(
                          padding: EdgeInsets.symmetric(vertical: AppSpacing.xs),
                          child: Text('채팅하기'),
                        ),
                      },
                      onValueChanged: (int? value) {
                        if (value == null) return;
                        _tabController.animateTo(value);
                      },
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [_buildListBody(), _buildChatSection()],
              ),
            ),
          ],
        ),
        floatingActionButton: _tabController.index == 0
            ? CupertinoButton(
                padding: const EdgeInsets.all(AppSpacing.sm),
                color: AppDesignColors.primary(context),
                borderRadius: BorderRadius.circular(999),
                onPressed: _showAddSuggestionBottomSheet,
                child: const Icon(CupertinoIcons.add),
              )
            : null,
        floatingActionButtonLocation: _tabController.index == 0
            ? const _LowerFabLocation()
            : null,
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
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        slivers: [
          CupertinoSliverRefreshControl(onRefresh: _fetch),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.xs,
              AppSpacing.md,
              AppSpacing.xl,
            ),
            sliver: SliverList.separated(
              itemBuilder: (_, index) => _buildCupertinoSuggestionTile(_list[index]),
              separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
              itemCount: _list.length,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCupertinoSuggestionTile(Map<String, dynamic> item) {
    final title = item['title'] as String? ?? '';
    final body = item['body'] as String? ?? '';
    final status = item['status'] as String? ?? 'pending';
    final dateStr = _formatDate(item['created_at'] as String?);
    // 백오피스에서 달 수 있는 관리자 댓글(컬럼 이름은 운영 DB 기준으로 선택적으로 존재)
    final adminComment =
        (item['admin_comment'] as String?) ?? (item['reply'] as String?) ?? '';
    final suggestionId = item['id']?.toString();
    final authorProfileId = item['author_id']?.toString();

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

    final titleStyle = AppFonts.scaled(
      context,
      AppFonts.bodyMedium,
    ).copyWith(color: AppColors.textDark);
    final subStyle = AppFonts.scaled(
      context,
      AppFonts.smallRegular,
    ).copyWith(color: AppColors.textSecondary, height: 1.47);
    final chipStyle = AppFonts.scaled(context, AppFonts.captionMedium);

    return AppleCard(
      onTap: () async {
        final baseBody = body.isEmpty ? '내용 없음' : body;
        final sections = <String>[baseBody];
        if (adminComment.isNotEmpty) {
          sections.add('[관리자 댓글]\n$adminComment');
        }
        final fullBody = sections.join('\n\n');

        if (!context.mounted) return;
        final ctx = context;
        if (suggestionId == null) {
          showM3DetailSheet(
            ctx,
            title: title.isEmpty ? '(제목 없음)' : title,
            body: fullBody,
            secondary: dateStr.isNotEmpty ? '$dateStr · $statusLabel' : statusLabel,
          );
          return;
        }

        showM3DetailSheet(
          ctx,
          title: title.isEmpty ? '(제목 없음)' : title,
          body: fullBody,
          secondary: dateStr.isNotEmpty ? '$dateStr · $statusLabel' : statusLabel,
          bodyWidget: _SuggestionDetailBodyWidget(
            suggestionId: suggestionId,
            baseBody: baseBody,
            adminComment: adminComment,
            onReportSuggestion: () => _showReportDialog(context, 'suggestion', suggestionId),
            onBlockAuthor: authorProfileId == null ? null : () => _blockAuthorAndRefresh(authorProfileId),
          ),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title.isEmpty ? '(제목 없음)' : title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: titleStyle,
                ),
              ),
              if (dateStr.isNotEmpty)
                Text(
                  dateStr,
                  style: AppTypography.caption(context),
                ),
              const SizedBox(width: AppSpacing.xs),
              Icon(
                CupertinoIcons.chevron_right,
                size: 16,
                color: AppDesignColors.tertiaryLabel(context),
              ),
            ],
          ),
          if (body.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(body, maxLines: 2, overflow: TextOverflow.ellipsis, style: subStyle),
          ],
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              _buildStatusChip(
                context: context,
                text: statusLabel,
                color: statusColor,
                style: chipStyle,
              ),
              if (adminComment.isNotEmpty)
                _buildStatusChip(
                  context: context,
                  text: '답변 있음',
                  color: AppColors.primaryBlue,
                  style: chipStyle,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip({
    required BuildContext context,
    required String text,
    required Color color,
    required TextStyle style,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: AppSpacing.xxs),
      decoration: BoxDecoration(
        color: AppDesignColors.elevatedSurface(context),
        borderRadius: BorderRadius.circular(AppleShape.radiusSmHairline),
        border: Border.all(color: AppDesignColors.separator(context)),
      ),
      child: Text(text, style: style.copyWith(color: color)),
    );
  }

  Widget _buildChatSection() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.xs,
        AppSpacing.md,
        AppSpacing.xl,
      ),
      children: [
        AppleCard(
          child: Column(
            children: [
              Icon(
                CupertinoIcons.chat_bubble_2_fill,
                size: context.rs(48),
                color: AppColors.primaryBlue,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                '학생회 1:1 채팅',
                style: AppTypography.title2(context),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '건의 내용이 길거나 빠른 응답이 필요하면 채팅으로 바로 문의하세요.',
                textAlign: TextAlign.center,
                style: AppTypography.subheadline(context),
              ),
              const SizedBox(height: AppSpacing.lg),
              AppleButton(
                label: '채팅 시작하기',
                fullWidth: true,
                icon: CupertinoIcons.arrow_up_right_circle_fill,
                onPressed: _startDirectChat,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _showReportDialog(
    BuildContext context,
    String contentType,
    String contentId,
  ) async {
    final controller = TextEditingController();
    String? selectedReason;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('신고하기'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: selectedReason,
                decoration: const InputDecoration(labelText: '사유 선택'),
                items: const [
                  DropdownMenuItem(value: '욕설/비하', child: Text('욕설/비하')),
                  DropdownMenuItem(value: '괴롭힘/따돌림', child: Text('괴롭힘/따돌림')),
                  DropdownMenuItem(value: '스팸', child: Text('스팸')),
                  DropdownMenuItem(value: '불법/위험 행위', child: Text('불법/위험 행위')),
                  DropdownMenuItem(value: '기타', child: Text('기타 (직접 입력)')),
                ],
                onChanged: (v) {
                  selectedReason = v;
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: '상세 사유 (선택)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('신고'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    final baseReason = selectedReason ?? '기타';
    final extra = controller.text.trim();
    final reason = extra.isEmpty ? baseReason : '$baseReason - $extra';

    try {
      await _contentReportRepo.reportContent(
        contentType: contentType,
        contentId: contentId,
        reason: reason,
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('신고가 접수되었습니다.'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('신고 중 오류가 발생했습니다: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _blockAuthorAndRefresh(String profileId) async {
    try {
      await _blockRepo.blockProfile(profileId);
      await _fetch();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('해당 사용자를 차단했습니다.'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('차단 중 오류가 발생했습니다: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _showAddSuggestionBottomSheet() {
    final titleController = TextEditingController();
    final bodyController = TextEditingController();
    bool submitting = false;
    final overlayContext = rootNavigatorKey.currentContext ?? context;

    showModalBottomSheet<bool>(
      context: overlayContext,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.66,
          minChildSize: 0.38,
          maxChildSize: 0.92,
          builder: (_, scrollController) {
            return StatefulBuilder(
              builder: (innerContext, setSheetState) {
                return Container(
                  decoration: BoxDecoration(
                    color: AppDesignColors.elevatedSurface(innerContext),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(AppRadius.lg),
                    ),
                  ),
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      AppSpacing.sm,
                      AppSpacing.md,
                      AppSpacing.xl,
                    ),
                    children: [
                      Center(
                        child: Container(
                          width: 36,
                          height: 4,
                          decoration: BoxDecoration(
                            color: AppDesignColors.separator(innerContext),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text('건의 등록', style: AppTypography.title2(innerContext)),
                      const SizedBox(height: AppSpacing.md),
                      AppleTextField(controller: titleController, placeholder: '제목'),
                      const SizedBox(height: AppSpacing.sm),
                      AppleTextField(
                        controller: bodyController,
                        placeholder: '내용 (선택)',
                        maxLines: 4,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      AppleButton(
                        label: '등록하기',
                        fullWidth: true,
                        loading: submitting,
                        onPressed: submitting
                            ? null
                            : () async {
                                AppProfile? profile = _profile;
                                profile ??=
                                    await AuthRepository.instance.getCurrentProfile();
                                if (mounted) {
                                  setState(() => _profile = profile);
                                }
                                if (profile == null) return;

                                final title = titleController.text.trim();
                                final bodyText = bodyController.text.trim();
                                if (title.isEmpty) return;

                                final moderation =
                                    ContentModerationService.checkText('$title\n$bodyText');
                                if (moderation.hasAbuse) {
                                  if (innerContext.mounted) {
                                    ScaffoldMessenger.of(innerContext).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          '부적절한 표현이 포함되어 있어 건의를 등록할 수 없습니다.',
                                        ),
                                        backgroundColor: AppColors.error,
                                      ),
                                    );
                                  }
                                  return;
                                }

                                setSheetState(() => submitting = true);
                                try {
                                  try {
                                    await supabase.rpc(
                                      'insert_suggestion',
                                      params: {
                                        'p_title': title,
                                        'p_body': bodyText.isEmpty ? null : bodyText,
                                      },
                                    );
                                  } catch (rpcError) {
                                    final msg = rpcError.toString();
                                    final isFunctionMissing =
                                        msg.contains('insert_suggestion') ||
                                        msg.contains('PGRST202') ||
                                        msg.contains('Could not find the function');
                                    if (isFunctionMissing) {
                                      await supabase.from('suggestions').insert({
                                        'author_id': profile.id,
                                        'title': title,
                                        'body': bodyText.isEmpty ? null : bodyText,
                                      });
                                    } else {
                                      rethrow;
                                    }
                                  }
                                  if (sheetContext.mounted) {
                                    Navigator.of(sheetContext).pop(true);
                                  }
                                } catch (_) {
                                  if (innerContext.mounted) {
                                    setSheetState(() => submitting = false);
                                  }
                                }
                              },
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    ).then((success) {
      titleController.dispose();
      bodyController.dispose();
      if (success == true && mounted) {
        _fetch();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('등록되었습니다.'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    });
  }
}

/// 질문하기(건의 등록) 폼. 카드 스타일, Supabase 연동.
class _AddSuggestionForm extends StatefulWidget {
  const _AddSuggestionForm({required this.profile, required this.onSubmitted});

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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          margin: const EdgeInsets.only(bottom: 80, left: 16, right: 16),
        ),
      );
      return;
    }

    final bodyText = _bodyController.text.trim();
    final moderation = ContentModerationService.checkText('$title\n$bodyText');
    if (moderation.hasAbuse) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            '부적절한 표현이 포함되어 있어 건의를 등록할 수 없습니다. 표현을 수정해 주세요.',
            style: TextStyle(color: AppColors.white),
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.error,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          margin: const EdgeInsets.only(bottom: 80, left: 16, right: 16),
        ),
      );
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final bodyText = _bodyController.text.trim();
      try {
        await supabase.rpc(
          'insert_suggestion',
          params: {
            'p_title': title,
            'p_body': bodyText.isEmpty ? null : bodyText,
          },
        );
      } catch (rpcError) {
        final msg = rpcError.toString();
        final isFunctionMissing =
            msg.contains('insert_suggestion') ||
            msg.contains('PGRST202') ||
            msg.contains('Could not find the function');
        if (isFunctionMissing) {
          await supabase.from('suggestions').insert({
            'author_id': widget.profile!.id,
            'title': title,
            'body': bodyText.isEmpty ? null : bodyText,
          });
        } else {
          rethrow;
        }
      }
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          margin: const EdgeInsets.only(bottom: 80, left: 16, right: 16),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _submitting = false;
      });
      final msg = e.toString();
      final isSessionError =
          msg.contains('P0001') ||
          msg.contains('로그인 세션이 없습니다') ||
          msg.contains('row-level security') ||
          msg.contains('42501');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isSessionError
                ? '서버 인증 세션이 없습니다. 로그아웃 후 다시 로그인해 주세요.'
                : '등록 중 오류가 발생했습니다: $e',
            style: const TextStyle(color: AppColors.white),
          ),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          backgroundColor: AppColors.error,
          margin: const EdgeInsets.only(bottom: 80, left: 16, right: 16),
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
              style: AppFonts.scaled(
                context,
                AppFonts.smallRegular,
              ).copyWith(color: AppColors.error),
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
                      style: AppFonts.scaled(
                        context,
                        AppFonts.bodyMedium,
                      ).copyWith(color: AppColors.white),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 건의 상세 시트 내 본문 + 댓글(공개/비공개·비밀번호)·댓글 작성 UI.
class _SuggestionDetailBodyWidget extends StatefulWidget {
  const _SuggestionDetailBodyWidget({
    required this.suggestionId,
    required this.baseBody,
    required this.adminComment,
    required this.onReportSuggestion,
    this.onBlockAuthor,
  });

  final String suggestionId;
  final String baseBody;
  final String adminComment;
  final VoidCallback onReportSuggestion;
  final VoidCallback? onBlockAuthor;

  @override
  State<_SuggestionDetailBodyWidget> createState() =>
      _SuggestionDetailBodyWidgetState();
}

class _SuggestionDetailBodyWidgetState
    extends State<_SuggestionDetailBodyWidget> {
  List<Map<String, dynamic>> _comments = [];
  final Set<String> _unlockedIds = {};
  bool _loading = true;
  final _contentReportRepo = ContentReportRepository();
  final _blockRepo = UserBlockRepository();

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  Future<void> _loadComments() async {
    setState(() => _loading = true);
    try {
      final res = await supabase
          .from('suggestion_comments')
          .select('id, content, is_private, password, created_at, author_id')
          .eq('suggestion_id', widget.suggestionId)
          .order('created_at', ascending: true);

      final blockedProfileIds = await _blockRepo.fetchBlockedProfileIds();

      if (!mounted) return;
      setState(() {
        final raw = List<Map<String, dynamic>>.from(res as List<dynamic>);
        if (blockedProfileIds.isEmpty) {
          _comments = raw;
        } else {
          _comments = raw.where((c) {
            final authorId = c['author_id']?.toString();
            if (authorId == null) return true;
            return !blockedProfileIds.contains(authorId);
          }).toList();
        }
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _comments = [];
        _loading = false;
      });
    }
  }

  Future<void> _showUnlockDialog(Map<String, dynamic> comment) async {
    final id = comment['id'] as String?;
    final storedPassword = comment['password'] as String? ?? '';
    if (id == null) return;
    final controller = TextEditingController();
    final ok = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('비공개 댓글'),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: CupertinoTextField(
            controller: controller,
            obscureText: true,
            placeholder: '비밀번호를 입력하세요',
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: CupertinoColors.systemGrey6.resolveFrom(ctx),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('취소'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('확인'),
          ),
        ],
      ),
    );
    final enteredPassword = controller.text;
    controller.dispose();
    if (ok == true && mounted && enteredPassword == storedPassword) {
      setState(() => _unlockedIds.add(id));
    } else if (ok == true && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('비밀번호가 맞지 않습니다.')));
    }
  }

  Future<bool?> _showAddCommentSheet() async {
    final contentController = TextEditingController();
    final passwordController = TextEditingController();
    bool isPrivate = false;
    bool submitting = false;

    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (innerContext, setSheetState) {
            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.5,
              minChildSize: 0.3,
              maxChildSize: 0.8,
              builder: (_, scrollController) {
                return Container(
                  decoration: BoxDecoration(
                    color: Theme.of(innerContext).colorScheme.surface,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(AppShapes.radiusLarge),
                    ),
                  ),
                  child: SafeArea(
                    top: false,
                    child: Padding(
                      padding: EdgeInsets.all(innerContext.rs(20)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '댓글 작성',
                            style: AppFonts.scaled(
                              innerContext,
                              AppFonts.titleBold,
                            ),
                          ),
                          SizedBox(height: innerContext.rh(16)),
                          TextField(
                            controller: contentController,
                            maxLines: 3,
                            decoration: const InputDecoration(
                              labelText: '댓글 내용',
                              hintText: '댓글을 입력하세요',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          SizedBox(height: innerContext.rh(12)),
                          Row(
                            children: [
                              Text(
                                '비공개',
                                style: AppFonts.scaled(
                                  innerContext,
                                  AppFonts.bodyRegular,
                                ),
                              ),
                              Switch(
                                value: isPrivate,
                                onChanged: (v) =>
                                    setSheetState(() => isPrivate = v),
                              ),
                            ],
                          ),
                          if (isPrivate) ...[
                            SizedBox(height: innerContext.rh(8)),
                            TextField(
                              controller: passwordController,
                              obscureText: true,
                              decoration: const InputDecoration(
                                labelText: '비밀번호',
                                hintText: '비공개 댓글 열람용 비밀번호',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ],
                          SizedBox(height: innerContext.rh(20)),
                          FilledButton(
                            onPressed: submitting
                                ? null
                                : () async {
                                    final text = contentController.text.trim();
                                    if (text.isEmpty) {
                                      ScaffoldMessenger.of(
                                        innerContext,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text('댓글 내용을 입력하세요.'),
                                        ),
                                      );
                                      return;
                                    }
                                    final moderation =
                                        ContentModerationService.checkText(
                                          text,
                                        );
                                    if (moderation.hasAbuse) {
                                      ScaffoldMessenger.of(
                                        innerContext,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            '부적절한 표현이 포함되어 있어 댓글을 등록할 수 없습니다. 표현을 수정해 주세요.',
                                          ),
                                        ),
                                      );
                                      return;
                                    }
                                    final profile = await getCurrentProfile();
                                    if (profile == null) {
                                      if (innerContext.mounted) {
                                        ScaffoldMessenger.of(
                                          innerContext,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text('로그인이 필요합니다.'),
                                          ),
                                        );
                                      }
                                      return;
                                    }
                                    setSheetState(() => submitting = true);
                                    try {
                                      await supabase
                                          .from('suggestion_comments')
                                          .insert({
                                            'suggestion_id':
                                                widget.suggestionId,
                                            'author_id': profile.id,
                                            'content': text,
                                            'is_private': isPrivate,
                                            if (isPrivate &&
                                                passwordController.text
                                                    .trim()
                                                    .isNotEmpty)
                                              'password': passwordController
                                                  .text
                                                  .trim(),
                                          });
                                      if (sheetContext.mounted) {
                                        Navigator.of(sheetContext).pop(true);
                                      }
                                    } catch (e) {
                                      if (innerContext.mounted) {
                                        setSheetState(() => submitting = false);
                                        ScaffoldMessenger.of(
                                          innerContext,
                                        ).showSnackBar(
                                          SnackBar(content: Text('등록 실패: $e')),
                                        );
                                      }
                                    }
                                  },
                            child: submitting
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text('댓글 추가'),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final ctx = context;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildSectionHeader(
          ctx,
          title: '내용',
          trailing: CupertinoButton(
            padding: EdgeInsets.zero,
            minimumSize: const Size(44, 44),
            onPressed: () {
              showCupertinoModalPopup<void>(
                context: ctx,
                builder: (sheetCtx) => CupertinoActionSheet(
                  actions: [
                    CupertinoActionSheetAction(
                      onPressed: () {
                        Navigator.of(sheetCtx).pop();
                        widget.onReportSuggestion();
                      },
                      child: const Text('신고'),
                    ),
                    if (widget.onBlockAuthor != null)
                      CupertinoActionSheetAction(
                        isDestructiveAction: true,
                        onPressed: () {
                          Navigator.of(sheetCtx).pop();
                          widget.onBlockAuthor!();
                        },
                        child: const Text('작성자 차단'),
                      ),
                  ],
                  cancelButton: CupertinoActionSheetAction(
                    isDefaultAction: true,
                    onPressed: () => Navigator.of(sheetCtx).pop(),
                    child: const Text('취소'),
                  ),
                ),
              );
            },
            child: Icon(
              CupertinoIcons.ellipsis_circle,
              color: AppDesignColors.primary(ctx),
              size: 24,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        AppleCard(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Text(
            widget.baseBody,
            style: AppTypography.body(ctx).copyWith(
              color: AppDesignColors.label(ctx),
            ),
          ),
        ),
        if (widget.adminComment.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          _buildSectionHeader(ctx, title: '관리자 댓글'),
          const SizedBox(height: AppSpacing.xs),
          AppleCard(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Text(
              widget.adminComment,
              style: AppTypography.body(ctx).copyWith(
                color: AppDesignColors.primary(ctx),
              ),
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        Container(height: 1, color: AppDesignColors.separator(ctx)),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: Text(
                '댓글',
                style: AppTypography.footnote(ctx),
              ),
            ),
            AppleButton(
              label: '댓글 작성',
              variant: AppleButtonVariant.plain,
              onPressed: _loading
                  ? null
                  : () async {
                      final added = await _showAddCommentSheet();
                      if (added == true && mounted) {
                        _loadComments();
                      }
                    },
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        if (_loading)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: const CupertinoActivityIndicator(radius: 12),
            ),
          )
        else if (_comments.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: Text(
              '등록된 댓글이 없습니다.',
              style: AppTypography.footnote(ctx),
            ),
          )
        else
          ..._comments.map((c) => _buildCommentCard(ctx, c)),
      ],
    );
  }

  Widget _buildSectionHeader(
    BuildContext context, {
    required String title,
    Widget? trailing,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: AppTypography.footnote(context),
          ),
        ),
        if (trailing != null) trailing,
      ],
    );
  }

  void _openCommentOverflowMenu(
    BuildContext context,
    Map<String, dynamic> comment,
  ) {
    final id = comment['id'] as String?;
    final authorId = comment['author_id']?.toString();
    showCupertinoModalPopup<void>(
      context: context,
      builder: (sheetCtx) => CupertinoActionSheet(
        actions: [
          if (id != null)
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.of(sheetCtx).pop();
                _reportComment(id);
              },
              child: const Text('신고'),
            ),
          if (authorId != null)
            CupertinoActionSheetAction(
              isDestructiveAction: true,
              onPressed: () {
                Navigator.of(sheetCtx).pop();
                _blockAuthor(authorId);
              },
              child: const Text('작성자 차단'),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.of(sheetCtx).pop(),
          child: const Text('취소'),
        ),
      ),
    );
  }

  Widget _buildCommentCard(BuildContext context, Map<String, dynamic> comment) {
    final id = comment['id'] as String?;
    final content =
        (comment['content'] ?? comment['body'] ?? comment['comment'] ?? '')
            .toString();
    final isPrivate =
        comment['is_private'] == true || comment['is_private'] == 'true';
    final unlocked = id != null && _unlockedIds.contains(id);
    final authorId = comment['author_id']?.toString();

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: AppleCard(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: isPrivate && !unlocked
                  ? GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _showUnlockDialog(comment),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            CupertinoIcons.lock_fill,
                            size: 16,
                            color: AppDesignColors.secondaryLabel(context),
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Expanded(
                            child: Text(
                              '비공개 댓글입니다. 탭하여 비밀번호 입력',
                              style: AppTypography.footnote(context),
                            ),
                          ),
                        ],
                      ),
                    )
                  : Text(
                      content.isEmpty ? '(내용 없음)' : content,
                      style: AppTypography.body(context).copyWith(
                        color: AppDesignColors.label(context),
                      ),
                    ),
            ),
            if (id != null || authorId != null)
              CupertinoButton(
                padding: EdgeInsets.zero,
                minimumSize: const Size(44, 36),
                onPressed: () => _openCommentOverflowMenu(context, comment),
                child: Icon(
                  CupertinoIcons.ellipsis_vertical,
                  size: 18,
                  color: AppDesignColors.secondaryLabel(context),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _reportComment(String commentId) async {
    final reason = await _askReason();
    if (reason == null) return;
    try {
      await _contentReportRepo.reportContent(
        contentType: 'suggestion_comment',
        contentId: commentId,
        reason: reason,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('댓글 신고가 접수되었습니다.'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('댓글 신고 중 오류가 발생했습니다: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _blockAuthor(String profileId) async {
    try {
      await _blockRepo.blockProfile(profileId);
      await _loadComments();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('해당 사용자를 차단했습니다.'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('차단 중 오류가 발생했습니다: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<String?> _askReason() async {
    final controller = TextEditingController();
    String? selectedReason;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('신고하기'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: selectedReason,
                decoration: const InputDecoration(labelText: '사유 선택'),
                items: const [
                  DropdownMenuItem(value: '욕설/비하', child: Text('욕설/비하')),
                  DropdownMenuItem(value: '괴롭힘/따돌림', child: Text('괴롭힘/따돌림')),
                  DropdownMenuItem(value: '스팸', child: Text('스팸')),
                  DropdownMenuItem(value: '불법/위험 행위', child: Text('불법/위험 행위')),
                  DropdownMenuItem(value: '기타', child: Text('기타 (직접 입력)')),
                ],
                onChanged: (v) {
                  selectedReason = v;
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: '상세 사유 (선택)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('신고'),
            ),
          ],
        );
      },
    );

    if (ok != true) return null;
    final baseReason = selectedReason ?? '기타';
    final extra = controller.text.trim();
    return extra.isEmpty ? baseReason : '$baseReason - $extra';
  }
}
