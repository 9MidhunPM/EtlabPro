import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../services/student_data.dart';
import '../../../utils/results_analysis.dart';

class AttendanceTab extends StatelessWidget {
  final StudentData data;
  final ColorScheme scheme;
  final Future<void> Function() onRefresh;
  final bool includeDutyLeave;
  final ValueChanged<bool> onIncludeDutyLeaveChanged;

  const AttendanceTab({
    super.key,
    required this.data,
    required this.scheme,
    required this.onRefresh,
    required this.includeDutyLeave,
    required this.onIncludeDutyLeaveChanged,
  });

  @override
  Widget build(BuildContext context) {
    final rows = data.attendance;
    final dutyRows = data.dutyLeaveAttendance;
    final subjectRows = rows.where((r) {
      final code = r['subject_code']?.toString().toLowerCase();
      return code != 'total';
    }).toList();

    final dutySubjectRows = dutyRows.where((r) {
      final code = r['subject_code']?.toString().toLowerCase();
      return code != null && code != 'total';
    }).toList();

    final dutyByCode = <String, dynamic>{
      for (final row in dutySubjectRows)
        (row['subject_code']?.toString().toLowerCase() ?? ''): row,
    };

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

    final dutyTotalRow = dutyRows.cast<Map<String, dynamic>?>().firstWhere(
      (r) => r != null && r['subject_code']?.toString().toLowerCase() == 'total',
      orElse: () => null,
    );

    final hasDutyData = dutySubjectRows.isNotEmpty;
    final useDuty = includeDutyLeave && hasDutyData;

    double pctFor(dynamic row) {
      final code = row['subject_code']?.toString().toLowerCase() ?? '';
      if (useDuty && code.isNotEmpty) {
        final duty = dutyByCode[code];
        final dutyPct = (duty?['percentage'] as num?)?.toDouble();
        if (dutyPct != null) return dutyPct;
      }
      return (row['percentage'] as num?)?.toDouble() ?? 0;
    }

    final avg = subjectRows.map((r) => pctFor(r)).reduce((a, b) => a + b) / subjectRows.length;
    final overall = useDuty
        ? ((dutyTotalRow?['percentage'] as num?)?.toDouble() ?? avg)
        : (((totalRow?['percentage'] as num?)?.toDouble()) ?? avg);

    final lowCount = subjectRows.where((r) => pctFor(r) < 75).length;
    final safeCount = subjectRows.where((r) {
      final pct = pctFor(r);
      return pct >= 75 && pct < 90;
    }).length;
    final strongCount = subjectRows.length - lowCount - safeCount;

    final attendanceMark = calculateAttendanceMarks(overall) ?? 0;
    final markBand = attendanceMarkBand(overall);

    final sortedRows = List<dynamic>.from(subjectRows)..sort((a, b) => pctFor(a).compareTo(pctFor(b)));

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
            includeDutyLeave: includeDutyLeave,
            hasDutyData: hasDutyData,
            onIncludeDutyLeaveChanged: onIncludeDutyLeaveChanged,
          ),
          const SizedBox(height: 16),
          if (includeDutyLeave && !hasDutyData) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withAlpha(14),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.withAlpha(60)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue),
                  SizedBox(width: 8),
                  Expanded(child: Text('Duty leave data not loaded yet. Using regular attendance values.')),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],
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
          ...sortedRows.map((r) {
            final code = r['subject_code']?.toString().toLowerCase() ?? '';
            final duty = dutyByCode[code];
            final basePct = (r['percentage'] as num?)?.toDouble() ?? 0;
            final dutyPct = (duty?['percentage'] as num?)?.toDouble();
            final activePct = useDuty && dutyPct != null ? dutyPct : basePct;
            final delta = (dutyPct ?? basePct) - basePct;
            final baseAttended = (r['classes_attended'] as num?)?.toInt() ?? 0;
            final activeAttended = useDuty
              ? ((duty?['classes_attended'] as num?)?.toInt() ?? baseAttended)
              : baseAttended;
            final activeTotal = useDuty
                ? ((duty?['classes_total'] as num?)?.toInt() ?? (r['classes_total'] as num?)?.toInt() ?? 0)
                : ((r['classes_total'] as num?)?.toInt() ?? 0);

            return _SubjectTile(
              row: r,
              activePct: activePct,
              activeAttended: activeAttended,
              activeTotal: activeTotal,
              includeDutyLeave: useDuty,
              dutyDeltaPct: delta,
              dutyLeaveCount: (activeAttended - baseAttended).clamp(0, 9999),
            );
          }),
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
  final bool includeDutyLeave;
  final bool hasDutyData;
  final ValueChanged<bool> onIncludeDutyLeaveChanged;

  const _OverallCard({
    required this.overall,
    required this.markBand,
    required this.attendanceMark,
    required this.lowCount,
    required this.safeCount,
    required this.strongCount,
    required this.subjectCount,
    required this.includeDutyLeave,
    required this.hasDutyData,
    required this.onIncludeDutyLeaveChanged,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final headerBg = isDark ? scheme.primary.withAlpha(38) : scheme.primary.withAlpha(20);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outline),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.insights_rounded, color: isDark ? const Color(0xFFD8C9FF) : scheme.primary, size: 20),
                  const SizedBox(width: 8),
                  Text('Attendance Snapshot', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: isDark ? const Color(0xFFD8C9FF) : scheme.primary)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(color: headerBg, borderRadius: BorderRadius.circular(10), border: Border.all(color: scheme.outline)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.military_tech_rounded, size: 14, color: isDark ? const Color(0xFFD8C9FF) : scheme.primary),
                    const SizedBox(width: 4),
                    Text(markBand, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: isDark ? const Color(0xFFD8C9FF) : scheme.primary)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text('Include Duty Leave?', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: scheme.onSurfaceVariant)),
              const Spacer(),
              if (!hasDutyData)
                Text('No data yet', style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
              const SizedBox(width: 6),
              Switch.adaptive(
                value: includeDutyLeave,
                onChanged: onIncludeDutyLeaveChanged,
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
                            Text('Total', style: TextStyle(fontSize: 11, color: scheme.onSurface)),
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
          decoration: BoxDecoration(color: scheme.primaryContainer, borderRadius: BorderRadius.circular(8)),
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
  final double activePct;
  final int activeAttended;
  final int activeTotal;
  final bool includeDutyLeave;
  final double dutyDeltaPct;
  final int? dutyLeaveCount;

  const _SubjectTile({
    required this.row,
    required this.activePct,
    required this.activeAttended,
    required this.activeTotal,
    required this.includeDutyLeave,
    required this.dutyDeltaPct,
    required this.dutyLeaveCount,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final pct = activePct;
    final isLow = pct < 75;
    final color = isLow ? scheme.error : pct >= 90 ? Colors.green.shade700 : scheme.primary;
    final stdData = context.read<StudentData>();
    String? lookupName;
    for (final m in stdData.marks) {
      if (m['subject_code'] == row['subject_code']) {
        lookupName = m['raw_subject_name'];
        break;
      }
    }
    final name = row['raw_subject_name'] ?? lookupName ?? row['subject_code'] ?? '—';
    final requiredToRecover = _classesNeededToReach75(activeAttended, activeTotal);
    final status = pct >= 90 ? 'Strong' : pct >= 75 ? 'Safe' : 'Risk';
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
                decoration: BoxDecoration(color: color.withAlpha(24), borderRadius: BorderRadius.circular(8)),
                child: Text(status, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: scheme.primaryContainer.withAlpha(180), borderRadius: BorderRadius.circular(8)),
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
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  '$activeAttended / $activeTotal classes attended',
                  style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                ),
              ),
              if (includeDutyLeave && dutyDeltaPct.abs() > 0.05)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.blue.withAlpha(18),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.withAlpha(65)),
                  ),
                  child: Text(
                    '${_pctDeltaLabel(dutyDeltaPct)}/+${dutyLeaveCount ?? 0} from duty leave',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.blue),
                  ),
                ),
            ],
          ),
          if (requiredToRecover > 0) ...[
            const SizedBox(height: 4),
            Text(
              'Need $requiredToRecover consecutive classes to reach 75%',
              style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant),
            ),
          ],
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

  String _pctDeltaLabel(double delta) {
    final abs = delta.abs();
    final nearInt = (abs - abs.roundToDouble()).abs() < 0.06;
    final v = nearInt ? abs.round().toString() : abs.toStringAsFixed(1);
    return '${delta >= 0 ? '+' : '-'}$v%';
  }
}
