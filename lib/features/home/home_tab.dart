import 'dart:async';
import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:myapp/core/auth/auth_state.dart';
import 'package:myapp/core/routing/app_router.dart';
import 'package:myapp/core/supabase_client.dart';
import 'package:myapp/core/theme/app_theme.dart';
import 'package:myapp/core/utils/timetable_utils.dart';
import 'package:myapp/core/theme/responsive.dart';
import 'package:myapp/core/utils/subject_theme_service.dart';
import 'package:myapp/core/widgets/laon_icon.dart';
import 'package:myapp/core/widgets/m3_carousel_scroll_physics.dart';
import 'package:myapp/providers/notification_provider.dart';
import 'package:myapp/repositories/announcement_repository.dart';
import 'package:myapp/repositories/schedule_repository.dart';
import 'package:myapp/widgets/notification_side_sheet.dart';
import 'package:provider/provider.dart';

/// Figma "App Wireframes > HOME" (node 296:5429) 홈 대시보드 탭.
///
/// 구성:
/// 1. 커스텀 앱바 (LAON 로고 + 알림/설정 아이콘)
/// 2. 프로필 인사말
/// 3. 오늘의 수업 (Material 3 카드)
/// 4. 다음 시간 과목 (상세 정보 카드)
class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  final AnnouncementRepository _announcementRepository = AnnouncementRepository();
  final ScheduleRepository _scheduleRepository = ScheduleRepository();

  String? _fullName;
  String? _avatarUrl;
  String? _role;
  bool _loading = true;
  String? _dynamicGreeting;
  bool _homeFeedLoading = true;
  String? _homeFeedError;
  List<Map<String, dynamic>> _todayEvents = const [];
  List<Map<String, dynamic>> _latestAnnouncements = const [];
  List<Map<String, dynamic>> _activePolls = const [];

  bool get _isTeacher => _role == 'teacher';
  String get _nameWithHonorific {
    final name = _fullName ?? (_isTeacher ? '선생님' : '학생');
    return _isTeacher ? '$name 선생님' : '$name님';
  }

  /// 오늘의 수업: Supabase timetable_entries에서 로드 (오늘 요일 기준).
  List<_SubjectCard>? _todayTimetableEntries;
  bool _timetableLoading = true;

  /// 현재 수업 갱신용. 1초마다 setState로 원·숫자가 자연스럽게 줄어들게 함.
  Timer? _currentClassTimer;

  _NextClassInfo? get _nextClassInfo {
    final list = _todayTimetableEntries ?? [];
    if (list.isEmpty) return null;
    final now = DateTime.now();
    final current = TimetableUtils.currentPeriodAndSecondsLeft(now).period;
    _SubjectCard? next;
    if (current != null) {
      for (final card in list) {
        if (card.period > current) {
          next = card;
          break;
        }
      }
    } else {
      final currentMinutes = now.hour * 60 + now.minute;
      for (final card in list) {
        final idx = card.period - 1;
        if (idx < 0 || idx >= TimetableUtils.periodStartTimes.length) continue;
        final start = TimetableUtils.periodStartTimes[idx];
        final startMinutes = start[0] * 60 + start[1];
        if (startMinutes > currentMinutes) {
          next = card;
          break;
        }
      }
      next ??= list.first;
    }
    if (next == null) return null;
    return _NextClassInfo(
      name: next.name,
      periodName: '${next.period}교시',
      location: (next.room == null || next.room!.trim().isEmpty) ? '장소 미정' : next.room!.trim(),
      time: TimetableUtils.startTimeString(next.period),
      notice: '다음 수업 준비물을 확인해 주세요.',
    );
  }

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadGreeting();
    _loadTodayTimetable();
    _loadHomeFeed();
    _currentClassTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _currentClassTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await getCurrentProfile();
      if (!mounted) return;
      setState(() {
        _fullName = profile?.fullName;
        _avatarUrl = profile?.avatarUrl;
        _role = profile?.role;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _loadGreeting() async {
    try {
      final res = await supabase
          .from('greeting_messages')
          .select('text')
          .eq('is_active', true)
          .order('sort_order', ascending: true)
          .order('created_at', ascending: false);

      final list = List<Map<String, dynamic>>.from(res as List);
      if (!mounted) return;

      if (list.isEmpty) {
        setState(() => _dynamicGreeting = null);
        return;
      }

      final random = Random();
      final picked =
          list[random.nextInt(list.length)]['text'] as String? ?? '';
      setState(() => _dynamicGreeting =
          picked.trim().isEmpty ? null : picked.trim());
    } catch (_) {
      if (!mounted) return;
      setState(() => _dynamicGreeting = null);
    }
  }

  Future<void> _loadTodayTimetable() async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) {
      if (!mounted) return;
      setState(() {
        _todayTimetableEntries = [];
        _timetableLoading = false;
      });
      return;
    }
    final today = DateTime.now();
    final weekday = TimetableUtils.dayOfWeekForDb(today);
    if (weekday == null) {
      if (!mounted) return;
      setState(() {
        _todayTimetableEntries = [];
        _timetableLoading = false;
      });
      return;
    }
    try {
      final res = await supabase
          .from('timetable_entries')
          .select('subject, period, room')
          .eq('user_id', uid)
          .eq('day_of_week', weekday)
          .order('period');
      final list = List<Map<String, dynamic>>.from(res as List);
      if (!mounted) return;
      setState(() {
        _todayTimetableEntries = list
            .map((e) => _SubjectCard(
                  name: (e['subject'] as String? ?? '').trim().isEmpty
                      ? '(없음)'
                      : (e['subject'] as String).trim(),
                  period: (e['period'] as num?)?.toInt() ?? 0,
                  room: (e['room'] as String?)?.trim().isEmpty == true
                      ? null
                      : (e['room'] as String?),
                ))
            .toList();
        _timetableLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _todayTimetableEntries = [];
        _timetableLoading = false;
      });
    }
  }

  Future<void> _loadHomeFeed() async {
    if (mounted) {
      setState(() {
        _homeFeedLoading = true;
        _homeFeedError = null;
      });
    }

    try {
      final profile = await getCurrentProfile();
      final announcementsFuture = _announcementRepository.fetchAnnouncements();
      final pollsFuture = _announcementRepository.fetchPolls();
      final scheduleFuture = _scheduleRepository.fetchScheduleItems();
      final personalFuture = profile?.userId != null
          ? _scheduleRepository.fetchPersonalEvents(profile!.userId)
          : Future.value(<Map<String, dynamic>>[]);
      final classFuture =
          profile?.gradeOrFromStudentId != null && profile?.classNumOrFromStudentId != null
          ? _scheduleRepository.fetchClassEvents(
              grade: profile!.gradeOrFromStudentId!,
              classNumber: profile.classNumOrFromStudentId!,
            )
          : Future.value(<Map<String, dynamic>>[]);

      final results = await Future.wait<dynamic>([
        announcementsFuture,
        pollsFuture,
        scheduleFuture,
        personalFuture,
        classFuture,
      ]);

      final announcements = List<Map<String, dynamic>>.from(results[0] as List);
      final polls = List<Map<String, dynamic>>.from(results[1] as List);
      final schoolEvents = List<Map<String, dynamic>>.from(results[2] as List);
      final personalEvents = List<Map<String, dynamic>>.from(results[3] as List);
      final classEvents = List<Map<String, dynamic>>.from(results[4] as List);

      final now = DateTime.now();
      final mergedEvents = <Map<String, dynamic>>[
        ...schoolEvents,
        ...personalEvents,
        ...classEvents,
      ];
      final todayEvents = mergedEvents.where((event) {
        final dt = _parseDateTime(event['start_at']);
        return dt != null && _isSameDay(dt.toLocal(), now);
      }).toList()
        ..sort((a, b) {
          final ad = _parseDateTime(a['start_at']) ?? DateTime(2100);
          final bd = _parseDateTime(b['start_at']) ?? DateTime(2100);
          return ad.compareTo(bd);
        });

      final activePolls = polls.where((poll) {
        final endsAtRaw = poll['ends_at'] as String?;
        if (endsAtRaw == null || endsAtRaw.isEmpty) return true;
        final endsAt = DateTime.tryParse(endsAtRaw);
        if (endsAt == null) return true;
        return endsAt.toLocal().isAfter(now);
      }).toList();

      if (!mounted) return;
      setState(() {
        _latestAnnouncements = announcements.take(3).toList();
        _activePolls = activePolls.take(2).toList();
        _todayEvents = todayEvents.take(4).toList();
        _homeFeedLoading = false;
        _homeFeedError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _homeFeedLoading = false;
        _homeFeedError = '홈 데이터를 불러오지 못했어요.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: () async {
          await _loadProfile();
          await _loadGreeting();
          await _loadTodayTimetable();
          await _loadHomeFeed();
        },
        child: _loading
            ? Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Theme.of(context).colorScheme.primary,
                ),
              )
            : ListView(
                padding: EdgeInsets.zero,
                children: [
                  _buildAppBar(),
                  SizedBox(height: context.rh(24)),
                  _buildGreeting(),
                  SizedBox(height: context.rh(24)),
                  _buildPremiumDashboard(),
                  SizedBox(height: context.rh(32)),
                ],
              ),
      ),
    );
  }

  Widget _buildPremiumDashboard() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: context.rs(22)),
      child: Column(
        children: [
          _buildCurrentHeroSection(),
          SizedBox(height: context.rh(18)),
          _buildPeriodsOverviewSection(),
          SizedBox(height: context.rh(18)),
          _buildTodayEventsSection(),
          SizedBox(height: context.rh(18)),
          _buildAnnouncementsSection(),
          SizedBox(height: context.rh(18)),
          _buildActivePollSection(),
          if (_homeFeedError != null) ...[
            SizedBox(height: context.rh(12)),
            Text(
              _homeFeedError!,
              style: AppFonts.scaled(context, AppFonts.captionRegular).copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCurrentHeroSection() {
    final nowInfo = TimetableUtils.currentPeriodAndSecondsLeft(DateTime.now());
    final list = _todayTimetableEntries ?? [];
    _SubjectCard? currentSubject;
    if (nowInfo.period != null) {
      for (final item in list) {
        if (item.period == nowInfo.period) {
          currentSubject = item;
          break;
        }
      }
    }
    final next = _nextClassInfo;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(context.rs(18)),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0040E0), Color(0xFF2E5BFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0040E0).withValues(alpha: 0.28),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '현재 수업',
            style: AppFonts.scaled(context, AppFonts.captionMedium).copyWith(
              color: AppColors.white.withValues(alpha: 0.85),
              letterSpacing: 0.3,
            ),
          ),
          SizedBox(height: context.rh(6)),
          Text(
            currentSubject?.name ?? '현재 진행 중인 수업이 없어요',
            style: AppFonts.scaled(context, AppFonts.titleSemiBold).copyWith(
              color: AppColors.white,
              fontSize: context.rs(24),
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: context.rh(6)),
          Text(
            currentSubject == null || nowInfo.period == null
                ? '다음 수업 정보를 확인해 주세요.'
                : '${TimetableUtils.startTimeString(nowInfo.period!)} · ${nowInfo.period}교시 · ${_formatSecondsLeft(nowInfo.secondsLeft ?? 0)}',
            style: AppFonts.scaled(context, AppFonts.bodyRegular).copyWith(
              color: AppColors.white.withValues(alpha: 0.92),
            ),
          ),
          SizedBox(height: context.rh(14)),
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(
              horizontal: context.rs(12),
              vertical: context.rh(10),
            ),
            decoration: BoxDecoration(
              color: AppColors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.white.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Icon(
                  CupertinoIcons.forward_fill,
                  size: context.rs(14),
                  color: AppColors.white.withValues(alpha: 0.9),
                ),
                SizedBox(width: context.rs(8)),
                Expanded(
                  child: Text(
                    next == null
                        ? '다음 시간 과목 없음'
                        : '다음: ${next.periodName} ${next.name} · ${next.time}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppFonts.scaled(context, AppFonts.smallMedium).copyWith(
                      color: AppColors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodsOverviewSection() {
    final byPeriod = <int, _SubjectCard>{};
    for (final item in _todayTimetableEntries ?? <_SubjectCard>[]) {
      byPeriod[item.period] = item;
    }
    final now = DateTime.now();
    final nowTotalMinutes = now.hour * 60 + now.minute;
    final currentPeriod = TimetableUtils.currentPeriodAndSecondsLeft(now).period;

    return _buildGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '오늘의 수업',
                style: AppFonts.scaled(context, AppFonts.sectionTitle),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => context.push(AppRoute.todayClasses.path),
                child: const Text('더보기'),
              ),
            ],
          ),
          SizedBox(height: context.rh(6)),
          Text(
            '1교시부터 7교시까지 한눈에 확인하세요.',
            style: AppFonts.scaled(context, AppFonts.captionRegular).copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          SizedBox(height: context.rh(12)),
          Stack(
            children: [
              Positioned(
                left: context.rs(8),
                top: context.rh(8),
                bottom: context.rh(8),
                child: Container(
                  width: context.rs(2),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              Column(
                children: List.generate(7, (index) {
                  final period = index + 1;
                  final subject = byPeriod[period];
                  final start = TimetableUtils.periodStartTimes[index];
                  final startMinutes = start[0] * 60 + start[1];
                  final endMinutes = startMinutes + TimetableUtils.durationMinutes;
                  final timeRange =
                      '${TimetableUtils.startTimeString(period)} - ${TimetableUtils.endTimeString(period)}';

                  final isCurrent = currentPeriod == period;
                  final isCompleted =
                      !isCurrent && nowTotalMinutes >= endMinutes;
                  final isUpcoming = !isCurrent && !isCompleted;

                  return Padding(
                    padding: EdgeInsets.only(
                      bottom: period == 7 ? 0 : context.rh(10),
                    ),
                    child: _buildRoadmapItem(
                      period: period,
                      subject: subject?.name ?? '수업 없음',
                      timeRange: timeRange,
                      isCurrent: isCurrent,
                      isCompleted: isCompleted,
                      isUpcoming: isUpcoming,
                    ),
                  );
                }),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRoadmapItem({
    required int period,
    required String subject,
    required String timeRange,
    required bool isCurrent,
    required bool isCompleted,
    required bool isUpcoming,
  }) {
    final pointColor = isCurrent
        ? AppColors.primaryBlue
        : isCompleted
            ? AppColors.surfaceContainerHigh
            : AppColors.surfaceContainer;
    final cardColor = isCurrent
        ? AppColors.primaryBlue.withValues(alpha: 0.1)
        : AppColors.surfaceContainerLow;
    final borderColor = isCurrent
        ? AppColors.primaryBlue.withValues(alpha: 0.35)
        : AppColors.borderLight;
    final textColor = isCompleted
        ? AppColors.textSecondary
        : AppColors.textPrimary;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: context.rs(20),
          child: Center(
            child: Container(
              width: context.rs(12),
              height: context.rs(12),
              decoration: BoxDecoration(
                color: pointColor,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isCurrent ? AppColors.white : AppColors.background,
                  width: 2,
                ),
                boxShadow: isCurrent
                    ? [
                        BoxShadow(
                          color: AppColors.primaryBlue.withValues(alpha: 0.25),
                          blurRadius: 10,
                        ),
                      ]
                    : null,
              ),
              child: isCompleted
                  ? Icon(
                      Icons.check,
                      size: context.rs(8),
                      color: AppColors.textSecondary,
                    )
                  : null,
            ),
          ),
        ),
        SizedBox(width: context.rs(10)),
        Expanded(
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: context.rs(12),
              vertical: context.rh(11),
            ),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            '$period교시',
                            style: AppFonts.scaled(
                              context,
                              AppFonts.smallMedium,
                            ).copyWith(
                              color: isCurrent
                                  ? AppColors.primaryBlue
                                  : AppColors.textSecondary,
                            ),
                          ),
                          if (isCurrent) ...[
                            SizedBox(width: context.rs(8)),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: context.rs(7),
                                vertical: context.rh(2),
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primaryBlue,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                'NOW',
                                style: AppFonts.scaled(
                                  context,
                                  AppFonts.tiny,
                                ).copyWith(
                                  color: AppColors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      SizedBox(height: context.rh(3)),
                      Text(
                        subject,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppFonts.scaled(
                          context,
                          AppFonts.bodyMedium,
                        ).copyWith(
                          color: textColor,
                          fontWeight: FontWeight.w700,
                          decoration: isCompleted
                              ? TextDecoration.lineThrough
                              : TextDecoration.none,
                        ),
                      ),
                      SizedBox(height: context.rh(2)),
                      Text(
                        timeRange,
                        style: AppFonts.scaled(
                          context,
                          AppFonts.captionRegular,
                        ).copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: context.rs(8)),
                if (isCurrent)
                  Icon(
                    Icons.near_me_rounded,
                    size: context.rs(18),
                    color: AppColors.primaryBlue,
                  )
                else if (isUpcoming)
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: context.rs(8),
                      vertical: context.rh(4),
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '예정',
                      style: AppFonts.scaled(context, AppFonts.tiny).copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  )
                else
                  Icon(
                    Icons.check_circle_rounded,
                    size: context.rs(18),
                    color: AppColors.textSecondary,
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTodayEventsSection() {
    return _buildGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '오늘의 일정',
            style: AppFonts.scaled(context, AppFonts.sectionTitle),
          ),
          SizedBox(height: context.rh(10)),
          if (_homeFeedLoading && _todayEvents.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: context.rh(8)),
              child: Text(
                '일정을 불러오는 중...',
                style: AppFonts.scaled(context, AppFonts.captionRegular),
              ),
            )
          else if (_todayEvents.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: context.rh(8)),
              child: Text(
                '오늘 등록된 일정이 없습니다.',
                style: AppFonts.scaled(context, AppFonts.captionRegular).copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            )
          else
            ..._todayEvents.map((event) {
              final title = (event['title'] as String? ?? '').trim();
              final startAt = _parseDateTime(event['start_at']);
              final scope = (event['event_scope'] as String?) ?? 'school';
              final icon = scope == 'personal'
                  ? Icons.person_outline
                  : scope == 'class'
                      ? Icons.groups_outlined
                      : Icons.campaign_outlined;
              return Container(
                margin: EdgeInsets.only(bottom: context.rh(8)),
                padding: EdgeInsets.all(context.rs(12)),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(icon, size: context.rs(18), color: AppColors.primaryBlue500),
                    SizedBox(width: context.rs(8)),
                    Expanded(
                      child: Text(
                        title.isEmpty ? '(제목 없음)' : title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppFonts.scaled(context, AppFonts.bodyMedium),
                      ),
                    ),
                    SizedBox(width: context.rs(8)),
                    Text(
                      startAt == null ? '' : _formatHm(startAt),
                      style: AppFonts.scaled(context, AppFonts.captionRegular).copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildAnnouncementsSection() {
    return _buildGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '공지사항',
                style: AppFonts.scaled(context, AppFonts.sectionTitle),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => context.go('/?tab=notice'),
                child: const Text('전체보기'),
              ),
            ],
          ),
          SizedBox(height: context.rh(8)),
          if (_homeFeedLoading && _latestAnnouncements.isEmpty)
            Text(
              '공지사항을 불러오는 중...',
              style: AppFonts.scaled(context, AppFonts.captionRegular),
            )
          else if (_latestAnnouncements.isEmpty)
            Text(
              '등록된 공지사항이 없습니다.',
              style: AppFonts.scaled(context, AppFonts.captionRegular).copyWith(
                color: AppColors.textSecondary,
              ),
            )
          else
            ..._latestAnnouncements.map((notice) {
              final title = (notice['title'] as String? ?? '').trim();
              final createdAt = notice['created_at'] as String?;
              return Container(
                margin: EdgeInsets.only(bottom: context.rh(8)),
                padding: EdgeInsets.all(context.rs(12)),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.campaign_outlined, size: context.rs(18), color: AppColors.primaryBlue500),
                    SizedBox(width: context.rs(8)),
                    Expanded(
                      child: Text(
                        title.isEmpty ? '(제목 없음)' : title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppFonts.scaled(context, AppFonts.bodyMedium),
                      ),
                    ),
                    SizedBox(width: context.rs(8)),
                    Text(
                      _formatTimeAgo(createdAt),
                      style: AppFonts.scaled(context, AppFonts.tiny).copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildActivePollSection() {
    return _buildGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '진행 중인 투표',
                style: AppFonts.scaled(context, AppFonts.sectionTitle),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => context.go('/?tab=notice'),
                child: const Text('참여하기'),
              ),
            ],
          ),
          SizedBox(height: context.rh(8)),
          if (_homeFeedLoading && _activePolls.isEmpty)
            Text(
              '투표 목록을 불러오는 중...',
              style: AppFonts.scaled(context, AppFonts.captionRegular),
            )
          else if (_activePolls.isEmpty)
            Text(
              '현재 진행 중인 투표가 없습니다.',
              style: AppFonts.scaled(context, AppFonts.captionRegular).copyWith(
                color: AppColors.textSecondary,
              ),
            )
          else
            ..._activePolls.map((poll) {
              final question = (poll['question'] as String? ?? '').trim();
              final options = (poll['options'] as List<dynamic>? ?? [])
                  .map((e) => e.toString())
                  .take(2)
                  .toList();
              final endsAt = poll['ends_at'] as String?;
              return Container(
                margin: EdgeInsets.only(bottom: context.rh(8)),
                padding: EdgeInsets.all(context.rs(12)),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      question.isEmpty ? '(투표)' : question,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppFonts.scaled(context, AppFonts.bodyMedium).copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (options.isNotEmpty) ...[
                      SizedBox(height: context.rh(6)),
                      Text(
                        options.join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppFonts.scaled(context, AppFonts.captionRegular).copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                    SizedBox(height: context.rh(6)),
                    Text(
                      endsAt == null || endsAt.isEmpty ? '종료 시각 미정' : '마감 ${_formatTimeAgo(endsAt)}',
                      style: AppFonts.scaled(context, AppFonts.tiny).copyWith(
                        color: AppColors.primaryBlue500,
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildGlassCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(context.rs(16)),
      decoration: BoxDecoration(
        color: AppColors.white.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }

  // ── 1. 앱바: LAON 로고 + 알림/설정 ──

  Widget _buildAppBar() {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: context.rs(22),
        vertical: context.rh(12),
      ),
      child: Row(
        children: [
          LaonIcon(size: context.rmin(36)),
          SizedBox(width: context.rs(7)),
          Text(
            'LAON',
            style: AppFonts.scaled(context, AppFonts.heading2Medium),
          ),
          const Spacer(),
          Consumer<NotificationProvider>(
            builder: (context, provider, _) {
              final hasUnread = provider.unreadCount > 0;
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  _buildIconButton(
                    'assets/images/icon_bell.svg',
                    onTap: () => showNotificationSideSheet(context),
                  ),
                  if (hasUnread)
                    Positioned(
                      right: -2,
                      top: -2,
                      child: Container(
                        width: context.rs(10),
                        height: context.rs(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF3B30), // iOS 스타일 빨간색
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Theme.of(context).colorScheme.surface,
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFF3B30).withValues(alpha: 0.4),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          SizedBox(width: context.rs(28)),
          _buildIconButton(
            'assets/images/icon_settings.svg',
            onTap: () => context.push(AppRoute.settings.path),
          ),
        ],
      ),
    );
  }

  Widget _buildIconButton(String svgPath, {VoidCallback? onTap}) {
    final size = context.rs(24);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: size,
        height: size,
        child: SvgPicture.asset(
          svgPath,
          width: size,
          height: size,
          fit: BoxFit.contain,
        ),
      ),
    );
  }


  // ── 2. 프로필 인사말 ──

  Widget _buildGreeting() {
    final avatarSize = context.rmin(64);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: context.rs(22)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: avatarSize,
            height: avatarSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.white,
              border: Border.all(
                color: AppColors.border,
                width: 1.5,
              ),
              boxShadow: const [
                BoxShadow(
                  color: AppColors.cardShadow,
                  offset: Offset(0, 2),
                  blurRadius: 8,
                ),
              ],
            ),
            child: ClipOval(
              child: _avatarUrl != null && _avatarUrl!.isNotEmpty
                  ? Image.network(
                      _avatarUrl!,
                      width: avatarSize,
                      height: avatarSize,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Icon(
                          CupertinoIcons.person_fill,
                          size: context.rmin(36),
                          color: AppColors.primaryBlue500,
                        );
                      },
                      errorBuilder: (_, __, ___) => Icon(
                        CupertinoIcons.person_fill,
                        size: context.rmin(36),
                        color: AppColors.primaryBlue500,
                      ),
                    )
                  : Icon(
                      CupertinoIcons.person_fill,
                      size: context.rmin(36),
                      color: AppColors.primaryBlue500,
                    ),
            ),
          ),
          SizedBox(width: context.rs(12)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '안녕하세요 $_nameWithHonorific,',
                  style: AppFonts.scaled(context, AppFonts.titleMedium),
                ),
                Text(
                  _greetingMessage(),
                  style: AppFonts.scaled(context, AppFonts.titleMedium),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── 3. 오늘의 수업 섹션 ──

  // ignore: unused_element
  Widget _buildTodayClassesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: context.rs(26)),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '오늘의 수업',
                style: AppFonts.scaled(context, AppFonts.sectionTitle),
              ),
              const Spacer(),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => context.push(AppRoute.todayClasses.path),
                  borderRadius: AppShapes.borderRadiusExtraLarge,
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: context.rs(14),
                      vertical: context.rh(8),
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .primaryContainer
                          .withValues(alpha: 0.6),
                      borderRadius: AppShapes.borderRadiusExtraLarge,
                    ),
                    child: Text(
                      '더보기',
                      style: AppFonts.scaled(
                        context,
                        AppFonts.display3Medium,
                      ).copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w600,
                        fontSize: context.rs(14),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: context.rh(2)),
        Padding(
          padding: EdgeInsets.only(left: context.rs(27)),
          child: Text(
            _isTeacher
                ? '오늘 $_nameWithHonorific의 수업이에요.'
                : '오늘 $_nameWithHonorific이 수강하실 과목이에요.',
            style: AppFonts.scaled(context, AppFonts.display3Regular),
          ),
        ),
        SizedBox(height: context.rh(16)),
        _buildTodayClassesList(),
      ],
    );
  }

  static const double _cardHeight = 119;
  static const double _cardWidth = 148;
  static const double _firstCardWidth = 149;

  Widget _buildTodayClassesList() {
    final list = _todayTimetableEntries ?? [];
    if (_timetableLoading) {
      return SizedBox(
        height: _cardHeight,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.symmetric(horizontal: context.rs(22)),
          children: List.generate(4, (i) => Padding(
            padding: EdgeInsets.only(right: i < 3 ? context.rs(12) : 0),
            child: SizedBox(
              width: i == 0 ? _firstCardWidth : _cardWidth,
              height: _cardHeight,
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.borderLight,
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          )),
        ),
      );
    }
    if (list.isEmpty) {
      return SizedBox(
        height: _cardHeight,
        child: Center(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: context.rs(22)),
            child: Text(
              TimetableUtils.isWeekday(DateTime.now())
                  ? '등록된 수업이 없어요.'
                  : '주말에는 수업이 없어요.',
              style: AppFonts.scaled(context, AppFonts.bodyRegular)
                  .copyWith(color: AppColors.textSecondary),
            ),
          ),
        ),
      );
    }
    return SizedBox(
      height: _cardHeight,
      child: ScrollConfiguration(
        behavior: M3CarouselScrollBehavior(),
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          physics: const ClampingScrollPhysics(),
          padding: EdgeInsets.symmetric(horizontal: context.rs(22)),
          itemCount: list.length,
          itemBuilder: (context, index) {
            return Padding(
              padding: EdgeInsets.only(
                right: index < list.length - 1 ? context.rs(12) : 0,
              ),
              child: _buildTodayClassCard(list[index], index == 0),
            );
          },
        ),
      ),
    );
  }

  Widget _buildTodayClassCard(_SubjectCard subject, bool isFirst) {
    final cardWidth = isFirst ? _firstCardWidth : _cardWidth;
    final theme = SubjectThemeService.getThemeForSubject(subject.name);

    return SizedBox(
      width: cardWidth,
      height: _cardHeight,
      child: Container(
        decoration: BoxDecoration(
          color: theme.color,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              offset: const Offset(0, 4),
              blurRadius: 12,
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Positioned(
              left: context.rs(16),
              top: context.rs(16),
              child: Icon(
                theme.icon,
                size: context.rs(24),
                color: AppColors.white,
              ),
            ),
            if (theme.decorationPath != null)
              Positioned(
                right: -cardWidth * 0.6,
                top: -_cardHeight * 0.6,
                child: SvgPicture.asset(
                  theme.decorationPath!,
                  width: cardWidth * 1.2,
                  height: _cardHeight * 1.2,
                  fit: BoxFit.contain,
                  alignment: Alignment.topRight,
                ),
              ),
            Positioned(
              left: context.rs(16),
              bottom: context.rs(16),
              child: Text(
                subject.name,
                style: AppFonts.scaled(context, AppFonts.titleSemiBold)
                    .copyWith(
                  color: AppColors.white,
                  fontSize: context.rs(16),
                  fontWeight: FontWeight.w600,
                  height: 1.5,
                ),
              ),
            ),
            Positioned(
              right: context.rs(12),
              top: context.rs(16),
              child: GestureDetector(
                onTap: () {},
                child: SvgPicture.asset(
                  'assets/icons/ellipsis_v_2dots.svg',
                  width: context.rs(24),
                  height: context.rs(24),
                  colorFilter: const ColorFilter.mode(
                    AppColors.white,
                    BlendMode.srcIn,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── 4. 현재 수업 (남은 시간) 섹션 ──

  static const int _durationSeconds = 50 * 60;

  // ignore: unused_element
  Widget _buildCurrentClassSection() {
    if (!TimetableUtils.isWeekday(DateTime.now())) {
      return const SizedBox.shrink();
    }
    final res = TimetableUtils.currentPeriodAndSecondsLeft(DateTime.now());
    if (res.period == null || res.secondsLeft == null) {
      return const SizedBox.shrink();
    }
    final list = _todayTimetableEntries ?? [];
    _SubjectCard? subject;
    for (final card in list) {
      if (card.period == res.period) {
        subject = card;
        break;
      }
    }
    if (subject == null) {
      return const SizedBox.shrink();
    }

    final secondsLeft = res.secondsLeft!;
    final theme = SubjectThemeService.getThemeForSubject(subject.name);
    final startTime = TimetableUtils.startTimeString(res.period!);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: context.rs(26)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '현재 수업',
            style: AppFonts.scaled(context, AppFonts.sectionTitle),
          ),
          SizedBox(height: context.rh(2)),
          Text(
            '지금 진행 중인 수업이에요.',
            style: AppFonts.scaled(context, AppFonts.display3Regular),
          ),
          SizedBox(height: context.rh(16)),
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(context.rs(16)),
            decoration: BoxDecoration(
              color: theme.color,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  offset: const Offset(0, 4),
                  blurRadius: 12,
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        subject.name,
                        style: AppFonts.scaled(context, AppFonts.titleSemiBold)
                            .copyWith(
                          color: AppColors.white,
                          fontSize: context.rs(18),
                          fontWeight: FontWeight.w600,
                          height: 1.4,
                        ),
                      ),
                      SizedBox(height: context.rh(4)),
                      Text(
                        '오늘 $startTime · ${res.period}교시',
                        style: AppFonts.scaled(context, AppFonts.display3Regular)
                            .copyWith(
                          color: AppColors.white,
                          fontSize: context.rs(14),
                          fontWeight: FontWeight.w500,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: context.rs(16)),
                SizedBox(
                  width: context.rs(72),
                  height: context.rs(72),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: context.rs(72),
                        height: context.rs(72),
                        child: CircularProgressIndicator(
                          value: secondsLeft / _durationSeconds,
                          strokeWidth: context.rs(5),
                          backgroundColor: AppColors.white.withValues(alpha: 0.3),
                          valueColor: const AlwaysStoppedAnimation<Color>(AppColors.white),
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${secondsLeft ~/ 60}',
                            style: AppFonts.scaled(context, AppFonts.titleSemiBold)
                                .copyWith(
                              color: AppColors.white,
                              fontSize: context.rs(22),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            '분 ${secondsLeft % 60}초 남음',
                            style: AppFonts.scaled(context, AppFonts.display3Regular)
                                .copyWith(
                              color: AppColors.white,
                              fontSize: context.rs(12),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── 5. 다음 시간 과목 섹션 ──

  // ignore: unused_element
  Widget _buildNextClassSection() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: context.rs(26)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '다음 시간 과목',
            style: AppFonts.scaled(context, AppFonts.sectionTitle),
          ),
          SizedBox(height: context.rh(2)),
          Text(
            '$_nameWithHonorific의 다음 시간 과목 정보에요.',
            style: AppFonts.scaled(context, AppFonts.display3Regular),
          ),
          SizedBox(height: context.rh(12)),
          if (_nextClassInfo != null) _buildNextClassCard(_nextClassInfo!),
          if (_nextClassInfo == null)
            Padding(
              padding: EdgeInsets.symmetric(vertical: context.rh(8)),
              child: Text(
                '오늘 남은 다음 수업이 없습니다.',
                style: AppFonts.scaled(context, AppFonts.display3Regular),
              ),
            ),
        ],
      ),
    );
  }

  /// Figma 노드 3:692 디자인 기반 다음 시간 과목 카드
  /// 크기: 319x137 (기본), 필요시 높이 확장 가능
  /// 레이아웃: 과목명, 교시명, 교실 위치, 시작 시간, 선생님 이름, 기타 알림
  Widget _buildNextClassCard(_NextClassInfo info) {
    final subjectTheme = SubjectThemeService.getThemeForSubject(info.name);
    final infoIconSize = context.rs(18); // 아이콘 크기 증가: 16 → 18

    return Container(
      width: double.infinity,
      constraints: BoxConstraints(
        minHeight: context.rh(137), // 최소 높이
      ),
      padding: EdgeInsets.all(context.rs(16)), // 패딩 조정: 20 → 16
      decoration: BoxDecoration(
        color: subjectTheme.color, // 과목별 색상 사용
        borderRadius: BorderRadius.circular(16), // Figma: cornerRadius 16
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            offset: const Offset(0, 4),
            blurRadius: 12,
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // 상단: 과목명과 메뉴 아이콘
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 과목명 (크기 증가: 16px → 20px)
                  Expanded(
                    child: Text(
                      info.name,
                      style: AppFonts.scaled(context, AppFonts.titleSemiBold)
                          .copyWith(
                        color: AppColors.white,
                        fontSize: context.rs(20), // 16px → 20px
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                      ),
                    ),
                  ),
                  SizedBox(width: context.rs(8)),
                  // 메뉴 아이콘 (Figma: 24x24, x: -3400, y: 2538)
                  GestureDetector(
                    onTap: () {},
                    child: SvgPicture.asset(
                      'assets/icons/ellipsis_v_2dots.svg',
                      width: context.rs(24),
                      height: context.rs(24),
                      colorFilter: const ColorFilter.mode(
                        AppColors.white,
                        BlendMode.srcIn,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: context.rh(2)), // 과목명과 교시명 사이 마진 줄임
              // 교시명 (크기 증가: 12px → 15px)
              Text(
                info.periodName,
                style: AppFonts.scaled(context, AppFonts.display3Regular)
                    .copyWith(
                  color: AppColors.white,
                  fontSize: context.rs(15), // 12px → 15px
                  fontWeight: FontWeight.w500,
                  height: 1.4,
                ),
              ),
              SizedBox(height: context.rh(8)), // 교시명과 하단 정보 사이 간격 조정: 12 → 8
              // 교실 위치 (크기 증가: 12px → 14px)
              Row(
                children: [
                  Icon(
                    Icons.location_on_outlined,
                    size: infoIconSize,
                    color: AppColors.white,
                  ),
                  SizedBox(width: context.rs(4)),
                  Text(
                    info.location, // "Room" 제거, 형식: 2-10
                    style: AppFonts.scaled(context, AppFonts.display3Regular)
                        .copyWith(
                      color: AppColors.white,
                      fontSize: context.rs(14), // 12px → 14px
                      fontWeight: FontWeight.w500, // 더 굵게
                      height: 1.4,
                    ),
                  ),
                ],
              ),
              SizedBox(height: context.rh(2)), // 간격 조정: 4 → 2
              // 시작 시간 (크기 증가: 12px → 14px)
              Row(
                children: [
                  Icon(
                    Icons.schedule_outlined,
                    size: infoIconSize,
                    color: AppColors.white,
                  ),
                  SizedBox(width: context.rs(4)),
                  Text(
                    info.time,
                    style: AppFonts.scaled(context, AppFonts.display3Regular)
                        .copyWith(
                      color: AppColors.white,
                      fontSize: context.rs(14), // 12px → 14px
                      fontWeight: FontWeight.w500, // 더 굵게
                      height: 1.4,
                    ),
                  ),
                ],
              ),
              SizedBox(height: context.rh(2)), // 간격 조정: 4 → 2
              // 기타 알림 (description 스타일: 더 굵고 잘 보이게, 좌우 정렬)
              if (info.notice.isNotEmpty) ...[
                SizedBox(height: context.rh(6)), // 마진 조정: 10 → 6
                Text(
                  info.notice,
                  textAlign: TextAlign.justify, // 좌우 정렬
                  style: AppFonts.scaled(context, AppFonts.titleMedium)
                      .copyWith(
                    color: AppColors.white,
                    fontSize: context.rs(15),
                    fontWeight: FontWeight.w600, // SemiBold로 더 굵게
                    height: 1.4,
                  ),
                  maxLines: 2, // 2줄까지 표시 가능
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
    );
  }

  // ── Helpers ──

  DateTime? _parseDateTime(dynamic value) {
    final raw = value as String?;
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw)?.toLocal();
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _formatHm(DateTime dateTime) {
    final h = dateTime.hour.toString().padLeft(2, '0');
    final m = dateTime.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String _formatSecondsLeft(int secondsLeft) {
    if (secondsLeft <= 0) return '곧 종료';
    final m = secondsLeft ~/ 60;
    final s = secondsLeft % 60;
    return '$m분 ${s.toString().padLeft(2, '0')}초 남음';
  }

  String _formatTimeAgo(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    final dateTime = DateTime.tryParse(iso)?.toLocal();
    if (dateTime == null) return '';
    final diff = DateTime.now().difference(dateTime);
    if (diff.inMinutes < 1) return '방금';
    if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
    if (diff.inHours < 24) return '${diff.inHours}시간 전';
    return '${diff.inDays}일 전';
  }

  String _greetingMessage() {
    if (_dynamicGreeting != null && _dynamicGreeting!.isNotEmpty) {
      return _dynamicGreeting!;
    }
    return '오늘도 좋은 하루 되세요!';
  }
}

/// 오늘의 수업 카드 데이터. [icon]은 Material 3 Icons.
/// 오늘의 수업 카드 데이터.
/// 색상, 아이콘, 장식 벡터는 [SubjectThemeService]를 통해 자동 할당됩니다.
class _SubjectCard {
  const _SubjectCard({
    required this.name,
    required this.period,
    this.room,
  });

  final String name;
  final int period;
  final String? room;
}

/// 다음 시간 과목 상세 정보 데이터.
/// 다음 시간 과목 정보.
/// 아이콘과 색상은 [SubjectThemeService]를 통해 자동 할당됩니다.
class _NextClassInfo {
  const _NextClassInfo({
    required this.name,
    required this.periodName,
    required this.location,
    required this.time,
    required this.notice,
  });

  final String name; // 과목명
  final String periodName; // 교시명 (예: "3단원: 동물계")
  final String location; // 교실 위치
  final String time; // 시작 시간
  final String notice; // 기타 알림 (한줄 짧게)
}
