import 'package:flutter/material.dart';
import '../../../widgets/screen_parts.dart';

class UpdatesSections extends StatelessWidget {
  final Map<String, dynamic> updates;

  const UpdatesSections({super.key, required this.updates});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _summaryCard(context, updates, scheme),
        const SizedBox(height: 16),
        _categoryCard('attendance_changes', Icons.calendar_month, 'Attendance Updates', Colors.blue, updates, scheme),
        const SizedBox(height: 16),
        _categoryCard('marks_changes', Icons.assessment, 'Marks Updates', Colors.green, updates, scheme),
        const SizedBox(height: 16),
        _categoryCard('university_result_changes', Icons.school, 'University Results Updates', Colors.orange, updates, scheme),
      ],
    );
  }

  Widget _summaryCard(BuildContext context, Map<String, dynamic> updates, ColorScheme scheme) {
    final totalChanges = updates['total_changes'] as int? ?? 0;
    final attendanceChanges = (updates['attendance_changes'] as List? ?? []).length;
    final marksChanges = (updates['marks_changes'] as List? ?? []).length;
    final universityChanges = (updates['university_result_changes'] as List? ?? []).length;

    return ScreenSectionCard(
      icon: Icons.new_releases,
      title: 'Recent Changes',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1.5,
            children: [
              _changeCard('Total\nChanges', totalChanges.toString(), Colors.purple, scheme),
              _changeCard('Attendance\nChanges', attendanceChanges.toString(), Colors.blue, scheme),
              _changeCard('Marks\nChanges', marksChanges.toString(), Colors.green, scheme),
              _changeCard('Results\nChanges', universityChanges.toString(), Colors.orange, scheme),
            ],
          ),
          if (updates['baseline_refreshed'] == true) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.green.withAlpha(20),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.withAlpha(60)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Baseline refreshed',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.green),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _categoryCard(String key, IconData icon, String title, Color color, Map<String, dynamic> updates, ColorScheme scheme) {
    final changes = (updates[key] as List? ?? []);
    if (changes.isEmpty) return const SizedBox.shrink();

    return ScreenSectionCard(
      icon: icon,
      title: title,
      trailing: _countPill(changes.length.toString(), color.withAlpha(60), color),
      child: ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: changes.length,
        itemBuilder: (context, index) {
          final change = changes[index] as Map<String, dynamic>;
          return _updateTile(change, color, scheme);
        },
      ),
    );
  }

  Widget _changeCard(String label, String count, Color color, ColorScheme scheme) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(count, style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 4),
          Text(label, textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: scheme.onSurfaceVariant)),
        ],
      ),
    );
  }

  Widget _countPill(String text, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: fg)),
    );
  }

  Widget _updateTile(Map<String, dynamic> change, Color color, ColorScheme scheme) {
    String title = change['field']?.toString() ?? 'Unknown';
    String? oldValue = change['old_value']?.toString();
    String? newValue = change['new_value']?.toString();
    String? context = change['context']?.toString();

    String subtitle = context ?? 'Value Changed';
    if (oldValue != null && newValue != null) {
      subtitle = '$oldValue → $newValue';
    } else if (newValue != null) {
      subtitle = 'Now: $newValue';
    }

    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color.withAlpha(30),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withAlpha(60)),
        ),
        child: Center(child: Icon(Icons.update, color: color, size: 20)),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: color.withAlpha(30), borderRadius: BorderRadius.circular(6)),
        child: Text('New', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color)),
      ),
    );
  }
}
