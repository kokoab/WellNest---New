part of 'package:my_app/screens/admin_dashboard.dart';

class _UsersSectionContainer extends StatefulWidget {
  final ThemeData theme;
  const _UsersSectionContainer({super.key, required this.theme});

  @override
  State<_UsersSectionContainer> createState() => _UsersSectionContainerState();
}

class _UsersSectionContainerState extends State<_UsersSectionContainer>
    with AutomaticKeepAliveClientMixin {
  List<AdminUser> _users = [];
  bool _loading = true;
  String? _error;
  String _searchQuery = '';
  _DateRangeFilter _usersRange = _DateRangeFilter.monthly;
  Timer? _usersSearchDebounce;
  int _usersPage = 1;
  final int _usersPerPage = 10;
  bool _usersLoadingPage = false;
  int _usersQuerySerial = 0;
  int _usersTotalCount = 0;

  @override
  void initState() {
    super.initState();
    refresh();
  }

  @override
  void dispose() {
    _usersSearchDebounce?.cancel();
    super.dispose();
  }

  Future<void> refresh() => _loadUsersPage(reset: true);

  int _getUsersTotalPages() {
    if (_usersTotalCount == 0) return 1;
    return (_usersTotalCount / _usersPerPage).ceil();
  }

  void _handleUsersSearchChanged(String value) {
    setState(() => _searchQuery = value);
    _usersSearchDebounce?.cancel();
    _usersSearchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      _loadUsersPage(reset: true);
    });
  }

  Future<void> _loadUsersPage({bool reset = false}) async {
    final querySerial = ++_usersQuerySerial;
    if (reset) {
      _usersPage = 1;
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final result = await AdminUserService.instance.fetchUsers(
        range: _usersRange.apiValue,
        search: _searchQuery,
        page: _usersPage,
        perPage: _usersPerPage,
      );
      if (!mounted || querySerial != _usersQuerySerial) return;
      setState(() {
        _users = result.users;
        _usersTotalCount = result.total;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _adminErrorMessage(e);
        _loading = false;
      });
    }
  }

  Future<void> _handleUsersPageChanged(int page) async {
    if (page < 1 || page > _getUsersTotalPages()) return;
    setState(() => _usersLoadingPage = true);
    try {
      final result = await AdminUserService.instance.fetchUsers(
        range: _usersRange.apiValue,
        search: _searchQuery,
        page: page,
        perPage: _usersPerPage,
      );
      if (!mounted) return;
      setState(() {
        _usersPage = page;
        _users = result.users;
        _usersTotalCount = result.total;
        _usersLoadingPage = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _adminErrorMessage(e);
        _usersLoadingPage = false;
      });
    }
  }

  Future<void> _showUserPostsModal(AdminUser user) async {
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (ctx) => _WebModal(
        title: 'Posts by ${user.name}',
        icon: Icons.article_outlined,
        iconColor: kPrimaryGreen,
        child: _PostsModalContent(userId: user.id),
      ),
    );
  }

  Future<void> _showUserCommentsModal(AdminUser user) async {
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (ctx) => _WebModal(
        title: "Comments on ${user.name}'s posts",
        icon: Icons.comment_outlined,
        iconColor: kAccentOrange,
        child: _CommentsModalContent(user: user),
      ),
    );
  }

  Future<void> _showUserRecipesModal(AdminUser user) async {
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (ctx) => _WebModal(
        title: 'Recipes by ${user.name}',
        icon: Icons.restaurant_menu_outlined,
        iconColor: const Color(0xFFE6930A),
        child: _RecipesModalContent(userId: user.id),
      ),
    );
  }

  Future<void> _updateStatus(int userId, String status) async {
    try {
      await AdminUserService.instance.updateUserStatus(userId, status);
      if (!mounted) return;
      _showAdminSnack(
        context,
        status == 'active' ? 'Account activated' : 'Account deactivated',
      );
      await refresh();
    } catch (e) {
      if (!mounted) return;
      _showAdminErrorSnack(context, e);
    }
  }

  Future<void> _confirmDeactivate(AdminUser user) async {
    final ok = await _showAdminConfirmDialog(
      context: context,
      title: 'Deactivate account?',
      content:
          'Deactivate "${user.name}" (${user.email})? They will not be able to sign in until reactivated.',
      actionLabel: 'Deactivate',
      actionColor: kAccentOrange,
    );
    if (ok == true) await _updateStatus(user.id, 'inactive');
  }

  Future<void> _confirmActivate(AdminUser user) async {
    final ok = await _showAdminConfirmDialog(
      context: context,
      title: 'Activate account?',
      content:
          'Reactivate "${user.name}" (${user.email})? They will be able to sign in again.',
      actionLabel: 'Activate',
      actionColor: kPrimaryGreen,
    );
    if (ok == true) await _updateStatus(user.id, 'active');
  }

  Future<void> _confirmDelete(AdminUser user) async {
    final ok = await _showAdminConfirmDialog(
      context: context,
      title: 'Delete account permanently?',
      content:
          'Permanently delete "${user.name}" (${user.email})? This cannot be undone.',
      actionLabel: 'Delete',
      actionColor: Colors.red,
    );
    if (ok != true) return;
    try {
      await AdminUserService.instance.deleteUser(user.id);
      if (!mounted) return;
      _showAdminSnack(context, 'Account deleted');
      await refresh();
    } catch (e) {
      if (!mounted) return;
      _showAdminErrorSnack(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return _UsersSection(
      theme: widget.theme,
      users: _users,
      loading: _loading,
      error: _error,
      searchQuery: _searchQuery,
      onSearchChanged: _handleUsersSearchChanged,
      selectedRange: _usersRange,
      onRangeChanged: (range) {
        setState(() => _usersRange = range);
        refresh();
      },
      onRefresh: refresh,
      onDeactivate: _confirmDeactivate,
      onActivate: _confirmActivate,
      onDelete: _confirmDelete,
      onViewPosts: _showUserPostsModal,
      onViewComments: _showUserCommentsModal,
      onViewRecipes: _showUserRecipesModal,
      currentPage: _usersPage,
      totalPages: _getUsersTotalPages(),
      loadingPage: _usersLoadingPage,
      onPageChanged: _handleUsersPageChanged,
    );
  }

  @override
  bool get wantKeepAlive => true;
}

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
              _AdminCsvExportButton(range: selectedRange),
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
