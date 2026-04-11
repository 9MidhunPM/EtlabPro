import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/api_client.dart';
import '../core/constants.dart';

class StudentData extends ChangeNotifier {
  static const _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  Map<String, dynamic>? profile;
  Map<String, dynamic>? summary;
  List<dynamic> attendance        = [];
  List<dynamic> marks             = [];
  List<dynamic> universityResults = [];
  List<dynamic> timetable         = [];
  String? shrNumber;

  // ── New endpoints data ─────────────────────────────────────────────
  List<dynamic> dutyLeaveAttendance = [];
  List<dynamic> monthlyAttendance = [];
  int? monthlySelectedDay;
  String? monthlySelectedMonthKey;
  Map<String, dynamic>? updates;
  Map<String, dynamic>? attendanceMetadata;

  bool isLoading = false;
  String? error;
  final Set<String> _loadingSections = <String>{};

  Set<String> get loadingSections => Set.unmodifiable(_loadingSections);

  // ── Sync timestamps (in-memory) ────────────────────────────────────
  DateTime? _attendanceSynced;
  DateTime? _marksSynced;
  DateTime? _timetableSynced;
  DateTime? _uniResultsSynced;

  DateTime? get attendanceSynced  => _attendanceSynced;
  DateTime? get marksSynced       => _marksSynced;
  DateTime? get timetableSynced   => _timetableSynced;
  DateTime? get uniResultsSynced  => _uniResultsSynced;

  // ── Restore data from local storage (instant, offline) ─────────────

  Future<void> restoreFromLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final p = prefs.getString(AppConstants.kLocalProfile);
    if (p != null) profile = jsonDecode(p) as Map<String, dynamic>;
    final s = prefs.getString(AppConstants.kLocalSummary);
    if (s != null) summary = jsonDecode(s) as Map<String, dynamic>;
    final a = prefs.getString(AppConstants.kLocalAttendance);
    if (a != null) attendance = jsonDecode(a) as List;
    final m = prefs.getString(AppConstants.kLocalMarks);
    if (m != null) marks = jsonDecode(m) as List;
    final u = prefs.getString(AppConstants.kLocalUniResults);
    if (u != null) universityResults = jsonDecode(u) as List;
    final t = prefs.getString(AppConstants.kLocalTimetable);
    if (t != null) timetable = jsonDecode(t) as List;
    final shr = prefs.getString(AppConstants.kLocalShrNumber);
    if (shr != null) shrNumber = shr;
    // Restore cached timestamps
    final att = await _secureStorage.read(key: AppConstants.kAttendanceTs);
    if (att != null) _attendanceSynced = DateTime.tryParse(att);
    final mks = await _secureStorage.read(key: AppConstants.kMarksTs);
    if (mks != null) _marksSynced = DateTime.tryParse(mks);
    final ttb = await _secureStorage.read(key: AppConstants.kTimetableTs);
    if (ttb != null) _timetableSynced = DateTime.tryParse(ttb);
    final uni = await _secureStorage.read(key: AppConstants.kUniResultsTs);
    if (uni != null) _uniResultsSynced = DateTime.tryParse(uni);
    notifyListeners();
  }

  // ── Save data to local storage ─────────────────────────────────────

  Future<void> _saveToLocal() async {
    final prefs = await SharedPreferences.getInstance();
    if (profile != null) await prefs.setString(AppConstants.kLocalProfile, jsonEncode(profile));
    if (summary != null) await prefs.setString(AppConstants.kLocalSummary, jsonEncode(summary));
    if (attendance.isNotEmpty) await prefs.setString(AppConstants.kLocalAttendance, jsonEncode(attendance));
    if (marks.isNotEmpty) await prefs.setString(AppConstants.kLocalMarks, jsonEncode(marks));
    if (universityResults.isNotEmpty) await prefs.setString(AppConstants.kLocalUniResults, jsonEncode(universityResults));
    if (timetable.isNotEmpty) await prefs.setString(AppConstants.kLocalTimetable, jsonEncode(timetable));
    if (shrNumber != null) await prefs.setString(AppConstants.kLocalShrNumber, shrNumber!);
  }

  // ── Smart load: only fetch stale data from DB ──────────────────────

  Future<void> loadAll(String roll, {bool force = false}) async {
    isLoading = true;
    error     = null;
    notifyListeners();

    try {
      final futures = <Future>[];

      if (force || await _isStale(AppConstants.kProfileTs, AppConstants.defaultTtl) || profile == null) {
        futures.add(_fetchProfile(roll));
      }
      if (force || await _isStale(AppConstants.kSummaryTs, AppConstants.defaultTtl) || summary == null) {
        futures.add(_fetchSummary(roll));
      }
      if (force || await _isStale(AppConstants.kAttendanceTs, AppConstants.attendanceTtl) || attendance.isEmpty) {
        futures.add(_fetchAttendance(roll));
      }
      if (force || await _isStale(AppConstants.kMarksTs, AppConstants.defaultTtl) || marks.isEmpty) {
        futures.add(_fetchMarks(roll));
      }
      if (force || await _isStale(AppConstants.kUniResultsTs, AppConstants.defaultTtl) || universityResults.isEmpty) {
        futures.add(_fetchUniResults(roll));
      }
      if (force || await _isStale(AppConstants.kTimetableTs, AppConstants.defaultTtl) || timetable.isEmpty) {
        futures.add(_fetchTimetable(roll));
      }

      await Future.wait(futures);
      await _saveToLocal();
    } on ApiException catch (e) {
      error = e.message;
    } catch (e) {
      error = 'Failed to load data.';
    }

    isLoading = false;
    notifyListeners();
  }

  // ── Individual fetchers ────────────────────────────────────────────

  Future<void> _fetchProfile(String roll) async {
    await _trackSectionLoad('Profile', () async {
      profile = await ApiClient.instance.get('/profile/$roll') as Map<String, dynamic>;
      await _stamp(AppConstants.kProfileTs);
    });
  }

  Future<void> _fetchSummary(String roll) async {
    await _trackSectionLoad('Summary', () async {
      summary = await ApiClient.instance.get('/summary/$roll') as Map<String, dynamic>;
      await _stamp(AppConstants.kSummaryTs);
    });
  }

  Future<void> _fetchAttendance(String roll) async {
    await _trackSectionLoad('Attendance', () async {
      final auth = await _loadStoredCredentials();
      if (auth == null) {
        throw StateError('Missing stored credentials for live attendance fetch.');
      }
      final r = await ApiClient.instance.post('/live/attendance', {
        'username': auth.$1,
        'password': auth.$2,
      });
      attendance = (r as Map)['attendance'] as List;
      await _stamp(AppConstants.kAttendanceTs);
    });
  }

  Future<void> _fetchMarks(String roll) async {
    await _trackSectionLoad('Marks', () async {
      final r = await ApiClient.instance.get('/internal-results/$roll');
      marks = (r as Map)['marks'] as List;
      await _stamp(AppConstants.kMarksTs);
    });
  }

  Future<void> _fetchUniResults(String roll) async {
    await _trackSectionLoad('University Results', () async {
      final r = await ApiClient.instance.get('/university-results/$roll');
      universityResults = (r as Map)['results'] as List;
      await _stamp(AppConstants.kUniResultsTs);
    });
  }

  Future<void> _fetchTimetable(String roll) async {
    await _trackSectionLoad('Timetable', () async {
      final r = await ApiClient.instance.get('/timetable/$roll');
      timetable = (r as Map)['slots'] as List;
      shrNumber = (r['student_details'] as Map?)?['roll_no'] as String?;
      await _stamp(AppConstants.kTimetableTs);
    });
  }

  // ── Force-refresh a single section ─────────────────────────────────

  Future<void> refreshAttendance(String roll) async {
    try {
      await _fetchAttendance(roll);
      await _saveToLocal();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> refreshMarks(String roll) async {
    try {
      await _fetchMarks(roll);
      await _saveToLocal();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> refreshTimetable(String roll) async {
    try {
      await _fetchTimetable(roll);
      await _saveToLocal();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> refreshUniResults(String roll) async {
    try {
      await _fetchUniResults(roll);
      await _saveToLocal();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> refreshAll(String roll) async {
    await loadAll(roll, force: true);
  }

  Future<void> refreshEverything(
    String roll, {
    String? username,
    String? password,
  }) async {
    await loadAll(roll, force: true);

    String? user = username;
    String? pass = password;
    if (user == null || pass == null) {
      final creds = await _loadStoredCredentials();
      user = creds?.$1;
      pass = creds?.$2;
    }
    if (user == null || pass == null) return;

    try {
      await fetchLiveDutyLeaveAttendance(user, pass);
    } catch (_) {}
    try {
      await fetchLiveMonthlyAttendance(username: user, password: pass);
    } catch (_) {}
    try {
      await fetchLiveUpdates(username: user, password: pass);
    } catch (_) {}
  }

  Future<(String, String)?> _loadStoredCredentials() async {
    final username = await _secureStorage.read(key: AppConstants.kUsername);
    final password = await _secureStorage.read(key: AppConstants.kPassword);
    if (username == null || password == null) {
      return null;
    }
    return (username, password);
  }

  // ── Live endpoints (duty leave, monthly attendance, updates) ────────

  Future<Map<String, dynamic>> fetchLiveDutyLeaveAttendance(String username, String password) async {
    try {
      final result = await ApiClient.instance.post('/live/attendance-duty-leave', {
        'username': username,
        'password': password,
      });
      dutyLeaveAttendance = (result as Map)['attendance'] as List? ?? [];
      notifyListeners();
      return result as Map<String, dynamic>;
    } catch (e) {
      error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<Map<String, dynamic>> fetchLiveMonthlyAttendance({
    required String username,
    required String password,
  }) async {
    try {
      final result = await ApiClient.instance.post('/live/monthly-attendance-simple', {
        'username': username,
        'password': password,
      });

      final typed = result as Map<String, dynamic>;
      monthlyAttendance = typed['months'] as List? ?? [];
      notifyListeners();
      return typed;
    } catch (e) {
      error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<Map<String, dynamic>> fetchLiveUpdates({
    required String username,
    required String password,
    bool includeUniversityResults = true,
  }) async {
    try {
      final result = await ApiClient.instance.post('/live/updates', {
        'username': username,
        'password': password,
        'include_university_results': includeUniversityResults,
      });
      updates = result as Map<String, dynamic>;
      notifyListeners();
      return result;
    } catch (e) {
      error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<Map<String, dynamic>> fetchAttendanceMetadata({
    required String username,
    required String password,
  }) async {
    try {
      final result = await ApiClient.instance.post('/live/attendance-metadata', {
        'username': username,
        'password': password,
      });
      attendanceMetadata = result as Map<String, dynamic>;
      notifyListeners();
      return result;
    } catch (e) {
      error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<bool> _isStale(String key, Duration ttl) async {
    final ts = await _secureStorage.read(key: key);
    if (ts == null) return true;
    final saved = DateTime.tryParse(ts);
    if (saved == null) return true;
    return DateTime.now().difference(saved) > ttl;
  }

  Future<void> _stamp(String key) async {
    final now = DateTime.now();
    await _secureStorage.write(key: key, value: now.toIso8601String());
    if (key == AppConstants.kAttendanceTs) {
      _attendanceSynced = now;
    } else if (key == AppConstants.kMarksTs) {
      _marksSynced = now;
    } else if (key == AppConstants.kTimetableTs) {
      _timetableSynced = now;
    } else if (key == AppConstants.kUniResultsTs) {
      _uniResultsSynced = now;
    }
  }

  Future<void> clear() async {
    profile = summary = shrNumber = null;
    attendance = marks = universityResults = timetable = [];
    dutyLeaveAttendance = monthlyAttendance = [];
    monthlySelectedDay = null;
    monthlySelectedMonthKey = null;
    updates = attendanceMetadata = null;
    error = null;
    final prefs = await SharedPreferences.getInstance();
    for (final k in [
      AppConstants.kLocalProfile, AppConstants.kLocalSummary,
      AppConstants.kLocalAttendance, AppConstants.kLocalMarks,
      AppConstants.kLocalUniResults, AppConstants.kLocalTimetable,
      AppConstants.kLocalShrNumber,
    ]) {
      await prefs.remove(k);
    }
    notifyListeners();
  }

  Future<void> _trackSectionLoad(String label, Future<void> Function() action) async {
    _loadingSections.add(label);
    notifyListeners();
    try {
      await action();
    } finally {
      _loadingSections.remove(label);
      notifyListeners();
    }
  }
}
