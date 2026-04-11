import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../services/student_data.dart';
import '../../../utils/attendance_analysis.dart';

class AttendanceAnalysisTab extends StatelessWidget {
  final StudentData data;
  final DateTime targetDate;
  final AttendanceAnalysis? analysis;
  final VoidCallback onPickDate;
  final VoidCallback onAnalyze;

  const AttendanceAnalysisTab({
    super.key,
    required this.data,
    required this.targetDate,
    required this.analysis,
    required this.onPickDate,
    required this.onAnalyze,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final headerBg = isDark ? scheme.primary.withAlpha(38) : scheme.primary.withAlpha(14);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        Container(
          decoration: BoxDecoration(color: scheme.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: scheme.outline)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                decoration: BoxDecoration(
                  color: headerBg,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.analytics_rounded, size: 18, color: scheme.primary),
                    const SizedBox(width: 8),
                    Text('Attendance Projections', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: isDark ? scheme.outline : scheme.primary)),
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
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: headerBg,
                          foregroundColor: isDark ? scheme.outline : scheme.primary,
                          side: BorderSide(color: scheme.outline),
                        ),
                        onPressed: onAnalyze,
                        child: const Text('Analyze'),
                      ),
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
      decoration: BoxDecoration(color: scheme.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: scheme.outline)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            decoration: BoxDecoration(color: (Theme.of(context).brightness == Brightness.dark) ? scheme.primary.withAlpha(38) : scheme.primary.withAlpha(14), borderRadius: const BorderRadius.vertical(top: Radius.circular(14))),
            child: Text('Analysis for: ${DateFormat('dd/MM/yyyy').format(analysis.targetDate)}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Theme.of(context).brightness == Brightness.dark ? scheme.outline : scheme.primary)),
          ),
          const SizedBox(height: 12),
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
          for (int i = 0; i < analysis.perfectAttendance.length; i++) _buildRow(i, scheme),
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
                Text('${p.currentPresent}/${p.currentTotal} (${p.currentPercentage.toStringAsFixed(0)}%)', style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant)),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Column(
              children: [
                Text('${p.projectedPercentage.toStringAsFixed(1)}%', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: p.projectedPercentage >= 75 ? Colors.green.shade600 : Colors.red.shade600)),
                Text('+${p.additionalClasses}', style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant)),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Column(
              children: [
                Text(s75.canMaintainTarget ? 'Miss ${s75.canSkip}' : 'N/A', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: s75.canMaintainTarget ? Colors.orange.shade700 : Colors.red.shade600), textAlign: TextAlign.center),
                Text('${s75.optimalPercentage.toStringAsFixed(1)}%', style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant), textAlign: TextAlign.center),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Column(
              children: [
                Text(s85.canMaintainTarget ? 'Miss ${s85.canSkip}' : 'N/A', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: s85.canMaintainTarget ? Colors.orange.shade700 : Colors.red.shade600), textAlign: TextAlign.center),
                Text('${s85.optimalPercentage.toStringAsFixed(1)}%', style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant), textAlign: TextAlign.center),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
