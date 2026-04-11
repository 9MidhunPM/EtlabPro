import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../services/connectivity_service.dart';

class AppShell extends StatelessWidget {
  final StatefulNavigationShell navigationShell;
  const AppShell({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context) {
    final isOnline = context.watch<ConnectivityService>().isOnline;
    return Scaffold(
      body: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 350),
            height: isOnline ? 0 : 34,
            color: Colors.red.shade700,
            child: isOnline
                ? null
                : SafeArea(
                    bottom: false,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.wifi_off_rounded, size: 14, color: Colors.white),
                        const SizedBox(width: 6),
                        const Text('No internet connection',
                            style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
          ),
          Expanded(child: navigationShell),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (i) => navigationShell.goBranch(i, initialLocation: i == navigationShell.currentIndex),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined),          selectedIcon: Icon(Icons.home_rounded),          label: 'Home'),
          NavigationDestination(icon: Icon(Icons.fact_check_outlined),    selectedIcon: Icon(Icons.fact_check_rounded),    label: 'Attendance'),
          NavigationDestination(icon: Icon(Icons.grade_outlined),         selectedIcon: Icon(Icons.grade_rounded),         label: 'Results'),
          NavigationDestination(icon: Icon(Icons.school_outlined),        selectedIcon: Icon(Icons.school_rounded),        label: 'End Sem'),
          NavigationDestination(icon: Icon(Icons.calendar_today_outlined),selectedIcon: Icon(Icons.calendar_today_rounded),label: 'Schedule'),
        ],
      ),
    );
  }
}
