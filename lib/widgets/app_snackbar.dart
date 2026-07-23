import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Consistent, presentable flash messages for the whole app — replaces bare
/// `ScaffoldMessenger.showSnackBar(SnackBar(content: Text(...)))` calls with a
/// floating, icon-led, colour-coded snackbar.
class AppSnackbar {
  AppSnackbar._();

  static void success(BuildContext context, String message) => _show(
        context,
        message: message,
        icon: Icons.check_circle_rounded,
        color: AppColors.success,
      );

  static void error(BuildContext context, String message) => _show(
        context,
        message: message,
        icon: Icons.error_rounded,
        color: AppColors.danger,
      );

  static void info(BuildContext context, String message) => _show(
        context,
        message: message,
        icon: Icons.info_rounded,
        color: AppColors.primary,
      );

  static void warning(BuildContext context, String message) => _show(
        context,
        message: message,
        icon: Icons.warning_rounded,
        color: AppColors.warning,
        iconColor: const Color(0xFF7A5B00),
        textColor: const Color(0xFF7A5B00),
      );

  static void _show(
    BuildContext context, {
    required String message,
    required IconData icon,
    required Color color,
    Color? iconColor,
    Color? textColor,
  }) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: color.withValues(alpha: 0.14),
        elevation: 0,
        margin: const EdgeInsets.all(14),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: color.withValues(alpha: 0.35)),
        ),
        duration: const Duration(seconds: 4),
        content: Row(
          children: [
            Icon(icon, color: iconColor ?? color, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: textColor ?? color, fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
