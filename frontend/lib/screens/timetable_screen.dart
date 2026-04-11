import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/student_data.dart';
import 'timetable/widgets/analysis_tab.dart';
import 'timetable/widgets/timetable_tab.dart';

class TimetableScreen extends StatefulWidget {
  const TimetableScreen({super.key});

  @override
  State<TimetableScreen> createState() => _TimetableScreenState();
}

class _TimetableScreenState extends State<TimetableScreen> with SingleTickerProviderStateMixin {
  static const _days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];

  late String _selectedDay;
  late final TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    final today = DateTime.now().weekday;
    _selectedDay = today >= 1 && today <= 6 ? _days[today - 1] : _days[0];
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _refreshTimetableWithFeedback() async {
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

  @override
  Widget build(BuildContext context) {
    final data = context.watch<StudentData>();
    final allSlots = data.timetable;
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
                tabs: const [Tab(text: 'Timetable'), Tab(text: 'Analysis')],
              ),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabCtrl,
              children: [
                // Timetable tab
                TimetableTab(
                  allSlots: allSlots,
                  selectedDay: _selectedDay,
                  days: _days,
                  onDayChanged: (d) => setState(() => _selectedDay = d),
                  scheme: scheme,
                  onRefresh: _refreshTimetableWithFeedback,
                ),
                // Analysis tab
                TimetableAnalysisTab(
                  slots: allSlots,
                  attendance: data.attendance,
                  marks: data.marks,
                  onRefresh: _refreshTimetableWithFeedback,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
