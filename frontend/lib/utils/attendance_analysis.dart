// Attendance analysis: projections, skippable classes.
import 'dart:math';

import 'timetable_analysis.dart';

class SubjectProjection {
  final String code;
  final String name;
  final int currentPresent;
  final int currentTotal;
  final double currentPercentage;
  final int additionalClasses;
  final int projectedTotal;
  final int projectedPresent;
  final double projectedPercentage;

  const SubjectProjection({
    required this.code,
    required this.name,
    required this.currentPresent,
    required this.currentTotal,
    required this.currentPercentage,
    required this.additionalClasses,
    required this.projectedTotal,
    required this.projectedPresent,
    required this.projectedPercentage,
  });
}

class SubjectSkippable {
  final String code;
  final String name;
  final int currentPresent;
  final int currentTotal;
  final double currentPercentage;
  final int additionalClasses;
  final int finalTotal;
  final int canSkip;
  final double optimalPercentage;
  final bool canMaintainTarget;

  const SubjectSkippable({
    required this.code,
    required this.name,
    required this.currentPresent,
    required this.currentTotal,
    required this.currentPercentage,
    required this.additionalClasses,
    required this.finalTotal,
    required this.canSkip,
    required this.optimalPercentage,
    required this.canMaintainTarget,
  });
}

class AttendanceAnalysis {
  final List<SubjectProjection> perfectAttendance;
  final List<SubjectSkippable> skip75;
  final List<SubjectSkippable> skip85;
  final DateTime targetDate;

  const AttendanceAnalysis({
    required this.perfectAttendance,
    required this.skip75,
    required this.skip85,
    required this.targetDate,
  });
}

/// Estimate additional classes from now to targetDate using weekly timetable counts.
int _estimateAdditional(int weeklyCount, DateTime targetDate) {
  final daysDiff = targetDate.difference(DateTime.now()).inDays;
  if (daysDiff <= 0) return 0;
  final weeksDiff = daysDiff / 7.0;
  return (weeklyCount * weeksDiff).ceil();
}

/// Try matching attendance subject name to a timetable subject name.
int _matchWeeklyCount(
  String attName,
  String attCode,
  Map<String, int> weeklyClasses,
) {
  final nameLow = attName.toLowerCase();
  final codeLow = attCode.toLowerCase();

  // Exact name match
  for (final entry in weeklyClasses.entries) {
    if (entry.key.toLowerCase() == nameLow) return entry.value;
  }

  // Partial match
  for (final entry in weeklyClasses.entries) {
    final tLow = entry.key.toLowerCase();
    if (tLow.contains(codeLow.substring(0, min(3, codeLow.length))) ||
        codeLow.contains(tLow.substring(0, min(3, tLow.length))) ||
        tLow.contains(nameLow.substring(0, min(4, nameLow.length))) ||
        nameLow.contains(tLow.substring(0, min(4, tLow.length)))) {
      return entry.value;
    }
  }
  return 0;
}

AttendanceAnalysis getComprehensiveAnalysis(
  List<dynamic> attendance,
  List<dynamic> timetableSlots,
  DateTime targetDate,
  [List<dynamic>? marks] // added marks to extract names
) {
  final weeklyClasses = getSubjectClassesPerWeek(timetableSlots);
  final subjectNames = <String, String>{};
  if (marks != null) {
    for (final m in marks) {
      if (m['subject_code'] != null && m['raw_subject_name'] != null) {
        subjectNames[m['subject_code']] = m['raw_subject_name'];
      }
    }
  }

  final perfect = <SubjectProjection>[];
  final s75 = <SubjectSkippable>[];
  final s85 = <SubjectSkippable>[];

  for (final a in attendance) {
    final code = (a['subject_code'] ?? '') as String;
    final name = (a['raw_subject_name'] ?? subjectNames[code] ?? code) as String;
    final present = (a['classes_attended'] as num?)?.toInt() ?? 0;
    final total = (a['classes_total'] as num?)?.toInt() ?? 0;
    final pct = (a['percentage'] as num?)?.toDouble() ?? 0;

    final additional = _estimateAdditional(
      _matchWeeklyCount(name, code, weeklyClasses),
      targetDate,
    );

    // Perfect attendance projection
    final projTotal = total + additional;
    final projPresent = present + additional;
    final projPct = projTotal > 0 ? (projPresent / projTotal) * 100 : 0;
    perfect.add(SubjectProjection(
      code: code,
      name: name,
      currentPresent: present,
      currentTotal: total,
      currentPercentage: pct,
      additionalClasses: additional,
      projectedTotal: projTotal,
      projectedPresent: projPresent,
      projectedPercentage: (projPct * 100).roundToDouble() / 100,
    ));

    // 75% target
    s75.add(_calcSkippable(code, name, present, total, pct, additional, 75));
    // 85% target
    s85.add(_calcSkippable(code, name, present, total, pct, additional, 85));
  }

  return AttendanceAnalysis(
    perfectAttendance: perfect,
    skip75: s75,
    skip85: s85,
    targetDate: targetDate,
  );
}

SubjectSkippable _calcSkippable(
  String code,
  String name,
  int present,
  int total,
  double pct,
  int additional,
  int target,
) {
  final finalTotal = total + additional;
  final minNeeded = (target / 100 * finalTotal).ceil();
  final maxCanAttend = present + additional;
  final canSkip = max(0, maxCanAttend - minNeeded);
  final optimalPresent = min(maxCanAttend, max(minNeeded, present));
  final optimalPct = finalTotal > 0 ? (optimalPresent / finalTotal) * 100 : 0;

  return SubjectSkippable(
    code: code,
    name: name,
    currentPresent: present,
    currentTotal: total,
    currentPercentage: pct,
    additionalClasses: additional,
    finalTotal: finalTotal,
    canSkip: canSkip,
    optimalPercentage: (optimalPct * 100).roundToDouble() / 100,
    canMaintainTarget: optimalPct >= target,
  );
}
