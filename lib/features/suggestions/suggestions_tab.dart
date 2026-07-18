import 'package:flutter/cupertino.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:myapp/components/components.dart';
import 'package:myapp/core/auth/auth_repository.dart';
import 'package:myapp/core/auth/auth_state.dart';
import 'package:myapp/core/routing/app_router.dart';
import 'package:myapp/core/supabase_client.dart';
import 'package:myapp/core/theme/app_resolved_colors.dart';
import 'package:myapp/core/theme/app_theme.dart';
import 'package:myapp/core/theme/apple_design_tokens.dart' show AppleShape;
import 'package:myapp/core/theme/responsive.dart';
import 'package:myapp/core/widgets/app_feedback.dart';
import 'package:myapp/core/widgets/async_body.dart';
import 'package:myapp/core/widgets/dismiss_keyboard.dart';
import 'package:myapp/core/widgets/m3_list.dart';
import 'package:myapp/design/design.dart';
import 'package:myapp/repositories/content_report_repository.dart';
import 'package:myapp/repositories/suggestions_repository.dart';
import 'package:myapp/repositories/user_block_repository.dart';
import 'package:myapp/services/content_moderation_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

class _SuggestionsTabState extends State<SuggestionsTab> {
  int _segmentIndex = 0;

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
    _loadProfile();
    _fetch();
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
        AppFeedback.showError(context, '관리자를 찾을 수 없습니다');
        return;
      }

      final currentUserId = await AuthRepository.instance.getUserId();
      if (currentUserId == null) {
        if (!mounted) return;
        AppFeedback.showError(context, '로그인이 필요합니다');
        return;
      }

      final result = await supabase.rpc(
        'create_or_get_direct_chat',
        params: {'p_other_user_id': adminUserId, 'p_user_id': currentUserId},
      );

      if (result == null) {
        if (!mounted) return;
        AppFeedback.showError(context, '채팅방을 생성할 수 없습니다');
        return;
      }

      final resultMap = result as Map<String, dynamic>;
      final roomId = resultMap['room_id'] as String?;
      if (roomId == null) {
        if (!mounted) return;
        AppFeedback.showError(context, '채팅방 ID를 가져올 수 없습니다');
        return;
      }

      if (!mounted) return;
      context.push('${AppRoute.chatList.path}/$roomId');
    } on PostgrestException catch (e) {
      if (!mounted) return;
      if (e.code == 'P0001' && e.message.contains('cannot_chat_with_self')) {
        // 관리자 계정이 자기 자신에게 채팅을 시도하는 경우 – 친절한 안내로 대체
        AppFeedback.showError(
          context,
          '관리자 계정에서는 이 버튼 대신 건의함 채팅 또는 기존 채팅방을 이용해 주세요.',
        );
      } else {
        AppFeedback.showError(context, '채팅방을 여는 중 오류가 발생했습니다: ${e.message}');
      }
    } catch (e) {
      if (!mounted) return;
      AppFeedback.showError(context, '채팅방을 여는 중 오류가 발생했습니다: $e');
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
      child: ColoredBox(
        color: AppDesignColors.groupedBackground(context),
        child: Stack(
          children: [
            Column(
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
                          groupValue: _segmentIndex,
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
                            setState(() => _segmentIndex = value);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: IndexedStack(
                    index: _segmentIndex,
                    children: [_buildListBody(), _buildChatSection()],
                  ),
                ),
              ],
            ),
            if (_segmentIndex == 0)
              Positioned(
                right: 16,
                bottom: 28,
                child: CupertinoButton(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  color: AppDesignColors.primary(context),
                  borderRadius: BorderRadius.circular(999),
                  onPressed: _showAddSuggestionBottomSheet,
                  child: const Icon(CupertinoIcons.add),
                ),
              ),
          ],
        ),
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
    final reason = await _pickReportReason(context);
    if (reason == null) return;

    try {
      await _contentReportRepo.reportContent(
        contentType: contentType,
        contentId: contentId,
        reason: reason,
      );
      if (!context.mounted) return;
      AppFeedback.showSuccess(context, '신고가 접수되었습니다.');
    } catch (e) {
      if (!context.mounted) return;
      AppFeedback.showError(context, '신고 중 오류가 발생했습니다: $e');
    }
  }

  Future<void> _blockAuthorAndRefresh(String profileId) async {
    try {
      await _blockRepo.blockProfile(profileId);
      await _fetch();
      if (!mounted) return;
      AppFeedback.showSuccess(context, '해당 사용자를 차단했습니다.');
    } catch (e) {
      if (!mounted) return;
      AppFeedback.showError(context, '차단 중 오류가 발생했습니다: $e');
    }
  }

  void _showAddSuggestionBottomSheet() {
    final titleController = TextEditingController();
    final bodyController = TextEditingController();
    bool submitting = false;
    final overlayContext = rootNavigatorKey.currentContext ?? context;

    GlassSheet.show<bool>(
      context: overlayContext,
      quality: kAppGlassQuality,
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
                                    AppFeedback.showError(
                                      innerContext,
                                      '부적절한 표현이 포함되어 있어 건의를 등록할 수 없습니다.',
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
        AppFeedback.showSuccess(context, '등록되었습니다.');
      }
    });
  }
}

Future<String?> _pickReportReason(BuildContext context) async {
  const reasons = [
    '욕설/비하',
    '괴롭힘/따돌림',
    '스팸',
    '불법/위험 행위',
    '기타 (직접 입력)',
  ];
  final detailController = TextEditingController();
  String? selectedReason;

  final confirmed = await GlassSheet.show<bool>(
    context: context,
    quality: kAppGlassQuality,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (innerCtx, setSheetState) {
          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('신고하기', style: AppTypography.title2(innerCtx)),
                  const SizedBox(height: AppSpacing.sm),
                  for (final reason in reasons)
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: () => setSheetState(() => selectedReason = reason),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Row(
                          children: [
                            Icon(
                              selectedReason == reason
                                  ? CupertinoIcons.check_mark_circled_solid
                                  : CupertinoIcons.circle,
                              size: 20,
                              color: AppDesignColors.primary(innerCtx),
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            Expanded(child: Text(reason)),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: AppSpacing.sm),
                  AppleTextField(
                    controller: detailController,
                    placeholder: '상세 사유 (선택)',
                    maxLines: 2,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      Expanded(
                        child: AppleButton(
                          label: '취소',
                          variant: AppleButtonVariant.secondary,
                          onPressed: () => Navigator.of(innerCtx).pop(false),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: AppleButton(
                          label: '신고',
                          onPressed: () => Navigator.of(innerCtx).pop(true),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );

  final detail = detailController.text.trim();
  detailController.dispose();
  if (confirmed != true) return null;
  final baseReason = selectedReason ?? '기타';
  return detail.isEmpty ? baseReason : '$baseReason - $detail';
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
      AppFeedback.showError(context, '제목을 입력해 주세요.');
      return;
    }

    final bodyText = _bodyController.text.trim();
    final moderation = ContentModerationService.checkText('$title\n$bodyText');
    if (moderation.hasAbuse) {
      if (!mounted) return;
      AppFeedback.showError(
        context,
        '부적절한 표현이 포함되어 있어 건의를 등록할 수 없습니다. 표현을 수정해 주세요.',
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
      AppFeedback.showSuccess(context, '등록 되었습니다.');
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
      AppFeedback.showError(
        context,
        isSessionError
            ? '서버 인증 세션이 없습니다. 로그아웃 후 다시 로그인해 주세요.'
            : '등록 중 오류가 발생했습니다: $e',
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
      AppFeedback.showError(context, '비밀번호가 맞지 않습니다.');
    }
  }

  Future<bool?> _showAddCommentSheet() async {
    final contentController = TextEditingController();
    final passwordController = TextEditingController();
    bool isPrivate = false;
    bool submitting = false;

    return GlassSheet.show<bool>(
      context: context,
      quality: kAppGlassQuality,
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
                    color: innerContext.appColors.surface,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(AppShapes.radiusLarge),
                    ),
                  ),
                  child: SafeArea(
                    top: false,
                    child: SingleChildScrollView(
                      controller: scrollController,
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
                          AppleTextField(
                            controller: contentController,
                            placeholder: '댓글 내용',
                            maxLines: 3,
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
                              CupertinoSwitch(
                                value: isPrivate,
                                onChanged: (v) =>
                                    setSheetState(() => isPrivate = v),
                              ),
                            ],
                          ),
                          if (isPrivate) ...[
                            SizedBox(height: innerContext.rh(8)),
                            AppleTextField(
                              controller: passwordController,
                              placeholder: '비공개 댓글 열람용 비밀번호',
                              obscureText: true,
                            ),
                          ],
                          SizedBox(height: innerContext.rh(20)),
                          AppleButton(
                            label: '댓글 추가',
                            fullWidth: true,
                            loading: submitting,
                            onPressed: submitting
                                ? null
                                : () async {
                                    final text = contentController.text.trim();
                                    if (text.isEmpty) {
                                      AppFeedback.showError(
                                        innerContext,
                                        '댓글 내용을 입력하세요.',
                                      );
                                      return;
                                    }
                                    final moderation =
                                        ContentModerationService.checkText(
                                          text,
                                        );
                                    if (moderation.hasAbuse) {
                                      AppFeedback.showError(
                                        innerContext,
                                        '부적절한 표현이 포함되어 있어 댓글을 등록할 수 없습니다. 표현을 수정해 주세요.',
                                      );
                                      return;
                                    }
                                    final profile = await getCurrentProfile();
                                    if (profile == null) {
                                      if (innerContext.mounted) {
                                        AppFeedback.showError(
                                          innerContext,
                                          '로그인이 필요합니다.',
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
                                        AppFeedback.showError(
                                          innerContext,
                                          '등록 실패: $e',
                                        );
                                      }
                                    }
                                  },
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
      AppFeedback.showSuccess(context, '댓글 신고가 접수되었습니다.');
    } catch (e) {
      if (!mounted) return;
      AppFeedback.showError(context, '댓글 신고 중 오류가 발생했습니다: $e');
    }
  }

  Future<void> _blockAuthor(String profileId) async {
    try {
      await _blockRepo.blockProfile(profileId);
      await _loadComments();
      if (!mounted) return;
      AppFeedback.showSuccess(context, '해당 사용자를 차단했습니다.');
    } catch (e) {
      if (!mounted) return;
      AppFeedback.showError(context, '차단 중 오류가 발생했습니다: $e');
    }
  }

  Future<String?> _askReason() => _pickReportReason(context);
}
