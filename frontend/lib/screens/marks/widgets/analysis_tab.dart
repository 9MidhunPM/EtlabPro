import 'package:flutter/material.dart';
import '../../../utils/results_analysis.dart';

class MarksAnalysisTab extends StatelessWidget {
  final List<SubjectAnalysis> analysisData;
  final VoidCallback onRefresh;
  final void Function(int index, double value) onUpdateAssignment;

  const MarksAnalysisTab({super.key, required this.analysisData, required this.onRefresh, required this.onUpdateAssignment});

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
                padding: const EdgeInsets.fromLTRB(16, 0, 4, 0),
                decoration: BoxDecoration(color: headerBg, borderRadius: const BorderRadius.vertical(top: Radius.circular(16))),
                child: Row(
                  children: [
                    Icon(Icons.analytics_rounded, size: 18, color: scheme.primary),
                    const SizedBox(width: 8),
                    Expanded(child: Text('Grade Analysis', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: isDark ? scheme.outline : scheme.primary))),
                    IconButton(icon: Icon(Icons.refresh, size: 20, color: isDark ? scheme.outline : scheme.primary), onPressed: onRefresh),
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
                      '• CAT-1 and Min CAT-2 are shown in scaled format',
                      '• Assignment input is included in total projection',
                      '• Min CAT-2 shows marks needed for 26+ total (red = impossible)',
                      '• Attendance: 90%+=5, 85-89%=4, 80-84%=3, 75-79%=2, 70-74%=1, <70%=0',
                    ].map((t) => Padding(padding: const EdgeInsets.only(bottom: 2), child: Text(t, style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)))),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (analysisData.isEmpty)
          Center(child: Text('No analysis data. Ensure results and attendance are loaded.', style: TextStyle(color: scheme.onSurfaceVariant)))
        else
          _AnalysisTable(analysisData: analysisData, onUpdateAssignment: onUpdateAssignment),
      ],
    );
  }
}

class _AnalysisTable extends StatelessWidget {
  final List<SubjectAnalysis> analysisData;
  final void Function(int index, double value) onUpdateAssignment;

  const _AnalysisTable({required this.analysisData, required this.onUpdateAssignment});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: scheme.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: scheme.outline)),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            decoration: BoxDecoration(color: (Theme.of(context).brightness == Brightness.dark) ? scheme.primary.withAlpha(38) : scheme.primary.withAlpha(14), borderRadius: BorderRadius.circular(8), border: Border.all(color: scheme.outline)),
            child: Row(
              children: [
                Expanded(flex: 3, child: Text('Subject', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: scheme.primary))),
                Expanded(flex: 2, child: Text('CAT-1', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: scheme.primary), textAlign: TextAlign.center)),
                Expanded(flex: 2, child: Text('Min CAT-2', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: scheme.primary), textAlign: TextAlign.center)),
                Expanded(flex: 2, child: Text('Assign', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: scheme.primary), textAlign: TextAlign.center)),
                Expanded(flex: 2, child: Text('Attend', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: scheme.primary), textAlign: TextAlign.center)),
                Expanded(flex: 2, child: Text('Total', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: scheme.primary), textAlign: TextAlign.center)),
              ],
            ),
          ),
          for (int i = 0; i < analysisData.length; i++) _buildAnalysisRow(context, i, scheme),
          ..._buildWarnings(scheme),
        ],
      ),
    );
  }

  Widget _buildAnalysisRow(BuildContext context, int i, ColorScheme scheme) {
    final item = analysisData[i];
    final cat2Needed = item.cat2NeededFor26;
    final cat2OutOf30 = roundToHalf((cat2Needed.clamp(0, item.cat2Scale) / item.cat2Scale) * 30);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      decoration: BoxDecoration(color: i.isEven ? scheme.surfaceContainerHighest.withAlpha(40) : Colors.transparent),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(item.subjectCode, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis),
              Text(item.subjectName, style: TextStyle(fontSize: 9, color: scheme.onSurfaceVariant), maxLines: 1, overflow: TextOverflow.ellipsis),
            ]),
          ),
          Expanded(
            flex: 2,
            child: Column(children: [
              Text('${item.cat1.toStringAsFixed(1)}/${item.cat1Scale}', style: const TextStyle(fontSize: 11)),
              Text('${roundToHalf((item.cat1 / item.cat1Scale) * 30).toStringAsFixed(1)}/30', style: TextStyle(fontSize: 9, color: scheme.onSurfaceVariant)),
            ]),
          ),
          Expanded(
            flex: 2,
            child: Column(children: [
              Text(item.isImpossible ? '${item.cat2Scale}+' : '${cat2Needed.toStringAsFixed(1)}/${item.cat2Scale}', style: TextStyle(fontSize: 11, color: item.isImpossible ? Colors.red.shade600 : null)),
              Text('${cat2OutOf30.toStringAsFixed(1)}/30', style: TextStyle(fontSize: 9, color: item.isImpossible ? Colors.red.shade600 : scheme.onSurfaceVariant)),
            ]),
          ),
          Expanded(
            flex: 2,
            child: Column(children: [
              SizedBox(
                width: 44,
                height: 32,
                child: TextField(
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  textAlignVertical: TextAlignVertical.center,
                  style: const TextStyle(fontSize: 12),
                  decoration: InputDecoration(
                    hintText: '0',
                    hintStyle: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: scheme.outlineVariant)),
                    isDense: true,
                  ),
                  onChanged: (v) => onUpdateAssignment(i, double.tryParse(v) ?? 0),
                ),
              ),
              Text('/${item.assignmentScale.toInt()}', style: TextStyle(fontSize: 9, color: scheme.onSurfaceVariant)),
            ]),
          ),
          Expanded(
            flex: 2,
            child: Column(children: [
              Text(item.attendanceMarks != null ? '${item.attendanceMarks}/5' : 'N/A', style: TextStyle(fontSize: 11, color: item.attendanceMarks != null ? Colors.green.shade600 : Colors.red.shade600)),
              if (item.attendancePercentage != null) Text('${item.attendancePercentage!.toStringAsFixed(1)}%', style: TextStyle(fontSize: 9, color: scheme.onSurfaceVariant)),
            ]),
          ),
          Expanded(
            flex: 2,
            child: Text('${item.total.toStringAsFixed(1)}/${item.totalScale.toInt()}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600), textAlign: TextAlign.center),
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
        decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.red.shade200)),
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
                  child: Text('${s.subjectCode} cannot obtain 26 marks with current assignment.', style: TextStyle(fontSize: 12, color: Colors.red.shade700)),
                )),
          ],
        ),
      ),
    ];
  }
}
