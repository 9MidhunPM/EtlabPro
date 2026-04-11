import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/student_data.dart';
import '../utils/attendance_analysis.dart';
import 'attendance/widgets/analysis_tab.dart';
import 'attendance/widgets/attendance_tab.dart';
import 'attendance/widgets/duty_leave_tab.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;
  DateTime _targetDate = DateTime.now().add(const Duration(days: 30));
  AttendanceAnalysis? _analysis;
  bool _dutyLeaveLoading = false;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
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
    messenger.showSnackBar(const SnackBar(content: Text('Refreshing attendance...'), duration: Duration(milliseconds: 900)));
    await data.refreshAttendance(roll);
    if (!mounted) return;
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(const SnackBar(content: Text('Attendance updated'), duration: Duration(milliseconds: 900)));
  }

  Future<void> _fetchDutyLeaveAttendance() async {
    final data = context.read<StudentData>();
    final auth = context.read<AuthService>();

    if (auth.username == null || auth.password == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Session not ready. Please login again.')));
      return;
    }

    setState(() => _dutyLeaveLoading = true);
    try {
      await data.fetchLiveDutyLeaveAttendance(auth.username!, auth.password!);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Duty leave attendance updated'), duration: Duration(milliseconds: 900)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
    } finally {
      if (mounted) setState(() => _dutyLeaveLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = context.watch<StudentData>();
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: Column(
        children: [
          Container(
            color: scheme.primary,
            child: SafeArea(
              bottom: false,
              child: Row(
                children: [
                  Expanded(
                    child: TabBar(
                      controller: _tabCtrl,
                      labelColor: scheme.onPrimary,
                      unselectedLabelColor: scheme.onPrimary.withAlpha(160),
                      indicatorColor: scheme.onPrimary,
                      dividerColor: Colors.transparent,
                      tabs: const [Tab(text: 'Attendance'), Tab(text: 'Analysis'), Tab(text: 'Duty Leave')],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: IconButton(
                      icon: Icon(Icons.refresh_rounded, color: scheme.onPrimary),
                      tooltip: 'Refresh',
                      onPressed: _refreshAttendanceWithFeedback,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabCtrl,
              children: [
                AttendanceTab(data: data, scheme: scheme, onRefresh: _refreshAttendanceWithFeedback),
                AttendanceAnalysisTab(
                  data: data,
                  targetDate: _targetDate,
                  analysis: _analysis,
                  onPickDate: _pickDate,
                  onAnalyze: _analyze,
                ),
                DutyLeaveTab(
                  data: data,
                  scheme: scheme,
                  isLoading: _dutyLeaveLoading,
                  onRefresh: _fetchDutyLeaveAttendance,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

