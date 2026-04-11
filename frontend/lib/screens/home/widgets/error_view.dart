import 'package:flutter/material.dart';
import '../../../services/auth_service.dart';
import '../../../services/student_data.dart';

class HomeErrorView extends StatelessWidget {
  final String error;
  final AuthService auth;
  final StudentData data;

  const HomeErrorView({super.key, required this.error, required this.auth, required this.data});

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
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Session not ready. Please login again.')));
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
