import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/auth_service.dart';
import '../screens/app_shell.dart';
import '../screens/login_screen.dart';
import '../screens/home_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/attendance_screen.dart';
import '../screens/marks_screen.dart';
import '../screens/uni_results_screen.dart';
import '../screens/timetable_screen.dart';
import '../screens/monthly_attendance_screen.dart';
import '../screens/updates_screen.dart';

GoRouter buildRouter(AuthService auth) {
  return GoRouter(
    initialLocation: '/login',
    redirect: (context, state) {
      final loggedIn = auth.isLoggedIn;
      final onLogin  = state.matchedLocation == '/login';
      if (!loggedIn && !onLogin) return '/login';
      if (loggedIn  &&  onLogin) return '/home';
      return null;
    },
    refreshListenable: auth,
    routes: [
      GoRoute(
        path: '/login',
        pageBuilder: (ctx, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const LoginScreen(),
          transitionsBuilder: (ctx, anim, secondAnim, child) =>
              FadeTransition(opacity: anim, child: child),
        ),
      ),
      StatefulShellRoute.indexedStack(
        builder: (ctx, state, shell) => AppShell(navigationShell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: '/home', builder: (ctx, _) => const HomeScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/attendance', builder: (ctx, _) => const AttendanceScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/monthly-attendance', builder: (ctx, _) => const MonthlyAttendanceScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/marks', builder: (ctx, _) => const MarksScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/updates', builder: (ctx, _) => const UpdatesScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/results', builder: (ctx, _) => const UniResultsScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/timetable', builder: (ctx, _) => const TimetableScreen()),
          ]),
        ],
      ),
      // Standalone push routes (not in bottom nav)
      GoRoute(
        path: '/profile',
        pageBuilder: (ctx, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const ProfileScreen(),
          transitionsBuilder: (ctx, anim, secondAnim, child) =>
              SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(1, 0),
                  end: Offset.zero,
                ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
                child: child,
              ),
        ),
      ),
    ],
  );
}
