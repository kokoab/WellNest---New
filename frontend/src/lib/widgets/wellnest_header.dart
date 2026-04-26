import 'package:flutter/material.dart';
import 'package:my_app/theme/app_theme.dart';
import 'package:my_app/widgets/georgia_pro_display_squish.dart';
import 'package:my_app/widgets/notifications_dropdown.dart';

/// Consistent header used on Discover, Feed, Saved, and Profile.
/// Logo + two-tone wordmark on the left; chat + notifications in soft pill actions.
class WellnestHeader extends StatelessWidget {
  static const double _logoHeight = 38.0;
  static const double _iconSize = 22.0;

  const WellnestHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Row(
            children: [
              Image.asset(
                'lib/assets/images/logo1.png',
                height: _logoHeight,
                fit: BoxFit.contain,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GeorgiaProDisplaySquish(
                  child: Text(
                    'Wellnest',
                    style: georgiaProDisplayStyle(
                      fontSize: 26,
                      color: AppColors.primaryGreen,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ),
            ],
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _HeaderActionPill(
              isDark: isDark,
              colorScheme: cs,
              onTap: () => Navigator.of(context).pushNamed('/conversations'),
              child: Icon(
                Icons.chat_bubble_outline_rounded,
                size: _iconSize,
                color: AppColors.primaryGreen,
              ),
            ),
            const SizedBox(width: 10),
            _HeaderActionPill(
              isDark: isDark,
              colorScheme: cs,
              child: NotificationsDropdown(
                iconColor: AppColors.accentOrange,
                child: Icon(
                  Icons.notifications_none_rounded,
                  color: AppColors.accentOrange,
                  size: _iconSize,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _HeaderActionPill extends StatelessWidget {
  const _HeaderActionPill({
    required this.isDark,
    required this.colorScheme,
    required this.child,
    this.onTap,
  });

  final bool isDark;
  final ColorScheme colorScheme;
  final Widget child;
  final VoidCallback? onTap;

  static const double _radius = 14.0;

  @override
  Widget build(BuildContext context) {
    final fill = isDark
        ? colorScheme.surfaceContainerHigh.withValues(alpha: 0.85)
        : colorScheme.surfaceContainerLowest;
    final borderColor =
        colorScheme.outline.withValues(alpha: isDark ? 0.28 : 0.14);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(_radius),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.06),
            blurRadius: isDark ? 12 : 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_radius),
        child: onTap != null
            ? Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onTap,
                  borderRadius: BorderRadius.circular(_radius),
                  splashColor: colorScheme.primary.withValues(alpha: 0.12),
                  highlightColor: colorScheme.primary.withValues(alpha: 0.06),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    child: child,
                  ),
                ),
              )
            : Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 4,
                  vertical: 2,
                ),
                child: child,
              ),
      ),
    );
  }
}
