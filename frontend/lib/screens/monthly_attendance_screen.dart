import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/student_data.dart';
import 'monthly/widgets/monthly_sections.dart';
import '../widgets/screen_parts.dart';

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
                      ScreenErrorCard(message: _error!),
                      const SizedBox(height: 16),
                    ],
                    if (month != null) ...[
                      MonthlyCalendarCard(month: month, selectedDay: _selectedDay, onDaySelected: (day) => setState(() => _selectedDay = day)),
                      const SizedBox(height: 16),
                      MonthlyDayDetailCard(month: month, selectedDay: _selectedDay),
                    ] else if (!_isLoading) ...[
                      const ScreenEmptyState(
                        icon: Icons.calendar_month,
                        title: 'No monthly attendance data available',
                      ),
                    ],
                  ],
                ),
              ),
            ),
    );
  }
}
