import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../widgets/screen_parts.dart';

class MonthlyCalendarCard extends StatelessWidget {
  final Map<String, dynamic> month;
  final int? selectedDay;
  final ValueChanged<int> onDaySelected;

  const MonthlyCalendarCard({
    super.key,
    required this.month,
    required this.selectedDay,
    required this.onDaySelected,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final year = int.tryParse(month['year']?.toString() ?? '') ?? DateTime.now().year;
    final monthIndex = monthNumber(month['month']?.toString());
    final daysInMonth = DateTime(year, monthIndex + 1, 0).day;
    final firstWeekday = DateTime(year, monthIndex, 1).weekday;
    final entries = (month['entries'] as List? ?? []).cast<Map<String, dynamic>>();
    final byDay = {for (final entry in entries) (entry['day'] as num?)?.toInt() ?? 0: entry};

    final cells = <Widget>[];
    for (int i = 1; i < firstWeekday; i++) {
      cells.add(const SizedBox.shrink());
    }

    for (int day = 1; day <= daysInMonth; day++) {
      final entry = byDay[day];
      cells.add(
        _MonthlyDayCell(
          day: day,
          entry: entry,
          isSelected: selectedDay == day,
          onTap: () => onDaySelected(day),
        ),
      );
    }

    return ScreenSectionCard(
      icon: Icons.calendar_month,
      title: 'Calendar View',
      trailing: Text(
        DateFormat('MMMM yyyy').format(DateTime(year, monthIndex)),
        style: TextStyle(color: scheme.onPrimary.withAlpha(220), fontWeight: FontWeight.w600),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              for (final label in const ['S', 'M', 'T', 'W', 'T', 'F', 'S'])
                Expanded(
                  child: Center(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        height: 1,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 0),
          GridView.count(
            crossAxisCount: 7,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 0.84,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            children: cells,
          ),
        ],
      ),
    );
  }
}

class _MonthlyDayCell extends StatelessWidget {
  final int day;
  final Map<String, dynamic>? entry;
  final bool isSelected;
  final VoidCallback onTap;

  const _MonthlyDayCell({
    required this.day,
    required this.entry,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final counts = (entry?['counts'] as Map<String, dynamic>?) ?? {};
    final color = colorForCounts(counts);
    final hasData = entry != null;
    final hasDetails = (entry?['periods'] as List?)?.isNotEmpty ?? false;

    return InkWell(
      onTap: hasData ? onTap : null,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color.withAlpha(40) : color.withAlpha(18),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? color.withAlpha(180) : color.withAlpha(80),
            width: isSelected ? 1.6 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.topLeft,
                      child: Text(
                        '$day',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: hasData ? color : Colors.grey,
                        ),
                      ),
                    ),
                  ),
                ),
                if (hasDetails) const SizedBox(width: 2),
                if (hasDetails)
                  Icon(
                    isSelected ? Icons.expand_less : Icons.expand_more,
                    size: 12,
                    color: color,
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Expanded(
              child: Center(
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: hasData ? color : Colors.grey.shade300,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MonthlyDayDetailCard extends StatelessWidget {
  final Map<String, dynamic> month;
  final int? selectedDay;

  const MonthlyDayDetailCard({super.key, required this.month, required this.selectedDay});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final entries = (month['entries'] as List? ?? []).cast<Map<String, dynamic>>();
    final selected = entries.cast<Map<String, dynamic>?>().firstWhere(
      (entry) => (entry?['day'] as num?)?.toInt() == selectedDay,
      orElse: () => null,
    );

    if (selected == null) {
      return const SizedBox.shrink();
    }

    final summary = selected['summary']?.toString().toLowerCase() ?? 'na';
    final color = colorForSummary(summary);
    final periods = (selected['periods'] as List? ?? []).cast<Map<String, dynamic>>();
    final dayNumber = (selected['day'] as num?)?.toInt() ?? 0;
    final monthLabel = DateFormat('MMMM').format(DateTime(
      int.tryParse(month['year']?.toString() ?? '') ?? DateTime.now().year,
      monthNumber(month['month']?.toString()),
    ));
    final isHolidayOnly = summary.contains('holiday') || periods.every((period) => period['status']?.toString().toLowerCase() == 'holiday');

    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      child: ScreenSectionCard(
        icon: Icons.today,
        title: '${ordinal(dayNumber)} $monthLabel',
        headerColor: color,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isHolidayOnly)
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: scheme.primary.withAlpha(14),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: scheme.primary.withAlpha(80)),
                  ),
                  child: Text(
                    'Holiday',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: scheme.primary,
                    ),
                  ),
                ),
              )
            else ...[
              const Text(
                'Periods',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 10),
              ...periods.map((period) {
                final status = period['status']?.toString().toLowerCase() ?? 'na';
                final periodColor = colorForSummary(status);
                final subject = period['subject']?.toString() ?? 'No subject';
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: periodColor.withAlpha(14),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: periodColor.withAlpha(60)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: periodColor.withAlpha(24),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '${period['period']}',
                          style: TextStyle(fontWeight: FontWeight.bold, color: periodColor),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              subject,
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              status.toUpperCase(),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: periodColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }
}

int monthNumber(String? month) {
  const map = {
    'jan': 1,
    'feb': 2,
    'mar': 3,
    'apr': 4,
    'may': 5,
    'jun': 6,
    'jul': 7,
    'aug': 8,
    'sep': 9,
    'oct': 10,
    'nov': 11,
    'dec': 12,
  };
  final key = (month ?? '').trim().toLowerCase();
  return map[key.length >= 3 ? key.substring(0, 3) : key] ?? DateTime.now().month;
}

String ordinal(int day) {
  if (day <= 0) return 'Day';
  if (day % 100 >= 11 && day % 100 <= 13) return '${day}th';
  switch (day % 10) {
    case 1:
      return '${day}st';
    case 2:
      return '${day}nd';
    case 3:
      return '${day}rd';
    default:
      return '${day}th';
  }
}

Color colorForSummary(String summary) {
  if (summary.contains('present')) return Colors.teal.shade600;
  if (summary.contains('absent')) return Colors.red.shade600;
  if (summary.contains('duty')) return Colors.blue.shade700;
  if (summary.contains('late')) return Colors.deepPurple.shade400;
  if (summary.contains('holiday')) return Colors.indigo.shade400;
  return Colors.blueGrey.shade400;
}

Color colorForCounts(Map<String, dynamic> counts) {
  final present = (counts['present'] as int?) ?? 0;
  final absent = (counts['absent'] as int?) ?? 0;
  final dutyLeave = (counts['duty_leave'] as int?) ?? 0;
  final holiday = (counts['holiday'] as int?) ?? 0;

  if (holiday > 0) return Colors.indigo.shade400;
  if (absent > 0) return Colors.red.shade600;
  if (dutyLeave > 0) return Colors.blue.shade700;
  if (present > 0) return Colors.teal.shade600;
  return Colors.blueGrey.shade400;
}
