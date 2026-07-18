import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:myapp/core/theme/app_theme.dart';
import 'package:myapp/core/theme/responsive.dart';

class AppInfoScreen extends StatefulWidget {
  const AppInfoScreen({super.key});

  @override
  State<AppInfoScreen> createState() => _AppInfoScreenState();
}

class _AppInfoScreenState extends State<AppInfoScreen> {
  PackageInfo? _info;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final info = await PackageInfo.fromPlatform();
    if (!mounted) return;
    setState(() => _info = info);
  }

  @override
  Widget build(BuildContext context) {
    final info = _info;

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
          '앱 정보',
          style: AppFonts.scaled(context, AppFonts.titleSemiBold)
              .copyWith(color: AppColors.textDark),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: context.rs(20),
            vertical: context.rh(20),
          ),
          child: info == null
              ? const Center(
                  child: CupertinoActivityIndicator(radius: 12),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      info.appName,
                      style: AppFonts.scaled(context, AppFonts.heading1Medium)
                          .copyWith(color: AppColors.textDark),
                    ),
                    SizedBox(height: context.rh(8)),
                    Text(
                      '버전 ${info.version} (${info.buildNumber})',
                      style: AppFonts.scaled(context, AppFonts.bodyRegular)
                          .copyWith(color: AppColors.textSecondary),
                    ),
                    SizedBox(height: context.rh(24)),
                    Text(
                      '저작권',
                      style: AppFonts.scaled(context, AppFonts.titleSemiBold)
                          .copyWith(color: AppColors.textDark),
                    ),
                    SizedBox(height: context.rh(8)),
                    Text(
                      '2025 We Are Goodwill',
                      style: AppFonts.scaled(context, AppFonts.bodyRegular)
                          .copyWith(color: AppColors.textPrimary),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
