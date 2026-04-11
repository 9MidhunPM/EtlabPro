import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/student_data.dart';
import '../utils/attendance_analysis.dart';
import '../utils/results_analysis.dart';

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
                _AttendanceTab(data: data, scheme: scheme, onRefresh: _refreshAttendanceWithFeedback),
                _AnalysisTab(
                  data: data,
                  targetDate: _targetDate,
                  analysis: _analysis,
                  onPickDate: _pickDate,
                  onAnalyze: _analyze,
                ),
                _DutyLeaveTab(
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

// ── Attendance Tab ────────────────────────────────────────────────────

class _AttendanceTab extends StatelessWidget {
  final StudentData data;
  final ColorScheme scheme;
  final Future<void> Function() onRefresh;
  const _AttendanceTab({required this.data, required this.scheme, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final rows = data.attendance;
    final subjectRows = rows.where((r) {
      final code = r['subject_code']?.toString().toLowerCase();
      return code != 'total';
    }).toList();

    if (subjectRows.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.event_busy_rounded, size: 56, color: scheme.onSurfaceVariant.withAlpha(100)),
            const SizedBox(height: 12),
            Text('No attendance data', style: TextStyle(color: scheme.onSurfaceVariant)),
          ],
        ),
      );
    }

    final totalRow = rows.cast<Map<String, dynamic>?>().firstWhere(
      (r) => r != null && r['subject_code']?.toString().toLowerCase() == 'total',
      orElse: () => null,
    );
    final avg = subjectRows
            .map((r) => (r['percentage'] as num?)?.toDouble() ?? 0)
            .reduce((a, b) => a + b) /
        subjectRows.length;
    final overall = ((totalRow?['percentage'] as num?)?.toDouble()) ?? avg;
    final lowCount = subjectRows.where((r) => ((r['percentage'] as num?)?.toDouble() ?? 0) < 75).length;
    final safeCount = subjectRows.where((r) {
      final pct = (r['percentage'] as num?)?.toDouble() ?? 0;
      return pct >= 75 && pct < 90;
    }).length;
    final strongCount = subjectRows.length - lowCount - safeCount;

    final attendanceMark = calculateAttendanceMarks(overall) ?? 0;
    final markBand = attendanceMarkBand(overall);

    final sortedRows = List<dynamic>.from(subjectRows)
      ..sort((a, b) => ((a['percentage'] as num?) ?? 0).compareTo((b['percentage'] as num?) ?? 0));

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          _OverallCard(
            overall: overall,
            markBand: markBand,
            attendanceMark: attendanceMark,
            lowCount: lowCount,
            safeCount: safeCount,
            strongCount: strongCount,
            subjectCount: subjectRows.length,
          ),
          const SizedBox(height: 16),
          if (lowCount > 0) ...[
            _RiskAlertCard(lowCount: lowCount, lowestRows: sortedRows.take(3).toList()),
            const SizedBox(height: 14),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('By Subject', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: scheme.onSurfaceVariant)),
              Text('Lowest first', style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
            ],
          ),
          const SizedBox(height: 8),
          ...sortedRows.map((r) => _SubjectTile(row: r)),
        ],
      ),
    );
  }
}

class _OverallCard extends StatelessWidget {
  final double overall;
  final String markBand;
  final int attendanceMark;
  final int lowCount;
  final int safeCount;
  final int strongCount;
  final int subjectCount;
  const _OverallCard({
    required this.overall,
    required this.markBand,
    required this.attendanceMark,
    required this.lowCount,
    required this.safeCount,
    required this.strongCount,
    required this.subjectCount,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: scheme.primary.withAlpha(20),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.primary.withAlpha(60)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.insights_rounded, color: scheme.primary, size: 20),
                  const SizedBox(width: 8),
                  Text('Attendance Snapshot', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: scheme.primary)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.military_tech_rounded, size: 14),
                    const SizedBox(width: 4),
                    Text(markBand, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: scheme.onPrimaryContainer)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 168,
            child: Row(
              children: [
                Expanded(
                  child: Center(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 132,
                          height: 132,
                          child: CircularProgressIndicator(
                            value: (overall / 100).clamp(0, 1),
                            strokeWidth: 12,
                            backgroundColor: scheme.primary.withAlpha(40),
                            color: scheme.primary,
                          ),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.fact_check_rounded, color: scheme.primary, size: 24),
                            const SizedBox(height: 4),
                            Text('${overall.toStringAsFixed(1)}%', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: scheme.primary)),
                            Text('Total', style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _BadgeLine(icon: Icons.workspace_premium_rounded, label: 'Attendance Marks', value: '$attendanceMark / 5'),
                      const SizedBox(height: 8),
                      _BadgeLine(icon: Icons.auto_graph_rounded, label: 'Grade Band', value: markBand),
                      const SizedBox(height: 8),
                      _BadgeLine(icon: Icons.menu_book_rounded, label: 'Subjects', value: '$subjectCount'),
                      const SizedBox(height: 8),
                      _BadgeLine(icon: Icons.warning_amber_rounded, label: 'Risk Subjects', value: '$lowCount'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(value: overall / 100, minHeight: 8, color: scheme.primary, backgroundColor: scheme.primary.withAlpha(40)),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _MetricPill(label: 'Strong', value: strongCount, color: Colors.green.shade700)),
              const SizedBox(width: 8),
              Expanded(child: _MetricPill(label: 'Safe', value: safeCount, color: Colors.amber.shade700)),
              const SizedBox(width: 8),
              Expanded(child: _MetricPill(label: 'Risk', value: lowCount, color: scheme.error)),
            ],
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: Text('$subjectCount subjects tracked', style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
          ),
          if (lowCount > 0) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.warning_amber_rounded, size: 16, color: scheme.error),
                const SizedBox(width: 6),
                Text('$lowCount subject${lowCount > 1 ? 's' : ''} below 75%',
                    style: TextStyle(fontSize: 13, color: scheme.error, fontWeight: FontWeight.w500)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _BadgeLine extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _BadgeLine({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: scheme.primaryContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Icon(icon, size: 16, color: scheme.onPrimaryContainer),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
              Text(value, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ],
    );
  }
}

class _MetricPill extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  const _MetricPill({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withAlpha(24),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withAlpha(65)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 11.5, color: color, fontWeight: FontWeight.w600)),
          Text('$value', style: TextStyle(fontSize: 12.5, color: color, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _RiskAlertCard extends StatelessWidget {
  final int lowCount;
  final List<dynamic> lowestRows;
  const _RiskAlertCard({required this.lowCount, required this.lowestRows});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.errorContainer.withAlpha(180),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.error.withAlpha(90)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_rounded, color: scheme.error, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '$lowCount subject${lowCount == 1 ? '' : 's'} below 75%',
                  style: TextStyle(fontWeight: FontWeight.w700, color: scheme.error),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Focus on: ${lowestRows.map((r) => (r['subject_code'] ?? r['raw_subject_name'] ?? 'Unknown').toString()).join(', ')}',
            style: TextStyle(fontSize: 12.5, color: scheme.onErrorContainer),
          ),
        ],
      ),
    );
  }
}

class _SubjectTile extends StatelessWidget {
  final dynamic row;
  const _SubjectTile({required this.row});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final pct = (row['percentage'] as num).toDouble();
    final isLow = pct < 75;
    final color = isLow
        ? scheme.error
      : pct >= 90
            ? Colors.green.shade700
            : scheme.primary;
    final stdData = context.read<StudentData>();
    String? lookupName;
    for (final m in stdData.marks) {
      if (m['subject_code'] == row['subject_code']) {
        lookupName = m['raw_subject_name'];
        break;
      }
    }
    final name = row['raw_subject_name'] ?? lookupName ?? row['subject_code'] ?? '—';
    final attended = (row['classes_attended'] as num?)?.toInt();
    final total = (row['classes_total'] as num?)?.toInt();
    final requiredToRecover = _classesNeededToReach75(attended, total);
    final status = pct >= 90
        ? 'Strong'
        : pct >= 75
            ? 'Safe'
            : 'Risk';
    final attMark = calculateAttendanceMarks(pct) ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withAlpha(80)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(name, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis)),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withAlpha(24),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(status, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: scheme.primaryContainer.withAlpha(180),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.stars_rounded, size: 12, color: scheme.onPrimaryContainer),
                    const SizedBox(width: 4),
                    Text('$attMark/5', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: scheme.onPrimaryContainer)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text('${pct.toStringAsFixed(1)}%', style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 15)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${attended ?? 0} / ${total ?? 0} classes attended'
            '${requiredToRecover > 0 ? ' • Need $requiredToRecover consecutive classes to reach 75%' : ''}',
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(value: pct / 100, minHeight: 5, color: color, backgroundColor: color.withAlpha(30)),
          ),
        ],
      ),
    );
  }

  int _classesNeededToReach75(int? attended, int? total) {
    if (attended == null || total == null || total <= 0) return 0;
    final current = (attended / total) * 100;
    if (current >= 75) return 0;
    final required = ((0.75 * total) - attended) / 0.25;
    return required.ceil().clamp(0, 10000);
  }
}

// ── Analysis Tab ──────────────────────────────────────────────────────

class _AnalysisTab extends StatelessWidget {
  final StudentData data;
  final DateTime targetDate;
  final AttendanceAnalysis? analysis;
  final VoidCallback onPickDate;
  final VoidCallback onAnalyze;

  const _AnalysisTab({
    required this.data,
    required this.targetDate,
    required this.analysis,
    required this.onPickDate,
    required this.onAnalyze,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        // Date picker card
        Container(
          decoration: BoxDecoration(color: scheme.surfaceContainerLow, borderRadius: BorderRadius.circular(16), border: Border.all(color: scheme.primary.withAlpha(30))),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                decoration: BoxDecoration(
                  color: scheme.primary,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.analytics_rounded, size: 18, color: scheme.onPrimary),
                    const SizedBox(width: 8),
                    Text('Attendance Projections', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: scheme.onPrimary)),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Target Date:', style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant)),
                    const SizedBox(height: 6),
                    InkWell(
                      onTap: onPickDate,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: scheme.outlineVariant),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.calendar_today, size: 18, color: scheme.primary),
                            const SizedBox(width: 10),
                            Text(DateFormat('dd/MM/yyyy').format(targetDate), style: const TextStyle(fontSize: 15)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(onPressed: onAnalyze, child: const Text('Analyze')),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        if (analysis != null) ...[
          const SizedBox(height: 16),
          _ProjectionTable(analysis: analysis!),
        ],
      ],
    );
  }
}

class _ProjectionTable extends StatelessWidget {
  final AttendanceAnalysis analysis;
  const _ProjectionTable({required this.analysis});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: scheme.surfaceContainerLow, borderRadius: BorderRadius.circular(16), border: Border.all(color: scheme.primary.withAlpha(30))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            decoration: BoxDecoration(
              color: scheme.primary,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Text('Analysis for: ${DateFormat('dd/MM/yyyy').format(analysis.targetDate)}',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: scheme.onPrimary)),
          ),
          const SizedBox(height: 12),
          // Header
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
            decoration: BoxDecoration(color: scheme.primaryContainer.withAlpha(80), borderRadius: BorderRadius.circular(8)),
            child: Row(
              children: [
                Expanded(flex: 3, child: Text('Subject', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: scheme.primary))),
                Expanded(flex: 2, child: Text('Perfect', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: scheme.primary), textAlign: TextAlign.center)),
                Expanded(flex: 2, child: Text('75%', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: scheme.primary), textAlign: TextAlign.center)),
                Expanded(flex: 2, child: Text('85%', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: scheme.primary), textAlign: TextAlign.center)),
              ],
            ),
          ),
          // Rows
          for (int i = 0; i < analysis.perfectAttendance.length; i++) ...[
            _buildRow(i, scheme),
          ],
        ],
      ),
    );
  }

  Widget _buildRow(int i, ColorScheme scheme) {
    final p = analysis.perfectAttendance[i];
    final s75 = analysis.skip75[i];
    final s85 = analysis.skip85[i];

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      decoration: BoxDecoration(color: i.isEven ? scheme.surfaceContainerHighest.withAlpha(40) : Colors.transparent),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${p.name} (${p.code})', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis),
                Text('${p.currentPresent}/${p.currentTotal} (${p.currentPercentage.toStringAsFixed(0)}%)',
                    style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant)),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Column(
              children: [
                Text('${p.projectedPercentage.toStringAsFixed(1)}%',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                        color: p.projectedPercentage >= 75 ? Colors.green.shade600 : Colors.red.shade600)),
                Text('+${p.additionalClasses}', style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant)),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Column(
              children: [
                Text(
                  s75.canMaintainTarget ? 'Miss ${s75.canSkip}' : 'N/A',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500,
                      color: s75.canMaintainTarget ? Colors.orange.shade700 : Colors.red.shade600),
                  textAlign: TextAlign.center,
                ),
                Text('${s75.optimalPercentage.toStringAsFixed(1)}%',
                    style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant), textAlign: TextAlign.center),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Column(
              children: [
                Text(
                  s85.canMaintainTarget ? 'Miss ${s85.canSkip}' : 'N/A',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500,
                      color: s85.canMaintainTarget ? Colors.orange.shade700 : Colors.red.shade600),
                  textAlign: TextAlign.center,
                ),
                Text('${s85.optimalPercentage.toStringAsFixed(1)}%',
                    style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant), textAlign: TextAlign.center),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Duty Leave Tab ────────────────────────────────────────────────────

class _DutyLeaveTab extends StatelessWidget {
  final StudentData data;
  final ColorScheme scheme;
  final bool isLoading;
  final Future<void> Function() onRefresh;
  const _DutyLeaveTab({
    required this.data,
    required this.scheme,
    required this.isLoading,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final rows = data.dutyLeaveAttendance;

    if (rows.isEmpty && !isLoading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.info_outline, size: 56, color: scheme.onSurfaceVariant.withAlpha(100)),
            const SizedBox(height: 12),
            Text('No duty leave data available', style: TextStyle(color: scheme.onSurfaceVariant)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('Fetch Duty Leave'),
              onPressed: onRefresh,
            ),
          ],
        ),
      );
    }

    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final subjectRows = rows.where((row) {
      final code = row['subject_code']?.toString().toLowerCase();
      return code != null && code != 'total';
    }).toList();

    final totalRow = rows.cast<Map<String, dynamic>?>().firstWhere(
      (row) => row != null && row['subject_code']?.toString().toLowerCase() == 'total',
      orElse: () => null,
    );

    final average = subjectRows.isNotEmpty
        ? subjectRows
                .map((row) => (row['percentage'] as num?)?.toDouble() ?? 0)
                .fold<double>(0, (sum, value) => sum + value) /
            subjectRows.length
        : 0.0;
    final overall = (totalRow?['percentage'] as num?)?.toDouble() ?? average;

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.orange.withAlpha(20),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.orange.withAlpha(60)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.assignment_outlined, color: Colors.orange, size: 20),
                    const SizedBox(width: 8),
                    Text('Duty Leave Attendance',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.orange)),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _DutyLeaveMetric(
                        label: 'Subjects',
                        value: subjectRows.length.toString(),
                        color: Colors.orange,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _DutyLeaveMetric(
                        label: 'Overall %',
                        value: '${overall.toStringAsFixed(1)}%',
                        color: Colors.orange,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (subjectRows.isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('By Subject', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: scheme.onSurfaceVariant)),
                Text('Fetched from duty-leave page', style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
              ],
            ),
            const SizedBox(height: 8),
            ...subjectRows.map((row) {
              final pct = (row['percentage'] as num?)?.toDouble() ?? 0;
              final attended = (row['classes_attended'] as num?)?.toInt() ?? 0;
              final total = (row['classes_total'] as num?)?.toInt() ?? 0;
              final subject = row['subject_code']?.toString() ?? 'Unknown';
              final dutyLeave = row['duty_leave'];

              return Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.orange.withAlpha(30),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.orange.withAlpha(60)),
                        ),
                        child: Center(
                          child: Text(
                            '${pct.toStringAsFixed(0)}%',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              subject,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              '$attended / $total classes attended',
                              style: TextStyle(
                                fontSize: 11,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                            if (dutyLeave != null)
                              Text(
                                'Duty leave: $dutyLeave',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.orange.withAlpha(30),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'DL',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ] else
            Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'No duty-leave subject data returned',
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DutyLeaveMetric extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _DutyLeaveMetric({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withAlpha(24),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Column(
        children: [
          Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}
