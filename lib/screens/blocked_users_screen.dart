import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:myapp/core/theme/app_theme.dart';
import 'package:myapp/core/theme/responsive.dart';
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('차단 해제 실패: $e'),
          backgroundColor: AppColors.error,
        ),
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
      child: Material(
        type: MaterialType.transparency,
        child: SafeArea(
          top: false,
          child: _buildBody(),
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
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final item = _items[index];
        return ListTile(
          title: Text(
            item.fullName ?? '이름 없음',
            style: AppFonts.scaled(context, AppFonts.bodyMedium)
                .copyWith(color: AppColors.textDark),
          ),
          subtitle: Text(
            item.studentId ?? '',
            style: AppFonts.scaled(context, AppFonts.captionRegular)
                .copyWith(color: AppColors.textSecondary),
          ),
          trailing: TextButton(
            onPressed: () => _unblock(item.profileId),
            child: const Text('차단 해제'),
          ),
        );
      },
    );
  }
}

