import 'package:flutter/material.dart';

class MarksResultsTab extends StatelessWidget {
  final List<MapEntry<String, List>> sortedEntries;
  final Future<void> Function() onRefresh;
  final ColorScheme scheme;

  const MarksResultsTab({super.key, required this.sortedEntries, required this.onRefresh, required this.scheme});

  @override
  Widget build(BuildContext context) {
    if (sortedEntries.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.assignment_outlined, size: 56, color: scheme.onSurfaceVariant.withAlpha(100)),
            const SizedBox(height: 12),
            Text('No marks data', style: TextStyle(color: scheme.onSurfaceVariant)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: sortedEntries.map((e) => ExamGroupCard(examLabel: e.key, rows: e.value)).toList(),
      ),
    );
  }
}

class ExamGroupCard extends StatelessWidget {
  final String examLabel;
  final List rows;

  const ExamGroupCard({super.key, required this.examLabel, required this.rows});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final leadingIcon = _examIcon(examLabel);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final headerBg = isDark ? scheme.primary.withAlpha(38) : scheme.primary.withAlpha(14);
    return Container(
      margin: const EdgeInsets.only(top: 12),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outline),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            decoration: BoxDecoration(
              color: headerBg,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Icon(leadingIcon, size: 16, color: isDark ? const Color(0xFFD8C9FF) : scheme.primary),
                const SizedBox(width: 8),
                Text(examLabel, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: isDark ? const Color(0xFFD8C9FF) : scheme.primary, letterSpacing: 0.5)),
              ],
            ),
          ),
          Divider(height: 1, thickness: 1.2, color: scheme.outline),
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
                  title: Text(r['raw_subject_name'] ?? r['subject_code'] ?? '—', style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(r['subject_code'] ?? '', style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(obtained != null ? '$obtained / $max' : '—', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: isLow ? scheme.error : scheme.onSurface)),
                      if (pct != null) Text('${pct.toStringAsFixed(0)}%', style: TextStyle(fontSize: 12, color: isLow ? scheme.error : scheme.onSurface)),
                    ],
                  ),
                ),
                if (entry.key < rows.length - 1) Divider(height: 1, thickness: 1.1, indent: 16, endIndent: 16, color: scheme.outline),
              ],
            );
          }),
        ],
      ),
    );
  }

  IconData _examIcon(String label) {
    final k = label.toLowerCase();
    if (k.contains('cat')) return Icons.fact_check_outlined;
    if (k.contains('assignment')) return Icons.assignment_turned_in_outlined;
    return Icons.description_outlined;
  }
}
