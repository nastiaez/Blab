String relativeTime(DateTime when, {DateTime? now}) {
  final n = now ?? DateTime.now();
  final diff = n.difference(when);
  if (diff.inSeconds < 60) return 'Now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m';
  if (diff.inHours < 24) return '${diff.inHours}h';
  if (diff.inDays < 7) return '${diff.inDays}d';
  return '${when.day}/${when.month}';
}
