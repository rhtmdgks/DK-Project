import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:myapp/core/routing/app_router.dart';
import 'package:myapp/core/supabase_client.dart';
import 'package:myapp/core/theme/app_theme.dart';
import 'package:myapp/core/theme/responsive.dart';
import 'package:myapp/core/widgets/async_body.dart';

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

  bool _loadingAnnouncements = false;
  bool _loadingPolls = false;
  String? _errorAnnouncements;
  String? _errorPolls;
  List<Map<String, dynamic>> _announcements = [];
  List<Map<String, dynamic>> _polls = [];

  @override
  void initState() {
    super.initState();
    _fetchAnnouncements();
    _fetchPolls();
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
      navigationBar: CupertinoNavigationBar(
        backgroundColor: AppColors.white,
        border: null,
        middle: Text(
          '공지 / 투표',
          style: AppFonts.scaled(context, AppFonts.titleSemiBold)
              .copyWith(color: AppColors.textDark),
        ),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => context.push(AppRoute.chatList.path),
          child: const Text('채팅'),
        ),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          children: [
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: context.rs(16),
              vertical: context.rh(8),
            ),
            child: CupertinoSegmentedControl<int>(
              groupValue: _segmentIndex,
              children: const {
                0: Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: Text('공지사항'),
                ),
                1: Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: Text('투표'),
                ),
              },
              onValueChanged: (v) => setState(() => _segmentIndex = v),
            ),
          ),
          Expanded(
            child: _segmentIndex == 0
                ? _buildAnnouncementsBody()
                : _buildPollsBody(),
          ),
        ],
        ),
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
      child: ListView.builder(
        padding: context.horizontalPadding.copyWith(
          top: context.rh(16),
          bottom: context.rh(16),
        ),
        itemCount: _announcements.length,
        itemBuilder: (context, i) {
          final a = _announcements[i];
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
                  a['title'] as String? ?? '',
                  style: AppFonts.scaled(context, AppFonts.bodyMedium),
                ),
                SizedBox(height: context.rh(4)),
                Text(
                  a['body'] as String? ?? '',
                  style: AppFonts.scaled(context, AppFonts.smallRegular),
                ),
              ],
            ),
          );
        },
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
      child: ListView.builder(
        padding: context.horizontalPadding.copyWith(
          top: context.rh(16),
          bottom: context.rh(16),
        ),
        itemCount: _polls.length,
        itemBuilder: (context, i) {
          return _PollCard(
            poll: _polls[i],
            onVote: _fetchPolls,
          );
        },
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
      margin: EdgeInsets.only(bottom: context.rh(8)),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderLight),
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
            RadioGroup<int>(
              groupValue: _selectedIndex ?? -1,
              onChanged: (int? v) {
                if (!_voted) setState(() => _selectedIndex = v);
              },
              child: Column(
                children: optionsList.asMap().entries.map((e) {
                  final idx = e.key;
                  final opt = e.value;
                  return Padding(
                    padding: EdgeInsets.only(top: context.rh(8)),
                    child: ListTile(
                      title: Text(
                        opt,
                        style:
                            AppFonts.scaled(context, AppFonts.smallMedium),
                      ),
                      leading: Radio<int>(
                        value: idx,
                        enabled: !_voted,
                      ),
                      onTap: _voted
                          ? null
                          : () => setState(() => _selectedIndex = idx),
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
