import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:myapp/core/auth/auth_state.dart';
import 'package:myapp/core/supabase_client.dart';
import 'package:myapp/core/utils/merged_school_timetable.dart';
import 'package:myapp/core/utils/timetable_utils.dart';
import 'package:myapp/services/class_move_notification_service.dart';

class ClassItem {
  const ClassItem({
    required this.name,
    required this.period,
    required this.chapter,
    required this.startTime,
    required this.endTime,
    required this.location,
    this.isMovingClass = false,
  });

  final String name;
  final int period;
  final String chapter;
  final String startTime;
  final String endTime;
  final String location;
  /// 개인 시간표에서 '이동 수업'으로 표시(알림 연동).
  final bool isMovingClass;
}

class TimetableChangeLogItem {
  const TimetableChangeLogItem({
    required this.weekOffset,
    required this.dayOfWeek,
    required this.period,
    this.previousSubject,
    required this.newSubject,
    this.reason,
    required this.createdAt,
  });

  final int weekOffset;
  final int dayOfWeek;
  final int period;
  final String? previousSubject;
  final String newSubject;
  final String? reason;
  final DateTime createdAt;

  static TimetableChangeLogItem? fromMap(Map<String, dynamic>? map) {
    if (map == null) return null;
    final createdAt = map['created_at'];
    return TimetableChangeLogItem(
      weekOffset: (map['week_offset'] as num?)?.toInt() ?? 0,
      dayOfWeek: (map['day_of_week'] as num?)?.toInt() ?? 1,
      period: (map['period'] as num?)?.toInt() ?? 1,
      previousSubject: map['previous_subject'] as String?,
      newSubject: (map['new_subject'] as String?) ?? '',
      reason: map['reason'] as String?,
      createdAt: createdAt is String
          ? DateTime.tryParse(createdAt) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

enum TimetableViewState {
  loading,
  emptyWeekday,
  emptyWeekend,
  hasCurrentClass,
  noCurrentClass,
  longText,
  accessibility,
  error,
}

class TodayClassesViewModel extends ChangeNotifier {
  late DateTime _selectedDate;

  TodayClassesViewModel() {
    _selectedDate = _normalizeSelectedDate(DateTime.now());
    _startProgressTimer();
    loadAll();
  }

  /// 주말에는 금요일 기준으로 맞춤 — 화면은 평일(월~금)만 다룸.
  static DateTime _normalizeSelectedDate(DateTime d) {
    final day = DateTime(d.year, d.month, d.day);
    if (day.weekday == DateTime.saturday) {
      return day.subtract(const Duration(days: 1));
    }
    if (day.weekday == DateTime.sunday) {
      return day.subtract(const Duration(days: 2));
    }
    return day;
  }
  List<ClassItem> _classes = [];
  List<TimetableChangeLogItem> _changeLogs = [];
  String? _avatarUrl;
  AppProfile? _profile;
  bool _timetableLoading = true;
  bool _changeLogsLoading = true;
  String? _error;
  Timer? _progressTimer;

  final Map<String, List<ClassItem>> _timetableCache = {};

  DateTime get selectedDate => _selectedDate;
  List<ClassItem> get classes => _classes;
  List<TimetableChangeLogItem> get changeLogs => _changeLogs;
  String? get avatarUrl => _avatarUrl;
  bool get timetableLoading => _timetableLoading;
  bool get changeLogsLoading => _changeLogsLoading;
  String? get error => _error;

  int? get currentPeriodIfToday {
    final now = DateTime.now();
    if (_selectedDate.year != now.year ||
        _selectedDate.month != now.month ||
        _selectedDate.day != now.day) {
      return null;
    }
    return TimetableUtils.currentPeriodAndSecondsLeft(now).period;
  }

  bool isCompleted(ClassItem item) {
    final cp = currentPeriodIfToday;
    if (cp == null) return false;
    return item.period < cp;
  }

  bool isCurrent(ClassItem item) => currentPeriodIfToday == item.period;

  int? minutesLeftForCurrentClass(ClassItem item) {
    if (!isCurrent(item)) return null;
    final now = DateTime.now();
    final parts = item.endTime.split(':');
    if (parts.length < 2) return null;
    final endHour = int.tryParse(parts[0]);
    final endMinute = int.tryParse(parts[1]);
    if (endHour == null || endMinute == null) return null;
    final endAt = DateTime(now.year, now.month, now.day, endHour, endMinute);
    final diff = endAt.difference(now).inMinutes;
    return diff < 0 ? 0 : diff;
  }

  double currentClassProgress(ClassItem item) {
    if (!isCurrent(item)) return 0;
    final now = DateTime.now();
    final startParts = item.startTime.split(':');
    final endParts = item.endTime.split(':');
    if (startParts.length < 2 || endParts.length < 2) return 0;
    final sh = int.tryParse(startParts[0]);
    final sm = int.tryParse(startParts[1]);
    final eh = int.tryParse(endParts[0]);
    final em = int.tryParse(endParts[1]);
    if (sh == null || sm == null || eh == null || em == null) return 0;
    final start = DateTime(now.year, now.month, now.day, sh, sm);
    final end = DateTime(now.year, now.month, now.day, eh, em);
    final total = end.difference(start).inSeconds;
    final elapsed = now.difference(start).inSeconds;
    if (total <= 0) return 0;
    return (elapsed / total).clamp(0.05, 1.0);
  }

  void selectDate(DateTime date) {
    _selectedDate = _normalizeSelectedDate(date);
    notifyListeners();
    _loadTimetableForDate(_selectedDate);
  }

  void selectWeekday(int weekday) {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - DateTime.monday));
    final target = monday.add(Duration(days: weekday - DateTime.monday));
    selectDate(DateTime(target.year, target.month, target.day));
  }

  void navigateMonth(int delta) {
    _selectedDate = DateTime(
      _selectedDate.year,
      _selectedDate.month + delta,
      1,
    );
    notifyListeners();
    _loadTimetableForDate(_selectedDate);
  }

  Future<void> loadAll() async {
    _error = null;
    notifyListeners();
    await _loadProfile();
    await Future.wait([
      _loadTimetableForDate(_selectedDate),
      _loadChangeLogs(),
    ]);
  }

  Future<void> refresh() async {
    _timetableCache.remove(_cacheKey(_selectedDate));
    await Future.wait([
      _loadTimetableForDate(_selectedDate),
      _loadChangeLogs(),
    ]);
  }

  Future<void> upsertTimetableEntry({
    required int period,
    required String subject,
    String? room,
    bool isMovingClass = false,
  }) async {
    final uid = supabase.auth.currentUser?.id;
    final dayOfWeek = TimetableUtils.dayOfWeekForDb(_selectedDate);
    if (uid == null || dayOfWeek == null) return;

    await supabase.from('timetable_entries').upsert({
      'user_id': uid,
      'day_of_week': dayOfWeek,
      'period': period,
      'subject': subject.trim(),
      'room': room?.trim().isEmpty == true ? null : room?.trim(),
      'is_moving_class': isMovingClass,
    }, onConflict: 'user_id,day_of_week,period');

    _timetableCache.remove(_cacheKey(_selectedDate));
    await _loadTimetableForDate(_selectedDate);
    try {
      await ClassMoveNotificationService.scheduleClassMoveNotifications();
    } catch (_) {}
  }

  Future<void> deleteTimetableEntry({required int period}) async {
    final uid = supabase.auth.currentUser?.id;
    final dayOfWeek = TimetableUtils.dayOfWeekForDb(_selectedDate);
    if (uid == null || dayOfWeek == null) return;

    await supabase
        .from('timetable_entries')
        .delete()
        .eq('user_id', uid)
        .eq('day_of_week', dayOfWeek)
        .eq('period', period);

    _timetableCache.remove(_cacheKey(_selectedDate));
    await _loadTimetableForDate(_selectedDate);
    try {
      await ClassMoveNotificationService.scheduleClassMoveNotifications();
    } catch (_) {}
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await getCurrentProfile();
      _profile = profile;
      _avatarUrl = profile?.avatarUrl;
      notifyListeners();
    } catch (_) {}
  }

  String _cacheKey(DateTime date) =>
      '${date.year}-${date.month}-${date.day}';

  Future<void> _loadTimetableForDate(DateTime date) async {
    final key = _cacheKey(date);
    final cached = _timetableCache[key];
    if (cached != null) {
      _classes = cached;
      _timetableLoading = false;
      notifyListeners();
      return;
    }

    _timetableLoading = true;
    notifyListeners();

    final uid = supabase.auth.currentUser?.id;
    if (uid == null) {
      _classes = [];
      _timetableLoading = false;
      notifyListeners();
      return;
    }

    _profile ??= await getCurrentProfile();

    final dayOfWeek = TimetableUtils.dayOfWeekForDb(date);
    if (dayOfWeek == null) {
      _classes = [];
      _timetableLoading = false;
      notifyListeners();
      return;
    }

    try {
      final rows = await MergedSchoolTimetable.fetchRowsForDate(
        date: date,
        userId: uid,
        profile: _profile,
      );
      _classes = rows.map((e) {
        final period = (e['period'] as num?)?.toInt() ?? 0;
        final rawSubject = (e['subject'] as String?)?.trim() ?? '';
        final subject = rawSubject.isEmpty ? '(없음)' : rawSubject;
        final room = (e['room'] as String?)?.trim() ?? '';
        final moving = e['is_moving_class'] == true;
        return ClassItem(
          name: subject,
          period: period,
          chapter: '$period교시${room.isNotEmpty ? ' - $room' : ''}',
          startTime: TimetableUtils.startTimeString(period, date: date),
          endTime: TimetableUtils.endTimeString(period, date: date),
          location: room,
          isMovingClass: moving,
        );
      }).toList();
      _timetableCache[key] = _classes;
      _error = null;
    } catch (e) {
      _classes = [];
      _error = '시간표를 불러오지 못했습니다';
    }
    _timetableLoading = false;
    notifyListeners();
  }

  Future<void> _loadChangeLogs() async {
    _changeLogsLoading = true;
    notifyListeners();
    try {
      final res = await supabase
          .from('class_timetable_change_logs')
          .select()
          .order('created_at', ascending: false)
          .limit(30);
      final list = List<Map<String, dynamic>>.from(res as List);
      _changeLogs = list
          .map((e) => TimetableChangeLogItem.fromMap(e))
          .whereType<TimetableChangeLogItem>()
          .toList();
    } catch (_) {
      _changeLogs = [];
    }
    _changeLogsLoading = false;
    notifyListeners();
  }

  void _startProgressTimer() {
    _progressTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => notifyListeners(),
    );
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    super.dispose();
  }
}
