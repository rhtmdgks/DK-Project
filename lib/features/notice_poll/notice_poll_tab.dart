import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:myapp/core/utils/avatar_url_resolver.dart';
import 'package:myapp/core/utils/avatar_utils.dart';
import 'package:myapp/core/supabase_client.dart';
import 'package:myapp/core/theme/app_theme.dart';
import 'package:myapp/core/theme/responsive.dart';
import 'package:myapp/core/widgets/async_body.dart';
import 'package:myapp/core/widgets/m3_list.dart';
import 'package:myapp/core/widgets/tab_page_header.dart';
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
        errorBuilder: (_, __, ___) => CircleAvatar(
          radius: radius,
          backgroundColor: AppColors.surfaceContainerHigh,
          child: Icon(Icons.person, size: context.rs(22), color: AppColors.textSecondary),
        ),
      ),
    );
  }
  return CircleAvatar(
    radius: radius,
    backgroundColor: AppColors.surfaceContainerHigh,
    child: Icon(Icons.person, size: context.rs(22), color: AppColors.textSecondary),
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
  return CircleAvatar(
    radius: radius,
    backgroundColor: AppColors.surfaceContainerHigh,
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

class _NoticePollTabState extends State<NoticePollTab>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late NoticePollViewModel _viewModel;
  RealtimeChannel? _pollsChannel;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppColors.background,
      child: Column(
        children: [
          SafeArea(
            top: true,
            bottom: false,
            minimum: EdgeInsets.zero,
            child: Padding(
              padding: EdgeInsets.only(left: context.rs(16)),
              child: TabPageHeader(
                title: '공지 / 투표',
                subtitle: '공지사항과 투표를 확인하세요.',
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          Expanded(
            child: Material(
              type: MaterialType.transparency,
              child: Column(
                children: [
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: context.rs(22)),
                    child: TabBar.secondary(
                      controller: _tabController,
                      indicatorColor: AppColors.primaryBlue500,
                      tabs: const [
                        Tab(text: '공지사항'),
                        Tab(text: '투표'),
                      ],
                    ),
                  ),
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildAnnouncementsBody(),
                        _buildPollsBody(),
                      ],
                    ),
                  ),
                ],
              ),
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
      child: RefreshIndicator(
        onRefresh: _viewModel.fetchAnnouncements,
        color: Theme.of(context).colorScheme.primary,
        child: ListView.separated(
          padding: EdgeInsets.fromLTRB(
            context.rs(22),
            context.rh(16),
            context.rs(22),
            context.rh(16),
          ),
          itemCount: _viewModel.announcements.length,
          separatorBuilder: (_, __) => Divider(height: 1),
          itemBuilder: (context, i) {
            final a = _viewModel.announcements[i];
            final title = a['title'] as String? ?? '';
            final body = a['body'] as String? ?? '';
            final dateStr = _formatDate(a['created_at'] as String?);
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
                  SizedBox(width: context.rs(4)),
                  Icon(Icons.chevron_right, size: context.rs(20), color: AppColors.hint),
                ],
              ),
              onTap: () => showM3DetailSheet(
                context,
                title: title.isEmpty ? '(제목 없음)' : title,
                body: body.isEmpty ? '내용 없음' : body,
                secondary: dateStr,
              ),
            );
          },
        ),
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
      child: RefreshIndicator(
        onRefresh: _viewModel.fetchPolls,
        color: Theme.of(context).colorScheme.primary,
        child: ListView.separated(
          padding: EdgeInsets.fromLTRB(
            context.rs(22),
            context.rh(16),
            context.rs(22),
            context.rh(24),
          ),
          itemCount: _viewModel.polls.length,
          separatorBuilder: (_, __) => SizedBox(height: context.rh(16)),
          itemBuilder: (context, i) {
            final poll = _viewModel.polls[i];
            final pollId = poll['id'] as String?;
            return PollPostCard(
              poll: poll,
              onTap: () => _showPollDetail(context, poll),
              onLikeTap: pollId != null
                  ? () => _onLikeTap(context, pollId)
                  : null,
            );
          },
        ),
      ),
    );
  }

  Future<void> _onLikeTap(BuildContext context, String pollId) async {
    try {
      final result = await _viewModel.togglePollLike(pollId);
      if (!context.mounted) return;
      if (result == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('로그인이 필요해요')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('좋아요에 실패했어요. 다시 시도해 주세요.')),
        );
      }
    }
  }

  void _showPollDetail(BuildContext context, Map<String, dynamic> poll) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.82,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (sheetContext, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: Theme.of(sheetContext).colorScheme.surface,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(AppShapes.radiusLarge),
                ),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  children: [
                    SizedBox(height: context.rh(12)),
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        controller: scrollController,
                        padding: EdgeInsets.all(context.rs(16)),
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
                            SizedBox(height: context.rh(24)),
                            Text(
                              '댓글',
                              style: AppFonts.scaled(sheetContext, AppFonts.titleSemiBold),
                            ),
                            SizedBox(height: context.rh(12)),
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

    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(AppShapes.radiusSmall),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.all(context.rs(16)),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(AppShapes.radiusSmall),
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
                          style: AppFonts.scaled(context, AppFonts.titleSemiBold),
                        ),
                        Text(
                          _formatTimeAgo(createdAt),
                          style: AppFonts.scaled(context, AppFonts.captionRegular),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.more_vert, size: context.rs(24), color: AppColors.textPrimary),
                    onPressed: () {},
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                  ),
                ],
              ),
              SizedBox(height: context.rh(12)),
              // 투표 질문 영역
              Text(
                question.isEmpty ? '(투표)' : question,
                style: AppFonts.scaled(context, AppFonts.titleSemiBold),
              ),
              SizedBox(height: context.rh(4)),
              Text(
                totalVotes > 0
                    ? '$totalVotes표 • 결과 보려면 투표하세요'
                    : '투표하면 결과 보기',
                style: AppFonts.scaled(context, AppFonts.captionRegular),
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
                  Icon(Icons.visibility_outlined, size: context.rs(14), color: AppColors.textSecondary),
                  SizedBox(width: context.rs(4)),
                  Text(
                    isEnded ? '투표 종료' : '공개 투표',
                    style: AppFonts.scaled(context, AppFonts.captionRegular),
                  ),
                  const Spacer(),
                  Icon(Icons.schedule, size: context.rs(14), color: AppColors.textSecondary),
                  SizedBox(width: context.rs(4)),
                  Text(
                    _formatEndsAt(endsAt),
                    style: AppFonts.scaled(context, AppFonts.captionRegular),
                  ),
                ],
              ),
              SizedBox(height: context.rh(12)),
              // 액션: 좋아요 · 댓글 · 공유
              Row(
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onLikeTap != null ? onLikeTap! : null,
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        vertical: context.rh(10),
                        horizontal: context.rs(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            userHasLiked ? Icons.favorite : Icons.favorite_border,
                            size: context.rs(24),
                            color: userHasLiked ? AppColors.error : AppColors.textSecondary,
                          ),
                          SizedBox(width: context.rs(4)),
                          Text('$likeCount', style: AppFonts.scaled(context, AppFonts.smallMedium)),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(width: context.rs(20)),
                  Icon(Icons.chat_bubble_outline, size: context.rs(24), color: AppColors.textSecondary),
                  SizedBox(width: context.rs(4)),
                  Text('$commentCount', style: AppFonts.scaled(context, AppFonts.smallMedium)),
                  const Spacer(),
                  Text('공유', style: AppFonts.scaled(context, AppFonts.smallMedium)),
                  SizedBox(width: context.rs(4)),
                  Icon(Icons.arrow_outward, size: context.rs(18), color: AppColors.textPrimary),
                ],
              ),
            ],
          ),
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

  static const _greenBg = Color(0xFFE8F5EC);
  static const _greenCheck = Color(0xFF22C55E);
  static const _grayBg = Color(0xFFF0F2F5);
  static const _purpleBg = Color(0xFFF3EEFC);

  @override
  Widget build(BuildContext context) {
    final bg = isLeading
        ? _greenBg
        : (optionIndex % 2 == 0 ? _grayBg : _purpleBg);

    return Container(
      padding: EdgeInsets.symmetric(horizontal: context.rs(12), vertical: context.rh(10)),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isLeading ? _greenCheck.withValues(alpha: 0.5) : AppColors.border,
        ),
      ),
      child: Row(
        children: [
          if (isLeading)
            Padding(
              padding: EdgeInsets.only(right: context.rs(8)),
              child: Icon(Icons.check_circle, size: context.rs(18), color: _greenCheck),
            ),
          Expanded(
            child: Text(
              label,
              style: AppFonts.scaled(context, AppFonts.smallMedium),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (percent > 0) _buildStackedAvatars(context),
          if (percent > 0) SizedBox(width: context.rs(8)),
          Text(
            '$percent%',
            style: AppFonts.scaled(context, AppFonts.smallMedium),
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
            child: CircleAvatar(
              radius: r,
              backgroundColor: hasUrl ? AppColors.border : colors[i % colors.length],
              child: hasUrl
                  ? ClipOval(
                      child: Image.network(
                        url,
                        width: r * 2,
                        height: r * 2,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Icon(
                          Icons.person,
                          size: context.rs(16),
                          color: AppColors.textSecondary,
                        ),
                      ),
                    )
                  : Text(
                      String.fromCharCode(0x41 + (optionIndex + i) % 5),
                      style: AppFonts.scaled(context, AppFonts.tiny).copyWith(
                        color: AppColors.white,
                        fontWeight: FontWeight.w600,
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
        );
      }
    }
    if (mounted) setState(() => _sending = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: context.rh(16)),
        child: Center(
          child: SizedBox(
            width: context.rs(24),
            height: context.rs(24),
            child: const CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
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
            padding: EdgeInsets.only(bottom: context.rh(12)),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildCommentAuthorAvatar(context, author, authorId, avatarUrl),
                SizedBox(width: context.rs(10)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        author,
                        style: AppFonts.scaled(context, AppFonts.smallMedium).copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (createdAt != null)
                        Text(
                          _formatTimeAgo(createdAt),
                          style: AppFonts.scaled(context, AppFonts.captionRegular),
                        ),
                      SizedBox(height: context.rh(4)),
                      Text(
                        body,
                        style: AppFonts.scaled(context, AppFonts.bodyRegular),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
        SizedBox(height: context.rh(16)),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                decoration: InputDecoration(
                  hintText: '댓글 입력...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppShapes.radiusSmall),
                  ),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: context.rs(12),
                    vertical: context.rh(10),
                  ),
                ),
                maxLines: 2,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendComment(),
              ),
            ),
            SizedBox(width: context.rs(8)),
            FilledButton(
              onPressed: _sending ? null : _sendComment,
              child: _sending
                  ? SizedBox(
                      width: context.rs(20),
                      height: context.rs(20),
                      child: const CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('전송'),
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

    return Container(
      margin: EdgeInsets.only(bottom: context.rh(12)),
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
      padding: EdgeInsets.all(context.rs(16)),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildAuthorAvatar(context, widget.poll['author_avatar_url'] as String?),
                SizedBox(width: context.rs(12)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.poll['author_name'] as String? ?? '대덕고등학교 학생회',
                        style: AppFonts.scaled(context, AppFonts.titleSemiBold),
                      ),
                      if (createdAt != null && createdAt.isNotEmpty)
                        Text(
                          _formatTimeAgo(createdAt),
                          style: AppFonts.scaled(context, AppFonts.captionRegular),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: context.rh(12)),
            Text(
              question,
              style: AppFonts.scaled(context, AppFonts.bodyMedium),
            ),
            if (_error != null)
              Padding(
                padding: EdgeInsets.only(top: context.rh(4)),
                child: Text(
                  _error!,
                  style: AppFonts.scaled(context, AppFonts.smallRegular)
                      .copyWith(color: AppColors.error),
                ),
              ),
            Theme(
              data: Theme.of(context).copyWith(
                radioTheme: RadioThemeData(
                  fillColor: WidgetStateProperty.resolveWith<Color>((states) {
                    if (states.contains(WidgetState.selected)) {
                      return AppColors.primaryBlue;
                    }
                    return AppColors.textSecondary;
                  }),
                ),
              ),
              child: Column(
                children: optionsList.asMap().entries.map((e) {
                  final idx = e.key;
                  final opt = e.value;
                  return Padding(
                    padding: EdgeInsets.only(top: context.rh(8)),
                    child: RadioListTile<int>(
                      value: idx,
                      // ignore: deprecated_member_use
                      groupValue: _selectedIndex ?? -1,
                      // ignore: deprecated_member_use
                      onChanged: _voted
                          ? null
                          : (int? v) {
                              if (v != null) setState(() => _selectedIndex = v);
                            },
                      title: Text(
                        opt,
                        style: AppFonts.scaled(context, AppFonts.smallMedium),
                      ),
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                    ),
                  );
                }).toList(),
              ),
            ),
            if (!_voted && _selectedIndex != null)
              Padding(
                padding: EdgeInsets.only(top: context.rh(8)),
                child: SizedBox(
                  width: double.infinity,
                  child: CupertinoButton(
                    padding: EdgeInsets.symmetric(vertical: context.rh(12)),
                    color: AppColors.primaryBlue,
                    onPressed: _loading ? null : _vote,
                    child: _loading
                        ? const CupertinoActivityIndicator(
                            color: AppColors.white,
                          )
                        : Text(
                            '투표하기',
                            style: AppFonts.scaled(context, AppFonts.titleSemiBold)
                                .copyWith(color: AppColors.white),
                          ),
                  ),
                ),
              ),
            if (_voted)
              Padding(
                padding: EdgeInsets.only(top: context.rh(8)),
                child: Text(
                  '투표 완료',
                  style: AppFonts.scaled(context, AppFonts.captionRegular),
                ),
              ),
          ],
        ),
    );
  }
}
