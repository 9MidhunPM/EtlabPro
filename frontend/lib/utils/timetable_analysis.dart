// Timetable analysis: weekly class counts + total hours from attendance.

/// Count classes per subject per week from the flat timetable slot list.
Map<String, int> getSubjectClassesPerWeek(List<dynamic> slots) {
  final counts = <String, int>{};
  for (final s in slots) {
    final name = (s['raw_subject_name'] ?? s['subject_code'] ?? '') as String;
    if (name.isEmpty) continue;
    counts[name] = (counts[name] ?? 0) + 1;
  }
  return counts;
}

/// Get total class hours per subject from attendance data.
Map<String, int> getSubjectTotalHoursFromAttendance(List<dynamic> attendance) {
  final hours = <String, int>{};
  for (final a in attendance) {
    final name = (a['raw_subject_name'] ?? a['subject_code'] ?? '') as String;
    final total = a['classes_total'] as int? ?? 0;
    if (name.isNotEmpty) hours[name] = total;
  }
  return hours;
}

/// Summary for the timetable analysis tab.
class TimetableSummary {
  final int totalSubjects;
  final int totalWeeklyClasses;
  final Map<String, int> weeklyClassesPerSubject;
  final Map<String, int> totalHoursPerSubject;
  final int totalHours;

  const TimetableSummary({
    required this.totalSubjects,
    required this.totalWeeklyClasses,
    required this.weeklyClassesPerSubject,
    required this.totalHoursPerSubject,
    required this.totalHours,
  });
}

TimetableSummary getTimetableSummary(
  List<dynamic> slots,
  List<dynamic> attendance,
) {
  final weekly = getSubjectClassesPerWeek(slots);
  final hours = getSubjectTotalHoursFromAttendance(attendance);
  final totalWeekly = weekly.values.fold<int>(0, (s, v) => s + v);
  final totalHrs = hours.values.fold<int>(0, (s, v) => s + v);

  return TimetableSummary(
    totalSubjects: weekly.length,
    totalWeeklyClasses: totalWeekly,
    weeklyClassesPerSubject: weekly,
    totalHoursPerSubject: hours,
    totalHours: totalHrs,
  );
}
