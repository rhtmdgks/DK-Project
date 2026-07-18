import 'dart:async';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:myapp/core/auth/auth_repository.dart';
import 'package:myapp/core/supabase_client.dart';
import 'package:myapp/core/utils/avatar_url_resolver.dart';
import 'package:myapp/core/theme/app_motion.dart';
import 'package:myapp/core/widgets/app_feedback.dart';
import 'package:myapp/core/widgets/dismiss_keyboard.dart';
import 'package:myapp/core/theme/app_theme.dart';
import 'package:myapp/core/theme/responsive.dart';
import 'package:myapp/repositories/content_report_repository.dart';
import 'package:myapp/repositories/user_block_repository.dart';
import 'package:myapp/services/content_moderation_service.dart';
import 'package:url_launcher/url_launcher.dart';

/// 발신자 표시 이름 (학번 + 이름)
String _senderDisplayName(Map<String, dynamic> m) {
  final studentId = m['sender_student_id'] as String? ?? '';
  final fullName = m['sender_full_name'] as String? ?? '알 수 없음';
  if (studentId.isEmpty) return fullName;
  return '$studentId $fullName';
}

/// DB는 UTC(timestamptz)로 오므로 로컬 시간으로 변환 후 표시
DateTime? _toLocal(String? createdAt) {
  if (createdAt == null || createdAt.isEmpty) return null;
  try {
    final dt = DateTime.parse(createdAt);
    return dt.isUtc ? dt.toLocal() : dt;
  } catch (_) {
    return null;
  }
}

/// 보낸 시간 "오전 02:34" 형식 (로컬 시간)
String _formatTime(String? createdAt) {
  final local = _toLocal(createdAt);
  if (local == null) return '';
  final h = local.hour;
  final prefix = h < 12 ? '오전' : '오후';
  final hour = h > 12 ? h - 12 : (h == 0 ? 12 : h);
  final minute = local.minute.toString().padLeft(2, '0');
  return '$prefix ${hour.toString().padLeft(2, '0')}:$minute';
}

/// 날짜 구분선용 "2026년 2월 20일" (로컬 날짜)
String _formatDate(String? createdAt) {
  final local = _toLocal(createdAt);
  if (local == null) return '';
  return '${local.year}년 ${local.month}월 ${local.day}일';
}

/// 같은 날인지 (로컬 기준)
bool _isSameDay(String? a, String? b) {
  final la = _toLocal(a);
  final lb = _toLocal(b);
  if (la == null || lb == null) return false;
  return la.year == lb.year && la.month == lb.month && la.day == lb.day;
}

/// 개별 채팅방 화면. 반응형 대응.
///
/// Supabase Realtime으로 실시간 메시지를 수신한다.
/// 메시지별 프로필·이름·보낸 시간·날짜 구분선·이미지 첨부·종이비행기 전송 버튼 지원.
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, required this.roomId});

  final String roomId;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final ImagePicker _imagePicker = ImagePicker();

  List<Map<String, dynamic>> _messages = [];
  bool _loading = true;
  String? _error;
  RealtimeChannel? _channel;
  bool _isDirectChat = false;
  String? _currentUserId;
  File? _pickedImage;
  File? _pickedVideo;
  bool _sending = false;
  final _contentReportRepo = ContentReportRepository();
  final _blockRepo = UserBlockRepository();
  Set<String> _blockedUserIds = <String>{};

  @override
  void initState() {
    super.initState();
    _loadCurrentUserId();
    _loadBlockedUsers();
    _loadRoomInfo();
    _fetchMessages();
    _subscribeRealtime();
  }

  Future<void> _loadCurrentUserId() async {
    final userId = await AuthRepository.instance.getUserId();
    if (mounted) {
      setState(() {
        _currentUserId = userId;
      });
    }
  }

  Future<void> _loadBlockedUsers() async {
    try {
      final ids = await _blockRepo.fetchBlockedUserIds();
      if (!mounted) return;
      setState(() {
        _blockedUserIds = ids;
      });
    } catch (_) {
      // 차단 목록 조회 실패 시 무시
    }
  }

  Future<void> _loadRoomInfo() async {
    try {
      final userId = _currentUserId ?? await AuthRepository.instance.getUserId();

      final roomResult = await supabase.rpc(
        'get_chat_room',
        params: {
          'p_room_id': widget.roomId,
          'p_user_id': userId!,
        },
      );

      final roomRes = roomResult as Map<String, dynamic>?;

      if (roomRes != null) {
        final roomMap = roomRes;
        final roomType = roomMap['type'] as String? ?? 'group';
        _isDirectChat = roomType == 'direct';

        if (_isDirectChat) {
          final otherUserResult = await supabase.rpc(
            'get_direct_chat_other_user',
            params: {
              'p_room_id': widget.roomId,
              'p_user_id': userId,
            },
          );
          if (otherUserResult != null) {
            // 1:1 채팅 상대방 정보 로드됨 (필요 시 제목 등에 활용 가능)
          }
        }
      }
    } catch (_) {
      // 실패 시 무시
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
      final userId = _currentUserId ?? await AuthRepository.instance.getUserId();

      if (userId == null) {
        if (!mounted) return;
        setState(() {
          _error = '사용자 ID를 가져올 수 없습니다';
          _loading = false;
        });
        return;
      }

      final result = await supabase.rpc(
        'get_chat_messages',
        params: {
          'p_room_id': widget.roomId,
          'p_user_id': userId,
        },
      );

      if (!mounted) return;

      final messagesList = result as List<dynamic>? ?? [];
      final messages = messagesList
          .map((m) => Map<String, dynamic>.from(m as Map))
          .toList();
      await _enrichMessageSenders(messages);
      if (!mounted) return;
      setState(() {
        _messages = messages
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

  Future<Map<String, dynamic>> _fetchSenderProfile(String senderId) async {
    try {
      final res = await supabase.rpc(
        'get_profile_display',
        params: {'p_user_id': senderId},
      );
      final p = res as Map<String, dynamic>?;
      if (p == null) return {};
      return {
        'sender_full_name': p['full_name'],
        'sender_student_id': p['student_id'],
        'sender_avatar_url': p['avatar_url'],
      };
    } catch (_) {
      return {};
    }
  }

  /// 메시지 발신자 이름이 비어 있으면 get_profile_display RPC로 보강 (백오피스 연동 대비)
  Future<void> _enrichMessageSenders(List<Map<String, dynamic>> messages) async {
    final needEnrich = messages
        .where((m) =>
            m['sender_id'] != null &&
            (m['sender_full_name'] == null || m['sender_full_name'] == ''))
        .map((m) => m['sender_id'] as String)
        .toSet()
        .toList();
    for (final senderId in needEnrich) {
      final profile = await _fetchSenderProfile(senderId);
      if (profile.isEmpty) continue;
      for (final m in messages) {
        if (m['sender_id'] == senderId) {
          m.addAll(profile);
        }
      }
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
          callback: (payload) async {
            final newRow = payload.newRecord;
            if (newRow.isEmpty || !mounted) return;
            final msg = Map<String, dynamic>.from(newRow);
            final id = msg['id'] as String?;
            if (id != null && _messages.any((m) => m['id'] == id)) return; // 이미 있으면 무시
            final senderId = msg['sender_id'] as String?;
            if (senderId != null) {
              final profile = await _fetchSenderProfile(senderId);
              msg.addAll(profile);
            }
            if (!mounted) return;
            setState(() {
              if (senderId != null &&
                  _blockedUserIds.contains(senderId)) {
                return;
              }
              _messages.add(msg);
            });
            _scrollToEnd();
          },
        )
        .subscribe();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: AppMotion.durationMedium1,
          curve: AppMotion.curveStandard,
        );
      }
    });
  }

  Future<void> _pickImage() async {
    final x = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      imageQuality: 85,
    );
    if (x != null && mounted) {
      setState(() {
        _pickedImage = File(x.path);
        _pickedVideo = null;
      });
    }
  }

  Future<void> _pickVideo() async {
    final x = await _imagePicker.pickVideo(source: ImageSource.gallery);
    if (x != null && mounted) {
      setState(() {
        _pickedVideo = File(x.path);
        _pickedImage = null;
      });
    }
  }

  void _showAttachmentOptions() {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('사진 또는 동영상'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(ctx).pop();
              _pickImage();
            },
            child: const Text('사진'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(ctx).pop();
              _pickVideo();
            },
            child: const Text('동영상'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('취소'),
        ),
      ),
    );
  }

  void _showErrorDialog(String title, String message) {
    if (!mounted) return;
    showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(title),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Text(message),
        ),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  Future<String?> _uploadImage(File file) async {
    final ext = file.path.split('.').last.toLowerCase();
    if (ext.isEmpty || !['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(ext)) {
      return null;
    }
    final path =
        '${widget.roomId}/${_currentUserId ?? 'anon'}/${DateTime.now().millisecondsSinceEpoch}.$ext';
    await supabase.storage.from('chat-attachments').upload(
          path,
          file,
          fileOptions: const FileOptions(upsert: true),
        );
    return supabase.storage.from('chat-attachments').getPublicUrl(path);
  }

  Future<String?> _uploadVideo(File file) async {
    final ext = file.path.split('.').last.toLowerCase();
    if (ext.isEmpty || !['mp4', 'mov', 'webm', 'm4v'].contains(ext)) {
      return null;
    }
    final path =
        '${widget.roomId}/${_currentUserId ?? 'anon'}/${DateTime.now().millisecondsSinceEpoch}.$ext';
    await supabase.storage.from('chat-attachments').upload(
          path,
          file,
          fileOptions: const FileOptions(upsert: true),
        );
    return supabase.storage.from('chat-attachments').getPublicUrl(path);
  }

  Future<void> _send() async {
    final content = _messageController.text.trim();
    final hasImage = _pickedImage != null;
    final hasVideo = _pickedVideo != null;
    if (content.isEmpty && !hasImage && !hasVideo) return;

    if (content.isNotEmpty) {
      final moderation = ContentModerationService.checkText(content);
      if (moderation.hasAbuse) {
        _showErrorDialog(
          '전송 불가',
          '부적절한 표현이 포함되어 있어 메시지를 보낼 수 없습니다. 표현을 수정해 주세요.',
        );
        return;
      }
    }

    final uid = await AuthRepository.instance.getUserId();
    if (uid == null) {
      _showErrorDialog('전송 불가', '로그인 정보가 없어 전송할 수 없습니다.');
      return;
    }

    final imageToSend = _pickedImage;
    final videoToSend = _pickedVideo;
    if (mounted) setState(() => _sending = true);

    try {
      String? attachmentUrl;
      String? attachmentType;
      if (imageToSend != null) {
        try {
          attachmentUrl = await _uploadImage(imageToSend)
              .timeout(const Duration(seconds: 30), onTimeout: () => throw TimeoutException('사진 업로드 시간 초과'));
        } catch (e) {
          if (mounted) setState(() => _sending = false);
          _showErrorDialog('사진 업로드 실패', e.toString());
          return;
        }
        attachmentType = attachmentUrl != null ? 'image' : null;
        if (attachmentUrl == null && mounted) {
          setState(() => _sending = false);
          _showErrorDialog('사진 형식 오류', 'jpg, png, gif, webp만 가능합니다.');
          return;
        }
      } else if (videoToSend != null) {
        try {
          attachmentUrl = await _uploadVideo(videoToSend);
        } catch (e) {
          if (mounted) setState(() => _sending = false);
          _showErrorDialog('동영상 업로드 실패', e.toString());
          return;
        }
        attachmentType = attachmentUrl != null ? 'video' : null;
        if (attachmentUrl == null && mounted) {
          setState(() => _sending = false);
          _showErrorDialog('동영상 형식 오류', 'mp4, mov, webm, m4v만 가능합니다.');
          return;
        }
      }

      await supabase
          .rpc(
            'insert_chat_message',
            params: {
              'p_room_id': widget.roomId,
              'p_sender_id': uid,
              'p_content': content,
              'p_attachment_url': attachmentUrl,
              'p_attachment_type': attachmentType,
            },
          )
          .timeout(const Duration(seconds: 15), onTimeout: () => throw TimeoutException('전송 요청 시간 초과'));

      _messageController.clear();
      if (mounted) {
        setState(() {
          _pickedImage = null;
          _pickedVideo = null;
          _sending = false;
        });
        // 새 메시지는 Realtime INSERT로만 추가 (fetch 시 중복 방지)
        _scrollToEnd();
      }
    } catch (e, stack) {
      if (mounted) setState(() => _sending = false);
      debugPrint('Chat send error: $e\n$stack');
      final msg = e.toString().toLowerCase();
      if (msg.contains('message_blocked')) {
        // 서버 측 금칙어 검열 (클라이언트 검사 우회 시)
        _showErrorDialog(
          '전송 불가',
          '부적절한 표현이 포함되어 있어 메시지를 보낼 수 없습니다. 표현을 수정해 주세요.',
        );
      } else if (msg.contains('insert_chat_message') || msg.contains('function') || msg.contains('not_room_member')) {
        _showErrorDialog(
          '전송 실패',
          '사진/동영상 전송을 위해 서버(Supabase)에 run_on_remote_fix_chat_and_profiles.sql 적용이 필요합니다.',
        );
      } else {
        _showErrorDialog('전송 실패', e.toString());
      }
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
      AppFeedback.showSuccess(context, '신고가 접수되었습니다.');
    } catch (e) {
      if (!mounted) return;
      AppFeedback.showError(context, '신고 중 오류가 발생했습니다: $e');
    }
  }

  Future<void> _blockSender(String userId) async {
    try {
      await _blockRepo.blockByUserId(userId);
      await _loadBlockedUsers();
      await _fetchMessages();
      if (!mounted) return;
      AppFeedback.showSuccess(context, '해당 사용자를 차단했습니다.');
    } catch (e) {
      if (!mounted) return;
      AppFeedback.showError(context, '차단 중 오류가 발생했습니다: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppColors.background,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: AppColors.white,
        border: null,
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => context.pop(),
          child: Icon(
            CupertinoIcons.back,
            color: AppColors.primaryBlue,
          ),
        ),
        middle: Text(
          '학생회와 채팅하기',
          style: AppFonts.scaled(context, AppFonts.titleSemiBold)
              .copyWith(color: AppColors.textDark),
        ),
      ),
      child: Column(
        children: [
          Expanded(
            child: DismissKeyboard(child: _buildBody()),
          ),
          _buildInputBar(),
        ],
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

    final children = <Widget>[];
    String? prevDate;

    for (var i = 0; i < _messages.length; i++) {
      final m = _messages[i];
      final createdAt = m['created_at'] as String?;
      final dateLabel = _formatDate(createdAt);
      if (dateLabel.isNotEmpty && !_isSameDay(prevDate, createdAt)) {
        children.add(_buildDateDivider(dateLabel));
        prevDate = createdAt;
      }
      children.add(_buildMessageRow(m, maxBubbleWidth, bubbleRadius));
    }

    return ListView(
      controller: _scrollController,
      padding: EdgeInsets.all(context.rs(12)),
      children: children,
    );
  }

  Widget _buildVideoPreview(
    BuildContext context,
    String url,
    double maxWidth,
    bool isMe,
  ) {
    return Padding(
      padding: EdgeInsets.only(top: context.rh(4)),
      child: GestureDetector(
        onTap: () async {
          final uri = Uri.tryParse(url);
          if (uri != null && await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        },
        child: Container(
          constraints: BoxConstraints(
            maxWidth: maxWidth - 24,
            minHeight: 80,
          ),
          padding: EdgeInsets.symmetric(
            horizontal: context.rs(12),
            vertical: context.rh(12),
          ),
          decoration: BoxDecoration(
            color: (isMe ? AppColors.white : AppColors.textDark)
                .withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                CupertinoIcons.play_circle,
                size: context.rs(40),
                color: isMe ? AppColors.primaryBlue : AppColors.white,
              ),
              SizedBox(width: context.rs(10)),
              Text(
                '동영상 재생',
                style: AppFonts.scaled(context, AppFonts.bodyMedium).copyWith(
                  color: isMe ? AppColors.primaryBlue : AppColors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDateDivider(String dateLabel) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: context.rh(16)),
      child: Row(
        children: [
          Expanded(
            child: Container(height: 1, color: AppColors.border),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: context.rs(12)),
            child: Text(
              dateLabel,
              style: AppFonts.scaled(context, AppFonts.captionRegular)
                  .copyWith(color: AppColors.textSecondary),
            ),
          ),
          Expanded(
            child: Container(height: 1, color: AppColors.border),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageRow(
    Map<String, dynamic> m,
    double maxBubbleWidth,
    double bubbleRadius,
  ) {
    final content = m['content'] as String? ?? '';
    final senderId = m['sender_id'] as String? ?? '';
    final isMe = senderId == _currentUserId;
    final displayName = _senderDisplayName(m);
    final timeStr = _formatTime(m['created_at'] as String?);
    final rawAvatarUrl = m['sender_avatar_url'] as String?;
    final avatarUrl = resolveAvatarUrl(rawAvatarUrl);
    String? attachmentUrl = m['attachment_url'] as String?;
    if (attachmentUrl != null && attachmentUrl.isNotEmpty) {
      final path = attachmentUrl.startsWith('http') ? null : attachmentUrl.replaceFirst(RegExp(r'^/+'), '');
      if (path != null && path.isNotEmpty) {
        attachmentUrl = supabase.storage.from('chat-attachments').getPublicUrl(path);
      }
    }
    final attachmentType = m['attachment_type'] as String?;
    final hasVideo = attachmentUrl != null &&
        (attachmentType == 'video' ||
            RegExp(r'\.(mp4|webm|mov|m4v)(\?|$)', caseSensitive: false)
                .hasMatch(attachmentUrl));
    final hasImage = attachmentUrl != null && !hasVideo;

    final effectiveAvatarUrl = (avatarUrl != null && avatarUrl.isNotEmpty)
        ? avatarUrl
        : 'https://api.dicebear.com/9.x/notionists/png?seed=${senderId.isEmpty ? 'unknown' : senderId}';

    final avatar = SizedBox(
      width: context.rs(36),
      height: context.rs(36),
      child: ClipOval(
        child: Image.network(
          effectiveAvatarUrl,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            color: AppColors.border,
            child: Center(
              child: Text(
                displayName.isNotEmpty ? displayName[0] : '?',
                style: AppFonts.scaled(context, AppFonts.captionMedium)
                    .copyWith(color: AppColors.textSecondary),
              ),
            ),
          ),
        ),
      ),
    );

    final nameAndTime = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isMe && timeStr.isNotEmpty)
          Padding(
            padding: EdgeInsets.only(right: context.rs(6)),
            child: Text(
              timeStr,
              style: AppFonts.scaled(context, AppFonts.captionRegular)
                  .copyWith(color: AppColors.textSecondary),
            ),
          ),
        Text(
          displayName,
          style: AppFonts.scaled(context, AppFonts.captionMedium)
              .copyWith(color: AppColors.textDark),
        ),
        if (!isMe && timeStr.isNotEmpty)
          Padding(
            padding: EdgeInsets.only(left: context.rs(6)),
            child: Text(
              timeStr,
              style: AppFonts.scaled(context, AppFonts.captionRegular)
                  .copyWith(color: AppColors.textSecondary),
            ),
          ),
      ],
    );

    final bubble = Container(
      constraints: BoxConstraints(maxWidth: maxBubbleWidth),
      padding: EdgeInsets.symmetric(
        horizontal: context.rs(12),
        vertical: context.rh(8),
      ),
      decoration: BoxDecoration(
        color: isMe ? AppColors.primaryBlue : AppColors.border,
        borderRadius: BorderRadius.circular(bubbleRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (content.isNotEmpty)
            Text(
              content,
              style: AppFonts.scaled(context, AppFonts.smallRegular)
                  .copyWith(
                      color: isMe ? AppColors.white : AppColors.textDark),
            ),
          if (content.isNotEmpty && (hasImage || hasVideo))
            SizedBox(height: context.rh(8)),
          if (hasImage)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: maxBubbleWidth - 24,
                  minHeight: 120,
                  maxHeight: 240,
                ),
                child: Image.network(
                  attachmentUrl,
                  fit: BoxFit.contain,
                  loadingBuilder: (_, child, progress) =>
                      progress == null
                          ? child
                          : Container(
                              color: AppColors.border.withValues(alpha: 0.3),
                              child: const Center(
                                child: CupertinoActivityIndicator(),
                              ),
                            ),
                  errorBuilder: (_, __, ___) => Container(
                    padding: EdgeInsets.all(context.rs(12)),
                    color: AppColors.border.withValues(alpha: 0.3),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            CupertinoIcons.photo_on_rectangle,
                            size: context.rs(32),
                            color: AppColors.textSecondary,
                          ),
                          SizedBox(height: context.rh(4)),
                          Text(
                            '이미지를 불러올 수 없습니다',
                            style: AppFonts.scaled(context, AppFonts.captionRegular)
                                .copyWith(color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          if (hasVideo)
            _buildVideoPreview(context, attachmentUrl, maxBubbleWidth, isMe),
        ],
      ),
    );

    return Padding(
      padding: EdgeInsets.only(bottom: context.rh(12)),
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
          children: isMe
              ? [
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        nameAndTime,
                        SizedBox(height: context.rh(4)),
                        bubble,
                      ],
                    ),
                  ),
                  SizedBox(width: context.rs(8)),
                  avatar,
                ]
              : [
                  avatar,
                  SizedBox(width: context.rs(8)),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        nameAndTime,
                        SizedBox(height: context.rh(4)),
                        bubble,
                      ],
                    ),
                  ),
                ],
        ),
      ),
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_pickedImage != null || _pickedVideo != null)
              Padding(
                padding: EdgeInsets.only(bottom: context.rh(8)),
                child: Row(
                  children: [
                    if (_pickedImage != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          _pickedImage!,
                          width: 64,
                          height: 64,
                          fit: BoxFit.cover,
                        ),
                      )
                    else if (_pickedVideo != null)
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: AppColors.border,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          CupertinoIcons.play_circle,
                          size: 32,
                          color: AppColors.primaryBlue,
                        ),
                      ),
                    SizedBox(width: context.rs(8)),
                    GestureDetector(
                      onTap: () => setState(() {
                        _pickedImage = null;
                        _pickedVideo = null;
                      }),
                      child: Icon(
                        CupertinoIcons.xmark_circle_fill,
                        size: context.rs(24),
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            Row(
              children: [
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: _sending ? null : _showAttachmentOptions,
                  child: Icon(
                    CupertinoIcons.paperclip,
                    color: AppColors.textSecondary,
                    size: context.rs(28),
                  ),
                ),
                SizedBox(width: context.rs(4)),
                Expanded(
                  child: CupertinoTextField(
                    controller: _messageController,
                    placeholder: '메시지를 입력하세요...',
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(),
                    enabled: !_sending,
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
                  minimumSize: Size.zero,
                  onPressed: _sending
                      ? null
                      : () {
                          FocusScope.of(context).unfocus();
                          _send();
                        },
                  child: Container(
                    width: context.rs(48),
                    height: context.rs(48),
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: AppColors.primaryBlue,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      CupertinoIcons.paperplane_fill,
                      color: AppColors.white,
                      size: context.rs(22),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
