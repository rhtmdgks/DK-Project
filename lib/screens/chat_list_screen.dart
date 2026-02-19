import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:myapp/core/routing/app_router.dart';
import 'package:myapp/core/supabase_client.dart';
import 'package:myapp/core/theme/app_theme.dart';
import 'package:myapp/core/theme/responsive.dart';
import 'package:myapp/core/widgets/async_body.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  Map<String, String> _roomDisplayNames = {}; // room_id -> display_name

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
      // 세션이 없으면 SharedPreferences에서 user_id 가져오기
      String? uid = supabase.auth.currentUser?.id;
      if (uid == null) {
        final prefs = await SharedPreferences.getInstance();
        uid = prefs.getString('logged_in_user_id');
      }
      
      if (uid == null) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _rooms = [];
        });
        return;
      }

      // RPC 함수를 사용하여 채팅방 목록 조회 (RLS 우회)
      final roomsResult = await supabase.rpc(
        'get_user_chat_rooms',
        params: {'p_user_id': uid},
      );

      final roomsList = roomsResult as List<dynamic>;
      
      if (roomsList.isEmpty) {
        if (!mounted) return;
        setState(() {
          _rooms = [];
          _loading = false;
        });
        return;
      }

      final roomRes = roomsList;

      // 1:1 채팅방의 경우 상대방 이름 가져오기
      final displayNames = <String, String>{};
      for (final room in (roomRes as List)) {
        final roomMap = room as Map<String, dynamic>;
        final roomId = roomMap['id'] as String? ?? '';
        final roomType = roomMap['type'] as String? ?? 'group';
        
        if (roomType == 'direct' && uid != null) {
          try {
            final otherUserResult = await supabase.rpc(
              'get_direct_chat_other_user',
              params: {
                'p_room_id': roomId,
                'p_user_id': uid,
              },
            );
            if (otherUserResult != null) {
              final otherUserMap = otherUserResult as Map<String, dynamic>;
              final otherUserName = otherUserMap['full_name'] as String? ?? '알 수 없음';
              displayNames[roomId] = otherUserName;
            } else {
              displayNames[roomId] = roomMap['name'] as String? ?? '채팅방';
            }
          } catch (_) {
            // 실패 시 기본 이름 사용
            displayNames[roomId] = roomMap['name'] as String? ?? '채팅방';
          }
        } else {
          displayNames[roomId] = roomMap['name'] as String? ?? '채팅방';
        }
      }

      if (!mounted) return;
      setState(() {
        _rooms = List<Map<String, dynamic>>.from(roomRes as List);
        _roomDisplayNames = displayNames;
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
            final displayName = _roomDisplayNames[id] ?? room['name'] as String? ?? '채팅방';
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
                      displayName,
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
