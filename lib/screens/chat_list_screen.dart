import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:myapp/core/routing/app_router.dart';
import 'package:myapp/core/supabase_client.dart';
import 'package:myapp/core/theme/app_theme.dart';
import 'package:myapp/core/theme/responsive.dart';
import 'package:myapp/core/widgets/async_body.dart';

/// 사용자가 참여 중인 채팅방 목록 화면. 반응형 대응.
class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _rooms = [];

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final uid = supabase.auth.currentUser?.id;
      if (uid == null) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _rooms = [];
        });
        return;
      }

      final memberRes = await supabase
          .from('chat_room_members')
          .select('room_id')
          .eq('user_id', uid);

      final roomIds = (memberRes as List)
          .map((r) => (r as Map<String, dynamic>)['room_id'] as String?)
          .whereType<String>()
          .toList();

      if (roomIds.isEmpty) {
        if (!mounted) return;
        setState(() {
          _rooms = [];
          _loading = false;
        });
        return;
      }

      final roomRes = await supabase
          .from('chat_rooms')
          .select()
          .inFilter('id', roomIds);

      if (!mounted) return;
      setState(() {
        _rooms = List<Map<String, dynamic>>.from(roomRes as List);
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
    return CupertinoPageScaffold(
      backgroundColor: AppColors.background,
      navigationBar: CupertinoNavigationBar(
        heroTag: 'nav-chat-list',
        transitionBetweenRoutes: true,
        backgroundColor: AppColors.white,
        border: null,
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => context.go(AppRoute.home.path),
          child: const Icon(CupertinoIcons.back),
        ),
        middle: Text(
          '채팅',
          style: AppFonts.scaled(context, AppFonts.titleSemiBold)
              .copyWith(color: AppColors.textDark),
        ),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: AsyncBody(
        loading: _loading,
        error: _error,
        isEmpty: _rooms.isEmpty,
        onRetry: _fetch,
        emptyMessage: '참여 중인 채팅방이 없습니다.',
        child: ListView.builder(
          padding: context.horizontalPadding.copyWith(
            top: context.rh(16),
            bottom: context.rh(16),
          ),
          itemCount: _rooms.length,
          itemBuilder: (context, i) {
            final room = _rooms[i];
            final id = room['id'] as String? ?? '';
            final name = room['name'] as String? ?? '채팅방';
            return CupertinoButton(
              padding: EdgeInsets.symmetric(
                vertical: context.rh(12),
                horizontal: context.rs(16),
              ),
              onPressed: () => context.push('${AppRoute.chatList.path}/$id'),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      name,
                      style: AppFonts.scaled(context, AppFonts.bodyMedium)
                          .copyWith(color: AppColors.textDark),
                    ),
                  ),
                  const Icon(CupertinoIcons.chevron_right, size: 18),
                ],
              ),
            );
          },
        ),
      ),
    ),
    );
  }
}
