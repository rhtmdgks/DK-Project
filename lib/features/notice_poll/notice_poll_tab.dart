import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:myapp/core/supabase_client.dart';
import 'package:myapp/core/theme/app_theme.dart';
import 'package:myapp/core/theme/responsive.dart';
import 'package:myapp/core/widgets/async_body.dart';
import 'package:myapp/core/widgets/m3_list.dart';
import 'package:myapp/core/widgets/tab_page_header.dart';

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

  bool _loadingAnnouncements = false;
  bool _loadingPolls = false;
  String? _errorAnnouncements;
  String? _errorPolls;
  List<Map<String, dynamic>> _announcements = [];
  List<Map<String, dynamic>> _polls = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchAnnouncements();
    _fetchPolls();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchAnnouncements() async {
    setState(() {
      _loadingAnnouncements = true;
      _errorAnnouncements = null;
    });

    try {
      final res = await supabase
          .from('announcements')
          .select()
          .order('created_at', ascending: false);

      if (!mounted) return;
      setState(() {
        _announcements = List<Map<String, dynamic>>.from(res as List);
        _loadingAnnouncements = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorAnnouncements = e.toString();
        _loadingAnnouncements = false;
      });
    }
  }

  Future<void> _fetchPolls() async {
    setState(() {
      _loadingPolls = true;
      _errorPolls = null;
    });

    try {
      final res = await supabase
          .from('polls')
          .select()
          .order('created_at', ascending: false);

      if (!mounted) return;
      setState(() {
        _polls = List<Map<String, dynamic>>.from(res as List);
        _loadingPolls = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorPolls = e.toString();
        _loadingPolls = false;
      });
    }
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
      loading: _loadingAnnouncements,
      error: _errorAnnouncements,
      isEmpty: _announcements.isEmpty,
      onRetry: _fetchAnnouncements,
      emptyMessage: '공지사항이 없습니다.',
      child: RefreshIndicator(
        onRefresh: _fetchAnnouncements,
        color: Theme.of(context).colorScheme.primary,
        child: ListView.separated(
          padding: EdgeInsets.fromLTRB(
            context.rs(22),
            context.rh(16),
            context.rs(22),
            context.rh(16),
          ),
          itemCount: _announcements.length,
          separatorBuilder: (_, __) => Divider(height: 1),
          itemBuilder: (context, i) {
            final a = _announcements[i];
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
      loading: _loadingPolls,
      error: _errorPolls,
      isEmpty: _polls.isEmpty,
      onRetry: _fetchPolls,
      emptyMessage: '투표가 없습니다.',
      child: ListView.separated(
        padding: EdgeInsets.fromLTRB(
          context.rs(22),
          context.rh(16),
          context.rs(22),
          context.rh(16),
        ),
        itemCount: _polls.length,
        separatorBuilder: (_, __) => Divider(height: 1),
        itemBuilder: (context, i) {
          final poll = _polls[i];
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
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: Theme.of(ctx).colorScheme.surface,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppShapes.radiusLarge),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(context.rs(16)),
                child: _PollCard(
                  poll: poll,
                  onVote: () {
                    _fetchPolls();
                    if (ctx.mounted) Navigator.of(ctx).pop();
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────
// PollCard - 개별 투표 카드
// ────────────────────────────────────────────────────────────

class _PollCard extends StatefulWidget {
  const _PollCard({required this.poll, required this.onVote});

  final Map<String, dynamic> poll;
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
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return;

    final pollId = widget.poll['id'] as String?;
    if (pollId == null) return;

    final res = await supabase
        .from('poll_votes')
        .select()
        .eq('poll_id', pollId)
        .eq('user_id', uid)
        .maybeSingle();

    if (!mounted) return;
    setState(() {
      _voted = res != null;
      if (res != null) _selectedIndex = res['option_index'] as int?;
    });
  }

  Future<void> _vote() async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null || _selectedIndex == null) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await supabase.from('poll_votes').insert({
        'poll_id': widget.poll['id'],
        'user_id': uid,
        'option_index': _selectedIndex,
      });

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
                      groupValue: _selectedIndex ?? -1,
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
