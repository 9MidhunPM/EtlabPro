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
    messenger.showSnackBar(const SnackBar(content: Text('Refreshing marks...'), duration: Duration(milliseconds: 900)));
    await data.refreshMarks(roll);
    if (!mounted) return;
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(const SnackBar(content: Text('Marks updated'), duration: Duration(milliseconds: 900)));
  }

  Future<void> _refreshAnalysisWithFeedback() async {
    HapticFeedback.selectionClick();
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(const SnackBar(content: Text('Refreshing analysis...'), duration: Duration(milliseconds: 900)));
    _refreshAnalysis();
    await Future<void>.delayed(const Duration(milliseconds: 120));
    if (!mounted) return;
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(const SnackBar(content: Text('Analysis refreshed'), duration: Duration(milliseconds: 900)));
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

    if (_analysisData.isEmpty && rows.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _refreshAnalysis());
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
                      tabs: const [Tab(text: 'Results'), Tab(text: 'Analysis')],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Refresh marks',
                    icon: Icon(Icons.refresh_rounded, color: scheme.onPrimary),
                    onPressed: _refreshMarksWithFeedback,
                  ),
                ],
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


