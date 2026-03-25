import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/student_data.dart';
import '../utils/results_analysis.dart';

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
    if (k.contains('series') || k.contains('cat')) return n;
    if (k.contains('assignment') || k.contains('assign')) return 100 + n;
    return 200 + n;
  }

  static String _normalizedExamKey(dynamic row) {
    final typeRaw = (row['exam_type'] ?? '').toString().trim();
    final numRaw = (row['exam_number'] ?? '').toString().trim();
    final type = typeRaw.toLowerCase();

    if (type.contains('assignment')) {
      final num = RegExp(r'\d+').firstMatch(numRaw)?.group(0);
      return num != null ? 'Assignment $num' : 'Assignment';
    }
    if (type.contains('series') || type.contains('cat')) {
      final num = RegExp(r'\d+').firstMatch(numRaw)?.group(0);
      return num != null ? 'Series Exam $num' : 'Series Exam';
    }
    if (typeRaw.isNotEmpty && numRaw.isNotEmpty) {
      return '$typeRaw $numRaw';
    }
    return typeRaw.isNotEmpty ? typeRaw : 'Unknown Exam';
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
    for (final r in rows) {
      final key = _normalizedExamKey(r);
      groups.putIfAbsent(key, () => []).add(r);
    }
    final sortedEntries = groups.entries.toList()
      ..sort((a, b) => _examPriority(a.key).compareTo(_examPriority(b.key)));

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
                // Results tab
                rows.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.assignment_outlined, size: 56, color: scheme.onSurfaceVariant.withAlpha(100)),
                            const SizedBox(height: 12),
                            Text('No marks data', style: TextStyle(color: scheme.onSurfaceVariant)),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                      onRefresh: _refreshMarksWithFeedback,
                        child: ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                          children: sortedEntries.map((e) => _ExamGroup(examLabel: e.key, rows: e.value)).toList(),
                        ),
                      ),
                // Analysis tab
                _AnalysisTab(
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

// ── Results tab group ─────────────────────────────────────────────────

class _ExamGroup extends StatelessWidget {
  final String examLabel;
  final List rows;
  const _ExamGroup({required this.examLabel, required this.rows});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(top: 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.primary.withAlpha(30)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            decoration: BoxDecoration(
              color: scheme.primary,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Icon(Icons.quiz_outlined, size: 16, color: scheme.onPrimary),
                const SizedBox(width: 8),
                Text(examLabel,
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: scheme.onPrimary, letterSpacing: 0.5)),
              ],
            ),
          ),
          ...rows.asMap().entries.map((entry) {
            final r = entry.value;
            final obtained = r['marks_obtained'];
            final max = r['max_marks'];
            final pct = (obtained != null && max != null && (max as num) > 0) ? (obtained as num) / max * 100 : null;
            final isLow = pct != null && pct < 40;

            return Column(
              children: [
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                  title: Text(r['subject_name'] ?? r['subject_code'] ?? '—',
                      style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(r['subject_code'] ?? '', style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(obtained != null ? '$obtained / $max' : '—',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: isLow ? scheme.error : scheme.onSurface)),
                      if (pct != null)
                        Text('${pct.toStringAsFixed(0)}%',
                            style: TextStyle(fontSize: 12, color: isLow ? scheme.error : scheme.onSurfaceVariant)),
                    ],
                  ),
                ),
                if (entry.key < rows.length - 1)
                  Divider(height: 1, indent: 16, endIndent: 16, color: scheme.outlineVariant.withAlpha(80)),
              ],
            );
          }),
        ],
      ),
    );
  }
}

// ── Analysis Tab ──────────────────────────────────────────────────────

class _AnalysisTab extends StatelessWidget {
  final List<SubjectAnalysis> analysisData;
  final VoidCallback onRefresh;
  final void Function(int index, double value) onUpdateAssignment;

  const _AnalysisTab({
    required this.analysisData,
    required this.onRefresh,
    required this.onUpdateAssignment,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        // Legend card
        Container(
          decoration: BoxDecoration(color: scheme.surfaceContainerLow, borderRadius: BorderRadius.circular(16), border: Border.all(color: scheme.primary.withAlpha(30))),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(16, 0, 4, 0),
                decoration: BoxDecoration(
                  color: scheme.primary,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.analytics_rounded, size: 18, color: scheme.onPrimary),
                    const SizedBox(width: 8),
                    Expanded(child: Text('Grade Analysis', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: scheme.onPrimary))),
                    IconButton(icon: Icon(Icons.refresh, size: 20, color: scheme.onPrimary), onPressed: onRefresh),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Marking Scale:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: scheme.onSurfaceVariant)),
                    const SizedBox(height: 4),
                    ...[
                '• Regular: CAT-1 & Min CAT-2: /12.5 each, Assignment: /10, Total: /40',
                '• 24CSR304: CAT-1 & Min CAT-2: /7.5 each, Assignment: /30, Total: /50',
                '• Min CAT-2 shows marks needed for 26+ total (red = impossible)',
                '• Attendance: 90%+=5, 85-89%=4, 80-84%=3, 75-79%=2, 70-74%=1, <70%=0',
                '• 24PWT208 is excluded from analysis',
              ].map((t) => Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(t, style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
              )),                  ],
                ),
              ),            ],
          ),
        ),
        const SizedBox(height: 16),

        if (analysisData.isEmpty)
          Center(child: Text('No analysis data. Ensure results and attendance are loaded.', style: TextStyle(color: scheme.onSurfaceVariant)))
        else ...[
          // Table
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: scheme.surfaceContainerLow, borderRadius: BorderRadius.circular(16), border: Border.all(color: scheme.primary.withAlpha(30))),
            child: Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                  decoration: BoxDecoration(color: scheme.primary, borderRadius: BorderRadius.circular(8)),
                  child: Row(
                    children: [
                      Expanded(flex: 3, child: Text('Subject', style: _headerStyle(scheme))),
                      Expanded(flex: 2, child: Text('CAT-1', style: _headerStyle(scheme), textAlign: TextAlign.center)),
                      Expanded(flex: 2, child: Text('Min CAT-2', style: _headerStyle(scheme), textAlign: TextAlign.center)),
                      Expanded(flex: 2, child: Text('Assign', style: _headerStyle(scheme), textAlign: TextAlign.center)),
                      Expanded(flex: 2, child: Text('Attend', style: _headerStyle(scheme), textAlign: TextAlign.center)),
                      Expanded(flex: 2, child: Text('Total', style: _headerStyle(scheme), textAlign: TextAlign.center)),
                    ],
                  ),
                ),
                // Rows
                for (int i = 0; i < analysisData.length; i++)
                  _buildAnalysisRow(context, i, scheme),

                // Impossible warnings
                ..._buildWarnings(scheme),
              ],
            ),
          ),
        ],
      ],
    );
  }

  TextStyle _headerStyle(ColorScheme scheme) => TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: scheme.onPrimary);

  Widget _buildAnalysisRow(BuildContext context, int i, ColorScheme scheme) {
    final item = analysisData[i];
    final cat2Needed = item.cat2NeededFor26;
    final cat2OutOf30 = roundToHalf((cat2Needed.clamp(0, item.cat2Scale) / item.cat2Scale) * 30);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      decoration: BoxDecoration(color: i.isEven ? scheme.surfaceContainerHighest.withAlpha(40) : Colors.transparent),
      child: Row(
        children: [
          // Subject
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.subjectCode, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(item.subjectName, style: TextStyle(fontSize: 9, color: scheme.onSurfaceVariant), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          // CAT-1
          Expanded(
            flex: 2,
            child: Column(
              children: [
                Text('${item.cat1.toStringAsFixed(1)}/${item.cat1Scale}', style: const TextStyle(fontSize: 11)),
                Text('${roundToHalf((item.cat1 / item.cat1Scale) * 30).toStringAsFixed(1)}/30',
                    style: TextStyle(fontSize: 9, color: scheme.onSurfaceVariant)),
              ],
            ),
          ),
          // Min CAT-2
          Expanded(
            flex: 2,
            child: Column(
              children: [
                Text(
                  item.isImpossible ? '${item.cat2Scale}+' : '${cat2Needed.toStringAsFixed(1)}/${item.cat2Scale}',
                  style: TextStyle(fontSize: 11, color: item.isImpossible ? Colors.red.shade600 : null),
                ),
                Text('${cat2OutOf30.toStringAsFixed(1)}/30',
                    style: TextStyle(fontSize: 9, color: item.isImpossible ? Colors.red.shade600 : scheme.onSurfaceVariant)),
              ],
            ),
          ),
          // Assignment (editable)
          Expanded(
            flex: 2,
            child: Column(
              children: [
                SizedBox(
                  width: 40,
                  height: 28,
                  child: TextField(
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12),
                    decoration: InputDecoration(
                      hintText: '0',
                      hintStyle: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                      contentPadding: EdgeInsets.zero,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: scheme.outlineVariant)),
                      isDense: true,
                    ),
                    onChanged: (v) => onUpdateAssignment(i, double.tryParse(v) ?? 0),
                  ),
                ),
                Text('/${item.assignmentScale.toInt()}', style: TextStyle(fontSize: 9, color: scheme.onSurfaceVariant)),
              ],
            ),
          ),
          // Attendance
          Expanded(
            flex: 2,
            child: Column(
              children: [
                Text(
                  item.attendanceMarks != null ? '${item.attendanceMarks}/5' : 'N/A',
                  style: TextStyle(fontSize: 11, color: item.attendanceMarks != null ? Colors.green.shade600 : Colors.red.shade600),
                ),
                if (item.attendancePercentage != null)
                  Text('${item.attendancePercentage!.toStringAsFixed(1)}%',
                      style: TextStyle(fontSize: 9, color: scheme.onSurfaceVariant)),
              ],
            ),
          ),
          // Total
          Expanded(
            flex: 2,
            child: Text('${item.total.toStringAsFixed(1)}/${item.totalScale.toInt()}',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600), textAlign: TextAlign.center),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildWarnings(ColorScheme scheme) {
    final impossible = analysisData.where((a) => a.isImpossible).toList();
    if (impossible.isEmpty) return [];

    return [
      const SizedBox(height: 12),
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning_amber_rounded, size: 18, color: Colors.red.shade600),
                const SizedBox(width: 6),
                Text('Cannot Achieve Target', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.red.shade600)),
              ],
            ),
            const SizedBox(height: 8),
            ...impossible.map((s) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text('${s.subjectCode} cannot obtain 26 marks with current assignment.',
                  style: TextStyle(fontSize: 12, color: Colors.red.shade700)),
            )),
          ],
        ),
      ),
    ];
  }
}
