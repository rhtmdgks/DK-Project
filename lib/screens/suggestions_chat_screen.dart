import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:myapp/core/supabase_client.dart';
import 'package:myapp/core/theme/app_motion.dart';
import 'package:myapp/core/widgets/dismiss_keyboard.dart';
import 'package:myapp/core/theme/app_theme.dart';
import 'package:myapp/core/theme/responsive.dart';
import 'package:myapp/repositories/content_report_repository.dart';
import 'package:myapp/repositories/user_block_repository.dart';
import 'package:myapp/services/content_moderation_service.dart';

/// 건의함 질문하기용 채팅방 ID (마이그레이션에서 생성한 고정 UUID)
const String kSuggestionsChatRoomId =
    'b1a2c3d4-e5f6-4789-a012-345678901234';

/// 건의함 전용 채팅 화면. Flutter 기본 아이콘(CupertinoIcons)만 사용.
///
/// Supabase [chat_rooms] / [chat_messages]와 연동하며,
/// 사용자가 건의함 문의방에 없으면 참여 후 메시지를 주고받는다.
class SuggestionsChatScreen extends StatefulWidget {
  const SuggestionsChatScreen({super.key});

  @override
  State<SuggestionsChatScreen> createState() => _SuggestionsChatScreenState();
}

class _SuggestionsChatScreenState extends State<SuggestionsChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();

  List<Map<String, dynamic>> _messages = [];
  bool _loading = true;
  bool _joining = false;
  String? _error;
  RealtimeChannel? _channel;
  final _contentReportRepo = ContentReportRepository();
  final _blockRepo = UserBlockRepository();
  Set<String> _blockedUserIds = <String>{};

  @override
  void initState() {
    super.initState();
    _ensureJoinedThenFetch();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _channel?.unsubscribe();
    super.dispose();
  }

  Future<void> _ensureJoinedThenFetch() async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    setState(() {
      _joining = true;
      _error = null;
    });

    try {
      await supabase.from('chat_room_members').insert({
        'room_id': kSuggestionsChatRoomId,
        'user_id': uid,
      });
    } catch (_) {
      // 이미 멤버이거나 정책으로 인해 실패할 수 있음 — 조회만 시도
    }

    if (!mounted) return;
    setState(() => _joining = false);
    await _loadBlockedUsers();
    _fetchMessages();
    _subscribeRealtime();
  }

  Future<void> _fetchMessages() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await supabase
          .from('chat_messages')
          .select()
          .eq('room_id', kSuggestionsChatRoomId)
          .order('created_at', ascending: true);

      if (!mounted) return;
      final raw = List<Map<String, dynamic>>.from(res as List);
      setState(() {
        _messages = raw
            .where((m) {
              final senderId = m['sender_id'] as String? ?? '';
              if (senderId.isEmpty) return true;
              return !_blockedUserIds.contains(senderId);
            })
            .toList();
        _loading = false;
      });
      _scrollToEnd();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _subscribeRealtime() {
    _channel = supabase
        .channel('suggestions_chat')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'chat_messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'room_id',
            value: kSuggestionsChatRoomId,
          ),
          callback: (payload) {
            final newRow = payload.newRecord;
            if (newRow.isNotEmpty && mounted) {
              final msg = Map<String, dynamic>.from(newRow);
              final senderId = msg['sender_id'] as String? ?? '';
              if (senderId.isNotEmpty &&
                  _blockedUserIds.contains(senderId)) {
                return;
              }
              setState(() {
                _messages.add(msg);
              });
              _scrollToEnd();
            }
          },
        )
        .subscribe();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: AppMotion.effectDuration,
          curve: AppMotion.effectCurve,
        );
      }
    });
  }

  Future<void> _send() async {
    final content = _messageController.text.trim();
    if (content.isEmpty) return;

    final moderation = ContentModerationService.checkText(content);
    if (moderation.hasAbuse) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '부적절한 표현이 포함되어 있어 메시지를 보낼 수 없습니다. 표현을 수정해 주세요.',
          ),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return;

    _messageController.clear();

    try {
      await supabase.from('chat_messages').insert({
        'room_id': kSuggestionsChatRoomId,
        'sender_id': uid,
        'content': content,
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('전송 실패: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return DismissKeyboard(
      child: CupertinoPageScaffold(
        backgroundColor: AppColors.background,
        navigationBar: CupertinoNavigationBar(
        heroTag: 'nav-suggestions-chat',
        transitionBetweenRoutes: true,
        backgroundColor: AppColors.white,
        border: null,
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.of(context).pop(),
          child: Icon(
            CupertinoIcons.back,
            color: AppColors.primaryBlue,
          ),
        ),
        middle: Text(
          '질문하기 채팅',
          style: AppFonts.scaled(context, AppFonts.titleSemiBold)
              .copyWith(color: AppColors.textDark),
        ),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          children: [
            Expanded(child: _buildBody()),
            _buildInputBar(),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildBody() {
    if (_joining || _loading) {
      return const Center(child: CupertinoActivityIndicator(radius: 12));
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _error!,
              style: AppFonts.scaled(context, AppFonts.smallRegular)
                  .copyWith(color: AppColors.error),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: context.rh(12)),
            CupertinoButton(
              onPressed: _fetchMessages,
              child: const Text('다시 시도'),
            ),
          ],
        ),
      );
    }
    if (_messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              CupertinoIcons.chat_bubble_2_fill,
              size: context.rs(64),
              color: AppColors.hint,
            ),
            SizedBox(height: context.rh(16)),
            Text(
              '아직 메시지가 없습니다.\n궁금한 점을 남겨보세요.',
              style: AppFonts.scaled(context, AppFonts.bodyRegular),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    final currentUserId = supabase.auth.currentUser?.id;
    final bubbleRadius = context.rs(12);
    final maxBubbleWidth = context.screenWidth * 0.75;

    return ListView.builder(
      controller: _scrollController,
      padding: EdgeInsets.all(context.rs(8)),
      itemCount: _messages.length,
      itemBuilder: (context, i) {
        final m = _messages[i];
        final content = m['content'] as String? ?? '';
        final senderId = m['sender_id'] as String? ?? '';
        final isMe = senderId == currentUserId;

        return Padding(
          padding: EdgeInsets.only(bottom: context.rh(8)),
          child: GestureDetector(
            onLongPress: () {
              showCupertinoModalPopup<void>(
                context: context,
                builder: (ctx) => CupertinoActionSheet(
                  title: const Text('메시지 옵션'),
                  actions: [
                    CupertinoActionSheetAction(
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        _showReportSheet(m);
                      },
                      child: const Text('신고하기'),
                    ),
                    if (!isMe)
                      CupertinoActionSheetAction(
                        isDestructiveAction: true,
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          if (senderId.isNotEmpty) {
                            _blockSender(senderId);
                          }
                        },
                        child: const Text('이 사용자 차단'),
                      ),
                  ],
                  cancelButton: CupertinoActionSheetAction(
                    isDefaultAction: true,
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('취소'),
                  ),
                ),
              );
            },
            child: Row(
              mainAxisAlignment:
                  isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (!isMe) _buildAvatar(),
                if (!isMe) SizedBox(width: context.rs(8)),
                Flexible(
                  child: Container(
                    constraints: BoxConstraints(maxWidth: maxBubbleWidth),
                    padding: EdgeInsets.symmetric(
                      horizontal: context.rs(12),
                      vertical: context.rh(10),
                    ),
                    decoration: BoxDecoration(
                      color: isMe ? AppColors.primaryBlue : AppColors.white,
                      borderRadius: BorderRadius.circular(bubbleRadius),
                      border: isMe
                          ? null
                          : Border.all(color: AppColors.borderLight),
                    ),
                    child: Text(
                      content,
                      style: AppFonts.scaled(context, AppFonts.smallRegular)
                          .copyWith(
                        color: isMe ? AppColors.white : AppColors.textDark,
                      ),
                    ),
                  ),
                ),
                if (isMe) SizedBox(width: context.rs(8)),
                if (isMe) _buildAvatar(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAvatar() {
    return Icon(
      CupertinoIcons.person_circle_fill,
      size: context.rs(32),
      color: AppColors.textSecondary,
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: EdgeInsets.all(context.rs(8)),
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(top: BorderSide(color: AppColors.border, width: 0.5)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: CupertinoTextField(
                controller: _messageController,
                placeholder: '메시지를 입력하세요',
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(),
                padding: EdgeInsets.symmetric(
                  horizontal: context.rs(14),
                  vertical: context.rh(10),
                ),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.border),
                ),
              ),
            ),
            SizedBox(width: context.rs(8)),
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: _send,
              child: Icon(
                CupertinoIcons.arrow_up_circle_fill,
                color: AppColors.primaryBlue,
                size: context.rs(36),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadBlockedUsers() async {
    try {
      final ids = await _blockRepo.fetchBlockedUserIds();
      if (!mounted) return;
      setState(() {
        _blockedUserIds = ids;
      });
    } catch (_) {
      // ignore
    }
  }

  Future<void> _showReportSheet(Map<String, dynamic> message) async {
    final id = message['id'] as String?;
    if (id == null) return;

    const reasons = [
      '욕설/비하',
      '괴롭힘/따돌림',
      '스팸',
      '불법/위험 행위',
      '기타',
    ];

    final selected = await showCupertinoModalPopup<String>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('메시지 신고'),
        message: const Text('사유를 선택하세요.'),
        actions: [
          for (final r in reasons)
            CupertinoActionSheetAction(
              onPressed: () => Navigator.of(ctx).pop(r),
              child: Text(r),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('취소'),
        ),
      ),
    );

    if (selected == null || !mounted) return;

    try {
      await _contentReportRepo.reportContent(
        contentType: 'chat_message',
        contentId: id,
        reason: selected,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('신고가 접수되었습니다.'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('신고 중 오류가 발생했습니다: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _blockSender(String userId) async {
    try {
      await _blockRepo.blockByUserId(userId);
      await _loadBlockedUsers();
      await _fetchMessages();
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
}
