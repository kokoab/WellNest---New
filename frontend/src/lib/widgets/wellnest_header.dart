import 'package:flutter/material.dart';
import 'package:my_app/theme/app_theme.dart';
import 'package:my_app/widgets/notifications_dropdown.dart';

/// Consistent header used on Discover, Feed, Saved, and Profile.
/// Logo + "Wellnest" on the left, notification bell on the right.
class WellnestHeader extends StatelessWidget {
  /// Logo height and icon size for consistency across all pages.
  static const double logoHeight = 40.0;
  static const double iconSize = 28.0;
  static const double fontSize = 22.0;

  const WellnestHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('lib/assets/images/logo1.png', height: logoHeight),
            const SizedBox(width: 10),
            Text(
              'Wellnest',
              style: TextStyle(
                fontFamily: 'Recoleta',
                fontSize: fontSize,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryGreen,
              ),
            ),
          ],
        ),
        NotificationsDropdown(
          iconColor: AppColors.accentOrange,
          child: Icon(Icons.notifications, color: AppColors.accentOrange, size: iconSize),
        ),
      ],
    );
  }
}
