import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import 'package:myapp/core/theme/app_theme.dart';
import 'package:myapp/core/theme/responsive.dart';

/// 개인정보 처리방침 화면. [assets/privacy_policy.md]를 마크다운으로 렌더링한다.
class PrivacyPolicyScreen extends StatefulWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  State<PrivacyPolicyScreen> createState() => _PrivacyPolicyScreenState();
}

class _PrivacyPolicyScreenState extends State<PrivacyPolicyScreen> {
  String _markdown = '';
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _loadMarkdown();
  }

  Future<void> _loadMarkdown() async {
    try {
      final text =
          await rootBundle.loadString('assets/privacy_policy.md');
      if (!mounted) return;
      setState(() {
        _markdown = text;
        _loadError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppColors.background,
      navigationBar: CupertinoNavigationBar(
        heroTag: 'nav-privacy-policy',
        transitionBetweenRoutes: true,
        backgroundColor: AppColors.white,
        border: null,
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.of(context).pop(),
          child: const Icon(CupertinoIcons.back),
        ),
        middle: Text(
          '개인정보 처리방침',
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
    if (_loadError != null) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(context.rs(24)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _loadError!,
                style: AppFonts.scaled(context, AppFonts.smallRegular)
                    .copyWith(color: AppColors.error),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: context.rh(16)),
              CupertinoButton(
                onPressed: _loadMarkdown,
                child: const Text('다시 시도'),
              ),
            ],
          ),
        ),
      );
    }

    if (_markdown.isEmpty) {
      return const Center(child: CupertinoActivityIndicator(radius: 12));
    }

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: context.rs(20),
        vertical: context.rh(20),
      ),
      child: MarkdownBody(
        data: _markdown,
        selectable: true,
        styleSheet: MarkdownStyleSheet(
        h1: AppFonts.scaled(context, AppFonts.titleBold),
        h2: AppFonts.scaled(context, AppFonts.titleSemiBold),
        p: AppFonts.scaled(context, AppFonts.bodyRegular),
        listBullet: AppFonts.scaled(context, AppFonts.bodyRegular),
        tableHead: AppFonts.scaled(context, AppFonts.smallMedium),
        tableBody: AppFonts.scaled(context, AppFonts.smallRegular),
        tableBorder: TableBorder.all(color: AppColors.border),
        blockquote: AppFonts.scaled(context, AppFonts.bodyRegular)
            .copyWith(color: AppColors.textSecondary),
        horizontalRuleDecoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: AppColors.border),
          ),
        ),
      ),
    ),
    );
  }
}
