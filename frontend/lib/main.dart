import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/router.dart';
import 'core/theme.dart';
import 'services/auth_service.dart';
import 'services/connectivity_service.dart';
import 'services/student_data.dart';
import 'services/theme_notifier.dart';
import 'widgets/latest_version_guard.dart';

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
            return LatestVersionGuard(
              child: child ?? const SizedBox(),
            );
          },
        );
      },
    );
  }
}


