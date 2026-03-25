import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/student_data.dart';

class UniResultsScreen extends StatefulWidget {
  const UniResultsScreen({super.key});

  @override
  State<UniResultsScreen> createState() => _UniResultsScreenState();
}

class _UniResultsScreenState extends State<UniResultsScreen> with TickerProviderStateMixin {
  TabController? _tabCtrl;
  List<int> _semesterKeys = [];

  static const _ordinal = ['Ist', 'IInd', 'IIIrd', 'IVth', 'Vth', 'VIth', 'VIIth', 'VIIIth'];

  static int _extractSemester(dynamic row) {
    final semesterField = (row['semester'] ?? '').toString();
    final labelField = (row['semester_label'] ?? row['exam_name'] ?? '').toString();
    final combined = '$semesterField $labelField';
    final m = RegExp(r'([1-8])').firstMatch(combined);
    return m != null ? int.parse(m.group(1)!) : 99;
  }

  static String _tabLabel(int semesterKey) {
    if (semesterKey >= 1 && semesterKey <= 8) {
      return '${_ordinal[semesterKey - 1]} Semester';
    }
    return 'Other';
  }

  void _updateTabs(List<int> keys) {
    if (keys.length != _semesterKeys.length) {
      _tabCtrl?.dispose();
      _semesterKeys = List.from(keys);
      _tabCtrl = keys.isNotEmpty ? TabController(length: keys.length, vsync: this) : null;
    }
  }

  @override
  void dispose() {
    _tabCtrl?.dispose();
    super.dispose();
  }

  Future<void> _refreshUniResultsWithFeedback() async {
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
    messenger.showSnackBar(const SnackBar(content: Text('Refreshing university results...'), duration: Duration(milliseconds: 900)));
    await data.refreshUniResults(roll);
    if (!mounted) return;
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(const SnackBar(content: Text('University results updated'), duration: Duration(milliseconds: 900)));
  }

  static Color _gradeColor(String? grade) {
    final g = grade?.toUpperCase() ?? '';
    if (['S', 'A+', 'A'].contains(g)) return Colors.green.shade600;
    if (['B+', 'B', 'B-'].contains(g)) return Colors.blue.shade600;
    if (['C+', 'C', 'C-'].contains(g)) return Colors.amber.shade700;
    if (['D+', 'D', 'F'].contains(g)) return Colors.red.shade600;
    if (g == 'P') return Colors.purple.shade600;
    return Colors.grey;
  }

  static Color _statusColor(String? status) {
    return (status?.toLowerCase().contains('pass') ?? false) ? Colors.green.shade600 : Colors.red.shade600;
  }

  @override
  Widget build(BuildContext context) {
    final data = context.watch<StudentData>();
    final rows = data.universityResults;
    final scheme = Theme.of(context).colorScheme;

    final Map<int, List> groups = {};
    for (final r in rows) {
      final semester = _extractSemester(r);
      groups.putIfAbsent(semester, () => []).add(r);
    }
    final keys = groups.keys.toList()..sort();
    _updateTabs(keys);

    if (rows.isEmpty || _tabCtrl == null) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.school_outlined, size: 56, color: scheme.onSurfaceVariant.withAlpha(100)),
                const SizedBox(height: 12),
                Text('No university results', style: TextStyle(color: scheme.onSurfaceVariant)),
              ],
            ),
          ),
        ),
      );
    }

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
                      isScrollable: true,
                      tabAlignment: TabAlignment.start,
                      labelColor: scheme.onPrimary,
                      unselectedLabelColor: scheme.onPrimary.withAlpha(160),
                      indicatorColor: scheme.onPrimary,
                      dividerColor: Colors.transparent,
                      tabs: keys
                          .map((k) => Tab(child: Text(_tabLabel(k), style: const TextStyle(fontSize: 12))))
                          .toList(),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Refresh results',
                    icon: Icon(Icons.refresh_rounded, color: scheme.onPrimary),
                    onPressed: _refreshUniResultsWithFeedback,
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabCtrl!,
              children: keys
                  .map((k) => _SemesterPage(
                        rows: groups[k]!,
                        gradeColor: _gradeColor,
                        statusColor: _statusColor,
                        onRefresh: _refreshUniResultsWithFeedback,
                      ))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _SemesterPage extends StatelessWidget {
  final List rows;
  final Color Function(String?) gradeColor;
  final Color Function(String?) statusColor;
  final Future<void> Function()? onRefresh;
  const _SemesterPage({required this.rows, required this.gradeColor, required this.statusColor, this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final sgpa = rows.isNotEmpty ? rows.last['sgpa'] : null;
    final cgpa = rows.isNotEmpty ? rows.last['cgpa'] : null;

    return RefreshIndicator(
      onRefresh: onRefresh ?? () async {},
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
        if (sgpa != null || cgpa != null) ...[
          Row(
            children: [
              if (sgpa != null) _Chip('SGPA ${(sgpa as num).toStringAsFixed(2)}', scheme.primaryContainer, scheme.onPrimaryContainer),
              if (sgpa != null && cgpa != null) const SizedBox(width: 8),
              if (cgpa != null) _Chip('CGPA ${(cgpa as num).toStringAsFixed(2)}', scheme.secondaryContainer, scheme.onSecondaryContainer),
            ],
          ),
          const SizedBox(height: 12),
        ],
        Container(
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: scheme.primary.withAlpha(30)),
          ),
          child: Column(
            children: rows.asMap().entries.map((entry) {
              final r = entry.value;
              final grade = r['grade'] ?? '—';
              final status = (r['result_status'] ?? '').toString();
              final credit = r['credit'];
              final slot = r['slot'] ?? '';
              final gc = gradeColor(grade);
              final sc = statusColor(status);

              return Column(
                children: [
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                    title: Text(r['subject_name'] ?? r['subject_code'] ?? '—',
                        style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text(
                      '${r['subject_code'] ?? ''}${slot.toString().isNotEmpty ? '  •  $slot' : ''}${credit != null ? '  •  $credit cr' : ''}',
                      style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(grade, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: gc)),
                        Text(status, style: TextStyle(fontSize: 11, color: sc)),
                      ],
                    ),
                  ),
                  if (entry.key < rows.length - 1)
                    Divider(height: 1, indent: 16, endIndent: 16, color: scheme.outlineVariant.withAlpha(80)),
                ],
              );
            }).toList(),
          ),
        ),
      ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String text;
  final Color bg, fg;
  const _Chip(this.text, this.bg, this.fg);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(text, style: TextStyle(fontSize: 11, color: fg, fontWeight: FontWeight.w500)),
    );
  }
}
