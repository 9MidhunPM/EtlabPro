String? syncedAgo(DateTime? dt) {
  if (dt == null) return null;
  final diff = DateTime.now().difference(dt);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return 'Synced ${diff.inMinutes}m ago';
  if (diff.inHours < 24) return 'Synced ${diff.inHours}h ago';
  return 'Synced ${diff.inDays}d ago';
}
