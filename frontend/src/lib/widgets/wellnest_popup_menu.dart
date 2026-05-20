import 'package:flutter/material.dart';
import 'package:wellnest/theme/app_theme.dart';

/// Branded [PopupMenuItem] row: green icon by default, Helvetica label.
/// Pass [context] so label color follows light/dark surfaces (not [kBodyTextDark]).
PopupMenuItem<String> wellnestPopupMenuItem(
  BuildContext context, {
  required String value,
  required IconData icon,
  required String label,
  Color? iconColor,
  Color? textColor,
}) {
  final cs = Theme.of(context).colorScheme;
  return PopupMenuItem<String>(
    value: value,
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    height: 48,
    child: Row(
      children: [
        Icon(
          icon,
          size: 22,
          color: iconColor ?? kPrimaryGreen,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontFamily: kFontHelveticaNow,
              fontWeight: FontWeight.w600,
              fontSize: 15,
              color: textColor ?? cs.onSurface,
            ),
          ),
        ),
      ],
    ),
  );
}
