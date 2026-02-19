import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:myapp/core/supabase_client.dart';
import 'package:myapp/core/theme/app_motion.dart';
import 'package:myapp/core/widgets/dismiss_keyboard.dart';
import 'package:myapp/core/theme/app_theme.dart';
import 'package:myapp/core/theme/responsive.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  String? _roomDisplayName;
  bool _isDirectChat = false;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _loadCurrentUserId();
    _loadRoomInfo();
    _fetchMessages();
    _subscribeRealtime();
  }

  Future<void> _loadCurrentUserId() async {
    // 세션이 있으면 사용, 없으면 SharedPreferences에서 가져오기
    String? userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      final prefs = await SharedPreferences.getInstance();
      userId = prefs.getString('logged_in_user_id');
    }
    if (mounted) {
      setState(() {
        _currentUserId = userId;
      });
    }
  }

  Future<void> _loadRoomInfo() async {
    try {
      // 현재 사용자 ID 가져오기
      String? userId = _currentUserId;
      if (userId == null) {
        userId = supabase.auth.currentUser?.id;
        if (userId == null) {
          final prefs = await SharedPreferences.getInstance();
          userId = prefs.getString('logged_in_user_id');
        }
      }

      // 채팅방 정보 가져오기 (RPC 함수 사용)
      final roomResult = await supabase.rpc(
        'get_chat_room',
        params: {
          'p_room_id': widget.roomId,
          'p_user_id': userId!,
        },
      );
      
      final roomRes = roomResult as Map<String, dynamic>?;

      if (roomRes != null) {
        final roomMap = roomRes as Map<String, dynamic>;
        final roomType = roomMap['type'] as String? ?? 'group';
        _isDirectChat = roomType == 'direct';

        if (_isDirectChat && userId != null) {
          // 1:1 채팅방인 경우 상대방 이름 가져오기
          final otherUserResult = await supabase.rpc(
            'get_direct_chat_other_user',
            params: {
              'p_room_id': widget.roomId,
              'p_user_id': userId,
            },
          );
          if (otherUserResult != null) {
            final otherUserMap = otherUserResult as Map<String, dynamic>;
            final otherUserName = otherUserMap['full_name'] as String? ?? '알 수 없음';
            if (mounted) {
              setState(() {
                _roomDisplayName = otherUserName;
              });
            }
          }
        } else {
          // 그룹 채팅방인 경우 방 이름 사용
          if (mounted) {
            setState(() {
              _roomDisplayName = roomMap['name'] as String? ?? '채팅방';
            });
          }
        }
      }
    } catch (_) {
      // 실패 시 기본값 사용
      if (mounted) {
        setState(() {
          _roomDisplayName = '채팅방';
        });
      }
    }
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
      // 현재 사용자 ID 가져오기
      String? userId = _currentUserId;
      if (userId == null) {
        userId = supabase.auth.currentUser?.id;
        if (userId == null) {
          final prefs = await SharedPreferences.getInstance();
          userId = prefs.getString('logged_in_user_id');
        }
      }

      if (userId == null) {
        if (!mounted) return;
        setState(() {
          _error = '사용자 ID를 가져올 수 없습니다';
          _loading = false;
        });
        return;
      }

      // RPC 함수를 사용하여 메시지 조회 (RLS 우회)
      final result = await supabase.rpc(
        'get_chat_messages',
        params: {
          'p_room_id': widget.roomId,
          'p_user_id': userId,
        },
      );

      if (!mounted) return;
      
      // RPC 결과를 파싱
      final messagesList = result as List<dynamic>;
      setState(() {
        _messages = messagesList.map((m) => Map<String, dynamic>.from(m as Map)).toList();
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
          duration: AppMotion.effectDuration,
          curve: AppMotion.effectCurve,
        );
      }
    });
  }

  Future<void> _send() async {
    final content = _messageController.text.trim();
    if (content.isEmpty) return;

    // 세션이 없으면 SharedPreferences에서 user_id 가져오기
    String? uid = supabase.auth.currentUser?.id;
    if (uid == null) {
      final prefs = await SharedPreferences.getInstance();
      uid = prefs.getString('logged_in_user_id');
    }
    
    if (uid == null) return;

    _messageController.clear();

    try {
      // RPC 함수를 사용하여 메시지 삽입 (RLS 우회)
      await supabase.rpc(
        'insert_chat_message',
        params: {
          'p_room_id': widget.roomId,
          'p_sender_id': uid,
          'p_content': content,
        },
      );
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
        backgroundColor: AppColors.white,
        border: null,
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => context.pop(),
          child: const Icon(CupertinoIcons.back),
        ),
        middle: Text(
          _roomDisplayName ?? '채팅',
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
        final isMe = senderId == _currentUserId;

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
