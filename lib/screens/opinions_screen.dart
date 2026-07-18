import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import 'package:myapp/components/apple_button.dart';
import 'package:myapp/components/apple_navigation_bar.dart';
import 'package:myapp/components/apple_text_field.dart';
import 'package:myapp/core/auth/auth_state.dart';
import 'package:myapp/core/theme/app_resolved_colors.dart';
import 'package:myapp/core/theme/app_theme.dart';
import 'package:myapp/core/theme/responsive.dart';
import 'package:myapp/core/widgets/app_feedback.dart';
import 'package:myapp/design/glass.dart';
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
    final colors = context.appColors;
    return GlassScaffold(
      backgroundColor: colors.background,
      appBar: AppleNavigationBar(
        title: '학생 의견 모집',
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => context.pop(),
          child: Icon(
            CupertinoIcons.back,
            color: AppColors.textDark,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: _loading
            ? const Center(child: CupertinoActivityIndicator(radius: 12))
            : _error != null
                ? _buildError()
                : CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    slivers: [
                      CupertinoSliverRefreshControl(onRefresh: _fetch),
                      if (_campaigns.isEmpty)
                        SliverFillRemaining(child: _buildEmpty())
                      else
                        SliverPadding(
                          padding: EdgeInsets.all(context.rs(20)),
                          sliver: SliverList.separated(
                            itemCount: _campaigns.length,
                            separatorBuilder: (_, __) =>
                                SizedBox(height: context.rh(12)),
                            itemBuilder: (context, i) =>
                                _buildCampaignCard(_campaigns[i]),
                          ),
                        ),
                    ],
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
            AppleButton(label: '다시 시도', onPressed: _fetch),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Column(
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
                  : AppleButton(
                      label: '의견 제출',
                      onPressed: () => _showSubmitSheet(campaign),
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

    final submitted = await GlassSheet.show<bool>(
      context: context,
      quality: kAppGlassQuality,
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
                  AppleTextField(
                    controller: controller,
                    placeholder: '의견을 입력해 주세요.',
                    maxLines: 6,
                  ),
                  SizedBox(height: innerContext.rh(12)),
                  AppleButton(
                    label: '익명으로 제출',
                    fullWidth: true,
                    loading: submitting,
                    onPressed: submitting
                        ? null
                        : () async {
                            final body = controller.text.trim();
                            if (body.isEmpty) return;

                            final moderation =
                                ContentModerationService.checkText(body);
                            if (moderation.hasAbuse) {
                              AppFeedback.showError(
                                innerContext,
                                '부적절한 표현이 포함되어 있습니다.',
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
                                AppFeedback.showError(
                                  innerContext,
                                  '제출에 실패했습니다. 이미 제출했거나 마감된 캠페인일 수 있습니다.',
                                );
                              }
                            }
                          },
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
        AppFeedback.showSuccess(
          context,
          '의견이 제출되었습니다. 소중한 의견 감사합니다!',
        );
      }
    }
  }
}
