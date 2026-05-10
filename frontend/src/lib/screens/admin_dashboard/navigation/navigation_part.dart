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
    final borderColor = isDark ? _kBorderDark : kPrimaryGreen.withValues(alpha: 0.15);
    final width = collapsed ? _kSidebarCollapsedWidth : _kSidebarWidth;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: width,
      decoration: BoxDecoration(
        color: _kSidebarDark,
        border: Border(right: BorderSide(color: borderColor, width: 1)),
      ),
      child: Column(
        children: [
          Container(
            height: _kTopBarHeight,
            padding: EdgeInsets.symmetric(horizontal: collapsed ? 0 : 20),
            alignment: collapsed ? Alignment.center : Alignment.centerLeft,
            child: collapsed
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.asset(kWellnestAssistantLogoAsset,
                        width: 32, height: 32),
                  )
                : Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.asset(kWellnestAssistantLogoAsset,
                            width: 32, height: 32),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'WellNest',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.2,
                            ),
                          ),
                          Text(
                            'ADMIN CONSOLE',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.5),
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: onToggleCollapsed,
                        icon: const Icon(
                          Icons.chevron_left_rounded,
                          color: Colors.white24,
                          size: 18,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
          ),
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
          Divider(height: 1, color: borderColor),
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
                        fontWeight: FontWeight.w700,
                        color: kAccentOrange.withValues(alpha: 0.9),
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
          duration: const Duration(milliseconds: 200),
          margin: EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 4,
          ),
          padding: EdgeInsets.symmetric(
            horizontal: collapsed ? 0 : 14,
            vertical: 10,
          ),
          decoration: BoxDecoration(
            color: isActive ? _kSidebarActiveBg : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isActive
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.transparent,
              width: 1,
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
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.45),
              ),
              if (!collapsed) ...[
                const SizedBox(width: 12),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
                    color: isActive
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.45),
                    letterSpacing: 0.1,
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
        color: _kSidebarDark,
        border: Border(
          top: BorderSide(
            color: isDark ? _kBorderDark : const Color(0xFF1F2937),
            width: 1,
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
    final bg = isDark ? _kSidebarDark : kPrimaryGreen;
    final borderColor = isDark ? _kBorderDark : kPrimaryGreen.withValues(alpha: 0.2);
    return Container(
      height: _kTopBarHeight,
      decoration: BoxDecoration(
        color: bg,
        border: Border(bottom: BorderSide(color: borderColor, width: 1)),
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
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: -0.4,
              ),
            ),
          const Spacer(),
          _TopBarIconBtn(
            icon: Icons.refresh_rounded,
            onPressed: onRefresh,
            tooltip: 'Refresh',
            color: Colors.white.withValues(alpha: 0.7),
          ),
          const SizedBox(width: 2),
          _TopBarIconBtn(
            icon: isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
            onPressed: onToggleTheme,
            tooltip: isDark ? 'Light mode' : 'Dark mode',
            color: Colors.white.withValues(alpha: 0.7),
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
                  fontWeight: FontWeight.w900,
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
