import 'package:flutter/material.dart';
import '../../../services/student_data.dart';

class DutyLeaveTab extends StatelessWidget {
  final StudentData data;
  final ColorScheme scheme;
  final bool isLoading;
  final Future<void> Function() onRefresh;

  const DutyLeaveTab({
    super.key,
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
            ElevatedButton(onPressed: onRefresh, child: const Text('Fetch Duty Leave')),
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
        ? subjectRows.map((row) => (row['percentage'] as num?)?.toDouble() ?? 0).fold<double>(0, (sum, value) => sum + value) / subjectRows.length
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
                    Text('Duty Leave Attendance', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.orange)),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: DutyLeaveMetric(label: 'Subjects', value: subjectRows.length.toString(), color: Colors.orange)),
                    const SizedBox(width: 12),
                    Expanded(child: DutyLeaveMetric(label: 'Overall %', value: '${overall.toStringAsFixed(1)}%', color: Colors.orange)),
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
                        child: Center(child: Text('${pct.toStringAsFixed(0)}%', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange))),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(subject, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                            Text('$attended / $total classes attended', style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
                            if (dutyLeave != null)
                              Text('Duty leave: $dutyLeave', style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: Colors.orange.withAlpha(30), borderRadius: BorderRadius.circular(6)),
                        child: const Text('DL', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.orange)),
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
                child: Text('No duty-leave subject data returned', style: TextStyle(color: scheme.onSurfaceVariant)),
              ),
            ),
        ],
      ),
    );
  }
}

class DutyLeaveMetric extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const DutyLeaveMetric({super.key, required this.label, required this.value, required this.color});

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
