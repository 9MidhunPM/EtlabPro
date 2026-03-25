import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/student_data.dart';
import '../utils/timetable_analysis.dart';

class TimetableScreen extends StatefulWidget {
  const TimetableScreen({super.key});

  @override
  State<TimetableScreen> createState() => _TimetableScreenState();
}

class _TimetableScreenState extends State<TimetableScreen> with SingleTickerProviderStateMixin {
  static const _days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];

  late String _selectedDay;
  late final TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    final today = DateTime.now().weekday;
    _selectedDay = today >= 1 && today <= 6 ? _days[today - 1] : _days[0];
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _refreshTimetableWithFeedback() async {
    final data = context.read<StudentData>();
    final auth = context.read<AuthService>();
    final roll = auth.rollNumber;
    if (roll == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Session not ready. Please login again.')));
      return;
    }
    HapticFeedback.selectionClick();
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(const SnackBar(content: Text('Refreshing timetable...'), duration: Duration(milliseconds: 900)));
    await data.refreshTimetable(roll);
    if (!mounted) return;
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(const SnackBar(content: Text('Timetable updated'), duration: Duration(milliseconds: 900)));
  }

  @override
  Widget build(BuildContext context) {
    final data = context.watch<StudentData>();
    final allSlots = data.timetable;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: Column(
        children: [
          Container(
            color: scheme.primary,
            child: SafeArea(
              bottom: false,
              child: Row(
                children: [
                  Expanded(
                    child: TabBar(
                      controller: _tabCtrl,
                      labelColor: scheme.onPrimary,
                      unselectedLabelColor: scheme.onPrimary.withAlpha(160),
                      indicatorColor: scheme.onPrimary,
                      dividerColor: Colors.transparent,
                      tabs: const [Tab(text: 'Timetable'), Tab(text: 'Analysis')],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Refresh timetable',
                    icon: Icon(Icons.refresh_rounded, color: scheme.onPrimary),
                    onPressed: _refreshTimetableWithFeedback,
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabCtrl,
              children: [
                // Timetable tab
                _TimetableTab(
                  allSlots: allSlots,
                  selectedDay: _selectedDay,
                  days: _days,
                  onDayChanged: (d) => setState(() => _selectedDay = d),
                  scheme: scheme,
                  onRefresh: _refreshTimetableWithFeedback,
                ),
                // Analysis tab
                _AnalysisTab(slots: allSlots, attendance: data.attendance),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Timetable Tab ─────────────────────────────────────────────────────

class _TimetableTab extends StatelessWidget {
  final List<dynamic> allSlots;
  final String selectedDay;
  final List<String> days;
  final ValueChanged<String> onDayChanged;
  final ColorScheme scheme;
  final Future<void> Function()? onRefresh;

  const _TimetableTab({
    required this.allSlots,
    required this.selectedDay,
    required this.days,
    required this.onDayChanged,
    required this.scheme,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final daySlots = allSlots
        .where((s) => (s['day'] as String?)?.toLowerCase() == selectedDay.toLowerCase())
        .toList()
      ..sort((a, b) => ((a['period'] as int?) ?? 0).compareTo((b['period'] as int?) ?? 0));

    return Column(
      children: [
        SizedBox(
          height: 56,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            itemCount: days.length,
            itemBuilder: (_, i) {
              final day = days[i];
              final selected = day == selectedDay;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(day.substring(0, 3)),
                  selected: selected,
                  onSelected: (_) => onDayChanged(day),
                  selectedColor: scheme.primaryContainer,
                  labelStyle: TextStyle(
                    fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                    color: selected ? scheme.onPrimaryContainer : scheme.onSurfaceVariant,
                  ),
                ),
              );
            },
          ),
        ),
        Expanded(
          child: daySlots.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.beach_access_rounded, size: 56, color: scheme.onSurfaceVariant.withAlpha(100)),
                      const SizedBox(height: 12),
                      Text('No classes on $selectedDay', style: TextStyle(color: scheme.onSurfaceVariant)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: onRefresh ?? () async {},
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                    itemCount: daySlots.length,
                    itemBuilder: (_, i) => _SlotCard(slot: daySlots[i]),
                  ),
                ),
        ),
      ],
    );
  }
}

class _SlotCard extends StatelessWidget {
  final dynamic slot;
  const _SlotCard({required this.slot});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final period = slot['period'] ?? '—';
    final time = slot['period_time'] ?? '';
    final name = slot['subject_name'] ?? slot['subject_code'] ?? 'Free';
    final code = slot['subject_code'] ?? '';
    final teacher = slot['teacher'] ?? '';
    final classType = slot['class_type'] ?? '';
    final isFree = name == 'Free' || slot['subject_code'] == null;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isFree ? scheme.surfaceContainerHighest.withAlpha(80) : scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: isFree ? scheme.outlineVariant.withAlpha(60) : scheme.primaryContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Text('$period', style: TextStyle(fontWeight: FontWeight.bold, color: isFree ? scheme.onSurfaceVariant : scheme.onPrimaryContainer)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: TextStyle(fontWeight: FontWeight.w600, color: isFree ? scheme.onSurfaceVariant : scheme.onSurface)),
                if (!isFree && code.isNotEmpty) Text(code, style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                if (!isFree && teacher.isNotEmpty) Text(teacher, style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                if (classType.isNotEmpty) Text(classType, style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant.withAlpha(150))),
              ],
            ),
          ),
          if (time.isNotEmpty) Text(time, style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

// ── Analysis Tab ──────────────────────────────────────────────────────

class _AnalysisTab extends StatelessWidget {
  final List<dynamic> slots;
  final List<dynamic> attendance;
  const _AnalysisTab({required this.slots, required this.attendance});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (slots.isEmpty) {
      return Center(child: Text('No timetable data', style: TextStyle(color: scheme.onSurfaceVariant)));
    }

    final summary = getTimetableSummary(slots, attendance);
    final subjects = summary.weeklyClassesPerSubject.keys.toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        Container(
          decoration: BoxDecoration(color: scheme.surfaceContainerLow, borderRadius: BorderRadius.circular(16), border: Border.all(color: scheme.primary.withAlpha(30))),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                decoration: BoxDecoration(
                  color: scheme.primary,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.analytics_rounded, size: 18, color: scheme.onPrimary),
                    const SizedBox(width: 8),
                    Text('Class Analysis', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: scheme.onPrimary)),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${summary.totalSubjects} subjects • ${summary.totalWeeklyClasses} classes per week',
                        style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant)),
                    Text('Total hours: ${attendance.isNotEmpty ? 'from attendance records' : 'not available'}',
                        style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant, fontStyle: FontStyle.italic)),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                      decoration: BoxDecoration(color: scheme.primary, borderRadius: BorderRadius.circular(8)),
                      child: Row(
                        children: [
                          Expanded(flex: 4, child: Text('Subject', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: scheme.onPrimary))),
                          Expanded(flex: 2, child: Text('Per Week', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: scheme.onPrimary), textAlign: TextAlign.center)),
                          Expanded(flex: 2, child: Text('Total Hours', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: scheme.onPrimary), textAlign: TextAlign.center)),
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
