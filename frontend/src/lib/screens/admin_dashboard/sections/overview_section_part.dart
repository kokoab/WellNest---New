part of 'package:my_app/screens/admin_dashboard.dart';

class _OverviewSectionContainer extends StatefulWidget {
  final ThemeData theme;
  final bool isWide;
  const _OverviewSectionContainer({
    super.key,
    required this.theme,
    required this.isWide,
  });

  @override
  State<_OverviewSectionContainer> createState() =>
      _OverviewSectionContainerState();
}

class _OverviewSectionContainerState extends State<_OverviewSectionContainer>
    with AutomaticKeepAliveClientMixin {
  List<AdminUser> _users = [];
  int _usersTotalCount = 0;
  int _usersActiveTotalCount = 0;
  bool _usersLoading = true;

  List<Report> _reports = [];
  bool _reportsLoading = true;

  int _recipeTotal = 0;
  bool _recipeTotalLoading = true;

  List<ActivityLog> _auditLogs = [];
  List<ActivityLog> _mealPlannerAuditLogs = [];
  int _mealPlannerTotal = 0;

  _DateRangeFilter _insightsRange = _DateRangeFilter.monthly;
  List<AdminStatPoint> _userGrowthPoints = [];
  List<AdminStatPoint> _postFrequencyPoints = [];
  List<AdminStatPoint> _chatbotInteractionPoints = [];
  bool _analyticsLoading = true;
  String? _analyticsError;
  int _rankingsRefreshNonce = 0;

  @override
  void initState() {
    super.initState();
    refresh();
  }

  Future<void> refresh() async {
    await Future.wait<void>([
      _loadUsersSummary(),
      _loadReports(),
      _loadRecipeTotal(),
      _loadAuditLogs(),
      _loadAnalytics(),
    ]);
    if (!mounted) return;
    setState(() => _rankingsRefreshNonce++);
  }

  Future<void> _loadUsersSummary() async {
    setState(() => _usersLoading = true);
    try {
      final result = await AdminUserService.instance.fetchUsers();
      if (!mounted) return;
      setState(() {
        _users = result.users;
        _usersTotalCount = result.total;
        _usersActiveTotalCount = result.activeTotal;
        _usersLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _usersLoading = false);
    }
  }

  Future<void> _loadReports() async {
    setState(() => _reportsLoading = true);
    try {
      final reports = await AdminModerationService.instance.fetchReports();
      if (!mounted) return;
      setState(() {
        _reports = reports;
        _reportsLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _reportsLoading = false);
    }
  }

  Future<void> _loadRecipeTotal() async {
    setState(() => _recipeTotalLoading = true);
    try {
      final res = await RecipeService.instance.fetchRecipes(page: 1);
      if (!mounted) return;
      setState(() {
        _recipeTotal = res.total;
        _recipeTotalLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _recipeTotalLoading = false);
    }
  }

  Future<void> _loadAuditLogs() async {
    try {
      final results = await Future.wait([
        AdminAuditLogService.instance.fetchLogs(page: 1),
        AdminAuditLogService.instance.fetchLogs(
          page: 1,
          category: 'meal_planner',
          perPage: 50,
        ),
      ]);
      if (!mounted) return;
      setState(() {
        _auditLogs = results[0].logs;
        _mealPlannerAuditLogs = results[1].logs;
        _mealPlannerTotal = results[1].total;
      });
    } catch (_) {
      // keep existing logs on failure
    }
  }

  Future<void> _loadAnalytics() async {
    setState(() {
      _analyticsLoading = true;
      _analyticsError = null;
    });
    try {
      final range = _insightsRange.apiValue;
      final results = await Future.wait<List<AdminStatPoint>>([
        AdminDashboardService.instance.fetchUserGrowth(range: range),
        AdminDashboardService.instance.fetchPostFrequency(range: range),
        AdminDashboardService.instance.fetchChatbotInteractions(range: range),
      ]);
      if (!mounted) return;
      setState(() {
        _userGrowthPoints = results[0];
        _postFrequencyPoints = results[1];
        _chatbotInteractionPoints = results[2];
        _analyticsLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _analyticsLoading = false;
        _analyticsError = _adminErrorMessage(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return _OverviewSection(
      theme: widget.theme,
      isWide: widget.isWide,
      users: _users,
      totalUsers: _usersTotalCount,
      activeUsers: _usersActiveTotalCount,
      loading: _usersLoading,
      reports: _reports,
      reportsLoading: _reportsLoading,
      recipeTotal: _recipeTotal,
      recipeTotalLoading: _recipeTotalLoading,
      auditLogs: _auditLogs,
      mealPlannerAuditLogs: _mealPlannerAuditLogs,
      mealPlannerTotal: _mealPlannerTotal,
      analyticsLoading: _analyticsLoading,
      analyticsError: _analyticsError,
      userGrowthPoints: _userGrowthPoints,
      postFrequencyPoints: _postFrequencyPoints,
      chatbotInteractionPoints: _chatbotInteractionPoints,
      selectedInsightsRange: _insightsRange,
      onInsightsRangeChanged: (range) {
        setState(() => _insightsRange = range);
        _loadAnalytics();
      },
      rankingsRefreshNonce: _rankingsRefreshNonce,
    );
  }

  @override
  bool get wantKeepAlive => true;
}

class _OverviewSection extends StatelessWidget {
  final ThemeData theme;
  final bool isWide;
  final List<AdminUser> users;
  final int totalUsers;
  final int activeUsers;
  final bool loading;
  final List<Report> reports;
  final bool reportsLoading;
  final int recipeTotal;
  final bool recipeTotalLoading;
  final List<ActivityLog> auditLogs;
  final List<ActivityLog> mealPlannerAuditLogs;
  final int mealPlannerTotal;
  final bool analyticsLoading;
  final String? analyticsError;
  final List<AdminStatPoint> userGrowthPoints;
  final List<AdminStatPoint> postFrequencyPoints;
  final List<AdminStatPoint> chatbotInteractionPoints;
  final _DateRangeFilter selectedInsightsRange;
  final ValueChanged<_DateRangeFilter> onInsightsRangeChanged;
  final int rankingsRefreshNonce;

  const _OverviewSection({
    required this.theme,
    required this.isWide,
    required this.users,
    required this.totalUsers,
    required this.activeUsers,
    required this.loading,
    required this.reports,
    required this.reportsLoading,
    required this.recipeTotal,
    required this.recipeTotalLoading,
    required this.auditLogs,
    required this.mealPlannerAuditLogs,
    required this.mealPlannerTotal,
    required this.analyticsLoading,
    required this.analyticsError,
    required this.userGrowthPoints,
    required this.postFrequencyPoints,
    required this.chatbotInteractionPoints,
    required this.selectedInsightsRange,
    required this.onInsightsRangeChanged,
    required this.rankingsRefreshNonce,
  });

  @override
  Widget build(BuildContext context) {
    final openReports = reports
        .where((r) => _normalizeReportStatus(r.status) == 'open')
        .length;
    final mealPlannerLogs = mealPlannerAuditLogs;
    final mealPlannerActions = mealPlannerTotal;
    final userGrowthTrend = _formatTrend(_seriesPercentDelta(userGrowthPoints));
    final postGrowthTrend = _formatTrend(
      _seriesPercentDelta(postFrequencyPoints),
    );
    final activeRatio = totalUsers == 0
        ? 0
        : ((activeUsers / totalUsers) * 100).round();
    final activeTrendText = users.isEmpty ? 'No data' : '$activeRatio% active';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        isWide
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Good day, Admin 👋',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: theme.colorScheme.onSurface,
                            letterSpacing: -0.3,
                            fontFamily: kFontHelveticaNow,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Here\'s a snapshot of your WellNest community.',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  _DateRangeDropdown(
                    value: selectedInsightsRange,
                    onChanged: onInsightsRangeChanged,
                  ),
                  const SizedBox(width: 8),
                  _AdminCsvExportButton(range: selectedInsightsRange),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Good day, Admin 👋',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurface,
                      letterSpacing: -0.3,
                      fontFamily: kFontHelveticaNow,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Here\'s a snapshot of your WellNest community.',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _DateRangeDropdown(
                        value: selectedInsightsRange,
                        onChanged: onInsightsRangeChanged,
                      ),
                      const SizedBox(width: 8),
                      _AdminCsvExportButton(range: selectedInsightsRange),
                    ],
                  ),
                ],
              ),
        const SizedBox(height: 22),
        isWide
            ? Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      theme: theme,
                      title: 'Total Users',
                      value: loading ? '—' : '$totalUsers',
                      icon: Icons.people_outline_rounded,
                      color: const Color(0xFF3C6DF0),
                      trend: userGrowthTrend,
                      trendUp: _isTrendUp(userGrowthTrend),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatCard(
                      theme: theme,
                      title: 'Active Users',
                      value: loading ? '—' : '$activeUsers',
                      icon: Icons.person_outline_rounded,
                      color: kPrimaryGreen,
                      trend: activeTrendText,
                      trendUp: true,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatCard(
                      theme: theme,
                      title: 'Total Recipes',
                      value: recipeTotalLoading ? '—' : '$recipeTotal',
                      icon: Icons.restaurant_menu_outlined,
                      color: const Color(0xFFE6930A),
                      trend: postGrowthTrend,
                      trendUp: _isTrendUp(postGrowthTrend),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatCard(
                      theme: theme,
                      title: 'Open Reports',
                      value: reportsLoading ? '—' : '$openReports',
                      icon: Icons.flag_outlined,
                      color: kAccentOrange,
                      trend: openReports > 0 ? 'Needs review' : 'All clear',
                      trendUp: false,
                    ),
                  ),
                ],
              )
            : Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          theme: theme,
                          title: 'Total Users',
                          value: loading ? '—' : '$totalUsers',
                          icon: Icons.people_outline_rounded,
                          color: const Color(0xFF3C6DF0),
                          trend: userGrowthTrend,
                          trendUp: _isTrendUp(userGrowthTrend),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _StatCard(
                          theme: theme,
                          title: 'Active Users',
                          value: loading ? '—' : '$activeUsers',
                          icon: Icons.person_outline_rounded,
                          color: kPrimaryGreen,
                          trend: activeTrendText,
                          trendUp: true,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          theme: theme,
                          title: 'Total Recipes',
                          value: recipeTotalLoading ? '—' : '$recipeTotal',
                          icon: Icons.restaurant_menu_outlined,
                          color: const Color(0xFFE6930A),
                          trend: postGrowthTrend,
                          trendUp: _isTrendUp(postGrowthTrend),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _StatCard(
                          theme: theme,
                          title: 'Open Reports',
                          value: reportsLoading ? '—' : '$openReports',
                          icon: Icons.flag_outlined,
                          color: kAccentOrange,
                          trend: openReports > 0 ? 'Needs review' : 'All clear',
                          trendUp: false,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
        const SizedBox(height: 24),
        _ChartsSection(
          theme: theme,
          users: users,
          reports: reports,
          auditLogs: auditLogs,
          analyticsLoading: analyticsLoading,
          analyticsError: analyticsError,
          userGrowthPoints: userGrowthPoints,
          postFrequencyPoints: postFrequencyPoints,
          chatbotInteractionPoints: chatbotInteractionPoints,
          isWide: isWide,
        ),
        const SizedBox(height: 24),
        _MinimalSectionLabel(theme: theme, label: 'Meal Planner Activity'),
        const SizedBox(height: 10),
        _SurfaceCard(
          theme: theme,
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: kPrimaryGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.calendar_month_outlined,
                  color: kPrimaryGreen,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Meal planner actions logged: $mealPlannerActions',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        if (mealPlannerLogs.isEmpty)
          _EmptyState(theme: theme, message: 'No meal planner activity yet.')
        else
          _RecentLogsList(theme: theme, logs: mealPlannerLogs.take(5).toList()),
        const SizedBox(height: 22),
        _MinimalSectionLabel(
          theme: theme,
          label: 'Recipe Rankings',
          subtitle: 'Views, ratings & combined score',
        ),
        const SizedBox(height: 10),
        _OverviewRecipeRankingsCard(
          theme: theme,
          refreshNonce: rankingsRefreshNonce,
        ),
        const SizedBox(height: 22),
        _MinimalSectionLabel(
          theme: theme,
          label: 'Recent Activity',
          subtitle: 'Last 5 audit log events',
        ),
        const SizedBox(height: 10),
        if (auditLogs.isEmpty)
          _EmptyState(theme: theme, message: 'No audit logs yet')
        else
          _RecentLogsList(theme: theme, logs: auditLogs.take(5).toList()),
        const SizedBox(height: 32),
      ],
    );
  }
}
