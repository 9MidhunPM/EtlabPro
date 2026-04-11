import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/student_data.dart';
import '../services/theme_notifier.dart';
import 'home/widgets/attendance_summary_card.dart';
import 'home/widgets/data_loading_card.dart';
import 'home/widgets/error_view.dart';
import 'home/widgets/next_class_card.dart';
import 'home/widgets/profile_info_card.dart';
import 'home/widgets/results_overview_card.dart';
import 'home/widgets/shimmer_placeholder.dart';

String _greeting() {
  final h = DateTime.now().hour;
  if (h < 12) return 'Good morning,';
  if (h < 17) return 'Good afternoon,';
  return 'Good evening,';
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _autoFetchLiveExtras());
  }

  Future<void> _autoFetchLiveExtras() async {
    if (!mounted) return;
    final auth = context.read<AuthService>();
    final data = context.read<StudentData>();
    final username = auth.username;
    final password = auth.password;
    if (username == null || password == null) return;
    try {
      await data.fetchLiveDutyLeaveAttendance(username, password);
    } catch (_) {}
    try {
      await data.fetchLiveMonthlyAttendance(username: username, password: password);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final data = context.watch<StudentData>();
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final topBarBg = isDark ? const Color(0xFF1C1031) : Colors.white;
    final topBarFg = isDark ? const Color(0xFFD8C9FF) : const Color(0xFF4B2880);

    final name = data.summary?['full_name']?.toString() ?? '';

    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        backgroundColor: topBarBg,
        foregroundColor: topBarFg,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(
            height: 1,
            thickness: 1.2,
            color: isDark ? scheme.outline : const Color(0xFF5A2E91),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_greeting(),
                style: TextStyle(
                    fontSize: 12,
                    color: topBarFg.withAlpha(185),
                    fontWeight: FontWeight.normal,
                    height: 1.1)),
            Text(
              name.isNotEmpty ? name : 'EtlabPro',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, height: 1.2, color: topBarFg),
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
          ? const HomeShimmer()
          : data.error != null && data.profile == null
            ? HomeErrorView(error: data.error!, auth: auth, data: data)
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
                    await data.refreshEverything(roll, username: auth.username, password: auth.password);
                    if (!context.mounted) return;
                    messenger.hideCurrentSnackBar();
                    messenger.showSnackBar(const SnackBar(content: Text('All sections refreshed'), duration: Duration(milliseconds: 900)));
                  },
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    children: [
                      DataLoadingCard(data: data),
                      if (data.isLoading || data.loadingSections.isNotEmpty) const SizedBox(height: 12),
                      _HomeNavCard(
                        onTap: () => context.go('/timetable'),
                        child: NextClassCard(timetable: data.timetable),
                      ),
                      const SizedBox(height: 12),
                      _HomeNavCard(
                        onTap: () => context.go('/attendance'),
                        child: AttendanceSummaryCard(attendance: data.attendance, syncedAt: data.attendanceSynced),
                      ),
                      const SizedBox(height: 12),
                      _HomeNavCard(
                        onTap: () => context.go('/marks'),
                        child: ResultsOverviewCard(marks: data.marks, syncedAt: data.marksSynced),
                      ),
                      const SizedBox(height: 12),
                      _HomeNavCard(
                        onTap: () => context.push('/profile'),
                        child: ProfileInfoCard(summary: data.summary),
                      ),
                    ],
                  ),
                ),
    );
  }
}

class _HomeNavCard extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;

  const _HomeNavCard({required this.child, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: child,
      ),
    );
  }
}

