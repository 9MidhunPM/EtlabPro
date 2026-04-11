import 'package:flutter/material.dart';
import '../../../widgets/screen_parts.dart';

class UniSemesterPage extends StatelessWidget {
  final List rows;
  final Color Function(String?) gradeColor;
  final Color Function(String?) statusColor;
  final Future<void> Function()? onRefresh;

  const UniSemesterPage({super.key, required this.rows, required this.gradeColor, required this.statusColor, this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final sgpa = rows.isNotEmpty ? rows.last['sgpa'] : null;
    final cgpa = rows.isNotEmpty ? rows.last['cgpa'] : null;

    return RefreshIndicator(
      onRefresh: onRefresh ?? () async {},
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          if (sgpa != null || cgpa != null) ...[
            Row(
              children: [
                if (sgpa != null) _chip('SGPA ${(sgpa as num).toStringAsFixed(2)}', scheme.primaryContainer, scheme.onPrimaryContainer),
                if (sgpa != null && cgpa != null) const SizedBox(width: 8),
                if (cgpa != null) _chip('CGPA ${(cgpa as num).toStringAsFixed(2)}', scheme.secondaryContainer, scheme.onSecondaryContainer),
              ],
            ),
            const SizedBox(height: 12),
          ],
          ScreenSectionCard(
            icon: Icons.school,
            title: 'Semester Results',
            child: Column(
              children: rows.asMap().entries.map((entry) {
                final r = entry.value;
                final grade = r['grade'] ?? '—';
                final rawStatus = (r['result_status'] ?? '').toString();
                final status = rawStatus.toLowerCase() == 'pending' ? '' : rawStatus;
                final credit = r['credit'];
                final slot = r['slot'] ?? '';
                final gc = gradeColor(grade);
                final sc = statusColor(status);

                return Column(
                  children: [
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                      title: Text(r['raw_subject_name'] ?? r['subject_code'] ?? '—', style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text('${r['subject_code'] ?? ''}${slot.toString().isNotEmpty ? '  •  $slot' : ''}${credit != null ? '  •  $credit cr' : ''}', style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(grade, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: gc)),
                          Text(status, style: TextStyle(fontSize: 11, color: sc)),
                        ],
                      ),
                    ),
                    if (entry.key < rows.length - 1) Divider(height: 1, indent: 16, endIndent: 16, color: scheme.outline),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String text, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(text, style: TextStyle(fontSize: 11, color: fg, fontWeight: FontWeight.w500)),
    );
  }
}
