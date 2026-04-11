import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/student_data.dart';

class MonthlyAttendanceScreen extends StatefulWidget {
  const MonthlyAttendanceScreen({super.key});

  @override
  State<MonthlyAttendanceScreen> createState() => _MonthlyAttendanceScreenState();
}

class _MonthlyAttendanceScreenState extends State<MonthlyAttendanceScreen> {
  bool _isLoading = false;
  String? _error;
  Map<String, dynamic>? _currentMonth;
  int? _selectedDay;

  @override
  void initState() {
    super.initState();
    _loadCurrentMonth();
  }

  Future<void> _loadCurrentMonth() async {
    final auth = context.read<AuthService>();
    final data = context.read<StudentData>();

    if (auth.username == null || auth.password == null) {
      return;
    }

    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final result = await data.fetchLiveMonthlyAttendance(
        username: auth.username!,
        password: auth.password!,
      );
      final months = (result['months'] as List? ?? []).cast<Map<String, dynamic>>();
      final month = _pickLatestMonth(months);
      setState(() {
        _currentMonth = month;
        _selectedDay = month == null ? null : _firstSelectableDay(month);
      });
    } catch (e) {
      setState(() => _error = 'Failed to load monthly attendance: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Map<String, dynamic>? _pickLatestMonth(List<Map<String, dynamic>> months) {
    if (months.isEmpty) return null;

    int monthIndex(String? month) {
      final key = (month ?? '').trim().toLowerCase();
      const lookup = {
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
      return lookup[key.length >= 3 ? key.substring(0, 3) : key] ?? 0;
    }

    DateTime score(Map<String, dynamic> month) {
      final year = int.tryParse(month['year']?.toString() ?? '') ?? 0;
      return DateTime(year, monthIndex(month['month']?.toString()));
    }

    months.sort((a, b) => score(a).compareTo(score(b)));
    return months.last;
  }

  int _firstSelectableDay(Map<String, dynamic> month) {
    final entries = (month['entries'] as List? ?? []).cast<Map<String, dynamic>>();
    if (entries.isEmpty) return 1;
    return (entries.first['day'] as num?)?.toInt() ?? 1;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final month = _currentMonth;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Monthly Attendance'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _loadCurrentMonth,
          ),
        ],
      ),
      body: _isLoading && month == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadCurrentMonth,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_error != null) ...[
                      Card(
                        color: scheme.errorContainer,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              Icon(Icons.error_outline, color: scheme.error),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _error!,
                                  style: TextStyle(color: scheme.onErrorContainer),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (month != null) ...[
                      _CalendarCard(
                        month: month,
                        selectedDay: _selectedDay,
                        onDaySelected: (day) => setState(() => _selectedDay = day),
                      ),
                      const SizedBox(height: 16),
                      _DayDetailCard(
                        month: month,
                        selectedDay: _selectedDay,
                      ),
                    ] else if (!_isLoading) ...[
                      Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.calendar_month,
                              size: 64,
                              color: scheme.onSurfaceVariant.withAlpha(100),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'No monthly attendance data available',
                              style: TextStyle(color: scheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final Map<String, dynamic> month;
  const _SummaryCard({required this.month});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final daysPresent = (month['days_present'] as num?)?.toInt() ?? 0;
    final daysAbsent = (month['days_absent'] as num?)?.toInt() ?? 0;
    final daysDutyLeave = (month['days_duty_leave'] as num?)?.toInt() ?? 0;
    final daysLate = (month['days_late'] as num?)?.toInt() ?? 0;
    final daysHoliday = (month['days_holiday'] as num?)?.toInt() ?? 0;
    final totalMarkedDays = (month['total_marked_days'] as num?)?.toInt() ?? 0;
    final totalAttended = daysPresent + daysLate;
    final percentage = totalMarkedDays > 0 ? (totalAttended / totalMarkedDays) * 100 : 0.0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    '${month['month']} ${month['year']}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${percentage.toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              month['semester']?.toString() ?? 'Current semester',
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 1.2,
              children: [
                _statCard('Present', daysPresent.toString(), Colors.green, scheme),
                _statCard('Absent', daysAbsent.toString(), Colors.red, scheme),
                _statCard('Duty Leave', daysDutyLeave.toString(), Colors.orange, scheme),
                _statCard('Late', daysLate.toString(), Colors.amber, scheme),
                _statCard('Holiday', daysHoliday.toString(), Colors.blue, scheme),
                _statCard('Total Days', totalMarkedDays.toString(), Colors.purple, scheme),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statCard(String label, String value, Color color, ColorScheme scheme) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _CalendarCard extends StatelessWidget {
  final Map<String, dynamic> month;
  final int? selectedDay;
  final ValueChanged<int> onDaySelected;

  const _CalendarCard({
    required this.month,
    required this.selectedDay,
    required this.onDaySelected,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final year = int.tryParse(month['year']?.toString() ?? '') ?? DateTime.now().year;
    final monthIndex = _monthNumber(month['month']?.toString());
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
        _DayCell(
          day: day,
          entry: entry,
          isSelected: selectedDay == day,
          onTap: () => onDaySelected(day),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Calendar View',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                Text(
                  DateFormat('MMMM yyyy').format(DateTime(year, monthIndex)),
                  style: TextStyle(color: scheme.onSurfaceVariant, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 7,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 1,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              children: [
                for (final label in const ['S', 'M', 'T', 'W', 'T', 'F', 'S'])
                  Center(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
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
      ),
    );
  }

  int _monthNumber(String? month) {
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
}

class _DayCell extends StatelessWidget {
  final int day;
  final Map<String, dynamic>? entry;
  final bool isSelected;
  final VoidCallback onTap;

  const _DayCell({
    required this.day,
    required this.entry,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final counts = (entry?['counts'] as Map<String, dynamic>?) ?? {};
    final color = _colorForCounts(counts);
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
                if (hasDetails)
                  const SizedBox(width: 2),
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

  Color _colorForCounts(Map<String, dynamic> counts) {
    final present = (counts['present'] as int?) ?? 0;
    final absent = (counts['absent'] as int?) ?? 0;
    final dutyLeave = (counts['duty_leave'] as int?) ?? 0;
    final holiday = (counts['holiday'] as int?) ?? 0;

    if (holiday > 0) return Colors.blue;
    if (absent > 0 || dutyLeave > 0) return Colors.orange;
    if (present > 0) return Colors.green;
    return Colors.grey;
  }
}

class _DayDetailCard extends StatelessWidget {
  final Map<String, dynamic> month;
  final int? selectedDay;

  const _DayDetailCard({required this.month, required this.selectedDay});

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
    final color = _colorForSummary(summary);
    final periods = (selected['periods'] as List? ?? []).cast<Map<String, dynamic>>();
    final dayNumber = (selected['day'] as num?)?.toInt() ?? 0;
    final monthLabel = DateFormat('MMMM').format(DateTime(
      int.tryParse(month['year']?.toString() ?? '') ?? DateTime.now().year,
      _monthNumber(month['month']?.toString()),
    ));
    final isHolidayOnly = summary.contains('holiday') || periods.every((period) => period['status']?.toString().toLowerCase() == 'holiday');

    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: color.withAlpha(24),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${selected['day']}',
                      style: TextStyle(fontWeight: FontWeight.bold, color: color),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_ordinal(dayNumber)} $monthLabel',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (isHolidayOnly)
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.blue.withAlpha(16),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: Colors.blue.withAlpha(70)),
                    ),
                    child: const Text(
                      'Holiday',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
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
                  final periodColor = _colorForSummary(status);
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
      ),
    );
  }

  String _ordinal(int day) {
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

  int _monthNumber(String? month) {
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

  Color _colorForSummary(String summary) {
    if (summary.contains('present')) return Colors.green;
    if (summary.contains('absent')) return Colors.red;
    if (summary.contains('duty')) return Colors.orange;
    if (summary.contains('late')) return Colors.amber;
    if (summary.contains('holiday')) return Colors.blue;
    return Colors.grey;
  }
}
