import 'package:flutter/foundation.dart';

import 'package:myapp/core/auth/auth_state.dart';
import 'package:myapp/repositories/schedule_repository.dart';

/// 일정 탭의 상태 및 데이터 로딩/변경 담당.
/// UI는 이 ViewModel을 통해 [ScheduleRepository]만 사용한다.
class ScheduleViewModel extends ChangeNotifier {
  ScheduleViewModel({ScheduleRepository? repository})
    : _repo = repository ?? ScheduleRepository(),
      _viewMonth = DateTime(DateTime.now().year, DateTime.now().month),
      _selectedDate = DateTime(
        DateTime.now().year,
        DateTime.now().month,
        DateTime.now().day,
      );

  final ScheduleRepository _repo;

  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _personalEvents = [];
  List<Map<String, dynamic>> _classEvents = [];
  List<Map<String, dynamic>> _neisItems = [];
  bool _loading = false;
  String? _error;
  AppProfile? _profile;
  DateTime _viewMonth;
  DateTime _selectedDate;

  List<Map<String, dynamic>> get items => _items;
  List<Map<String, dynamic>> get personalEvents => _personalEvents;
  List<Map<String, dynamic>> get classEvents => _classEvents;
  List<Map<String, dynamic>> get neisItems => _neisItems;
  bool get loading => _loading;
  String? get error => _error;
  AppProfile? get profile => _profile;
  DateTime get viewMonth => _viewMonth;
  DateTime get selectedDate => _selectedDate;

  set viewMonth(DateTime v) {
    _viewMonth = v;
    notifyListeners();
  }

  set selectedDate(DateTime v) {
    _selectedDate = v;
    notifyListeners();
  }

  Future<void> loadProfile() async {
    _profile = await getCurrentProfile();
    notifyListeners();
  }

  Future<void> fetch() async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      _items = await _repo.fetchScheduleItems();
      final uid = _profile?.userId;
      final grade = _profile?.gradeOrFromStudentId;
      final classNum = _profile?.classNumOrFromStudentId;
      if (uid != null) {
        _personalEvents = await _repo.fetchPersonalEvents(uid);
      } else {
        _personalEvents = [];
      }
      if (grade != null && classNum != null) {
        _classEvents = await _repo.fetchClassEvents(
          grade: grade,
          classNumber: classNum,
        );
      } else {
        _classEvents = [];
      }
      _neisItems = await _repo.fetchAcademicCalendar(_viewMonth);
      _error = null;
    } catch (e) {
      _error = e.toString();
    }
    _loading = false;
    notifyListeners();
  }

  Future<void> addScheduleItem({
    required String title,
    String? description,
    required String startAt,
    required String endAt,
    required String createdBy,
  }) async {
    await _repo.addScheduleItem(
      title: title,
      description: description,
      startAt: startAt,
      endAt: endAt,
      createdBy: createdBy,
    );
    await fetch();
  }

  Future<void> deleteScheduleItem(String id) async {
    await _repo.deleteScheduleItem(id);
    await fetch();
  }

  Future<void> addPersonalEvent({
    required String userId,
    required String title,
    String? description,
    required String startAt,
    String? endAt,
    required bool allDay,
  }) async {
    await _repo.addPersonalEvent(
      userId: userId,
      title: title,
      description: description,
      startAt: startAt,
      endAt: endAt,
      allDay: allDay,
    );
    await fetch();
  }

  Future<void> deletePersonalEvent(String id) async {
    await _repo.deletePersonalEvent(id);
    await fetch();
  }

  Future<void> addClassEvent({
    required int grade,
    required int classNumber,
    required String title,
    String? description,
    required String startAt,
    String? endAt,
    required bool allDay,
    required String createdByUserId,
    required String createdByProfileId,
  }) async {
    await _repo.addClassEvent(
      grade: grade,
      classNumber: classNumber,
      title: title,
      description: description,
      startAt: startAt,
      endAt: endAt,
      allDay: allDay,
      createdByUserId: createdByUserId,
      createdByProfileId: createdByProfileId,
    );
    await fetch();
  }

  Future<void> deleteClassEvent(String id) async {
    await _repo.deleteClassEvent(id);
    await fetch();
  }
}
