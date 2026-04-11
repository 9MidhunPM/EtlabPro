import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/student_data.dart';

class MonthlyAttendanceScreen extends StatefulWidget {
  const MonthlyAttendanceScreen({super.key});

  @override
  State<MonthlyAttendanceScreen> createState() => _MonthlyAttendanceScreenState();
}

class _MonthlyAttendanceScreenState extends State<MonthlyAttendanceScreen> {
  String? _selectedSemester;
  String? _selectedMonth;
  String? _selectedYear;
  bool _isLoading = false;
  String? _error;

  Map<String, dynamic>? _attendanceData;

  @override
  void initState() {
    super.initState();
    _loadMetadata();
  }

  Future<void> _loadMetadata() async {
    final auth = context.read<AuthService>();
    final data = context.read<StudentData>();

    if (auth.username == null || auth.password == null) return;

    try {
      setState(() => _isLoading = true);
      await data.fetchAttendanceMetadata(
        username: auth.username!,
        password: auth.password!,
      );
      final metadata = data.attendanceMetadata;
      if (metadata != null) {
        setState(() {
          _selectedSemester = metadata['current_semester']?.toString();
          // Get first available month
          final months = metadata['available_months'] as List?;
          if (months != null && months.isNotEmpty) {
            _selectedMonth = months.first['value']?.toString();
          }
          // Get first available year
          final years = metadata['available_years'] as List?;
          if (years != null && years.isNotEmpty) {
            _selectedYear = years.first['value']?.toString();
          }
        });
      }
    } catch (e) {
      setState(() => _error = 'Failed to load metadata: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchAttendance() async {
    if (_selectedSemester == null || _selectedMonth == null || _selectedYear == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select semester, month, and year')),
      );
      return;
    }

    final auth = context.read<AuthService>();
    final data = context.read<StudentData>();

    if (auth.username == null || auth.password == null) return;

    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });
      final result = await data.fetchLiveMonthlyAttendance(
        username: auth.username!,
        password: auth.password!,
        semester: _selectedSemester,
        month: _selectedMonth,
        year: _selectedYear,
      );
      setState(() => _attendanceData = result);
    } catch (e) {
      setState(() => _error = 'Failed to fetch attendance: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = context.watch<StudentData>();
    final scheme = Theme.of(context).colorScheme;
    final metadata = data.attendanceMetadata;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Monthly Attendance'),
        elevation: 0,
      ),
      body: _isLoading && metadata == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Filters Card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Select Period',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          if (metadata != null) ...[
                            // Semester Dropdown
                            DropdownButtonFormField<String>(
                              value: _selectedSemester,
                              decoration: InputDecoration(
                                labelText: 'Semester',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              items: (metadata['available_semesters'] as List? ?? [])
                                  .map((sem) => DropdownMenuItem(
                                value: sem['value']?.toString(),
                                child: Text(sem['label']?.toString() ?? ''),
                              ))
                                  .toList(),
                              onChanged: (value) {
                                setState(() => _selectedSemester = value);
                              },
                            ),
                            const SizedBox(height: 12),
                            // Month Dropdown
                            DropdownButtonFormField<String>(
                              value: _selectedMonth,
                              decoration: InputDecoration(
                                labelText: 'Month',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              items: (metadata['available_months'] as List? ?? [])
                                  .map((month) => DropdownMenuItem(
                                value: month['value']?.toString(),
                                child: Text(month['label']?.toString() ?? ''),
                              ))
                                  .toList(),
                              onChanged: (value) {
                                setState(() => _selectedMonth = value);
                              },
                            ),
                            const SizedBox(height: 12),
                            // Year Dropdown
                            DropdownButtonFormField<String>(
                              value: _selectedYear,
                              decoration: InputDecoration(
                                labelText: 'Year',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              items: (metadata['available_years'] as List? ?? [])
                                  .map((year) => DropdownMenuItem(
                                value: year['value']?.toString(),
                                child: Text(year['label']?.toString() ?? ''),
                              ))
                                  .toList(),
                              onChanged: (value) {
                                setState(() => _selectedYear = value);
                              },
                            ),
                          ],
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _fetchAttendance,
                              child: _isLoading
                                  ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                                  : const Text('Fetch Attendance'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Error message
                  if (_error != null)
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
                  // Attendance Data
                  if (_attendanceData != null) ...[
                    _buildAttendanceSummary(_attendanceData!, scheme),
                    const SizedBox(height: 16),
                    _buildDailyBreakdown(_attendanceData!, scheme),
                  ] else if (!_isLoading && _attendanceData == null)
                    Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.calendar_month,
                            size: 64,
                            color: scheme.onSurfaceVariant.withAlpha(100),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Select a period and fetch attendance',
                            style: TextStyle(color: scheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildAttendanceSummary(Map<String, dynamic> data, ColorScheme scheme) {
    final months = (data['months'] as List? ?? []);
    if (months.isEmpty) {
      return const SizedBox.shrink();
    }

    final month = months.first as Map<String, dynamic>;
    final daysPresent = month['days_present'] ?? 0;
    final daysAbsent = month['days_absent'] ?? 0;
    final daysDutyLeave = month['days_duty_leave'] ?? 0;
    final daysLate = month['days_late'] ?? 0;
    final daysHoliday = month['days_holiday'] ?? 0;
    final totalMarkedDays = month['total_marked_days'] ?? 0;

    final totalAttended = (daysPresent as int) + (daysLate as int);
    final percentage = totalMarkedDays > 0 
        ? ((totalAttended / totalMarkedDays) * 100).toStringAsFixed(1)
        : '0.0';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${month['month']} ${month['year']}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$percentage%',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ],
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

  Widget _buildDailyBreakdown(Map<String, dynamic> data, ColorScheme scheme) {
    final months = (data['months'] as List? ?? []);
    if (months.isEmpty) {
      return const SizedBox.shrink();
    }

    final month = months.first as Map<String, dynamic>;
    final entries = (month['entries'] as List? ?? []);

    if (entries.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Daily Breakdown',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: entries.length,
            itemBuilder: (context, index) {
              final entry = entries[index] as Map<String, dynamic>;
              final day = entry['day'];
              final dayLabel = entry['day_label']?.toString() ?? 'Day $day';
              final summary = entry['summary']?.toString().toLowerCase() ?? 'na';
              final counts = entry['counts'] as Map<String, dynamic>? ?? {};

              Color statusColor = Colors.grey;
              if (summary.contains('present')) statusColor = Colors.green;
              if (summary.contains('absent')) statusColor = Colors.red;
              if (summary.contains('duty')) statusColor = Colors.orange;
              if (summary.contains('late')) statusColor = Colors.amber;
              if (summary.contains('holiday')) statusColor = Colors.blue;

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: statusColor.withAlpha(30),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: statusColor.withAlpha(60)),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              dayLabel.split(' ')[0],
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            summary.isEmpty ? 'N/A' : summary.toUpperCase(),
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: statusColor,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 4,
                            children: [
                              if (((counts['present'] as int?) ?? 0) > 0)
                                _smallBadge('P: ${counts['present']}', Colors.green),
                              if (((counts['absent'] as int?) ?? 0) > 0)
                                _smallBadge('A: ${counts['absent']}', Colors.red),
                              if (((counts['duty_leave'] as int?) ?? 0) > 0)
                                _smallBadge('DL: ${counts['duty_leave']}', Colors.orange),
                              if (((counts['late'] as int?) ?? 0) > 0)
                                _smallBadge('L: ${counts['late']}', Colors.amber),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _smallBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
