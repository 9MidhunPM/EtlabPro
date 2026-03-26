import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import '../services/auth_service.dart';
import '../services/student_data.dart';
import '../services/theme_notifier.dart';
import '../utils/next_class_analysis.dart';

String _greeting() {
  final h = DateTime.now().hour;
  if (h < 12) return 'Good morning,';
  if (h < 17) return 'Good afternoon,';
  return 'Good evening,';
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final data = context.watch<StudentData>();
    final scheme = Theme.of(context).colorScheme;

    final name = data.summary?['full_name']?.toString() ?? '';

    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_greeting(),
                style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurface.withAlpha(155),
                    fontWeight: FontWeight.normal,
                    height: 1.1)),
            Text(
              name.isNotEmpty ? name : 'EtlabPro',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, height: 1.2),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: context.watch<ThemeNotifier>().tooltip,
            icon: Icon(context.watch<ThemeNotifier>().icon),
            onPressed: () => context.read<ThemeNotifier>().toggle(),
          ),
          IconButton(
            tooltip: 'Profile',
            icon: const Icon(Icons.person_outline),
            onPressed: () => context.push('/profile'),
          ),
          IconButton(
            tooltip: 'Refresh all',
            icon: const Icon(Icons.sync_rounded),
            onPressed: () async {
              final roll = auth.rollNumber;
              if (roll == null) {
                ScaffoldMessenger.of(context)
                    .showSnackBar(const SnackBar(content: Text('Session not ready. Please login again.')));
                return;
              }
              HapticFeedback.selectionClick();
              final messenger = ScaffoldMessenger.of(context);
              messenger.hideCurrentSnackBar();
              messenger.showSnackBar(const SnackBar(content: Text('Refreshing all data...'), duration: Duration(milliseconds: 900)));
              await data.refreshAll(roll);
              if (!context.mounted) return;
              messenger.hideCurrentSnackBar();
              messenger.showSnackBar(const SnackBar(content: Text('All sections refreshed'), duration: Duration(milliseconds: 900)));
            },
          ),
          IconButton(
            tooltip: 'Logout',
            icon: Icon(Icons.logout, color: scheme.error),
            onPressed: () async {
              data.clear();
              await auth.logout();
              if (context.mounted) context.go('/login');
            },
          ),
        ],
      ),
      body: data.isLoading && data.profile == null
          ? _Shimmer()
          : data.error != null && data.profile == null
              ? _ErrorView(error: data.error!, auth: auth, data: data)
              : RefreshIndicator(
                  onRefresh: () async {
                    final roll = auth.rollNumber;
                    if (roll == null) {
                      ScaffoldMessenger.of(context)
                          .showSnackBar(const SnackBar(content: Text('Session not ready. Please login again.')));
                      return;
                    }
                    HapticFeedback.selectionClick();
                    final messenger = ScaffoldMessenger.of(context);
                    messenger.hideCurrentSnackBar();
                    messenger.showSnackBar(const SnackBar(content: Text('Refreshing all data...'), duration: Duration(milliseconds: 900)));
                    await data.refreshAll(roll);
                    if (!context.mounted) return;
                    messenger.hideCurrentSnackBar();
                    messenger.showSnackBar(const SnackBar(content: Text('All sections refreshed'), duration: Duration(milliseconds: 900)));
                  },
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    children: [
                      _DataLoadingCard(data: data),
                      if (data.isLoading || data.loadingSections.isNotEmpty) const SizedBox(height: 12),
                      _NextClassCard(timetable: data.timetable),
                      const SizedBox(height: 12),
                      _AttendanceSummaryCard(attendance: data.attendance, syncedAt: data.attendanceSynced),
                      const SizedBox(height: 12),
                      _ResultsOverviewCard(marks: data.marks, syncedAt: data.marksSynced),
                      const SizedBox(height: 12),
                      _ProfileInfoCard(summary: data.summary),
                    ],
                  ),
                ),
    );
  }
}

class _DataLoadingCard extends StatelessWidget {
  final StudentData data;
  const _DataLoadingCard({required this.data});

  @override
  Widget build(BuildContext context) {
    if (!data.isLoading && data.loadingSections.isEmpty) return const SizedBox();
    final scheme = Theme.of(context).colorScheme;
    const sections = <String>['Profile', 'Summary', 'Attendance', 'Marks', 'University Results', 'Timetable'];
    final loaded = <String>{
      if (data.profile != null) 'Profile',
      if (data.summary != null) 'Summary',
      if (data.attendance.isNotEmpty) 'Attendance',
      if (data.marks.isNotEmpty) 'Marks',
      if (data.universityResults.isNotEmpty) 'University Results',
      if (data.timetable.isNotEmpty) 'Timetable',
    };
    final active = data.loadingSections.toList()..sort();
    final current = active.isNotEmpty ? active.first : 'Finishing';
    final currentIcon = _sectionIcon(current);
    final totalSteps = sections.length;
    final currentStep = active.isNotEmpty
        ? (loaded.length + 1).clamp(1, totalSteps)
        : totalSteps;
    final progress = (currentStep / totalSteps).clamp(0, 1).toDouble();

    return _PurpleCard(
      icon: Icons.sync_rounded,
      title: 'Data Sync Status',
      subtitle: 'Step $currentStep/$totalSteps',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest.withAlpha(110),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: scheme.primary.withAlpha(50)),
            ),
            child: Column(
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 26,
                        color: scheme.primary,
                        backgroundColor: scheme.primary.withAlpha(35),
                      ),
                    ),
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: scheme.surface,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: scheme.primary.withAlpha(120)),
                      ),
                      alignment: Alignment.center,
                      child: Icon(currentIcon, size: 18, color: scheme.primary),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  active.isEmpty ? 'Applying latest updates...' : 'Loading: $current',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: scheme.onSurface, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  'Buffering step $currentStep of $totalSteps',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _sectionIcon(String label) {
    switch (label) {
      case 'Profile':
        return Icons.person_rounded;
      case 'Summary':
        return Icons.dashboard_rounded;
      case 'Attendance':
        return Icons.fact_check_rounded;
      case 'Marks':
        return Icons.grade_rounded;
      case 'University Results':
        return Icons.school_rounded;
      case 'Timetable':
        return Icons.calendar_today_rounded;
      default:
        return Icons.sync_rounded;
    }
  }
}

// ── Next Class Card ───────────────────────────────────────────────────

class _NextClassCard extends StatelessWidget {
  final List<dynamic> timetable;
  const _NextClassCard({required this.timetable});

  @override
  Widget build(BuildContext context) {
    if (timetable.isEmpty) return const SizedBox();
    final scheme = Theme.of(context).colorScheme;
    final info = getNextClassInfo(timetable);

    final String cardTitle = info.isClassOngoing
        ? 'Current Class'
        : info.showTomorrowSchedule
            ? 'Schedule'
            : 'Next Class';

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.primary.withAlpha(30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            decoration: BoxDecoration(
              color: scheme.primary,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Icon(Icons.school_rounded, size: 20, color: scheme.onPrimary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(cardTitle,
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: scheme.onPrimary)),
                ),
                Text(info.currentTime,
                    style: TextStyle(fontSize: 12, color: scheme.onPrimary.withAlpha(200), fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          Divider(height: 1, color: scheme.primary.withAlpha(180)),
          // Card body — two-pane layout
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _buildLeftPane(scheme, info)),
                VerticalDivider(width: 1, color: scheme.outlineVariant.withAlpha(70)),
                Expanded(child: _buildRightPane(scheme, info)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeftPane(ColorScheme scheme, NextClassResult info) {
    if (info.isClassOngoing && info.currentClass != null) {
      return _buildClassPane(scheme, info.currentClass!, isOngoing: true);
    }
    if (!info.isClassOngoing && info.nextClass != null) {
      return _buildClassPane(scheme, info.nextClass!, isOngoing: false);
    }
    // No classes left today
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(
              color: scheme.primaryContainer.withAlpha(80),
              borderRadius: BorderRadius.circular(26),
            ),
            alignment: Alignment.center,
            child: Icon(Icons.nights_stay_rounded, size: 26, color: scheme.primary),
          ),
          const SizedBox(height: 12),
          Text('No more classes today',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: scheme.onSurface),
              textAlign: TextAlign.center),
          const SizedBox(height: 4),
          Text('See you tomorrow!',
              style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildRightPane(ColorScheme scheme, NextClassResult info) {
    if (info.isClassOngoing) {
      if (info.nextClass != null) {
        // Ongoing + next class
        return _buildClassPane(scheme, info.nextClass!, isOngoing: false);
      }
      // Last class of day
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                color: scheme.primaryContainer.withAlpha(80),
                borderRadius: BorderRadius.circular(26),
              ),
              alignment: Alignment.center,
              child: Icon(Icons.nights_stay_rounded, size: 26, color: scheme.primary),
            ),
            const SizedBox(height: 12),
            Text('No more classes today',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: scheme.onSurface),
                textAlign: TextAlign.center),
            const SizedBox(height: 4),
            Text('See you tomorrow!',
                style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
                textAlign: TextAlign.center),
          ],
        ),
      );
    } else if (info.nextClass != null) {
      // Morning / Before classes start
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                color: scheme.primaryContainer.withAlpha(80),
                borderRadius: BorderRadius.circular(26),
              ),
              alignment: Alignment.center,
              child: Icon(Icons.wb_sunny_rounded, size: 26, color: scheme.primary),
            ),
            const SizedBox(height: 12),
            Text('Good morning!',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: scheme.onSurface),
                textAlign: TextAlign.center),
            const SizedBox(height: 4),
            Text('Classes start soon',
                style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
                textAlign: TextAlign.center),
          ],
        ),
      );
    }
    // Day done — show tomorrow's first class
    if (info.tomorrowFirstClass != null) {
      final c = info.tomorrowFirstClass!;
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: scheme.secondaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('TOMORROW', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                  color: scheme.onSecondaryContainer, letterSpacing: 0.4)),
            ),
            const SizedBox(height: 10),
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                color: scheme.primary.withAlpha(25),
                borderRadius: BorderRadius.circular(14),
              ),
              alignment: Alignment.center,
              child: Icon(Icons.menu_book_rounded, size: 22, color: scheme.primary),
            ),
            const SizedBox(height: 8),
            Text(c.subject,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.access_time_rounded, size: 11, color: scheme.onSurfaceVariant),
                const SizedBox(width: 3),
                Text(c.timing, style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
              ],
            ),
            if (c.teacher != null) ...[const SizedBox(height: 2),
              Text(c.teacher!, style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
                  textAlign: TextAlign.center)],
          ],
        ),
      );
    }
    // No tomorrow data either
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.calendar_today_rounded, size: 32, color: scheme.onSurfaceVariant.withAlpha(100)),
          const SizedBox(height: 8),
          Text('No classes found', style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildClassPane(ColorScheme scheme, ClassInfo c, {required bool isOngoing}) {
    final isFree = c.isFree || c.subject.toLowerCase().contains('free');
    final badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isOngoing ? Colors.green.shade600 : scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isOngoing) ...[Container(width: 6, height: 6,
              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
            const SizedBox(width: 4),
            const Text('LIVE', style: TextStyle(fontSize: 10, color: Colors.white,
                fontWeight: FontWeight.w800, letterSpacing: 0.5))],
          if (!isOngoing) Text('NEXT',
              style: TextStyle(fontSize: 10, color: scheme.onSecondaryContainer,
                  fontWeight: FontWeight.w800, letterSpacing: 0.5)),
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: scheme.primaryContainer.withAlpha(80),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.access_time_rounded, size: 12, color: scheme.onPrimaryContainer),
                const SizedBox(width: 4),
                Text(c.timing, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: scheme.onPrimaryContainer)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(isFree ? 'Free Period' : c.subject,
              style: TextStyle(
                  fontSize: 12.5, fontWeight: FontWeight.w700, height: 1.3,
                  color: isFree ? scheme.onSurfaceVariant : scheme.onSurface,
                  fontStyle: isFree ? FontStyle.italic : FontStyle.normal),
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis),
          if (!isFree && c.teacher != null) ...[
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.person_rounded, size: 12, color: scheme.onSurfaceVariant),
                const SizedBox(width: 4),
                Flexible(child: Text(c.teacher!, style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
                    textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis)),
              ],
            )
          ],
          const SizedBox(height: 16),
          badge,
        ],
      ),
    );
  }

}

// ── Attendance Summary Card ───────────────────────────────────────────

class _AttendanceSummaryCard extends StatelessWidget {
  final List<dynamic> attendance;
  final DateTime? syncedAt;
  const _AttendanceSummaryCard({required this.attendance, this.syncedAt});

  @override
  Widget build(BuildContext context) {
    if (attendance.isEmpty) return const SizedBox();
    final scheme = Theme.of(context).colorScheme;

    final sorted = List<dynamic>.from(attendance)
      ..sort((a, b) => ((a['percentage'] as num?) ?? 0).compareTo((b['percentage'] as num?) ?? 0));
    final lowest = sorted.take(3).toList();
    final total = (attendance.firstWhere(
          (r) => r['subject_code'] == null || r['subject_code'] == 'total',
          orElse: () => null,
        )?['percentage'] as num?)?.toDouble();
    final avg = attendance
            .map((r) => (r['percentage'] as num).toDouble())
            .reduce((a, b) => a + b) /
        attendance.length;
    final overallPct = total ?? avg;

    Color attColor() {
      if (overallPct >= 85) return Colors.green.shade600;
      if (overallPct >= 75) return Colors.amber.shade700;
      return Colors.red.shade600;
    }

    String attMsg() {
      if (overallPct >= 85) return 'Great! 🌟';
      if (overallPct >= 75) return 'Safe Zone 👍';
      return 'At Risk ⚠️';
    }

    return _PurpleCard(
      icon: Icons.fact_check_rounded,
      title: 'Attendance',
      subtitle: _syncedAgo(syncedAt),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left: lowest 3
          Expanded(
            flex: 6,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Lowest Attendance',
                    style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                ...lowest.map((r) {
                  final pct = (r['percentage'] as num).toDouble();
                  final color = pct < 75 ? Colors.red.shade600 : Colors.amber.shade700;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 7),
                    child: Row(
                      children: [
                        Expanded(
                            child: Text(r['raw_subject_name'] ?? r['subject_code'] ?? '—',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis)),
                        Text('${pct.toStringAsFixed(1)}%',
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: color)),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
          Container(width: 1, height: 90, color: scheme.outlineVariant.withAlpha(80),
              margin: const EdgeInsets.symmetric(horizontal: 12)),
          // Right: total attendance
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text('Overall', style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text('${overallPct.toStringAsFixed(1)}%',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: attColor(), height: 1),
                    textAlign: TextAlign.center),
                const SizedBox(height: 4),
                Text(attMsg(), style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant), textAlign: TextAlign.center),
                const SizedBox(height: 2),
                Text('${attendance.length} subjects',
                    style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant.withAlpha(160))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Results Overview Card ─────────────────────────────────────────────

class _ResultsOverviewCard extends StatelessWidget {
  final List<dynamic> marks;
  final DateTime? syncedAt;
  const _ResultsOverviewCard({required this.marks, this.syncedAt});

  @override
  Widget build(BuildContext context) {
    if (marks.isEmpty) return const SizedBox();
    final scheme = Theme.of(context).colorScheme;

    bool isSeriesOneOrTwo(dynamic r) {
      final type = (r['exam_type'] ?? '').toString().toLowerCase();
      final num = int.tryParse((r['exam_number'] ?? '').toString());
      final hasSeriesType = type.contains('series') || type.contains('cat');
      return hasSeriesType && (num == 1 || num == 2);
    }

    final seriesMarks = marks.where(isSeriesOneOrTwo).toList();
    final sourceMarks = seriesMarks.isNotEmpty ? seriesMarks : marks;

    // Compute percentage for each mark, sort lowest first
    final withPct = sourceMarks
        .where((r) => r['marks_obtained'] != null && r['max_marks'] != null && (r['max_marks'] as num) > 0)
        .map((r) {
      final pct = (r['marks_obtained'] as num) / (r['max_marks'] as num) * 100;
      return {'pct': pct, 'mark': r};
    }).toList()
      ..sort((a, b) => (a['pct'] as double).compareTo(b['pct'] as double));

    final worst3 = withPct.take(3).toList();

    final totalObtained = sourceMarks
        .where((r) => r['marks_obtained'] != null)
        .fold<double>(0, (s, r) => s + (r['marks_obtained'] as num).toDouble());
    final totalMax = sourceMarks
        .where((r) => r['max_marks'] != null)
        .fold<double>(0, (s, r) => s + (r['max_marks'] as num).toDouble());
    final overallPct = totalMax > 0 ? (totalObtained / totalMax * 100) : 0.0;

    Color perfColor() {
      if (overallPct >= 80) return Colors.green.shade600;
      if (overallPct >= 70) return Colors.amber.shade700;
      if (overallPct >= 60) return Colors.orange.shade600;
      return Colors.red.shade600;
    }

    String perfMsg() {
      if (overallPct >= 85) return 'Excellent! 🌟';
      if (overallPct >= 75) return 'Good Job! 👍';
      if (overallPct >= 65) return 'Average 📚';
      return 'Needs Work 💪';
    }

    return _PurpleCard(
      icon: Icons.emoji_events_rounded,
      title: 'Results Overview',
      subtitle: _syncedAgo(syncedAt),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left: overall
          Expanded(
            flex: 5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text('Overall', style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text('${overallPct.toStringAsFixed(1)}%',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: perfColor(), height: 1),
                    textAlign: TextAlign.center),
                const SizedBox(height: 4),
                Text(perfMsg(), style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant), textAlign: TextAlign.center),
                const SizedBox(height: 2),
                Text('${sourceMarks.length} exam${sourceMarks.length != 1 ? 's' : ''} (Series 1/2)',
                    style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant.withAlpha(160))),
              ],
            ),
          ),
          Container(width: 1, height: 80, color: scheme.outlineVariant.withAlpha(80), margin: const EdgeInsets.symmetric(horizontal: 12)),
          // Right: worst 3
          Expanded(
            flex: 6,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Needs Attention', style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                ...worst3.map((item) {
                  final r = item['mark'] as Map;
                  final pct = item['pct'] as double;
                  final pctColor = pct >= 50 ? Colors.amber.shade700 : Colors.red.shade600;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(r['subject_code'] ?? r['raw_subject_name'] ?? '—',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ),
                        const SizedBox(width: 6),
                        Text('${pct.toStringAsFixed(1)}%',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: pctColor)),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Profile Info Card ─────────────────────────────────────────────────

class _ProfileInfoCard extends StatelessWidget {
  final Map<String, dynamic>? summary;
  const _ProfileInfoCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    if (summary == null) return const SizedBox();
    final scheme = Theme.of(context).colorScheme;
    return _PurpleCard(
      icon: Icons.person_rounded,
      title: 'Profile Info',
      child: Column(
        children: [
          _row(Icons.badge_rounded, 'Name', summary!['full_name'], scheme),
          _row(Icons.school_rounded, 'Semester', _formatSemester(summary!['semester'] as String?), scheme),
          _row(Icons.numbers_rounded, 'SHR Number', summary!['roll_number'], scheme),
          _row(Icons.account_balance_rounded, 'Department', summary!['department'], scheme),
        ],
      ),
    );
  }

  String _formatSemester(String? semStr) {
    if (semStr == null || semStr.isEmpty) return '—';
    final match = RegExp(r'\d+').firstMatch(semStr);
    if (match != null) {
      int semNum = int.parse(match.group(0)!);
      semNum = (semNum + 1).clamp(1, 8);
      return 'S$semNum';
    }
    return semStr.replaceAll(RegExp(r'semester\s*', caseSensitive: false), 'S');
  }

  Widget _row(IconData icon, String label, dynamic value, ColorScheme scheme) {
    if (value == null) return const SizedBox();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: scheme.primaryContainer.withAlpha(80),
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 15, color: scheme.primary),
          ),
          const SizedBox(width: 10),
          SizedBox(
              width: 90,
              child: Text(label,
                  style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant, fontWeight: FontWeight.w500))),
          Expanded(
              child: Text('$value',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }
}

// ── Shared purple-tinted card wrapper ─────────────────────────────────

class _PurpleCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget child;
  const _PurpleCard({required this.icon, required this.title, this.subtitle, required this.child});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.primary.withAlpha(30)),
      ),
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
                Icon(icon, size: 18, color: scheme.onPrimary),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(title,
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: scheme.onPrimary))),
                if (subtitle != null)
                  Text(subtitle!,
                      style: TextStyle(fontSize: 11, color: scheme.onPrimary.withAlpha(200), fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          Divider(height: 1, color: scheme.primary),
          Padding(padding: const EdgeInsets.all(16), child: child),
        ],
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────

String? _syncedAgo(DateTime? dt) {
  if (dt == null) return null;
  final diff = DateTime.now().difference(dt);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return 'Synced ${diff.inMinutes}m ago';
  if (diff.inHours < 24) return 'Synced ${diff.inHours}h ago';
  return 'Synced ${diff.inDays}d ago';
}

// ── Shimmer ───────────────────────────────────────────────────────────

class _Shimmer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Shimmer.fromColors(
      baseColor: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
      highlightColor: isDark ? Colors.grey.shade700 : Colors.grey.shade100,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: List.generate(5, (i) => Container(
          height: i == 0 ? 100 : 70,
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
        )),
      ),
    );
  }
}

// ── Error view ────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  final String error;
  final AuthService auth;
  final StudentData data;
  const _ErrorView({required this.error, required this.auth, required this.data});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(error, textAlign: TextAlign.center),
            const SizedBox(height: 24),
            FilledButton.icon(
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
              onPressed: () {
                final roll = auth.rollNumber;
                if (roll == null) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(const SnackBar(content: Text('Session not ready. Please login again.')));
                  return;
                }
                data.loadAll(roll);
              },
            ),
          ],
        ),
      ),
    );
  }
}
