import 'package:flutter/material.dart';
import 'package:my_app/theme/app_spacing.dart';
import 'package:my_app/theme/app_theme.dart';

class CustomBottomNav extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const CustomBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: 64,
      margin: const EdgeInsets.only(left: AppSpacing.md, right: AppSpacing.md, bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.08),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Expanded(child: _NavItem(icon: Icons.grid_view_rounded, label: 'Discover', active: currentIndex == 0, onTap: () => onTap(0))),
            Expanded(child: _NavItem(icon: Icons.dynamic_feed_rounded, label: 'Feed', active: currentIndex == 1, onTap: () => onTap(1))),
            Expanded(child: _NavItem(icon: Icons.bookmark_rounded, label: 'Saved recipes', active: currentIndex == 2, onTap: () => onTap(2))),
            Expanded(child: _NavItem(icon: Icons.person_rounded, label: 'Profile', active: currentIndex == 3, onTap: () => onTap(3))),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const activeColor = AppColors.primaryGreen;
    final inactiveColor = AppColors.primaryGreen.withValues(alpha: 0.5);
    return Semantics(
      button: true,
      label: label,
      selected: active,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: const BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.all(Radius.circular(24)),
          ),
          child: Icon(
            icon,
            size: 26,
            color: active ? activeColor : inactiveColor,
          ),
        ),
      ),
    ),
    );
  }
}