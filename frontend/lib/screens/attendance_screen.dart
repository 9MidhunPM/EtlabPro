import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/student_data.dart';
import '../utils/attendance_analysis.dart';
import '../widgets/screen_parts.dart';
import 'attendance/widgets/analysis_tab.dart';
import 'attendance/widgets/attendance_tab.dart';
import 'monthly/widgets/monthly_sections.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;
  DateTime _targetDate = DateTime.now().add(const Duration(days: 30));
  AttendanceAnalysis? _analysis;
  bool _includeDutyLeave = false;
  bool _monthlyLoading = false;
  String? _monthlyError;
  Map<String, dynamic>? _currentMonth;
  int? _selectedDay;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _hydrateMonthlyFromCache();
    if (_currentMonth == null) {
      _loadMonthlyAttendance();
    }
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  void _analyze() {
    final data = context.read<StudentData>();
    if (data.attendance.isEmpty || data.timetable.isEmpty) return;
    setState(() {
      _analysis = getComprehensiveAnalysis(data.attendance, data.timetable, _targetDate, data.marks);
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _targetDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _targetDate = picked);
    }
  }

  Future<void> _refreshAttendanceWithFeedback() async {
    final data = context.read<StudentData>();
    final auth = context.read<AuthService>();
    final roll = auth.rollNumber;
    if (roll == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Session not ready. Please login again.')));
      return;
    }
    HapticFeedback.selectionClick();
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(const SnackBar(content: Text('Refreshing all data...'), duration: Duration(milliseconds: 900)));
    await data.refreshEverything(
      roll,
      username: auth.username,
      password: auth.password,
    );
    if (!mounted) return;
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(const SnackBar(content: Text('All sections refreshed'), duration: Duration(milliseconds: 900)));
  }

  Future<void> _loadMonthlyAttendance() async {
    final data = context.read<StudentData>();
    final auth = context.read<AuthService>();

    if (auth.username == null || auth.password == null) {
      return;
    }

    setState(() {
      _monthlyLoading = true;
      _monthlyError = null;
    });

    try {
      final result = await data.fetchLiveMonthlyAttendance(
        username: auth.username!,
        password: auth.password!,
      );
      final months = (result['months'] as List? ?? []).cast<Map<String, dynamic>>();
      final month = _pickLatestMonth(months);
      final key = month == null ? null : _monthKey(month);
      final cachedSelectedDay = key != null && data.monthlySelectedMonthKey == key
          ? data.monthlySelectedDay
          : null;
      final previousSelectedDay = month != null && _currentMonth != null && _monthKey(_currentMonth!) == key
          ? _selectedDay
          : null;
      final resolvedSelectedDay = month == null
          ? null
          : _resolveSelectableDay(month, cachedSelectedDay ?? previousSelectedDay);
      if (!mounted) return;
      setState(() {
        _currentMonth = month;
        _selectedDay = resolvedSelectedDay;
      });
      if (month != null) {
        data.monthlySelectedMonthKey = key;
        data.monthlySelectedDay = resolvedSelectedDay;
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _monthlyError = 'Failed to load monthly attendance: $e');
    } finally {
      if (mounted) setState(() => _monthlyLoading = false);
    }
  }

  Map<String, dynamic>? _pickLatestMonth(List<Map<String, dynamic>> months) {
    if (months.isEmpty) return null;

    int monthIndex(String? month) {
      final key = (month ?? '').trim().toLowerCase();
      const lookup = {
        'jan': 1,
        'feb': 2,
        'mar': 3,
        'apr': 4,
        'may': 5,
        'jun': 6,
        'jul': 7,
        'aug': 8,
        'sep': 9,
        'oct': 10,
        'nov': 11,
        'dec': 12,
      };
      return lookup[key.length >= 3 ? key.substring(0, 3) : key] ?? 0;
    }

    DateTime score(Map<String, dynamic> month) {
      final year = int.tryParse(month['year']?.toString() ?? '') ?? 0;
      return DateTime(year, monthIndex(month['month']?.toString()));
    }

    months.sort((a, b) => score(a).compareTo(score(b)));
    return months.last;
  }

  int _firstSelectableDay(Map<String, dynamic> month) {
    final entries = (month['entries'] as List? ?? []).cast<Map<String, dynamic>>();
    if (entries.isEmpty) return 1;
    return (entries.first['day'] as num?)?.toInt() ?? 1;
  }

  void _hydrateMonthlyFromCache() {
    final data = context.read<StudentData>();
    if (data.monthlyAttendance.isEmpty) return;
    final months = data.monthlyAttendance.cast<Map<String, dynamic>>();
    final month = _pickLatestMonth(List<Map<String, dynamic>>.from(months));
    if (month == null) return;
    final key = _monthKey(month);
    final cachedDay = data.monthlySelectedMonthKey == key ? data.monthlySelectedDay : null;
    _currentMonth = month;
    _selectedDay = _resolveSelectableDay(month, cachedDay);
  }

  String _monthKey(Map<String, dynamic> month) {
    return '${month['month']}-${month['year']}';
  }

  int _resolveSelectableDay(Map<String, dynamic> month, int? preferredDay) {
    final entries = (month['entries'] as List? ?? []).cast<Map<String, dynamic>>();
    final validDays = entries
        .map((e) => (e['day'] as num?)?.toInt())
        .whereType<int>()
        .toSet();
    if (preferredDay != null && validDays.contains(preferredDay)) {
      return preferredDay;
    }
    return _firstSelectableDay(month);
  }

  void _setSelectedDay(int day) {
    final data = context.read<StudentData>();
    final month = _currentMonth;
    setState(() => _selectedDay = day);
    if (month != null) {
      data.monthlySelectedMonthKey = _monthKey(month);
      data.monthlySelectedDay = day;
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = context.watch<StudentData>();
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final topBarBg = isDark ? const Color(0xFF1C1031) : Colors.white;
    final topBarFg = isDark ? const Color(0xFFD8C9FF) : const Color(0xFF4B2880);

    return Scaffold(
      body: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: topBarBg,
              border: Border(bottom: BorderSide(color: scheme.outline, width: 1.2)),
            ),
            child: SafeArea(
              bottom: false,
              child: TabBar(
                controller: _tabCtrl,
                labelColor: topBarFg,
                unselectedLabelColor: topBarFg.withAlpha(160),
                indicatorColor: scheme.primary,
                dividerColor: Colors.transparent,
                tabs: const [Tab(text: 'Attendance'), Tab(text: 'Monthly'), Tab(text: 'Analysis')],
              ),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabCtrl,
              children: [
                AttendanceTab(
                  data: data,
                  scheme: scheme,
                  onRefresh: _refreshAttendanceWithFeedback,
                  includeDutyLeave: _includeDutyLeave,
                  onIncludeDutyLeaveChanged: (value) => setState(() => _includeDutyLeave = value),
                ),
                _buildMonthlyTab(),
                AttendanceAnalysisTab(
                  data: data,
                  targetDate: _targetDate,
                  analysis: _analysis,
                  onPickDate: _pickDate,
                  onAnalyze: _analyze,
                  onRefresh: () async {
                    await _refreshAttendanceWithFeedback();
                    await _loadMonthlyAttendance();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthlyTab() {
    final month = _currentMonth;
    if (_monthlyLoading && month == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _loadMonthlyAttendance,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          if (_monthlyError != null) ...[
            ScreenErrorCard(message: _monthlyError!),
            const SizedBox(height: 16),
          ],
          if (month != null) ...[
            MonthlyCalendarCard(
              month: month,
              selectedDay: _selectedDay,
              onDaySelected: _setSelectedDay,
            ),
            const SizedBox(height: 16),
            MonthlyDayDetailCard(month: month, selectedDay: _selectedDay),
          ] else if (!_monthlyLoading) ...[
            const ScreenEmptyState(
              icon: Icons.calendar_month,
              title: 'No monthly attendance data available',
            ),
          ],
        ],
      ),
    );
  }
}

