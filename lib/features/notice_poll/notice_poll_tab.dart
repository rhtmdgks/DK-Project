import 'package:flutter/cupertino.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:myapp/components/components.dart';
import 'package:myapp/core/utils/avatar_url_resolver.dart';
import 'package:myapp/core/utils/avatar_utils.dart';
import 'package:myapp/core/supabase_client.dart';
import 'package:myapp/core/theme/app_theme.dart';
import 'package:myapp/core/theme/apple_design_tokens.dart' show AppleShape;
import 'package:myapp/core/theme/responsive.dart';
import 'package:myapp/core/widgets/app_feedback.dart';
import 'package:myapp/core/widgets/async_body.dart';
import 'package:myapp/core/widgets/m3_list.dart';
import 'package:myapp/design/design.dart';
import 'package:myapp/features/notice_poll/notice_poll_viewmodel.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// [createdAt] ISO 문자열을 "2월 18일" 형식으로 포맷.
String _formatDate(String? createdAt) {
  if (createdAt == null || createdAt.isEmpty) return '';
  try {
    final dt = DateTime.parse(createdAt);
    const months = ['1월', '2월', '3월', '4월', '5월', '6월', '7월', '8월', '9월', '10월', '11월', '12월'];
    return '${months[dt.month - 1]} ${dt.day}일';
  } catch (_) {
    return '';
  }
}

/// [createdAt] ISO 문자열을 "·21분전" 형태의 상대 시간으로 포맷.
String _formatTimeAgo(String? createdAt) {
  if (createdAt == null || createdAt.isEmpty) return '';
  try {
    final dt = DateTime.parse(createdAt).toLocal();
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return '·방금 전';
    if (diff.inMinutes < 60) return '·${diff.inMinutes}분전';
    if (diff.inHours < 24) return '·${diff.inHours}시간 전';
    if (diff.inDays < 7) return '·${diff.inDays}일 전';
    return '·${_formatDate(createdAt)}';
  } catch (_) {
    return '';
  }
}

/// [endsAt] 기준으로 "N days remaining" 스타일 문자열 (예: "3일 남음").
String _formatEndsAt(String? endsAt) {
  if (endsAt == null || endsAt.isEmpty) return '투표 종료';
  try {
    final end = DateTime.parse(endsAt).toLocal();
    final now = DateTime.now();
    if (end.isBefore(now)) return '투표 종료';
    final diff = end.difference(now);
    if (diff.inDays > 0) return '${diff.inDays}일 남음';
    if (diff.inHours > 0) return '${diff.inHours}시간 남음';
    return '${diff.inMinutes}분 남음';
  } catch (_) {
    return '투표 종료';
  }
}

/// poll_votes 리스트에서 옵션별 득표 수 반환. [optionCount]는 선택지 개수.
List<int> _optionCountsFromVotes(dynamic pollVotes, int optionCount) {
  final list = pollVotes is List ? pollVotes : null;
  if (list == null) return List.filled(optionCount, 0);
  final counts = List<int>.filled(optionCount, 0);
  for (final e in list) {
    final idx = e is Map ? e['option_index'] : null;
    if (idx is int && idx >= 0 && idx < optionCount) counts[idx]++;
  }
  return counts;
}

/// 작성자 프로필 사진. [avatarUrl]이 있으면 네트워크 이미지, 없으면 기본 아이콘.
Widget _buildAuthorAvatar(BuildContext context, String? avatarUrl) {
  final radius = context.rs(20);
  final resolved = resolveAvatarUrl(avatarUrl);
  if (resolved != null && resolved.isNotEmpty) {
    return ClipOval(
      child: Image.network(
        resolved,
        width: radius * 2,
        height: radius * 2,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _avatarCircle(
          context,
          radius,
          child: Icon(CupertinoIcons.person_fill, size: context.rs(22), color: AppColors.textSecondary),
        ),
      ),
    );
  }
  return _avatarCircle(
    context,
    radius,
    child: Icon(CupertinoIcons.person_fill, size: context.rs(22), color: AppColors.textSecondary),
  );
}

Widget _avatarCircle(BuildContext context, double radius, {required Widget child}) {
  return Container(
    width: radius * 2,
    height: radius * 2,
    decoration: const BoxDecoration(
      color: AppColors.surfaceContainerHigh,
      shape: BoxShape.circle,
    ),
    clipBehavior: Clip.antiAlias,
    child: Center(child: child),
  );
}

/// 댓글 작성자 아바타. [avatarUrl] 있으면 프로필 사진, 없으면 [authorId]로 DiceBear 생성, 둘 다 없으면 이름 첫 글자.
Widget _buildCommentAuthorAvatar(BuildContext context, String author, String? authorId, String? avatarUrl) {
  final radius = context.rs(14);
  final effectiveUrl = resolveAvatarUrl(avatarUrl) ??
      (authorId != null && authorId.isNotEmpty ? generateAvatarUrlPng(authorId) : null);
  if (effectiveUrl != null) {
    return ClipOval(
      child: Image.network(
        effectiveUrl,
        width: radius * 2,
        height: radius * 2,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _commentAvatarPlaceholder(context, radius, author),
      ),
    );
  }
  return _commentAvatarPlaceholder(context, radius, author);
}

Widget _commentAvatarPlaceholder(BuildContext context, double radius, String author) {
  return _avatarCircle(
    context,
    radius,
    child: Text(
      author.isNotEmpty ? author[0] : '?',
      style: AppFonts.scaled(context, AppFonts.smallMedium).copyWith(
        color: AppColors.textPrimary,
      ),
    ),
  );
}

/// 공지/투표 탭. 반응형 대응.
///
/// [TabBar]로 공지사항과 투표를 분리하여 표시한다.
class NoticePollTab extends StatefulWidget {
  const NoticePollTab({super.key});

  @override
  State<NoticePollTab> createState() => _NoticePollTabState();
}

class _NoticePollTabState extends State<NoticePollTab> {
  int _segmentIndex = 0;
  late NoticePollViewModel _viewModel;
  RealtimeChannel? _pollsChannel;

  @override
  void initState() {
    super.initState();
    _viewModel = NoticePollViewModel()..addListener(_onViewModelChanged);
    _viewModel.fetchAnnouncements();
    _viewModel.fetchPolls();
    _subscribePollsRealtime();
  }

  void _onViewModelChanged() {
    if (mounted) setState(() {});
  }

  /// 백오피스에서 투표 생성/수정/삭제 시 목록 자동 갱신.
  void _subscribePollsRealtime() {
    _pollsChannel = supabase
        .channel('notice_poll_polls')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'polls',
          callback: (_) {
            if (mounted) _viewModel.fetchPolls();
          },
        )
        .subscribe();
  }

  @override
  void dispose() {
    _pollsChannel?.unsubscribe();
    _viewModel.removeListener(_onViewModelChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppDesignColors.groupedBackground(context),
      child: Column(
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
                  Text('공지 / 투표', style: AppTypography.largeTitle(context)),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '학교 공지와 실시간 투표를 한 화면에서 확인하세요.',
                    style: AppTypography.subheadline(context),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  CupertinoSlidingSegmentedControl<int>(
                    groupValue: _segmentIndex,
                    children: const <int, Widget>{
                      0: Padding(
                        padding: EdgeInsets.symmetric(vertical: AppSpacing.xs),
                        child: Text('공지사항'),
                      ),
                      1: Padding(
                        padding: EdgeInsets.symmetric(vertical: AppSpacing.xs),
                        child: Text('투표'),
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
              children: [
                _buildAnnouncementsBody(),
                _buildPollsBody(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnnouncementsBody() {
    return AsyncBody(
      loading: _viewModel.loadingAnnouncements,
      error: _viewModel.errorAnnouncements,
      isEmpty: _viewModel.announcements.isEmpty,
      onRetry: _viewModel.fetchAnnouncements,
      emptyMessage: '공지사항이 없습니다.',
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        slivers: [
          CupertinoSliverRefreshControl(
            onRefresh: _viewModel.fetchAnnouncements,
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.xs,
              AppSpacing.md,
              AppSpacing.xl,
            ),
            sliver: SliverList.separated(
              itemCount: _viewModel.announcements.length,
              separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, index) =>
                  _buildAnnouncementTile(context, _viewModel.announcements[index]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnnouncementTile(BuildContext context, Map<String, dynamic> a) {
    final title = a['title'] as String? ?? '';
    final body = a['body'] as String? ?? '';
    final dateStr = _formatDate(a['created_at'] as String?);
    return AppleCard(
      onTap: () => showM3DetailSheet(
        context,
        title: title.isEmpty ? '(제목 없음)' : title,
        body: body.isEmpty ? '내용 없음' : body,
        secondary: dateStr,
      ),
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
                  style: AppTypography.headline(context).copyWith(
                    color: AppDesignColors.label(context),
                  ),
                ),
              ),
              if (dateStr.isNotEmpty) ...[
                const SizedBox(width: AppSpacing.xs),
                Text(dateStr, style: AppTypography.caption(context)),
              ],
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
            Text(
              body,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.subheadline(context),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPollsBody() {
    return AsyncBody(
      loading: _viewModel.loadingPolls,
      error: _viewModel.errorPolls,
      isEmpty: _viewModel.polls.isEmpty,
      onRetry: _viewModel.fetchPolls,
      emptyMessage: '투표가 없습니다.',
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        slivers: [
          CupertinoSliverRefreshControl(onRefresh: _viewModel.fetchPolls),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              AppSpacing.xl,
            ),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, i) {
                  final poll = _viewModel.polls[i];
                  final pollId = poll['id'] as String?;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: PollPostCard(
                      poll: poll,
                      onTap: () => _showPollDetail(context, poll),
                      onLikeTap: pollId != null
                          ? () => _onLikeTap(context, pollId)
                          : null,
                    ),
                  );
                },
                childCount: _viewModel.polls.length,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _onLikeTap(BuildContext context, String pollId) async {
    try {
      final result = await _viewModel.togglePollLike(pollId);
      if (!context.mounted) return;
      if (result == null) {
        AppFeedback.showToast(context, '로그인이 필요해요');
      }
    } catch (e) {
      if (context.mounted) {
        AppFeedback.showError(context, '좋아요에 실패했어요. 다시 시도해 주세요.');
      }
    }
  }

  void _showPollDetail(BuildContext context, Map<String, dynamic> poll) {
    GlassSheet.show<void>(
      context: context,
      quality: kAppGlassQuality,
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.86,
          minChildSize: 0.45,
          maxChildSize: 0.95,
          builder: (sheetContext, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: AppDesignColors.elevatedSurface(sheetContext),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppRadius.lg),
                ),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  children: [
                    const SizedBox(height: AppSpacing.sm),
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppDesignColors.separator(sheetContext),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        controller: scrollController,
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _PollCard(
                              poll: poll,
                              viewModel: _viewModel,
                              onVote: () {
                                _viewModel.fetchPolls();
                                if (sheetContext.mounted) Navigator.of(sheetContext).pop();
                              },
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            Text(
                              '댓글',
                              style: AppTypography.title3(sheetContext),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            _PollCommentsSection(
                              pollId: poll['id'] as String? ?? '',
                              viewModel: _viewModel,
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
    );
  }
}

// ────────────────────────────────────────────────────────────
// PollPostCard - 게시물형 투표 카드 (Figma 투표 페이지 UI)
// ────────────────────────────────────────────────────────────

/// 스크린샷 기준 게시물 UI: 프로필·이름·시간·더보기, 질문·N표·투표하면 결과 보기, 옵션 바(색상·체크·아바타·%), 공개 투표·N일 남음, 좋아요·댓글·공유.
class PollPostCard extends StatelessWidget {
  const PollPostCard({
    super.key,
    required this.poll,
    required this.onTap,
    this.onLikeTap,
  });

  final Map<String, dynamic> poll;
  final VoidCallback onTap;
  /// 좋아요 아이콘 탭 시 호출 (카드 onTap은 발생하지 않음).
  final VoidCallback? onLikeTap;

  @override
  Widget build(BuildContext context) {
    final question = poll['question'] as String? ?? '';
    final options = poll['options'] as List<dynamic>? ?? [];
    final optionsList = options.map((e) => e is String ? e : e.toString()).toList();
    final optionCount = optionsList.length;
    final votes = poll['poll_votes'] as List<dynamic>?;
    final optionCounts = _optionCountsFromVotes(votes, optionCount);
    final totalVotes = optionCounts.fold<int>(0, (a, b) => a + b);
    final createdAt = poll['created_at'] as String?;
    final endsAt = poll['ends_at'] as String?;
    final isEnded = endsAt != null && endsAt.isNotEmpty && DateTime.parse(endsAt).toLocal().isBefore(DateTime.now());
    final likeCount = poll['like_count'] as int? ?? 0;
    final commentCount = poll['comment_count'] as int? ?? 0;
    final userHasLiked = poll['user_has_liked'] as bool? ?? false;
    // 최다 득표 옵션 인덱스(동률 시 첫 번째) → 해당 옵션만 녹색·체크 표시
    int leadingIndex = 0;
    if (optionCount > 0) {
      int maxCount = optionCounts[0];
      for (int i = 1; i < optionCount; i++) {
        if (optionCounts[i] > maxCount) {
          maxCount = optionCounts[i];
          leadingIndex = i;
        }
      }
    }

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: EdgeInsets.all(context.rs(16)),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(AppleShape.radiusUtilityCard),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 헤더: 프로필 사진 + 이름·시간 + 더보기(⋮)
              Row(
                children: [
                  _buildAuthorAvatar(context, poll['author_avatar_url'] as String?),
                  SizedBox(width: context.rs(12)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          poll['author_name'] as String? ?? '대덕고등학교 학생회',
                          style: AppFonts.scaled(context, AppFonts.titleSemiBold).copyWith(
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          _formatTimeAgo(createdAt),
                          style: AppFonts.scaled(context, AppFonts.captionRegular).copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 44,
                    height: 44,
                    child: CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: () {},
                      child: Icon(
                        CupertinoIcons.ellipsis_vertical,
                        size: context.rs(22),
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: context.rh(12)),
              // 투표 질문 영역
              Text(
                question.isEmpty ? '(투표)' : question,
                style: AppFonts.scaled(context, AppFonts.titleSemiBold).copyWith(
                  color: AppColors.textDark,
                ),
              ),
              SizedBox(height: context.rh(4)),
              Text(
                totalVotes > 0
                    ? '$totalVotes표 • 결과 보려면 투표하세요'
                    : '투표하면 결과 보기',
                style: AppFonts.scaled(context, AppFonts.captionRegular).copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              SizedBox(height: context.rh(12)),
              // 옵션 바 (녹색/회색/보라 변형 + 체크 + 아바타·%)
              ...optionsList.asMap().entries.map((e) {
                final idx = e.key;
                final label = e.value;
                final count = optionCounts[idx];
                final pct = totalVotes > 0 ? (count / totalVotes * 100).round() : 0;
                final isLeading = idx == leadingIndex && totalVotes > 0;
                final voterAvatars = (poll['option_avatar_urls'] as List<dynamic>?)?[idx] as List<dynamic>?;
                final avatarUrls = voterAvatars
                    ?.map((e) => e is String ? e : null)
                    .whereType<String?>()
                    .toList() ?? [];
                return Padding(
                  padding: EdgeInsets.only(bottom: context.rh(8)),
                  child: _PollOptionBar(
                    label: label,
                    percent: pct,
                    optionIndex: idx,
                    isLeading: isLeading,
                    voterAvatarUrls: avatarUrls,
                  ),
                );
              }),
              SizedBox(height: context.rh(12)),
              // 바닥글: 공개 투표 | N일 남음
              Row(
                children: [
                  Icon(CupertinoIcons.eye, size: context.rs(14), color: AppColors.textSecondary),
                  SizedBox(width: context.rs(4)),
                  Text(
                    isEnded ? '투표 종료' : '공개 투표',
                    style: AppFonts.scaled(context, AppFonts.captionRegular).copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const Spacer(),
                  Icon(CupertinoIcons.time, size: context.rs(14), color: AppColors.textSecondary),
                  SizedBox(width: context.rs(4)),
                  Text(
                    _formatEndsAt(endsAt),
                    style: AppFonts.scaled(context, AppFonts.captionRegular).copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              SizedBox(height: context.rh(12)),
              // 액션: 좋아요 · 댓글 · 공유
              Row(
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onLikeTap,
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        vertical: context.rh(10),
                        horizontal: context.rs(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            userHasLiked
                                ? CupertinoIcons.heart_fill
                                : CupertinoIcons.heart,
                            size: context.rs(22),
                            color: userHasLiked
                                ? AppColors.error
                                : AppColors.textSecondary,
                          ),
                          SizedBox(width: context.rs(4)),
                          Text(
                            '$likeCount',
                            style: AppFonts.scaled(context, AppFonts.smallMedium).copyWith(
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(width: context.rs(20)),
                  Icon(
                    CupertinoIcons.chat_bubble_2,
                    size: context.rs(22),
                    color: AppColors.textSecondary,
                  ),
                  SizedBox(width: context.rs(4)),
                  Text(
                    '$commentCount',
                    style: AppFonts.scaled(context, AppFonts.smallMedium).copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '공유',
                    style: AppFonts.scaled(context, AppFonts.smallMedium).copyWith(
                      color: AppColors.primaryBlue,
                    ),
                  ),
                  SizedBox(width: context.rs(4)),
                  Icon(
                    CupertinoIcons.share,
                    size: context.rs(18),
                    color: AppColors.primaryBlue,
                  ),
                ],
              ),
            ],
          ),
        ),
    );
  }
}

/// 옵션 한 줄: 배경(녹색/회색/보라) + 체크(선택 시) + 텍스트 + 겹친 투표자 아바타 + 득표율(%).
class _PollOptionBar extends StatelessWidget {
  const _PollOptionBar({
    required this.label,
    required this.percent,
    required this.optionIndex,
    required this.isLeading,
    this.voterAvatarUrls = const [],
  });

  final String label;
  final int percent;
  final int optionIndex;
  final bool isLeading;
  /// 해당 옵션에 투표한 사람들의 프로필 사진 URL (먼저 투표한 순, 1등 4개·2등 3개·나머지 2개).
  final List<String?> voterAvatarUrls;

  @override
  Widget build(BuildContext context) {
    final bg = isLeading
        ? AppColors.primaryBlue.withValues(alpha: 0.08)
        : (optionIndex.isEven
            ? AppColors.surfaceContainerLowest
            : AppColors.white);

    return Container(
      padding: EdgeInsets.symmetric(horizontal: context.rs(12), vertical: context.rh(10)),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppleShape.radiusSmHairline),
        border: Border.all(
          color: isLeading ? AppColors.primaryBlue : AppColors.border,
          width: isLeading ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          if (isLeading)
            Padding(
              padding: EdgeInsets.only(right: context.rs(8)),
              child: Icon(
                CupertinoIcons.check_mark_circled_solid,
                size: context.rs(18),
                color: AppColors.primaryBlue,
              ),
            ),
          Expanded(
            child: Text(
              label,
              style: AppFonts.scaled(context, AppFonts.smallMedium).copyWith(
                color: AppColors.textPrimary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (percent > 0) _buildStackedAvatars(context),
          if (percent > 0) SizedBox(width: context.rs(8)),
          Text(
            '$percent%',
            style: AppFonts.scaled(context, AppFonts.smallMedium).copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  /// 겹쳐진 작은 원형 아바타: 투표자 프로필 사진(URL) 또는 플레이스홀더.
  Widget _buildStackedAvatars(BuildContext context) {
    final urls = voterAvatarUrls;
    final n = urls.isNotEmpty ? urls.length : 1;
    final r = context.rs(14);
    final overlap = context.rs(8);
    final colors = [
      AppColors.primaryBlue500,
      const Color(0xFF9C27B0),
      const Color(0xFFFFB74D),
      const Color(0xFF26A69A),
    ];
    return SizedBox(
      width: r * 2 * n - overlap * (n - 1) + 4,
      height: r * 2 + 4,
      child: Stack(
        children: List.generate(n, (i) {
          final url = i < urls.length ? urls[i] : null;
          final hasUrl = url != null && url.isNotEmpty;
          return Positioned(
            left: (r * 2 - overlap) * i.toDouble(),
            child: Container(
              width: r * 2,
              height: r * 2,
              decoration: BoxDecoration(
                color: hasUrl ? AppColors.border : colors[i % colors.length],
                shape: BoxShape.circle,
              ),
              clipBehavior: Clip.antiAlias,
              child: hasUrl
                  ? Image.network(
                      url,
                      width: r * 2,
                      height: r * 2,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Icon(
                        CupertinoIcons.person_fill,
                        size: context.rs(16),
                        color: AppColors.textSecondary,
                      ),
                    )
                  : Center(
                      child: Text(
                        String.fromCharCode(0x41 + (optionIndex + i) % 5),
                        style: AppFonts.scaled(context, AppFonts.tiny).copyWith(
                          color: AppColors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
            ),
          );
        }),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────
// PollCommentsSection - 투표 상세 시트 내 댓글 목록 + 작성
// ────────────────────────────────────────────────────────────

class _PollCommentsSection extends StatefulWidget {
  const _PollCommentsSection({
    required this.pollId,
    required this.viewModel,
  });

  final String pollId;
  final NoticePollViewModel viewModel;

  @override
  State<_PollCommentsSection> createState() => _PollCommentsSectionState();
}

class _PollCommentsSectionState extends State<_PollCommentsSection> {
  List<Map<String, dynamic>> _comments = [];
  bool _loading = true;
  final TextEditingController _controller = TextEditingController();
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    if (widget.pollId.isEmpty) {
      if (mounted) setState(() { _loading = false; });
      return;
    }
    setState(() => _loading = true);
    try {
      final list = await widget.viewModel.getPollComments(widget.pollId);
      if (mounted) {
        setState(() {
          _comments = list;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _sendComment() async {
    final content = _controller.text.trim();
    if (content.isEmpty || _sending) return;
    if (!mounted) return;
    setState(() => _sending = true);
    try {
      await widget.viewModel.addPollComment(
        pollId: widget.pollId,
        content: content,
      );
      _controller.clear();
      await _loadComments();
      widget.viewModel.fetchPolls();
    } catch (e) {
      if (mounted) {
        final msg = e is Exception
            ? e.toString().replaceFirst('Exception: ', '')
            : '댓글 등록에 실패했어요. 다시 시도해 주세요.';
        AppFeedback.showError(context, msg);
      }
    }
    if (mounted) setState(() => _sending = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Center(child: CupertinoActivityIndicator()),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ..._comments.map((c) {
          final author = c['author_name'] as String? ?? '알 수 없음';
          final authorId = c['author_id'] as String?;
          final avatarUrl = c['author_avatar_url'] as String?;
          final body = c['content'] as String? ?? '';
          final createdAt = c['created_at'] as String?;
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: AppleCard(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildCommentAuthorAvatar(context, author, authorId, avatarUrl),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        author,
                        style: AppTypography.subheadline(context).copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppDesignColors.label(context),
                        ),
                      ),
                      if (createdAt != null)
                        Text(
                          _formatTimeAgo(createdAt),
                          style: AppTypography.caption(context),
                        ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        body,
                        style: AppTypography.body(context).copyWith(
                          color: AppDesignColors.label(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            ),
          );
        }),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: AppleTextField(
                controller: _controller,
                placeholder: '댓글 입력...',
                maxLines: 2,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendComment(),
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            AppleButton(
              label: '전송',
              loading: _sending,
              onPressed: _sending ? null : _sendComment,
            ),
          ],
        ),
      ],
    );
  }
}

// ────────────────────────────────────────────────────────────
// PollCard - 개별 투표 카드 (바텀시트 상세)
// ────────────────────────────────────────────────────────────

class _PollCard extends StatefulWidget {
  const _PollCard({
    required this.poll,
    required this.viewModel,
    required this.onVote,
  });

  final Map<String, dynamic> poll;
  final NoticePollViewModel viewModel;
  final VoidCallback onVote;

  @override
  State<_PollCard> createState() => _PollCardState();
}

class _PollCardState extends State<_PollCard> {
  bool _loading = false;
  String? _error;
  bool _voted = false;
  int? _selectedIndex;

  @override
  void initState() {
    super.initState();
    _loadVoteStatus();
  }

  Future<void> _loadVoteStatus() async {
    final pollId = widget.poll['id'] as String?;
    if (pollId == null) return;

    final res = await widget.viewModel.getPollVote(pollId);

    if (!mounted) return;
    setState(() {
      _voted = res != null;
      if (res != null) _selectedIndex = res['option_index'] as int?;
    });
  }

  Future<void> _vote() async {
    if (_selectedIndex == null) return;

    final pollId = widget.poll['id'] as String?;
    if (pollId == null) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await widget.viewModel.vote(pollId, _selectedIndex!);

      if (!mounted) return;
      setState(() {
        _voted = true;
        _loading = false;
      });
      widget.onVote();
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
    final question = widget.poll['question'] as String? ?? '';
    final options = widget.poll['options'] as List<dynamic>? ?? [];
    final optionsList =
        options.map((e) => e is String ? e : e.toString()).toList();
    final createdAt = widget.poll['created_at'] as String?;

    return AppleCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildAuthorAvatar(context, widget.poll['author_avatar_url'] as String?),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.poll['author_name'] as String? ?? '대덕고등학교 학생회',
                        style: AppTypography.subheadline(context).copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppDesignColors.label(context),
                        ),
                      ),
                      if (createdAt != null && createdAt.isNotEmpty)
                        Text(
                          _formatTimeAgo(createdAt),
                          style: AppTypography.caption(context),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              question,
              style: AppTypography.headline(context).copyWith(
                color: AppDesignColors.label(context),
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xxs),
                child: Text(
                  _error!,
                  style: AppTypography.footnote(context).copyWith(
                    color: AppDesignColors.destructive(context),
                  ),
                ),
              ),
            const SizedBox(height: AppSpacing.sm),
            ...optionsList.asMap().entries.map((e) {
              final idx = e.key;
              final opt = e.value;
              final selected = _selectedIndex == idx;
              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: CupertinoButton(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.sm,
                  ),
                  color: selected
                      ? AppDesignColors.primary(context).withValues(alpha: 0.12)
                      : AppDesignColors.surface(context),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  onPressed: _voted ? null : () => setState(() => _selectedIndex = idx),
                  child: Row(
                    children: [
                      Icon(
                        selected
                            ? CupertinoIcons.check_mark_circled_solid
                            : CupertinoIcons.circle,
                        size: 20,
                        color: selected
                            ? AppDesignColors.primary(context)
                            : AppDesignColors.secondaryLabel(context),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Text(
                          opt,
                          style: AppTypography.body(context).copyWith(
                            color: AppDesignColors.label(context),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
            if (!_voted && _selectedIndex != null)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs),
                child: SizedBox(
                  width: double.infinity,
                  child: AppleButton(
                    label: '투표하기',
                    loading: _loading,
                    fullWidth: true,
                    onPressed: _loading ? null : _vote,
                  ),
                ),
              ),
            if (_voted)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs),
                child: Text(
                  '투표 완료',
                  style: AppTypography.caption(context),
                ),
              ),
          ],
        ),
    );
  }
}
