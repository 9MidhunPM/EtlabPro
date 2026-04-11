import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/student_data.dart';
import '../utils/results_analysis.dart';
import 'marks/widgets/analysis_tab.dart';
import 'marks/widgets/results_tab.dart';

class MarksScreen extends StatefulWidget {
  const MarksScreen({super.key});

  @override
  State<MarksScreen> createState() => _MarksScreenState();
}

class _MarksScreenState extends State<MarksScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;
  List<SubjectAnalysis> _analysisData = [];
  bool _analysisQueued = false;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  void _refreshAnalysis() {
    final data = context.read<StudentData>();
    if (data.marks.isEmpty) return;
    setState(() {
      _analysisData = getResultsAnalysis(data.marks, data.attendance);
    });
  }

  Future<void> _refreshMarksWithFeedback() async {
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

  Future<void> _refreshAnalysisWithFeedback() async {
    await _refreshMarksWithFeedback();
    if (!mounted) return;
    _refreshAnalysis();
  }

  static int _examPriority(String key) {
    final k = key.toLowerCase();
    final n = int.tryParse(RegExp(r'\d+').firstMatch(k)?.group(0) ?? '') ?? 99;
    if (k.contains('cat')) return n;
    if (k.contains('assignment') || k.contains('assign')) return 100 + n;
    return 200 + n;
  }

  static String _normalizeExamLabel(String raw, String examNumber) {
    final normalized = raw.trim().toLowerCase().replaceAll('_', ' ').replaceAll('-', ' ');
    final num = RegExp(r'\d+').firstMatch(examNumber)?.group(0) ?? RegExp(r'\d+').firstMatch(normalized)?.group(0) ?? '';

    if (normalized.contains('series') || normalized.contains('cat')) {
      return num.isNotEmpty ? 'CAT $num' : 'CAT';
    }
    if (normalized.contains('assignment') || normalized.contains('assign')) {
      return num.isNotEmpty ? 'Assignment $num' : 'Assignment';
    }
    return raw.trim().isNotEmpty ? raw.trim() : 'Unknown Exam';
  }

  static String _examLabel(Map row) {
    final labelRaw = row['exam_label']?.toString() ?? '';
    final typeRaw = row['exam_type']?.toString() ?? '';
    final numRaw = row['exam_number']?.toString().trim() ?? '';

    if (labelRaw.trim().isNotEmpty) {
      return _normalizeExamLabel(labelRaw, numRaw);
    }

    if (typeRaw.trim().isNotEmpty) {
      return _normalizeExamLabel(typeRaw, numRaw);
    }

    return 'Unknown Exam';
  }

  @override
  Widget build(BuildContext context) {
    final data = context.watch<StudentData>();
    final rows = data.marks;
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final topBarBg = isDark ? const Color(0xFF1C1031) : Colors.white;
    final topBarFg = isDark ? const Color(0xFFD8C9FF) : const Color(0xFF4B2880);

    if (!_analysisQueued && _analysisData.isEmpty && rows.isNotEmpty) {
      _analysisQueued = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _refreshAnalysis();
      });
    }

    final Map<String, List> groups = {};
    for (final row in rows) {
      final key = _examLabel(row as Map);
      groups.putIfAbsent(key, () => []).add(row);
    }
    final sortedEntries = groups.entries.toList()..sort((a, b) => _examPriority(a.key).compareTo(_examPriority(b.key)));

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
                tabs: const [Tab(text: 'Results'), Tab(text: 'Analysis')],
              ),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabCtrl,
              children: [
                MarksResultsTab(
                  sortedEntries: sortedEntries,
                  onRefresh: _refreshMarksWithFeedback,
                  scheme: scheme,
                ),
                MarksAnalysisTab(
                  analysisData: _analysisData,
                  onRefresh: _refreshAnalysisWithFeedback,
                  onUpdateAssignment: (index, value) {
                    setState(() {
                      final item = _analysisData[index];
                      item.assignment = value.clamp(0, item.assignmentScale);
                    });
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


