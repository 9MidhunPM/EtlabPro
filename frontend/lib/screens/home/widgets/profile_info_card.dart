import 'package:flutter/material.dart';
import 'purple_card.dart';

class ProfileInfoCard extends StatelessWidget {
  final Map<String, dynamic>? summary;

  const ProfileInfoCard({super.key, required this.summary});

  @override
  Widget build(BuildContext context) {
    if (summary == null) return const SizedBox();
    final scheme = Theme.of(context).colorScheme;
    return PurpleCard(
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
          SizedBox(width: 90, child: Text(label, style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant, fontWeight: FontWeight.w500))),
          Expanded(
            child: Text(
              '$value',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
