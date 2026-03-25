import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/router.dart';
import 'core/theme.dart';
import 'services/auth_service.dart';
import 'services/connectivity_service.dart';
import 'services/lock_service.dart';
import 'services/student_data.dart';
import 'services/theme_notifier.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {
    // Keep startup resilient in case .env is missing in CI or release builds.
  }
  final auth = AuthService();
  await auth.restoreSession();
  final studentData = StudentData();
  await studentData.restoreFromLocal();
  final prefs = await SharedPreferences.getInstance();
  final saved = prefs.getString('themeMode') ?? 'dark';
  final themeMode = ThemeMode.values.firstWhere(
    (m) => m.name == saved, orElse: () => ThemeMode.dark);
  runApp(EtlabProApp(auth: auth, studentData: studentData, themeMode: themeMode));
}

class EtlabProApp extends StatelessWidget {
  final AuthService auth;
  final StudentData studentData;
  final ThemeMode themeMode;
  const EtlabProApp({super.key, required this.auth, required this.studentData, required this.themeMode});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: auth),
        ChangeNotifierProvider.value(value: studentData),
        ChangeNotifierProvider(create: (_) => ThemeNotifier(themeMode)),
        ChangeNotifierProvider(create: (_) => ConnectivityService()),
        ChangeNotifierProvider(create: (_) => LockService()),
      ],
      builder: (context, _) {
        final router = buildRouter(context.read<AuthService>());
        final themeNotifier = context.watch<ThemeNotifier>();
        return MaterialApp.router(
          title: 'EtlabPro',
          theme: lightTheme,
          darkTheme: darkTheme,
          themeMode: themeNotifier.mode,
          routerConfig: router,
          debugShowCheckedModeBanner: false,
          builder: (context, child) {
            final lock      = context.watch<LockService>();
            final authState = context.watch<AuthService>();
            if (lock.isLocked && authState.isLoggedIn) return _LockScreen();
            return child ?? const SizedBox();
          },
        );
      },
    );
  }
}

class _LockScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80, height: 80,
                decoration: BoxDecoration(
                  color: scheme.primary.withAlpha(20),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(Icons.lock_rounded, size: 40, color: scheme.primary),
              ),
              const SizedBox(height: 24),
              Text('EtlabPro is locked',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: scheme.onSurface)),
              const SizedBox(height: 8),
              Text('Authenticate to continue',
                  style: TextStyle(fontSize: 14, color: scheme.onSurfaceVariant)),
              const SizedBox(height: 32),
              FilledButton.icon(
                icon: const Icon(Icons.fingerprint_rounded),
                label: const Text('Unlock'),
                onPressed: () => context.read<LockService>().authenticate(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
