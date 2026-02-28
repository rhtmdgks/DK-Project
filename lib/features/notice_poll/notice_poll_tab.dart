import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:myapp/core/auth/auth_repository.dart';
import 'package:myapp/core/theme/app_theme.dart';
import 'package:myapp/core/theme/responsive.dart';
import 'package:myapp/core/widgets/async_body.dart';
import 'package:myapp/core/widgets/m3_list.dart';
import 'package:myapp/core/widgets/tab_page_header.dart';
import 'package:myapp/features/notice_poll/notice_poll_viewmodel.dart';

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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _viewModel = NoticePollViewModel()..addListener(_onViewModelChanged);
    _viewModel.fetchAnnouncements();
    _viewModel.fetchPolls();
  }

  void _onViewModelChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
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
      child: ListView.separated(
        padding: EdgeInsets.fromLTRB(
          context.rs(22),
          context.rh(16),
          context.rs(22),
          context.rh(16),
        ),
        itemCount: _viewModel.polls.length,
        separatorBuilder: (_, __) => Divider(height: 1),
        itemBuilder: (context, i) {
          final poll = _viewModel.polls[i];
          final question = poll['question'] as String? ?? '';
          final options = poll['options'] as List<dynamic>? ?? [];
          final optionCount = options.length;
          return M3ListTileInbox(
            title: question.isEmpty ? '(투표)' : question,
            subtitle: optionCount > 0 ? '$optionCount개 선택지' : null,
            trailing: Icon(Icons.chevron_right, size: context.rs(20), color: AppColors.hint),
            onTap: () => _showPollDetail(context, poll),
          );
        },
      ),
    );
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
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.9,
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
                        child: _PollCard(
                          poll: poll,
                          viewModel: _viewModel,
                          onVote: () {
                            _viewModel.fetchPolls();
                            if (sheetContext.mounted) Navigator.of(sheetContext).pop();
                          },
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
// PollCard - 개별 투표 카드
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
    final uid = await AuthRepository.instance.getUserId();
    if (uid == null) return;

    final pollId = widget.poll['id'] as String?;
    if (pollId == null) return;

    final res = await widget.viewModel.getPollVote(pollId, uid);

    if (!mounted) return;
    setState(() {
      _voted = res != null;
      if (res != null) _selectedIndex = res['option_index'] as int?;
    });
  }

  Future<void> _vote() async {
    final uid = await AuthRepository.instance.getUserId();
    if (uid == null || _selectedIndex == null) return;

    final pollId = widget.poll['id'] as String?;
    if (pollId == null) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await widget.viewModel.vote(pollId, uid, _selectedIndex!);

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
                        : const Text('투표하기'),
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
