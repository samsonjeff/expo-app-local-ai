import 'package:flutter/material.dart';

/// Centralized, premium floating notification system for the application.
/// Provides consistent rounded floating toast/snackbar styling across all screens.
class AppNotification {
  static void showSuccess(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 2),
    double bottomMargin = 84,
  }) {
    _show(
      context: context,
      message: message,
      icon: Icons.check_circle_rounded,
      iconColor: const Color(0xFF22C55E),
      duration: duration,
      bottomMargin: bottomMargin,
    );
  }

  static void showError(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
    double bottomMargin = 84,
  }) {
    _show(
      context: context,
      message: message,
      icon: Icons.error_outline_rounded,
      iconColor: const Color(0xFFEF4444),
      duration: duration,
      bottomMargin: bottomMargin,
    );
  }

  static void showWarning(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 2),
    double bottomMargin = 84,
  }) {
    _show(
      context: context,
      message: message,
      icon: Icons.warning_amber_rounded,
      iconColor: const Color(0xFFF59E0B),
      duration: duration,
      bottomMargin: bottomMargin,
    );
  }

  static void showInfo(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 2),
    double bottomMargin = 84,
  }) {
    _show(
      context: context,
      message: message,
      icon: Icons.info_outline_rounded,
      iconColor: const Color(0xFF38BDF8),
      duration: duration,
      bottomMargin: bottomMargin,
    );
  }

  static void _show({
    required BuildContext context,
    required String message,
    required IconData icon,
    required Color iconColor,
    required Duration duration,
    required double bottomMargin,
  }) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;

    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        elevation: 6,
        backgroundColor: const Color(0xFF1E293B),
        margin: EdgeInsets.only(
          bottom: bottomMargin,
          left: 20,
          right: 20,
        ),
        duration: duration,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: Color(0xFF334155), width: 1),
        ),
        content: Row(
          children: [
            Icon(icon, color: iconColor, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  letterSpacing: -0.1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
