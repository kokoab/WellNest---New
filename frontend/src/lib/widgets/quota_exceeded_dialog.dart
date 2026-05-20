import 'package:flutter/material.dart';
import 'package:wellnest/theme/app_theme.dart';

/// Friendly modal shown when the user hits the daily assistant message limit.
class QuotaExceededDialog extends StatelessWidget {
  final String? retryAfter;

  const QuotaExceededDialog({super.key, this.retryAfter});

  static Future<void> show(BuildContext context, {String? retryAfter}) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => QuotaExceededDialog(retryAfter: retryAfter),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final resetCopy = retryAfter != null && retryAfter!.isNotEmpty
        ? 'Your quota resets $retryAfter.'
        : 'Your quota resets daily — come back tomorrow!';

    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.lg),
      ),
      icon: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: kAccentOrange.withOpacity(0.12),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.chat_bubble_outline,
          color: kAccentOrange,
          size: 28,
        ),
      ),
      title: Text(
        'Daily Limit Reached',
        style: textTheme.titleLarge?.copyWith(color: colorScheme.onSurface),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "You've used all 10 messages for today with the WellNest Assistant.",
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            resetCopy,
            textAlign: TextAlign.center,
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
      actions: [
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            style: FilledButton.styleFrom(backgroundColor: kPrimaryGreen),
            child: const Text('Got it'),
          ),
        ),
      ],
    );
  }
}
