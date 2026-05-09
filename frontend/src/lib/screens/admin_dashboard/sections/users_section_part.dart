part of 'package:my_app/screens/admin_dashboard.dart';

class _UsersSection extends StatelessWidget {
  final ThemeData theme;
  final List<AdminUser> users;
  final bool loading;
  final String? error;
  final String searchQuery;
  final ValueChanged<String> onSearchChanged;
  final _DateRangeFilter selectedRange;
  final ValueChanged<_DateRangeFilter> onRangeChanged;
  final VoidCallback onRefresh;
  final VoidCallback? onExport;
  final bool exporting;
  final void Function(AdminUser) onDeactivate;
  final void Function(AdminUser) onActivate;
  final void Function(AdminUser) onDelete;
  final void Function(AdminUser) onViewPosts;
  final void Function(AdminUser) onViewComments;
  final void Function(AdminUser) onViewRecipes;
  // Pagination parameters
  final int currentPage;
  final int totalPages;
  final bool loadingPage;
  final ValueChanged<int> onPageChanged;

  const _UsersSection({
    required this.theme,
    required this.users,
    required this.loading,
    required this.error,
    required this.searchQuery,
    required this.onSearchChanged,
    required this.selectedRange,
    required this.onRangeChanged,
    required this.onRefresh,
    required this.onExport,
    required this.exporting,
    required this.onDeactivate,
    required this.onActivate,
    required this.onDelete,
    required this.onViewPosts,
    required this.onViewComments,
    required this.onViewRecipes,
    required this.currentPage,
    required this.totalPages,
    required this.loadingPage,
    required this.onPageChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _MinimalSectionLabel(
                theme: theme,
                label: 'Registered Users',
                subtitle: loading ? 'Loading…' : '${users.length} users',
              ),
            ),
            _DateRangeDropdown(value: selectedRange, onChanged: onRangeChanged),
            const SizedBox(width: 6),
            if (!loading) ...[
              _TopBarIconBtn(
                icon: Icons.refresh_rounded,
                onPressed: onRefresh,
                tooltip: 'Refresh',
                color: kPrimaryGreen,
              ),
              const SizedBox(width: 4),
              _GreenButton(
                label: exporting ? 'Exporting…' : 'Export',
                icon: Icons.download_rounded,
                loading: exporting,
                onPressed: exporting ? null : onExport,
                compact: true,
              ),
            ],
          ],
        ),
        const SizedBox(height: 14),
        _SearchBar(
          theme: theme,
          onChanged: onSearchChanged,
          hintText: 'Search by name or email…',
        ),
        const SizedBox(height: 14),
        if (loading && users.isEmpty)
          const _LoadingState()
        else if (error != null)
          _ErrorState(theme: theme, message: error!, onRetry: onRefresh)
        else if (users.isEmpty)
          _EmptyState(
            theme: theme,
            message: searchQuery.isEmpty
                ? 'No users yet'
                : 'No users match your search',
          )
        else ...[
          _UsersTable(
            theme: theme,
            users: users,
            onDeactivate: onDeactivate,
            onActivate: onActivate,
            onDelete: onDelete,
            onViewPosts: onViewPosts,
            onViewComments: onViewComments,
            onViewRecipes: onViewRecipes,
          ),
          const SizedBox(height: 16),
          _PaginationControls(
            currentPage: currentPage,
            totalPages: totalPages,
            loading: loadingPage,
            onPageChanged: onPageChanged,
          ),
        ],
        const SizedBox(height: 32),
      ],
    );
  }
}

// ─── Moderation Section ───────────────────────────────────────────────────────

class _UsersTable extends StatelessWidget {
  final ThemeData theme;
  final List<AdminUser> users;
  final void Function(AdminUser) onDeactivate;
  final void Function(AdminUser) onActivate;
  final void Function(AdminUser) onDelete;
  final void Function(AdminUser) onViewPosts;
  final void Function(AdminUser) onViewComments;
  final void Function(AdminUser) onViewRecipes; // ← NEW

  const _UsersTable({
    required this.theme,
    required this.users,
    required this.onDeactivate,
    required this.onActivate,
    required this.onDelete,
    required this.onViewPosts,
    required this.onViewComments,
    required this.onViewRecipes,
  });

  @override
  Widget build(BuildContext context) {
    // Render table without an inner vertical scroll so the page's outer
    // ScrollController can detect when the bottom is reached.
    final screenWidth = MediaQuery.of(context).size.width;
    return SizedBox(
      width: screenWidth,
      child: _flexTable(
        theme: theme,
        columnWidths: {
          0: FlexColumnWidth(screenWidth * 0.08),
          1: FlexColumnWidth(screenWidth * 0.20),
          2: FlexColumnWidth(screenWidth * 0.28),
          3: FlexColumnWidth(screenWidth * 0.15),
          4: FlexColumnWidth(screenWidth * 0.29),
        },
          headers: ['ID', 'NAME', 'EMAIL', 'STATUS', 'ACTIONS'],
          rows: users.asMap().entries.map((e) {
            final user = e.value;
            return _tableRow(theme, [
              Text(
                '${user.id}',
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              Row(
                children: [
                  _UserAvatar(name: user.name),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      user.name.isEmpty ? '—' : user.name,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(
                width: screenWidth * 0.28,
                child: Text(
                  user.email,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              _StatusPill(isActive: user.isActive),
              SizedBox(
                width: screenWidth * 0.29,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (user.isActive)
                      _ActionIconBtn(
                        icon: Icons.person_off_outlined,
                        color: kAccentOrange,
                        tooltip: 'Deactivate',
                        onPressed: () => onDeactivate(user),
                      )
                    else
                      _ActionIconBtn(
                        icon: Icons.person_add_outlined,
                        color: kPrimaryGreen,
                        tooltip: 'Activate',
                        onPressed: () => onActivate(user),
                      ),
                    const SizedBox(width: 4),
                    _ActionIconBtn(
                      icon: Icons.article_outlined,
                      color: kPrimaryGreen,
                      tooltip: 'Posts',
                      onPressed: () => onViewPosts(user),
                    ),
                    const SizedBox(width: 4),
                    _ActionIconBtn(
                      icon: Icons.comment_outlined,
                      color: kAccentOrange,
                      tooltip: 'Comments',
                      onPressed: () => onViewComments(user),
                    ),
                    const SizedBox(width: 4),
                    _ActionIconBtn(
                      icon: Icons.restaurant_menu_outlined,
                      color: const Color(0xFFE6930A),
                      tooltip: 'Recipes',
                      onPressed: () => onViewRecipes(user),
                    ),
                    const SizedBox(width: 4),
                    _ActionIconBtn(
                      icon: Icons.delete_outline_rounded,
                      color: Colors.red,
                      tooltip: 'Delete',
                      onPressed: () => onDelete(user),
                    ),
                  ],
                ),
              ),
            ], null);
          }).toList(),
        ),
      );
  }
}

