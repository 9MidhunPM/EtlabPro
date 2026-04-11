import 'package:flutter/material.dart';
import 'purple_card.dart';
import 'sync_time.dart';

class ResultsOverviewCard extends StatelessWidget {
  final List<dynamic> marks;
  final DateTime? syncedAt;

  const ResultsOverviewCard({super.key, required this.marks, this.syncedAt});

  @override
  Widget build(BuildContext context) {
    if (marks.isEmpty) return const SizedBox();
    final scheme = Theme.of(context).colorScheme;

    bool isSeriesOneOrTwo(dynamic r) {
      final type = (r['exam_type'] ?? '').toString().toLowerCase();
      final num = int.tryParse((r['exam_number'] ?? '').toString());
      final hasSeriesType = type.contains('series') || type.contains('cat');
      return hasSeriesType && (num == 1 || num == 2);
    }

    final seriesMarks = marks.where(isSeriesOneOrTwo).toList();
    final sourceMarks = seriesMarks.isNotEmpty ? seriesMarks : marks;

    final withPct = sourceMarks
        .where((r) => r['marks_obtained'] != null && r['max_marks'] != null && (r['max_marks'] as num) > 0)
        .map((r) {
      final pct = (r['marks_obtained'] as num) / (r['max_marks'] as num) * 100;
      return {'pct': pct, 'mark': r};
    }).toList()
      ..sort((a, b) => (a['pct'] as double).compareTo(b['pct'] as double));

    final worst3 = withPct.take(3).toList();

    final totalObtained = sourceMarks.where((r) => r['marks_obtained'] != null).fold<double>(0, (s, r) => s + (r['marks_obtained'] as num).toDouble());
    final totalMax = sourceMarks.where((r) => r['max_marks'] != null).fold<double>(0, (s, r) => s + (r['max_marks'] as num).toDouble());
    final overallPct = totalMax > 0 ? (totalObtained / totalMax * 100) : 0.0;

    Color perfColor() {
      if (overallPct >= 80) return Colors.green.shade600;
      if (overallPct >= 70) return Colors.amber.shade700;
      if (overallPct >= 60) return Colors.orange.shade600;
      return Colors.red.shade600;
    }

    String perfMsg() {
      if (overallPct >= 85) return 'Excellent!';
      if (overallPct >= 75) return 'Good Job!';
      if (overallPct >= 65) return 'Average';
      return 'Needs Work';
    }

    return PurpleCard(
      icon: Icons.emoji_events_rounded,
      title: 'Results Overview',
      subtitle: syncedAgo(syncedAt),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text('Overall', style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text('${overallPct.toStringAsFixed(1)}%', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: perfColor(), height: 1), textAlign: TextAlign.center),
                const SizedBox(height: 4),
                Text(perfMsg(), style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant), textAlign: TextAlign.center),
                const SizedBox(height: 2),
                Text('${sourceMarks.length} exam${sourceMarks.length != 1 ? 's' : ''} (Series 1/2)', style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant.withAlpha(160))),
              ],
            ),
          ),
          Container(width: 1, height: 80, color: scheme.outlineVariant.withAlpha(80), margin: const EdgeInsets.symmetric(horizontal: 12)),
          Expanded(
            flex: 6,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Needs Attention', style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                ...worst3.map((item) {
                  final r = item['mark'] as Map;
                  final pct = item['pct'] as double;
                  final pctColor = pct >= 50 ? Colors.amber.shade700 : Colors.red.shade600;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            r['subject_code'] ?? r['raw_subject_name'] ?? '—',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text('${pct.toStringAsFixed(1)}%', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: pctColor)),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
