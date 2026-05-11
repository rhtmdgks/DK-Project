import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:myapp/core/auth/auth_repository.dart';
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
      final uid = await AuthRepository.instance.getUserId();

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
      for (final room in roomRes) {
        final roomMap = room as Map<String, dynamic>;
        final roomId = roomMap['id'] as String? ?? '';
        final roomType = roomMap['type'] as String? ?? 'group';
        
        if (roomType == 'direct') {
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
              final studentId = otherUserMap['student_id'] as String? ?? '';
              final fullName = otherUserMap['full_name'] as String? ?? '알 수 없음';
              displayNames[roomId] = studentId.isEmpty
                  ? fullName
                  : '$studentId $fullName';
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
        _rooms = List<Map<String, dynamic>>.from(roomRes);
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
        backgroundColor: AppColors.white.withValues(alpha: 0.92),
        border: null,
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => context.go(AppRoute.home.path),
          child: Icon(
            CupertinoIcons.back,
            color: AppColors.primaryBlue,
          ),
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
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            CupertinoSliverRefreshControl(onRefresh: _fetch),
            SliverToBoxAdapter(
              child: CupertinoListSection.insetGrouped(
                margin: EdgeInsets.fromLTRB(
                  context.rs(16),
                  context.rh(16),
                  context.rs(16),
                  context.rh(24),
                ),
                backgroundColor: AppColors.background,
                header: Text(
                  '1:1 및 그룹',
                  style: AppFonts.scaled(context, AppFonts.captionMedium).copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                children: _rooms.map((room) {
                  final id = room['id'] as String? ?? '';
                  final displayName =
                      _roomDisplayNames[id] ?? room['name'] as String? ?? '채팅방';
                  return CupertinoListTile(
                    title: Text(
                      displayName,
                      style: AppFonts.scaled(context, AppFonts.bodyMedium)
                          .copyWith(color: AppColors.textDark),
                    ),
                    trailing: const CupertinoListTileChevron(),
                    onTap: () => context.push('${AppRoute.chatList.path}/$id'),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    ),
    );
  }
}
