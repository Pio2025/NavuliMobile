/// Formats a "YYYY-MM-DD HH:MM:SS" (or ISO) timestamp the same way the web
/// app's notice/announcement views do: relative for anything under a week,
/// an absolute date after that.
String timeAgo(dynamic raw) {
  final str = raw?.toString();
  if (str == null || str.isEmpty) return '';
  DateTime dt;
  try {
    dt = DateTime.parse(str);
  } catch (_) {
    return str;
  }
  final diff = DateTime.now().difference(dt);
  if (diff.inSeconds < 60) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
}
