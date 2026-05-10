part of 'package:my_app/screens/admin_dashboard.dart';

class _Sidebar extends StatelessWidget {
  final bool collapsed;
  final _Section currentSection;
  final ValueChanged<_Section> onSectionChanged;
  final VoidCallback onToggleCollapsed;
  final VoidCallback onLogout;
  final ThemeData theme;

  const _Sidebar({
    required this.collapsed,
    required this.currentSection,
    required this.onSectionChanged,
    required this.onToggleCollapsed,
    required this.onLogout,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = theme.brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF161616) : Colors.white;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.black.withValues(alpha: 0.07);
    final width = collapsed ? _kSidebarCollapsedWidth : _kSidebarWidth;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeInOut,
      width: width,
      decoration: BoxDecoration(
        color: bg,
        border: Border(right: BorderSide(color: borderColor, width: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: _kTopBarHeight,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: collapsed ? 12 : 16),
              child: Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Image.asset(
                      'lib/assets/images/logo1.png',
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: kPrimaryGreen,
                        child: const Icon(
                          Icons.eco_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  ),
                  if (!collapsed) ...[
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'WellNest',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurface,
                              letterSpacing: -0.3,
                            ),
                          ),
                          Text(
                            'Admin Console',
                            style: TextStyle(
                              fontSize: 10,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    InkWell(
                      onTap: onToggleCollapsed,
                      borderRadius: BorderRadius.circular(6),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(
                          Icons.chevron_left_rounded,
                          size: 18,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ] else ...[
                    const Spacer(),
                    InkWell(
                      onTap: onToggleCollapsed,
                      borderRadius: BorderRadius.circular(6),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(
                          Icons.chevron_right_rounded,
                          size: 18,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          Divider(height: 0.5, color: borderColor),
          const SizedBox(height: 12),
          if (!collapsed)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
              child: Text(
                'MAIN',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1,
                  color: theme.colorScheme.onSurfaceVariant.withValues(
                    alpha: 0.5,
                  ),
                ),
              ),
            ),
          _NavItem(
            section: _Section.overview,
            currentSection: currentSection,
            icon: Icons.grid_view_rounded,
            label: 'Overview',
            collapsed: collapsed,
            onTap: onSectionChanged,
            theme: theme,
          ),
          _NavItem(
            section: _Section.analytics,
            currentSection: currentSection,
            icon: Icons.insights_outlined,
            label: 'Analytics',
            collapsed: collapsed,
            onTap: onSectionChanged,
            theme: theme,
          ),
          _NavItem(
            section: _Section.users,
            currentSection: currentSection,
            icon: Icons.people_outline_rounded,
            label: 'Users',
            collapsed: collapsed,
            onTap: onSectionChanged,
            theme: theme,
          ),
          _NavItem(
            section: _Section.recipes,
            currentSection: currentSection,
            icon: Icons.restaurant_menu_outlined,
            label: 'Recipes',
            collapsed: collapsed,
            onTap: onSectionChanged,
            theme: theme,
          ),
          _NavItem(
            section: _Section.moderation,
            currentSection: currentSection,
            icon: Icons.shield_outlined,
            label: 'Moderation',
            collapsed: collapsed,
            onTap: onSectionChanged,
            theme: theme,
          ),
          _NavItem(
            section: _Section.auditLogs,
            currentSection: currentSection,
            icon: Icons.history_rounded,
            label: 'Audit Logs',
            collapsed: collapsed,
            onTap: onSectionChanged,
            theme: theme,
          ),
          const Spacer(),
          Divider(height: 0.5, color: borderColor),
          InkWell(
            onTap: onLogout,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: collapsed ? 0 : 16,
                vertical: 14,
              ),
              child: Row(
                mainAxisAlignment: collapsed
                    ? MainAxisAlignment.center
                    : MainAxisAlignment.start,
                children: [
                  Icon(Icons.logout_rounded, size: 16, color: kAccentOrange),
                  if (!collapsed) ...[
                    const SizedBox(width: 10),
                    Text(
                      'Logout',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: kAccentOrange,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final _Section section;
  final _Section currentSection;
  final IconData icon;
  final String label;
  final bool collapsed;
  final ValueChanged<_Section> onTap;
  final ThemeData theme;

  const _NavItem({
    required this.section,
    required this.currentSection,
    required this.icon,
    required this.label,
    required this.collapsed,
    required this.onTap,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = section == currentSection;
    final isDark = theme.brightness == Brightness.dark;
    return Tooltip(
      message: collapsed ? label : '',
      preferBelow: false,
      child: InkWell(
        onTap: () => onTap(section),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: EdgeInsets.symmetric(
            horizontal: collapsed ? 8 : 10,
            vertical: 1,
          ),
          padding: EdgeInsets.symmetric(
            horizontal: collapsed ? 0 : 12,
            vertical: 9,
          ),
          decoration: BoxDecoration(
            color: isActive
                ? kPrimaryGreen.withValues(alpha: isDark ? 0.18 : 0.08)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border(
              left: isActive
                  ? const BorderSide(color: kPrimaryGreen, width: 2.5)
                  : const BorderSide(color: Colors.transparent, width: 2.5),
            ),
          ),
          child: Row(
            mainAxisAlignment: collapsed
                ? MainAxisAlignment.center
                : MainAxisAlignment.start,
            children: [
              Icon(
                icon,
                size: 20,
                color: isActive
                    ? kPrimaryGreen
                    : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
              ),
              if (!collapsed) ...[
                const SizedBox(width: 10),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                    color: isActive
                        ? kPrimaryGreen
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Bottom nav ───────────────────────────────────────────────────────────────
class _BottomNav extends StatelessWidget {
  final _Section currentSection;
  final ValueChanged<_Section> onSectionChanged;
  final ThemeData theme;
  const _BottomNav({
    required this.currentSection,
    required this.onSectionChanged,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161616) : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.07),
            width: 0.5,
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
          _BottomNavItem(
            icon: Icons.grid_view_rounded,
            label: 'Overview',
            section: _Section.overview,
            currentSection: currentSection,
            onTap: onSectionChanged,
          ),
          _BottomNavItem(
            icon: Icons.insights_outlined,
            label: 'Analytics',
            section: _Section.analytics,
            currentSection: currentSection,
            onTap: onSectionChanged,
          ),
          _BottomNavItem(
            icon: Icons.people_outline_rounded,
            label: 'Users',
            section: _Section.users,
            currentSection: currentSection,
            onTap: onSectionChanged,
          ),
          _BottomNavItem(
            icon: Icons.restaurant_menu_outlined,
            label: 'Recipes',
            section: _Section.recipes,
            currentSection: currentSection,
            onTap: onSectionChanged,
          ),
          _BottomNavItem(
            icon: Icons.shield_outlined,
            label: 'Reports',
            section: _Section.moderation,
            currentSection: currentSection,
            onTap: onSectionChanged,
          ),
          _BottomNavItem(
            icon: Icons.history_rounded,
            label: 'Logs',
            section: _Section.auditLogs,
            currentSection: currentSection,
            onTap: onSectionChanged,
          ),
        ],
        ),
      ),
    );
  }
}

class _BottomNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final _Section section;
  final _Section currentSection;
  final ValueChanged<_Section> onTap;
  const _BottomNavItem({
    required this.icon,
    required this.label,
    required this.section,
    required this.currentSection,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = section == currentSection;
    return InkWell(
      onTap: () => onTap(section),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 20,
              color: isActive ? kPrimaryGreen : Colors.grey.shade400,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                color: isActive ? kPrimaryGreen : Colors.grey.shade400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Top bar ──────────────────────────────────────────────────────────────────
class _TopBar extends StatelessWidget {
  final ThemeData theme;
  final _Section currentSection;
  final VoidCallback onRefresh;
  final bool showMenuButton;
  final VoidCallback? onMenuPressed;
  final VoidCallback onToggleTheme;

  const _TopBar({
    required this.theme,
    required this.currentSection,
    required this.onRefresh,
    this.showMenuButton = false,
    this.onMenuPressed,
    required this.onToggleTheme,
  });

  String get _title {
    switch (currentSection) {
      case _Section.overview:
        return 'Overview';
      case _Section.analytics:
        return 'Analytics';
      case _Section.users:
        return 'User Management';
      case _Section.recipes:
        return 'Recipe Management';
      case _Section.moderation:
        return 'Content Moderation';
      case _Section.auditLogs:
        return 'Audit Logs';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = theme.brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF161616) : Colors.white;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.black.withValues(alpha: 0.07);
    return Container(
      height: _kTopBarHeight,
      decoration: BoxDecoration(
        color: bg,
        border: Border(bottom: BorderSide(color: borderColor, width: 0.5)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          if (showMenuButton)
            IconButton(
              onPressed: onMenuPressed,
              icon: const Icon(Icons.logout_rounded, size: 18),
              color: kAccentOrange,
              tooltip: 'Logout',
            )
          else
            Text(
              _title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
                letterSpacing: -0.2,
              ),
            ),
          const Spacer(),
          _TopBarIconBtn(
            icon: Icons.refresh_rounded,
            onPressed: onRefresh,
            tooltip: 'Refresh',
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 2),
          _TopBarIconBtn(
            icon: isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
            onPressed: onToggleTheme,
            tooltip: isDark ? 'Light mode' : 'Dark mode',
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 2),
          NotificationsBellButton(
            borderedToolbar: true,
            iconColor: kAccentOrange,
            icon: Icons.notifications_outlined,
          ),
          const SizedBox(width: 8),
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: kPrimaryGreen.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                'AD',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: kPrimaryGreen,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TopBarIconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final String tooltip;
  final Color color;
  const _TopBarIconBtn({
    required this.icon,
    required this.onPressed,
    required this.tooltip,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: _kAdminControlHeight,
    child: IconButton(
      onPressed: onPressed,
      icon: Icon(icon, size: 20, color: color),
      tooltip: tooltip,
      style: IconButton.styleFrom(
        minimumSize: const Size(_kAdminControlHeight, _kAdminControlHeight),
        maximumSize: const Size(_kAdminControlHeight, _kAdminControlHeight),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        side: BorderSide(color: color.withValues(alpha: 0.45), width: 1.2),
      ),
    ),
  );
}

// ─── Overview Section ─────────────────────────────────────────────────────────
