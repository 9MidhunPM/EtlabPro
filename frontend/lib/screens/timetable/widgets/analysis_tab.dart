import 'package:flutter/material.dart';
import '../../../utils/timetable_analysis.dart';

class TimetableAnalysisTab extends StatelessWidget {
  final List<dynamic> slots;
  final List<dynamic> attendance;
  final List<dynamic>? marks;

  const TimetableAnalysisTab({super.key, required this.slots, required this.attendance, this.marks});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final headerBg = isDark ? scheme.primary.withAlpha(38) : scheme.primary.withAlpha(14);
    if (slots.isEmpty) {
      return Center(child: Text('No timetable data', style: TextStyle(color: scheme.onSurfaceVariant)));
    }

    final summary = getTimetableSummary(slots, attendance, marks);
    final subjects = summary.weeklyClassesPerSubject.keys.toList();

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
                    Text('Class Analysis', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: isDark ? scheme.outline : scheme.primary)),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${summary.totalSubjects} subjects • ${summary.totalWeeklyClasses} classes per week', style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant)),
                    Text('Total hours: ${attendance.isNotEmpty ? 'from attendance records' : 'not available'}', style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant, fontStyle: FontStyle.italic)),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                      decoration: BoxDecoration(color: headerBg, borderRadius: BorderRadius.circular(8)),
                      child: Row(
                        children: [
                          Expanded(flex: 4, child: Text('Subject', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isDark ? scheme.outline : scheme.primary))),
                          Expanded(flex: 2, child: Text('Per Week', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isDark ? scheme.outline : scheme.primary), textAlign: TextAlign.center)),
                          Expanded(flex: 2, child: Text('Total Hours', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isDark ? scheme.outline : scheme.primary), textAlign: TextAlign.center)),
                        ],
                      ),
                    ),
                    for (int i = 0; i < subjects.length; i++)
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                        decoration: BoxDecoration(color: i.isEven ? scheme.surfaceContainerHighest.withAlpha(40) : Colors.transparent),
                        child: Row(
                          children: [
                            Expanded(flex: 4, child: Text(subjects[i], style: const TextStyle(fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis)),
                            Expanded(flex: 2, child: Text('${summary.weeklyClassesPerSubject[subjects[i]]}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500), textAlign: TextAlign.center)),
                            Expanded(flex: 2, child: Text('${summary.totalHoursPerSubject[subjects[i]] ?? 0}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500), textAlign: TextAlign.center)),
                          ],
                        ),
                      ),
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                      decoration: BoxDecoration(color: scheme.primary.withAlpha(40), borderRadius: BorderRadius.circular(8)),
                      child: Row(
                        children: [
                          Expanded(flex: 4, child: Text('Total', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: scheme.onSurface))),
                          Expanded(flex: 2, child: Text('${summary.totalWeeklyClasses}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: scheme.onSurface), textAlign: TextAlign.center)),
                          Expanded(flex: 2, child: Text('${summary.totalHours}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: scheme.onSurface), textAlign: TextAlign.center)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
