import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/student_data.dart';
import 'updates/widgets/updates_sections.dart';
import '../widgets/screen_parts.dart';

class UpdatesScreen extends StatefulWidget {
  const UpdatesScreen({super.key});

  @override
  State<UpdatesScreen> createState() => _UpdatesScreenState();
}

class _UpdatesScreenState extends State<UpdatesScreen> {
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchUpdates();
  }

  Future<void> _fetchUpdates() async {
    final auth = context.read<AuthService>();
    final data = context.read<StudentData>();

    if (auth.username == null || auth.password == null) return;

    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });
      await data.fetchLiveUpdates(
        username: auth.username!,
        password: auth.password!,
      );
    } catch (e) {
      setState(() => _error = 'Failed to fetch updates: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = context.watch<StudentData>();
    final scheme = Theme.of(context).colorScheme;
    final updates = data.updates;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Updates'),
        elevation: 0,
        actions: [
          if (!_isLoading)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _fetchUpdates,
            ),
        ],
      ),
      body: _isLoading && updates == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchUpdates,
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
                    if (updates != null)
                      UpdatesSections(updates: updates)
                    else
                      const ScreenEmptyState(
                        icon: Icons.notifications_none,
                        title: 'No updates available',
                      ),
                  ],
                ),
              ),
            ),
    );
  }
}
