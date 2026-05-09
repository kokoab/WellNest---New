part of 'package:my_app/screens/admin_dashboard.dart';

class _AnalyticsSection extends StatelessWidget {
  final ThemeData theme;
  final bool isWide;
  final List<AdminUser> users;
  final List<Report> reports;
  final List<ActivityLog> auditLogs;
  final bool analyticsLoading;
  final String? analyticsError;
  final List<AdminStatPoint> userGrowthPoints;
  final List<AdminStatPoint> postFrequencyPoints;
  final List<AdminStatPoint> chatbotInteractionPoints;
  final _DateRangeFilter selectedInsightsRange;
  final ValueChanged<_DateRangeFilter> onInsightsRangeChanged;
  final VoidCallback onRefresh;

  const _AnalyticsSection({
    required this.theme,
    required this.isWide,
    required this.users,
    required this.reports,
    required this.auditLogs,
    required this.analyticsLoading,
    required this.analyticsError,
    required this.userGrowthPoints,
    required this.postFrequencyPoints,
    required this.chatbotInteractionPoints,
    required this.selectedInsightsRange,
    required this.onInsightsRangeChanged,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Analytics Dashboard',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.onSurface,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Track growth, moderation outcomes, and activity trends.',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            _DateRangeDropdown(
              value: selectedInsightsRange,
              onChanged: onInsightsRangeChanged,
            ),
            const SizedBox(width: 8),
            _GreenButton(
              label: analyticsLoading ? 'Refreshing…' : 'Refresh',
              icon: Icons.refresh_rounded,
              loading: analyticsLoading,
              onPressed: analyticsLoading ? null : onRefresh,
            ),
          ],
        ),
        const SizedBox(height: 16),
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

// ─── Charts Section ───────────────────────────────────────────────────────────

