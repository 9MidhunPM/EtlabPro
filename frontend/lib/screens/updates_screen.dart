import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/student_data.dart';

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
                      Card(
                        color: scheme.errorContainer,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              Icon(Icons.error_outline, color: scheme.error),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _error!,
                                  style: TextStyle(color: scheme.onErrorContainer),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (updates != null) ...[
                      _buildSummaryCard(updates, scheme),
                      const SizedBox(height: 16),
                      _buildAttendanceUpdates(updates, scheme),
                      const SizedBox(height: 16),
                      _buildMarksUpdates(updates, scheme),
                      const SizedBox(height: 16),
                      _buildUniversityUpdates(updates, scheme),
                    ] else
                      Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.notifications_none,
                              size: 64,
                              color: scheme.onSurfaceVariant.withAlpha(100),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'No updates available',
                              style: TextStyle(color: scheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSummaryCard(Map<String, dynamic> updates, ColorScheme scheme) {
    final totalChanges = updates['total_changes'] as int? ?? 0;
    final attendanceChanges = (updates['attendance_changes'] as List? ?? []).length;
    final marksChanges = (updates['marks_changes'] as List? ?? []).length;
    final universityChanges = (updates['university_result_changes'] as List? ?? []).length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.new_releases, color: scheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Recent Changes',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 1.5,
              children: [
                _changeCard('Total\nChanges', totalChanges.toString(), Colors.purple, scheme),
                _changeCard('Attendance\nChanges', attendanceChanges.toString(), Colors.blue, scheme),
                _changeCard('Marks\nChanges', marksChanges.toString(), Colors.green, scheme),
                _changeCard('Results\nChanges', universityChanges.toString(), Colors.orange, scheme),
              ],
            ),
            if (updates['baseline_refreshed'] == true) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.green.withAlpha(20),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.withAlpha(60)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green, size: 16),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Baseline refreshed',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.green,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _changeCard(String label, String count, Color color, ColorScheme scheme) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            count,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceUpdates(Map<String, dynamic> updates, ColorScheme scheme) {
    final changes = (updates['attendance_changes'] as List? ?? []);
    if (changes.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.calendar_month, color: scheme.primary, size: 20),
            const SizedBox(width: 6),
            Text(
              'Attendance Updates',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                changes.length.toString(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: scheme.onPrimaryContainer,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Card(
          child: ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: changes.length,
            itemBuilder: (context, index) {
              final change = changes[index] as Map<String, dynamic>;
              return _updateTile(
                change,
                Colors.blue,
                scheme,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMarksUpdates(Map<String, dynamic> updates, ColorScheme scheme) {
    final changes = (updates['marks_changes'] as List? ?? []);
    if (changes.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.assessment, color: Colors.green, size: 20),
            const SizedBox(width: 6),
            Text(
              'Marks Updates',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.green.withAlpha(60),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                changes.length.toString(),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Card(
          child: ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: changes.length,
            itemBuilder: (context, index) {
              final change = changes[index] as Map<String, dynamic>;
              return _updateTile(
                change,
                Colors.green,
                scheme,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildUniversityUpdates(Map<String, dynamic> updates, ColorScheme scheme) {
    final changes = (updates['university_result_changes'] as List? ?? []);
    if (changes.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.school, color: Colors.orange, size: 20),
            const SizedBox(width: 6),
            Text(
              'University Results Updates',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.orange.withAlpha(60),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                changes.length.toString(),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Card(
          child: ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: changes.length,
            itemBuilder: (context, index) {
              final change = changes[index] as Map<String, dynamic>;
              return _updateTile(
                change,
                Colors.orange,
                scheme,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _updateTile(
    Map<String, dynamic> change,
    Color color,
    ColorScheme scheme,
  ) {
    String title = change['field']?.toString() ?? 'Unknown';
    String? oldValue = change['old_value']?.toString();
    String? newValue = change['new_value']?.toString();
    String? context = change['context']?.toString(); // e.g., subject code, exam type

    // Format display
    String subtitle = context ?? 'Value Changed';
    if (oldValue != null && newValue != null) {
      subtitle = '$oldValue → $newValue';
    } else if (newValue != null) {
      subtitle = 'Now: $newValue';
    }

    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color.withAlpha(30),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withAlpha(60)),
        ),
        child: Center(
          child: Icon(
            Icons.update,
            color: color,
            size: 20,
          ),
        ),
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        subtitle,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withAlpha(30),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          'New',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ),
    );
  }
}
