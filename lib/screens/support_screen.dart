import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:myapp/core/theme/app_theme.dart';
import 'package:myapp/core/theme/responsive.dart';
import 'package:url_launcher/url_launcher.dart';

class SupportScreen extends StatelessWidget {
  const SupportScreen({super.key});

  Future<void> _launchEmail() async {
    final uri = Uri(
      scheme: 'mailto',
      path: 's.h.putrats@the-saena.ai',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _launchPhone() async {
    final uri = Uri(
      scheme: 'tel',
      path: '01042941083',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
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
          '지원',
          style: AppFonts.scaled(context, AppFonts.titleSemiBold)
              .copyWith(color: AppColors.textDark),
        ),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: context.rs(20),
              vertical: context.rh(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '연락처',
                  style: AppFonts.scaled(context, AppFonts.titleSemiBold)
                      .copyWith(color: AppColors.textDark),
                ),
                SizedBox(height: context.rh(12)),
                Text(
                  'App: LAON\n'
                  'Developer: Edmond Ko\n'
                  'Phone: 010-4294-1083\n'
                  'Email: s.h.putrats@the-saena.ai\n'
                  'Response time: Within 48 hours',
                  style: AppFonts.scaled(context, AppFonts.bodyRegular)
                      .copyWith(color: AppColors.textPrimary),
                ),
                SizedBox(height: context.rh(24)),
                Row(
                  children: [
                    Expanded(
                      child: CupertinoButton(
                        color: AppColors.primaryBlue,
                        onPressed: _launchPhone,
                        child: Text(
                          '전화 걸기',
                          style: AppFonts.scaled(context, AppFonts.bodyMedium)
                              .copyWith(color: AppColors.white),
                        ),
                      ),
                    ),
                    SizedBox(width: context.rs(12)),
                    Expanded(
                      child: CupertinoButton.filled(
                        onPressed: _launchEmail,
                        child: Text(
                          '이메일 보내기',
                          style: AppFonts.scaled(context, AppFonts.bodyMedium)
                              .copyWith(color: AppColors.white),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: context.rh(32)),
                Text(
                  '정책',
                  style: AppFonts.scaled(context, AppFonts.titleSemiBold)
                      .copyWith(color: AppColors.textDark),
                ),
                SizedBox(height: context.rh(12)),
                Text(
                  '개인정보 처리방침과 서비스 이용약관은 설정 화면의 법적 고지 섹션에서 언제든지 확인하실 수 있습니다.',
                  style: AppFonts.scaled(context, AppFonts.bodyRegular)
                      .copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

