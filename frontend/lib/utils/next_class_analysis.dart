import 'package:intl/intl.dart';
import '../core/constants.dart';

class ClassInfo {
  final String subject;
  final String? teacher;
  final String timing;
  final bool isFree;

  const ClassInfo({
    required this.subject,
    this.teacher,
    required this.timing,
    this.isFree = false,
  });
}

class NextClassResult {
  final ClassInfo? currentClass;
  final ClassInfo? nextClass;
  final ClassInfo? tomorrowFirstClass;
  final bool isClassOngoing;
  final bool showTomorrowSchedule;
  final String currentTime;

  const NextClassResult({
    this.currentClass,
    this.nextClass,
    this.tomorrowFirstClass,
    this.isClassOngoing = false,
    this.showTomorrowSchedule = false,
    required this.currentTime,
  });
}

const _days = ['sunday', 'monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday'];

int _timeToMinutes(String t) {
  final parts = t.split(':');
  return int.parse(parts[0]) * 60 + int.parse(parts[1]);
}

String _currentTimeString() {
  final now = DateTime.now();
  return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
}

String _formatCurrentTime() => DateFormat.jm().format(DateTime.now());

String _currentDay() => _days[DateTime.now().weekday % 7];

ClassInfo _formatPeriod(Map<String, dynamic>? slot, int period) {
  if (slot == null || slot['subject_code'] == null) {
    final timing = AppConstants.periodTimings[period]?['display'] ?? '';
    return ClassInfo(subject: 'Free Period', timing: timing, isFree: true);
  }
  return ClassInfo(
    subject: slot['raw_subject_name'] ?? slot['subject_code'] ?? 'Free Period',
    teacher: slot['teacher'] as String?,
    timing: AppConstants.periodTimings[period]?['display'] ?? '',
    isFree: false,
  );
}

/// Get current/next class info based on timetable + current time.
NextClassResult getNextClassInfo(List<dynamic> timetableSlots) {
  final currentDay = _currentDay();
  final currentTime = _currentTimeString();
  final currentMinutes = _timeToMinutes(currentTime);
  final displayTime = _formatCurrentTime();

  if (currentDay == 'sunday' || currentDay == 'saturday') {
    final tomorrow = _getTomorrowFirstClass(timetableSlots, currentDay);
    return NextClassResult(
      showTomorrowSchedule: true,
      tomorrowFirstClass: tomorrow,
      currentTime: displayTime,
    );
  }

  // Build period list for today
  final todaySlots = <int, Map<String, dynamic>>{};
  for (final s in timetableSlots) {
    if ((s['day'] as String?)?.toLowerCase() == currentDay) {
      todaySlots[s['period'] as int? ?? 0] = s as Map<String, dynamic>;
    }
  }

  ClassInfo? currentClass;
  ClassInfo? nextClass;
  bool isOngoing = false;

  for (int p = 1; p <= 7; p++) {
    final timing = AppConstants.periodTimings[p];
    if (timing == null) continue;
    final start = _timeToMinutes(timing['start']!);
    final end = _timeToMinutes(timing['end']!);

    if (currentMinutes >= start && currentMinutes < end) {
      currentClass = _formatPeriod(todaySlots[p], p);
      isOngoing = true;
    } else if (currentMinutes < start && nextClass == null) {
      nextClass = _formatPeriod(todaySlots[p], p);
    }
  }

  final showTomorrow = !isOngoing && nextClass == null;
  final tomorrowFirst = showTomorrow ? _getTomorrowFirstClass(timetableSlots, currentDay) : null;

  return NextClassResult(
    currentClass: currentClass,
    nextClass: nextClass,
    tomorrowFirstClass: tomorrowFirst,
    isClassOngoing: isOngoing,
    showTomorrowSchedule: showTomorrow,
    currentTime: displayTime,
  );
}

ClassInfo? _getTomorrowFirstClass(List<dynamic> slots, String currentDay) {
  final dayIndex = _days.indexOf(currentDay);
  // Find next weekday
  int nextDayIndex = (dayIndex + 1) % 7;
  while (nextDayIndex == 0) {
    // skip sunday
    nextDayIndex = (nextDayIndex + 1) % 7;
  }
  final nextDayName = _days[nextDayIndex];

  final tomorrowSlots = <int, Map<String, dynamic>>{};
  for (final s in slots) {
    if ((s['day'] as String?)?.toLowerCase() == nextDayName) {
      tomorrowSlots[s['period'] as int? ?? 0] = s as Map<String, dynamic>;
    }
  }

  // Find first real (non-free) class in period order
  for (int p = 1; p <= 7; p++) {
    final slot = tomorrowSlots[p];
    if (slot != null && slot['subject_code'] != null) {
      return _formatPeriod(slot, p);
    }
  }
  return null;
}
