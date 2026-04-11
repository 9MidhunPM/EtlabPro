import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/student_data.dart';
import 'uni_results/widgets/semester_page.dart';
import '../widgets/screen_parts.dart';

class UniResultsScreen extends StatefulWidget {
  const UniResultsScreen({super.key});

  @override
  State<UniResultsScreen> createState() => _UniResultsScreenState();
}

class _UniResultsScreenState extends State<UniResultsScreen> with TickerProviderStateMixin {
  TabController? _tabCtrl;
  List<int> _semesterKeys = [];

  static int _extractSemester(dynamic row) {
    final semesterField = (row['semester'] ?? '').toString().toLowerCase();
    final labelField = (row['semester_label'] ?? row['exam_name'] ?? '').toString().toLowerCase();
    final combined = '$semesterField $labelField';
    
    if (combined.contains('first')) return 1;
    if (combined.contains('second')) return 2;
    if (combined.contains('third')) return 3;
    if (combined.contains('fourth')) return 4;
    if (combined.contains('fifth')) return 5;
    if (combined.contains('sixth')) return 6;
    if (combined.contains('seventh')) return 7;
    if (combined.contains('eighth')) return 8;

    final m = RegExp(r'([1-8])').firstMatch(combined);
    return m != null ? int.parse(m.group(1)!) : 99;
  }

  static String _tabLabel(int semesterKey) {
    if (semesterKey >= 1 && semesterKey <= 8) {
      return 'Semester - $semesterKey';
    }
    return 'Other';
  }

  void _updateTabs(List<int> keys) {
    if (keys.length != _semesterKeys.length) {
      _tabCtrl?.dispose();
      _semesterKeys = List.from(keys);
      _tabCtrl = keys.isNotEmpty ? TabController(length: keys.length, vsync: this) : null;
    }
  }

  @override
  void dispose() {
    _tabCtrl?.dispose();
    super.dispose();
  }

  Future<void> _refreshUniResultsWithFeedback() async {
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

  static Color _gradeColor(String? grade) {
    final g = grade?.toUpperCase() ?? '';
    if (g == 'S') return Colors.teal.shade500;
    if (g == 'A+') return Colors.green.shade600;
    if (g == 'A') return Colors.lightGreen.shade700;
    if (g == 'B+') return Colors.blue.shade500;
    if (g == 'B') return Colors.blue.shade700;
    if (g == 'B-') return Colors.indigo.shade500;
    if (g == 'C+') return Colors.orange.shade500;
    if (g == 'C') return Colors.orange.shade700;
    if (g == 'C-') return Colors.deepOrange.shade600;
    if (g == 'D+') return Colors.pink.shade400;
    if (g == 'D') return Colors.red.shade500;
    if (g == 'F') return Colors.red.shade800;
    if (g == 'P') return Colors.deepPurple.shade500;
    return Colors.grey;
  }

  static Color _statusColor(String? status) {
    return (status?.toLowerCase().contains('pass') ?? false) ? Colors.green.shade600 : Colors.red.shade600;
  }

  @override
  Widget build(BuildContext context) {
    final data = context.watch<StudentData>();
    final rows = data.universityResults;
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final topBarBg = isDark ? const Color(0xFF1C1031) : Colors.white;
    final topBarFg = isDark ? const Color(0xFFD8C9FF) : const Color(0xFF4B2880);

    final Map<int, List> groups = {};
    for (final r in rows) {
      final semester = _extractSemester(r);
      groups.putIfAbsent(semester, () => []).add(r);
    }
    final keys = groups.keys.toList()..sort();
    _updateTabs(keys);

    if (rows.isEmpty || _tabCtrl == null) {
      return Scaffold(
        body: const SafeArea(
          child: ScreenEmptyState(
            icon: Icons.school_outlined,
            title: 'No university results',
          ),
        ),
      );
    }

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
                isScrollable: false,
                labelColor: topBarFg,
                unselectedLabelColor: topBarFg.withAlpha(160),
                indicatorColor: scheme.primary,
                dividerColor: Colors.transparent,
                tabs: keys
                    .map((k) => Tab(child: Text(_tabLabel(k), style: const TextStyle(fontSize: 12))))
                    .toList(),
              ),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabCtrl!,
              children: keys
                  .map((k) => UniSemesterPage(
                        rows: groups[k]!,
                        gradeColor: _gradeColor,
                        statusColor: _statusColor,
                        onRefresh: _refreshUniResultsWithFeedback,
                      ))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}
