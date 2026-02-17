import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:myapp/core/supabase_client.dart';
import 'package:myapp/core/theme/app_theme.dart';
import 'package:myapp/core/theme/responsive.dart';

/// 개별 채팅방 화면. 반응형 대응.
///
/// Supabase Realtime으로 실시간 메시지를 수신한다.
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, required this.roomId});

  final String roomId;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();

  List<Map<String, dynamic>> _messages = [];
  bool _loading = true;
  String? _error;
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    _fetchMessages();
    _subscribeRealtime();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _channel?.unsubscribe();
    super.dispose();
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
          .eq('room_id', widget.roomId)
          .order('created_at', ascending: true);

      if (!mounted) return;
      setState(() {
        _messages = List<Map<String, dynamic>>.from(res as List);
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
        .channel('chat:${widget.roomId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'chat_messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'room_id',
            value: widget.roomId,
          ),
          callback: (payload) {
            final newRow = payload.newRecord;
            if (newRow.isNotEmpty && mounted) {
              setState(() {
                _messages.add(Map<String, dynamic>.from(newRow));
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
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send() async {
    final content = _messageController.text.trim();
    if (content.isEmpty) return;

    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return;

    _messageController.clear();

    try {
      await supabase.from('chat_messages').insert({
        'room_id': widget.roomId,
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
    return CupertinoPageScaffold(
      backgroundColor: AppColors.background,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: AppColors.white,
        border: null,
        middle: Text(
          '채팅 ${widget.roomId.substring(0, 8)}...',
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
    );
  }

  Widget _buildBody() {
    if (_loading) {
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
            ),
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
        child: Text(
          '아직 메시지가 없습니다.',
          style: AppFonts.scaled(context, AppFonts.bodyRegular),
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

        return Align(
          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            constraints: BoxConstraints(maxWidth: maxBubbleWidth),
            margin: EdgeInsets.only(bottom: context.rh(4)),
            padding: EdgeInsets.symmetric(
              horizontal: context.rs(12),
              vertical: context.rh(8),
            ),
            decoration: BoxDecoration(
              color: isMe ? AppColors.timetableBg : AppColors.border,
              borderRadius: BorderRadius.circular(bubbleRadius),
            ),
            child: Text(
              content,
              style: AppFonts.scaled(context, AppFonts.smallRegular)
                  .copyWith(color: AppColors.textDark),
            ),
          ),
        );
      },
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: EdgeInsets.all(context.rs(8)),
      color: AppColors.white,
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
}
