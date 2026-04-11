import 'package:flutter/material.dart';
import '../../../utils/next_class_analysis.dart';

class NextClassCard extends StatelessWidget {
  final List<dynamic> timetable;

  const NextClassCard({super.key, required this.timetable});

  @override
  Widget build(BuildContext context) {
    if (timetable.isEmpty) return const SizedBox();
    final scheme = Theme.of(context).colorScheme;
    final info = getNextClassInfo(timetable);

    final String cardTitle = info.isClassOngoing
        ? 'Current Class'
        : info.showTomorrowSchedule
            ? 'Schedule'
            : 'Next Class';

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.primary.withAlpha(30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            decoration: BoxDecoration(
              color: scheme.primary,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Icon(Icons.school_rounded, size: 20, color: scheme.onPrimary),
                const SizedBox(width: 10),
                Expanded(child: Text(cardTitle, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: scheme.onPrimary))),
                Text(info.currentTime, style: TextStyle(fontSize: 12, color: scheme.onPrimary.withAlpha(200), fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          Divider(height: 1, color: scheme.primary.withAlpha(180)),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _pane(scheme, info, left: true)),
                VerticalDivider(width: 1, color: scheme.outlineVariant.withAlpha(70)),
                Expanded(child: _pane(scheme, info, left: false)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _pane(ColorScheme scheme, NextClassResult info, {required bool left}) {
    if (left) {
      if (info.isClassOngoing && info.currentClass != null) {
        return _classPane(scheme, info.currentClass!, isOngoing: true);
      }
      if (!info.isClassOngoing && info.nextClass != null) {
        return _classPane(scheme, info.nextClass!, isOngoing: false);
      }
      return _messagePane(scheme, Icons.nights_stay_rounded, 'No more classes today', 'See you tomorrow!');
    }

    if (info.isClassOngoing) {
      if (info.nextClass != null) {
        return _classPane(scheme, info.nextClass!, isOngoing: false);
      }
      return _messagePane(scheme, Icons.nights_stay_rounded, 'No more classes today', 'See you tomorrow!');
    }

    if (info.nextClass != null) {
      return _messagePane(scheme, Icons.wb_sunny_rounded, 'Good morning!', 'Classes start soon');
    }

    if (info.tomorrowFirstClass != null) {
      final c = info.tomorrowFirstClass!;
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: scheme.secondaryContainer, borderRadius: BorderRadius.circular(8)),
              child: Text('TOMORROW', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: scheme.onSecondaryContainer, letterSpacing: 0.4)),
            ),
            const SizedBox(height: 10),
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(color: scheme.primary.withAlpha(25), borderRadius: BorderRadius.circular(14)),
              alignment: Alignment.center,
              child: Icon(Icons.menu_book_rounded, size: 22, color: scheme.primary),
            ),
            const SizedBox(height: 8),
            Text(c.subject, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700), textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.access_time_rounded, size: 11, color: scheme.onSurfaceVariant),
                const SizedBox(width: 3),
                Text(c.timing, style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
              ],
            ),
            if (c.teacher != null) ...[
              const SizedBox(height: 2),
              Text(c.teacher!, style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant), textAlign: TextAlign.center),
            ],
          ],
        ),
      );
    }

    return _messagePane(scheme, Icons.calendar_today_rounded, 'No classes found', null);
  }

  Widget _messagePane(ColorScheme scheme, IconData icon, String title, String? subtitle) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: scheme.primaryContainer.withAlpha(80),
              borderRadius: BorderRadius.circular(26),
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 26, color: scheme.primary),
          ),
          const SizedBox(height: 12),
          Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: scheme.onSurface), textAlign: TextAlign.center),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(subtitle, style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant), textAlign: TextAlign.center),
          ],
        ],
      ),
    );
  }

  Widget _classPane(ColorScheme scheme, ClassInfo c, {required bool isOngoing}) {
    final isFree = c.isFree || c.subject.toLowerCase().contains('free');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(color: scheme.primaryContainer.withAlpha(80), borderRadius: BorderRadius.circular(8)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.access_time_rounded, size: 12, color: scheme.onPrimaryContainer),
                const SizedBox(width: 4),
                Text(c.timing, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: scheme.onPrimaryContainer)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            isFree ? 'Free Period' : c.subject,
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, height: 1.3, color: isFree ? scheme.onSurfaceVariant : scheme.onSurface, fontStyle: isFree ? FontStyle.italic : FontStyle.normal),
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          if (!isFree && c.teacher != null) ...[
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.person_rounded, size: 12, color: scheme.onSurfaceVariant),
                const SizedBox(width: 4),
                Flexible(child: Text(c.teacher!, style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis)),
              ],
            ),
          ],
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: isOngoing ? Colors.green.shade600 : scheme.secondaryContainer, borderRadius: BorderRadius.circular(8)),
            child: Text(
              isOngoing ? 'LIVE' : 'NEXT',
              style: TextStyle(fontSize: 10, color: isOngoing ? Colors.white : scheme.onSecondaryContainer, fontWeight: FontWeight.w800, letterSpacing: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}
