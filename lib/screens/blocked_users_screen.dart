import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';

import 'package:myapp/components/apple_list_tile.dart';
import 'package:myapp/core/theme/app_theme.dart';
import 'package:myapp/core/theme/responsive.dart';
import 'package:myapp/core/widgets/app_feedback.dart';
import 'package:myapp/repositories/user_block_repository.dart';

class BlockedUsersScreen extends StatefulWidget {
  const BlockedUsersScreen({super.key});

  @override
  State<BlockedUsersScreen> createState() => _BlockedUsersScreenState();
}

class _BlockedUsersScreenState extends State<BlockedUsersScreen> {
  final _repo = UserBlockRepository();

  bool _loading = true;
  String? _error;
  List<BlockedProfile> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await _repo.fetchBlockedProfiles();
      if (!mounted) return;
      setState(() {
        _items = items;
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

  Future<void> _unblock(String profileId) async {
    try {
      await _repo.unblockProfile(profileId);
      await _load();
    } catch (e) {
      if (!mounted) return;
      AppFeedback.showError(context, '차단 해제 실패: $e');
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
          child: const Icon(CupertinoIcons.back),
        ),
        middle: Text(
          '차단한 사용자',
          style: AppFonts.scaled(context, AppFonts.titleSemiBold)
              .copyWith(color: AppColors.textDark),
        ),
      ),
      child: SafeArea(
        top: false,
        child: _buildBody(),
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
            Padding(
              padding: EdgeInsets.symmetric(horizontal: context.rs(24)),
              child: Text(
                _error!,
                style: AppFonts.scaled(context, AppFonts.smallRegular)
                    .copyWith(color: AppColors.error),
                textAlign: TextAlign.center,
              ),
            ),
            SizedBox(height: context.rh(12)),
            CupertinoButton(
              onPressed: _load,
              child: const Text('다시 시도'),
            ),
          ],
        ),
      );
    }
    if (_items.isEmpty) {
      return Center(
        child: Text(
          '차단한 사용자가 없습니다.',
          style: AppFonts.scaled(context, AppFonts.bodyRegular)
              .copyWith(color: AppColors.textSecondary),
        ),
      );
    }

    return ListView.separated(
      padding: EdgeInsets.symmetric(
        horizontal: context.rs(16),
        vertical: context.rh(16),
      ),
      itemCount: _items.length,
      separatorBuilder: (_, __) => Container(
        height: 1,
        color: AppColors.border,
      ),
      itemBuilder: (context, index) {
        final item = _items[index];
        return AppleListTile(
          title: item.fullName ?? '이름 없음',
          subtitle: item.studentId ?? '',
          trailing: CupertinoButton(
            padding: EdgeInsets.zero,
            minimumSize: Size.zero,
            onPressed: () => _unblock(item.profileId),
            child: Text(
              '차단 해제',
              style: AppFonts.scaled(context, AppFonts.bodyMedium)
                  .copyWith(color: AppColors.primaryBlue),
            ),
          ),
        );
      },
    );
  }
}
