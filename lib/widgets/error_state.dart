import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Strips the redundant `Exception: ` prefix `'$e'` leaves behind so screens
/// can show a clean, human-readable message instead of raw Dart exception text.
String friendlyErrorMessage(Object error) {
  var msg = error.toString();
  if (msg.startsWith('Exception: ')) {
    msg = msg.substring('Exception: '.length);
  }
  return msg.isEmpty ? 'Something went wrong. Please try again.' : msg;
}

/// A consistent, presentable full-body error/empty state — replaces bare
/// `Center(child: Text('Failed to load X: $_error'))` blocks across the app.
class ErrorState extends StatelessWidget {
  final Object error;
  final VoidCallback? onRetry;
  final String retryLabel;
  final EdgeInsetsGeometry padding;

  const ErrorState({
    super.key,
    required this.error,
    this.onRetry,
    this.retryLabel = 'Try Again',
    this.padding = const EdgeInsets.fromLTRB(28, 90, 28, 28),
  });

  ({IconData icon, Color color, String title}) _classify(String msg) {
    final lower = msg.toLowerCase();
    if (lower.contains('do not have access') || lower.contains('permission') || lower.contains('not authorized') || lower.contains('forbidden')) {
      return (icon: Icons.lock_outline_rounded, color: AppColors.warning, title: 'Access Restricted');
    }
    if (lower.contains('not found') || lower.contains('no longer exists')) {
      return (icon: Icons.search_off_rounded, color: AppColors.secondary, title: 'Not Found');
    }
    if (lower.contains('socket') || lower.contains('network') || lower.contains('timed out') || lower.contains('connection')) {
      return (icon: Icons.wifi_off_rounded, color: AppColors.danger, title: 'Connection Problem');
    }
    return (icon: Icons.error_outline_rounded, color: AppColors.danger, title: 'Something Went Wrong');
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final msg = friendlyErrorMessage(error);
    final c = _classify(msg);

    return Center(
      child: SingleChildScrollView(
        padding: padding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(color: c.color.withValues(alpha: 0.12), shape: BoxShape.circle),
              child: Icon(c.icon, color: c.color, size: 34),
            ),
            const SizedBox(height: 18),
            Text(c.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(
              msg,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant, height: 1.4),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: Text(retryLabel),
                style: OutlinedButton.styleFrom(
                  foregroundColor: c.color,
                  side: BorderSide(color: c.color.withValues(alpha: 0.4)),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
