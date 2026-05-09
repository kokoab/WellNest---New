part of 'package:my_app/screens/admin_dashboard.dart';

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
  final bool analyticsLoading;
  final String? analyticsError;
  final List<AdminStatPoint> userGrowthPoints;
  final List<AdminStatPoint> postFrequencyPoints;
  final List<AdminStatPoint> chatbotInteractionPoints;
  final bool exportingInsightsCsv;
  final _DateRangeFilter selectedInsightsRange;
  final ValueChanged<_DateRangeFilter> onInsightsRangeChanged;
  final VoidCallback onExportInsights;
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
    required this.analyticsLoading,
    required this.analyticsError,
    required this.userGrowthPoints,
    required this.postFrequencyPoints,
    required this.chatbotInteractionPoints,
    required this.exportingInsightsCsv,
    required this.selectedInsightsRange,
    required this.onInsightsRangeChanged,
    required this.onExportInsights,
    required this.rankingsRefreshNonce,
  });

  @override
  Widget build(BuildContext context) {
    final openReports = reports
        .where((r) => _normalizeReportStatus(r.status) == 'open')
        .length;
    final mealPlannerLogs = auditLogs
        .where((l) => l.category.toLowerCase() == 'meal_planner')
        .toList();
    final mealPlannerActions = mealPlannerLogs.length;
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
        Text(
          'Good day, Admin',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.onSurface,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          'Here\'s a snapshot of your WellNest community.',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: theme.colorScheme.onSurfaceVariant,
          ),
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
        Row(
          children: [
            _DateRangeDropdown(
              value: selectedInsightsRange,
              onChanged: onInsightsRangeChanged,
            ),
            const SizedBox(width: 8),
            _GreenButton(
              label: exportingInsightsCsv ? 'Exporting…' : 'Export Insights',
              icon: Icons.download_rounded,
              loading: exportingInsightsCsv,
              onPressed: exportingInsightsCsv ? null : onExportInsights,
            ),
          ],
        ),
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

