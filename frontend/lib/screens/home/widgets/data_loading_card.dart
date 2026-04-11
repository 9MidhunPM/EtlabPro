import 'package:flutter/material.dart';
import '../../../services/student_data.dart';
import 'purple_card.dart';

class DataLoadingCard extends StatelessWidget {
  final StudentData data;
  const DataLoadingCard({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    if (!data.isLoading && data.loadingSections.isEmpty) return const SizedBox();
    final scheme = Theme.of(context).colorScheme;
    const sections = <String>['Profile', 'Summary', 'Attendance', 'Marks', 'University Results', 'Timetable'];
    final loaded = <String>{
      if (data.profile != null) 'Profile',
      if (data.summary != null) 'Summary',
      if (data.attendance.isNotEmpty) 'Attendance',
      if (data.marks.isNotEmpty) 'Marks',
      if (data.universityResults.isNotEmpty) 'University Results',
      if (data.timetable.isNotEmpty) 'Timetable',
    };
    final active = data.loadingSections.toList()..sort();
    final current = active.isNotEmpty ? active.first : 'Finishing';
    final currentIcon = _sectionIcon(current);
    final totalSteps = sections.length;
    final currentStep = active.isNotEmpty ? (loaded.length + 1).clamp(1, totalSteps) : totalSteps;
    final progress = (currentStep / totalSteps).clamp(0, 1).toDouble();

    return PurpleCard(
      icon: Icons.sync_rounded,
      title: 'Data Sync Status',
      subtitle: 'Step $currentStep/$totalSteps',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withAlpha(110),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: scheme.outline),
        ),
        child: Column(
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 26,
                    color: scheme.primary,
                    backgroundColor: scheme.primary.withAlpha(35),
                  ),
                ),
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: scheme.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: scheme.outline),
                  ),
                  alignment: Alignment.center,
                  child: Icon(currentIcon, size: 18, color: scheme.primary),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              active.isEmpty ? 'Applying latest updates...' : 'Loading: $current',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: scheme.onSurface, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              'Buffering step $currentStep of $totalSteps',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  IconData _sectionIcon(String label) {
    switch (label) {
      case 'Profile':
        return Icons.person_rounded;
      case 'Summary':
        return Icons.dashboard_rounded;
      case 'Attendance':
        return Icons.fact_check_rounded;
      case 'Marks':
        return Icons.grade_rounded;
      case 'University Results':
        return Icons.school_rounded;
      case 'Timetable':
        return Icons.calendar_today_rounded;
      default:
        return Icons.sync_rounded;
    }
  }
}
