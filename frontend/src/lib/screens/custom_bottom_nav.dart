import 'package:flutter/material.dart';
import 'package:my_app/theme/app_spacing.dart';
import 'package:my_app/theme/app_theme.dart';

/// Solid [BottomAppBar] with center notch for a docked FAB ([CircularNotchedRectangle]).
/// Pair [fab] + [fabLocation] with the root [Scaffold].
class CustomBottomNav extends StatelessWidget {
  /// Standard FAB diameter + notch clearance.
  static const double fabClearanceWidth = 56;

  static const FloatingActionButtonLocation fabLocation =
      FloatingActionButtonLocation.centerDocked;

  static Widget fab({required VoidCallback onPressed}) {
    return FloatingActionButton(
      onPressed: onPressed,
      tooltip: 'Create',
      child: const Icon(Icons.add_rounded, size: 28),
    );
  }

  final int currentIndex;
  final ValueChanged<int> onTap;

  const CustomBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return BottomAppBar(
      shape: const CircularNotchedRectangle(),
      notchMargin: 8,
      elevation: theme.bottomAppBarTheme.elevation ?? 8,
      shadowColor:
          theme.bottomAppBarTheme.shadowColor ??
          Colors.black.withValues(alpha: 0.08),
      surfaceTintColor: Colors.transparent,
      color: scheme.brightness == Brightness.dark
          ? scheme.surface
          : Colors.white,
      padding: EdgeInsets.zero,
      height: theme.bottomAppBarTheme.height ?? 64,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        child: Row(
          children: [
            Expanded(
              child: _DockNavItem(
                icon: Icons.grid_view_rounded,
                label: 'Discover',
                selected: currentIndex == 0,
                onTap: () => onTap(0),
              ),
            ),
            Expanded(
              child: _DockNavItem(
                icon: Icons.dynamic_feed_rounded,
                label: 'Feed',
                selected: currentIndex == 1,
                onTap: () => onTap(1),
              ),
            ),
            const SizedBox(width: fabClearanceWidth),
            Expanded(
              child: _DockNavItem(
                icon: Icons.bookmark_rounded,
                label: 'Saved',
                selected: currentIndex == 2,
                onTap: () => onTap(2),
              ),
            ),
            Expanded(
              child: _DockNavItem(
                icon: Icons.person_rounded,
                label: 'Profile',
                selected: currentIndex == 3,
                onTap: () => onTap(3),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DockNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _DockNavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final active = AppColors.primaryGreen;
    final inactive = AppColors.primaryGreen.withValues(alpha: 0.42);
    final color = selected ? active : inactive;

    return Semantics(
      button: true,
      label: label,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.md),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 24, color: color),
              AppSpacing.gapV4,
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: kFontHelveticaNow,
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
