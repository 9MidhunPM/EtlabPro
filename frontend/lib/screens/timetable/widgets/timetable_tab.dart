import 'package:flutter/material.dart';

class TimetableTab extends StatelessWidget {
  final List<dynamic> allSlots;
  final String selectedDay;
  final List<String> days;
  final ValueChanged<String> onDayChanged;
  final ColorScheme scheme;
  final Future<void> Function()? onRefresh;

  const TimetableTab({
    super.key,
    required this.allSlots,
    required this.selectedDay,
    required this.days,
    required this.onDayChanged,
    required this.scheme,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final daySlots = allSlots
        .where((s) {
          final dayStr = s['day_of_week'] as String?;
          return dayStr?.toLowerCase() == selectedDay.substring(0, 3).toLowerCase();
        })
        .toList()
      ..sort((a, b) => ((a['period_number'] as int?) ?? 0).compareTo((b['period_number'] as int?) ?? 0));

    return Column(
      children: [
        SizedBox(
          height: 56,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            itemCount: days.length,
            itemBuilder: (_, i) {
              final day = days[i];
              final selected = day == selectedDay;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(day.substring(0, 3)),
                  selected: selected,
                  onSelected: (_) => onDayChanged(day),
                  selectedColor: scheme.primaryContainer,
                  labelStyle: TextStyle(
                    fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                    color: selected ? scheme.onPrimaryContainer : scheme.onSurfaceVariant,
                  ),
                ),
              );
            },
          ),
        ),
        Expanded(
          child: daySlots.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.beach_access_rounded, size: 56, color: scheme.onSurfaceVariant.withAlpha(100)),
                      const SizedBox(height: 12),
                      Text('No classes on $selectedDay', style: TextStyle(color: scheme.onSurfaceVariant)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: onRefresh ?? () async {},
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                    itemCount: daySlots.length,
                    itemBuilder: (_, i) => SlotCard(slot: daySlots[i]),
                  ),
                ),
        ),
      ],
    );
  }
}

class SlotCard extends StatelessWidget {
  final dynamic slot;
  const SlotCard({super.key, required this.slot});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final period = slot['period_number'] ?? '—';
    final time = slot['period_time'] ?? '';
    final name = slot['raw_subject_name'] ?? slot['subject_code'] ?? 'Free';
    final code = slot['subject_code'] ?? '';
    final teacher = slot['teacher_name_raw'] ?? '';
    final classType = slot['class_type'] ?? '';
    final isFree = name == 'Free Period' || name == 'Free' || slot['subject_code'] == null;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outline),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isFree ? scheme.outlineVariant.withAlpha(60) : scheme.primaryContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Text('$period', style: TextStyle(fontWeight: FontWeight.bold, color: isFree ? scheme.onSurface : scheme.onPrimaryContainer)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: TextStyle(fontWeight: FontWeight.w600, color: isFree ? scheme.onSurface : scheme.onSurface)),
                if (!isFree && code.isNotEmpty) Text(code, style: TextStyle(fontSize: 12, color: scheme.onSurface)),
                if (!isFree && teacher.isNotEmpty) Text(teacher, style: TextStyle(fontSize: 12, color: scheme.onSurface)),
                if (classType.isNotEmpty) Text(classType, style: TextStyle(fontSize: 11, color: scheme.onSurface.withAlpha(160))),
              ],
            ),
          ),
          if (time.isNotEmpty) Text(time, style: TextStyle(fontSize: 11, color: scheme.onSurface)),
        ],
      ),
    );
  }
}
