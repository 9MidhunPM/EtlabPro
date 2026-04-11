import 'package:flutter/material.dart';

class ScreenErrorCard extends StatelessWidget {
  final String message;
  const ScreenErrorCard({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: scheme.error),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: scheme.onErrorContainer),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ScreenEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  const ScreenEmptyState({super.key, required this.icon, required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 64, color: scheme.onSurfaceVariant.withAlpha(100)),
          const SizedBox(height: 12),
          Text(title, style: TextStyle(color: scheme.onSurfaceVariant)),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(subtitle!, style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant.withAlpha(180))),
          ],
        ],
      ),
    );
  }
}

class ScreenSectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;
  final Widget? trailing;
  final Color? headerColor;
  final Color? borderColor;
  final EdgeInsetsGeometry bodyPadding;

  const ScreenSectionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.child,
    this.trailing,
    this.headerColor,
    this.borderColor,
    this.bodyPadding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final background = headerColor ?? scheme.primary;
    final foreground = ThemeData.estimateBrightnessForColor(background) == Brightness.dark
        ? Colors.white
        : Colors.white;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor ?? scheme.primary.withAlpha(30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
            decoration: BoxDecoration(
              color: background,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Icon(icon, size: 18, color: foreground),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: foreground),
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
          ),
          Padding(padding: bodyPadding, child: child),
        ],
      ),
    );
  }
}

class ScreenInfoRow extends StatelessWidget {
  final String label;
  final String value;
  final double labelWidth;

  const ScreenInfoRow({
    super.key,
    required this.label,
    required this.value,
    this.labelWidth = 130,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: labelWidth,
            child: Text(label, style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}