import 'package:flutter/material.dart';
import 'purple_card.dart';
import 'sync_time.dart';

class AttendanceSummaryCard extends StatelessWidget {
  final List<dynamic> attendance;
  final DateTime? syncedAt;

  const AttendanceSummaryCard({super.key, required this.attendance, this.syncedAt});

  @override
  Widget build(BuildContext context) {
    if (attendance.isEmpty) return const SizedBox();
    final scheme = Theme.of(context).colorScheme;

    final sorted = List<dynamic>.from(attendance)
      ..sort((a, b) => ((a['percentage'] as num?) ?? 0).compareTo((b['percentage'] as num?) ?? 0));
    final lowest = sorted.take(3).toList();
    final total = (attendance.firstWhere(
          (r) => r['subject_code'] == null || r['subject_code'] == 'total',
          orElse: () => null,
        )?['percentage'] as num?)?.toDouble();
    final avg = attendance.map((r) => (r['percentage'] as num).toDouble()).reduce((a, b) => a + b) / attendance.length;
    final overallPct = total ?? avg;

    Color attColor() {
      if (overallPct >= 85) return Colors.green.shade600;
      if (overallPct >= 75) return Colors.amber.shade700;
      return Colors.red.shade600;
    }

    String attMsg() {
      if (overallPct >= 85) return 'Great!';
      if (overallPct >= 75) return 'Safe Zone';
      return 'At Risk';
    }

    return PurpleCard(
      icon: Icons.fact_check_rounded,
      title: 'Attendance',
      subtitle: syncedAgo(syncedAt),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 6,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Lowest Attendance', style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                ...lowest.map((r) {
                  final pct = (r['percentage'] as num).toDouble();
                  final color = pct < 75 ? Colors.red.shade600 : Colors.amber.shade700;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 7),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            r['raw_subject_name'] ?? r['subject_code'] ?? '—',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text('${pct.toStringAsFixed(1)}%', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: color)),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
          Container(width: 1, height: 90, color: scheme.outlineVariant.withAlpha(80), margin: const EdgeInsets.symmetric(horizontal: 12)),
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text('Overall', style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(
                  '${overallPct.toStringAsFixed(1)}%',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: attColor(), height: 1),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(attMsg(), style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant), textAlign: TextAlign.center),
                const SizedBox(height: 2),
                Text('${attendance.length} subjects', style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant.withAlpha(160))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
