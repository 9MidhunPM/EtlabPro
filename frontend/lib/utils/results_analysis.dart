// Results analysis: grade analysis with attendance marks, CAT-1 scaling, min CAT-2.

/// Attendance marks based on percentage.
/// 90%+ = 5, 85-89 = 4, 80-84 = 3, 75-79 = 2, 70-74 = 1, below 70 = 0.
int? calculateAttendanceMarks(double percentage) {
  if (percentage >= 90) return 5;
  if (percentage >= 85) return 4;
  if (percentage >= 80) return 3;
  if (percentage >= 75) return 2;
  if (percentage >= 70) return 1;
  return 0;
}

String attendanceMarkBand(double percentage) {
  if (percentage >= 90) return '5/5';
  if (percentage >= 85) return '4/5';
  if (percentage >= 80) return '3/5';
  if (percentage >= 75) return '2/5';
  if (percentage >= 70) return '1/5';
  return '0/5';
}

/// Convert marks to 12.5 scale.
double convertToScale12_5(double marks, double maxMarks) {
  if (maxMarks == 0) return 0;
  return (marks / maxMarks) * 12.5;
}

class SubjectAnalysis {
  final String subjectCode;
  final String subjectName;
  double cat1;         // Already scaled
  double assignment;   // Editable by user
  int? attendanceMarks;
  double? attendancePercentage;
  bool isSpecial;      // 24CSR304

  SubjectAnalysis({
    required this.subjectCode,
    required this.subjectName,
    required this.cat1,
    this.assignment = 0,
    this.attendanceMarks,
    this.attendancePercentage,
    this.isSpecial = false,
  });

  double get cat1Scale => isSpecial ? 7.5 : 12.5;
  double get cat2Scale => isSpecial ? 7.5 : 12.5;
  double get assignmentScale => isSpecial ? 30.0 : 10.0;
  double get totalScale => isSpecial ? 50.0 : 40.0;

  double get total => cat1 + assignment + (attendanceMarks ?? 0);

  double get cat2NeededFor26 {
    final currentWithout = cat1 + assignment + (attendanceMarks ?? 0);
    return (26 - currentWithout).clamp(0, double.infinity);
  }

  bool get isImpossible => cat2NeededFor26 > cat2Scale;
}

/// Generate analysis from marks + attendance data.
List<SubjectAnalysis> getResultsAnalysis(
  List<dynamic> marks,
  List<dynamic> attendance,
) {
  // Group marks by subject, prioritize CAT 1 / Series 1
  final subjectMap = <String, Map<String, dynamic>>{};
  for (final m in marks) {
    final code = m['subject_code'] as String? ?? '';
    if (code.isEmpty || code == '24PWT208') continue;
    
    final type = (m['exam_type'] ?? '').toString().toLowerCase();
    final numStr = (m['exam_number'] ?? '').toString();
    final isCat1 = (type.contains('series') || type.contains('cat')) && numStr == '1';

    if (!subjectMap.containsKey(code)) {
      subjectMap[code] = m;
    } else if (isCat1) {
      subjectMap[code] = m;
    }
  }

  // Build attendance lookup: subject_code → percentage
  final attLookup = <String, double>{};
  for (final a in attendance) {
    final code = a['subject_code'] as String? ?? '';
    final pct = (a['percentage'] as num?)?.toDouble();
    if (code.isNotEmpty && pct != null) attLookup[code] = pct;
  }

  final result = <SubjectAnalysis>[];
  for (final entry in subjectMap.entries) {
    final code = entry.key;
    final m = entry.value;
    final obtained = (m['marks_obtained'] as num?)?.toDouble() ?? 0;
    final max = (m['max_marks'] as num?)?.toDouble() ?? 0;
    final isSpecial = code == '24CSR304';

    double cat1;
    if (isSpecial) {
      // Convert to 7.5 scale
      cat1 = max > 0 ? (obtained / max) * 7.5 : 0;
    } else {
      cat1 = convertToScale12_5(obtained, max);
    }

    final attPct = attLookup[code];
    final attMarks = attPct != null ? calculateAttendanceMarks(attPct) : null;

    result.add(SubjectAnalysis(
      subjectCode: code,
      subjectName: m['raw_subject_name'] ?? code,
      cat1: cat1,
      attendanceMarks: attMarks,
      attendancePercentage: attPct,
      isSpecial: isSpecial,
    ));
  }
  return result;
}

double roundToHalf(double v) => (v * 2).round() / 2;
