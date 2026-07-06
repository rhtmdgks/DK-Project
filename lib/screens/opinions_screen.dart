import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:myapp/core/auth/auth_state.dart';
import 'package:myapp/core/theme/app_theme.dart';
import 'package:myapp/core/theme/responsive.dart';
import 'package:myapp/repositories/opinion_repository.dart';
import 'package:myapp/services/content_moderation_service.dart';

/// 학생 의견 공개 모집 화면.
///
/// 진행 중(open) 캠페인 목록을 보여주고, 캠페인별로 의견을 1회 제출할 수 있다.
/// 제출은 앱에서 익명으로 표시되며(작성자 비노출), 학생회·관리자는
/// 백오피스에서 작성자를 확인할 수 있다.
class OpinionsScreen extends StatefulWidget {
  const OpinionsScreen({super.key});

  @override
  State<OpinionsScreen> createState() => _OpinionsScreenState();
}

class _OpinionsScreenState extends State<OpinionsScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _campaigns = [];
  Set<String> _submittedCampaignIds = {};
  AppProfile? _profile;

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
      final profile = await getCurrentProfile();
      final campaigns = await OpinionRepository.instance.fetchOpenCampaigns();
      var submitted = <String>{};
      if (profile != null) {
        submitted = await OpinionRepository.instance
            .fetchMySubmittedCampaignIds(profile.id);
      }
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _campaigns = campaigns;
        _submittedCampaignIds = submitted;
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
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(CupertinoIcons.back),
          color: AppColors.textDark,
          onPressed: () => context.pop(),
        ),
        title: Text(
          '학생 의견 모집',
          style: AppFonts.scaled(context, AppFonts.titleSemiBold)
              .copyWith(color: AppColors.textDark),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        top: false,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? _buildError()
                : RefreshIndicator(
                    onRefresh: _fetch,
                    child: _campaigns.isEmpty
                        ? _buildEmpty()
                        : ListView.separated(
                            padding: EdgeInsets.all(context.rs(20)),
                            itemCount: _campaigns.length,
                            separatorBuilder: (_, __) =>
                                SizedBox(height: context.rh(12)),
                            itemBuilder: (context, i) =>
                                _buildCampaignCard(_campaigns[i]),
                          ),
                  ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(context.rs(24)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '의견 모집을 불러올 수 없습니다.',
              style: AppFonts.scaled(context, AppFonts.bodyRegular),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: context.rh(16)),
            FilledButton(onPressed: _fetch, child: const Text('다시 시도')),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return ListView(
      children: [
        SizedBox(height: context.rh(120)),
        Icon(
          CupertinoIcons.lightbulb,
          size: context.rs(48),
          color: AppColors.hint,
        ),
        SizedBox(height: context.rh(12)),
        Text(
          '진행 중인 의견 모집이 없습니다.',
          textAlign: TextAlign.center,
          style: AppFonts.scaled(context, AppFonts.bodyRegular),
        ),
      ],
    );
  }

  Widget _buildCampaignCard(Map<String, dynamic> campaign) {
    final id = (campaign['id'] ?? '').toString();
    final title = campaign['title'] as String? ?? '(제목 없음)';
    final description = campaign['description'] as String? ?? '';
    final endsAtRaw = campaign['ends_at'] as String?;
    final endsAt = endsAtRaw != null ? DateTime.tryParse(endsAtRaw) : null;
    final submitted = _submittedCampaignIds.contains(id);

    return Container(
      padding: EdgeInsets.all(context.rs(18)),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: AppShapes.borderRadiusMedium,
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppFonts.scaled(context, AppFonts.titleMedium)
                .copyWith(color: AppColors.textDark),
          ),
          if (description.isNotEmpty) ...[
            SizedBox(height: context.rh(6)),
            Text(
              description,
              style: AppFonts.scaled(context, AppFonts.smallRegular),
            ),
          ],
          if (endsAt != null) ...[
            SizedBox(height: context.rh(6)),
            Text(
              '마감: ${endsAt.year}년 ${endsAt.month}월 ${endsAt.day}일',
              style: AppFonts.scaled(context, AppFonts.captionRegular),
            ),
          ],
          SizedBox(height: context.rh(12)),
          Row(
            children: [
              Icon(
                CupertinoIcons.eye_slash,
                size: context.rs(14),
                color: AppColors.textSecondary,
              ),
              SizedBox(width: context.rs(4)),
              Expanded(
                child: Text(
                  '의견은 익명으로 제출됩니다.',
                  style: AppFonts.scaled(context, AppFonts.captionRegular),
                ),
              ),
              submitted
                  ? Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: context.rs(12),
                        vertical: context.rh(6),
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(context.rs(12)),
                      ),
                      child: Text(
                        '제출 완료',
                        style: AppFonts.scaled(context, AppFonts.captionMedium)
                            .copyWith(color: AppColors.success),
                      ),
                    )
                  : FilledButton(
                      onPressed: () => _showSubmitSheet(campaign),
                      child: const Text('의견 제출'),
                    ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _showSubmitSheet(Map<String, dynamic> campaign) async {
    final profile = _profile;
    if (profile == null) return;

    final controller = TextEditingController();
    final campaignId = (campaign['id'] ?? '').toString();

    final submitted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) {
        var submitting = false;
        return StatefulBuilder(
          builder: (innerContext, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: innerContext.rs(22),
                right: innerContext.rs(22),
                top: innerContext.rh(20),
                bottom: MediaQuery.of(innerContext).viewInsets.bottom +
                    innerContext.rh(20),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    campaign['title'] as String? ?? '의견 제출',
                    style: AppFonts.scaled(innerContext, AppFonts.titleBold),
                  ),
                  SizedBox(height: innerContext.rh(8)),
                  Text(
                    '작성한 의견은 익명으로 제출되며, 캠페인당 1회만 제출할 수 있습니다.',
                    style:
                        AppFonts.scaled(innerContext, AppFonts.captionRegular),
                  ),
                  SizedBox(height: innerContext.rh(16)),
                  TextField(
                    controller: controller,
                    maxLines: 6,
                    maxLength: 1000,
                    decoration: const InputDecoration(
                      hintText: '의견을 입력해 주세요.',
                    ),
                  ),
                  SizedBox(height: innerContext.rh(12)),
                  FilledButton(
                    onPressed: submitting
                        ? null
                        : () async {
                            final body = controller.text.trim();
                            if (body.isEmpty) return;

                            // 금칙어 검사 (건의함·채팅과 동일 기준)
                            final moderation =
                                ContentModerationService.checkText(body);
                            if (moderation.hasAbuse) {
                              ScaffoldMessenger.of(innerContext).showSnackBar(
                                const SnackBar(
                                  content: Text('부적절한 표현이 포함되어 있습니다.'),
                                  backgroundColor: AppColors.error,
                                ),
                              );
                              return;
                            }

                            setSheetState(() => submitting = true);
                            try {
                              await OpinionRepository.instance.submitOpinion(
                                campaignId: campaignId,
                                authorProfileId: profile.id,
                                body: body,
                              );
                              if (sheetContext.mounted) {
                                Navigator.of(sheetContext).pop(true);
                              }
                            } catch (_) {
                              setSheetState(() => submitting = false);
                              if (innerContext.mounted) {
                                ScaffoldMessenger.of(innerContext).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                        '제출에 실패했습니다. 이미 제출했거나 마감된 캠페인일 수 있습니다.'),
                                    backgroundColor: AppColors.error,
                                  ),
                                );
                              }
                            }
                          },
                    child: submitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('익명으로 제출'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    controller.dispose();

    if (submitted == true) {
      _fetch();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('의견이 제출되었습니다. 소중한 의견 감사합니다!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    }
  }
}
