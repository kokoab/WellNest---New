part of 'package:my_app/screens/admin_dashboard.dart';

class _AnalyticsSectionContainer extends StatefulWidget {
  final ThemeData theme;
  final bool isWide;
  const _AnalyticsSectionContainer({
    super.key,
    required this.theme,
    required this.isWide,
  });

  @override
  State<_AnalyticsSectionContainer> createState() =>
      _AnalyticsSectionContainerState();
}

class _AnalyticsSectionContainerState extends State<_AnalyticsSectionContainer>
    with AutomaticKeepAliveClientMixin {
  List<AdminUser> _users = [];
  List<Report> _reports = [];
  List<ActivityLog> _auditLogs = [];
  _DateRangeFilter _insightsRange = _DateRangeFilter.all;
  List<AdminStatPoint> _userGrowthPoints = [];
  List<AdminStatPoint> _postFrequencyPoints = [];
  List<AdminStatPoint> _chatbotInteractionPoints = [];
  bool _analyticsLoading = true;
  String? _analyticsError;

  @override
  void initState() {
    super.initState();
    refresh();
  }

  Future<void> refresh() async {
    await Future.wait<void>([
      _loadAnalytics(),
      _loadReports(),
      _loadAuditLogs(),
      _loadUsers(),
    ]);
  }

  Future<void> _loadUsers() async {
    try {
      final result = await AdminUserService.instance.fetchUsers();
      if (!mounted) return;
      setState(() => _users = result.users);
    } catch (_) {}
  }

  Future<void> _loadReports() async {
    try {
      final reports = await AdminModerationService.instance.fetchReports(
        range: _insightsRange.apiValue,
      );
      if (!mounted) return;
      setState(() => _reports = reports);
    } catch (_) {}
  }

  Future<void> _loadAuditLogs() async {
    try {
      final logs = await AdminAuditLogService.instance.fetchLogs(
        page: 1,
        range: _insightsRange.apiValue,
      );
      if (!mounted) return;
      setState(() => _auditLogs = logs.logs);
    } catch (_) {}
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
        _analyticsError = _adminErrorMessage(e);
        _analyticsLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return _AnalyticsSection(
      theme: widget.theme,
      isWide: widget.isWide,
      users: _users,
      reports: _reports,
      auditLogs: _auditLogs,
      analyticsLoading: _analyticsLoading,
      analyticsError: _analyticsError,
      userGrowthPoints: _userGrowthPoints,
      postFrequencyPoints: _postFrequencyPoints,
      chatbotInteractionPoints: _chatbotInteractionPoints,
      selectedInsightsRange: _insightsRange,
      onInsightsRangeChanged: (range) {
        setState(() => _insightsRange = range);
        refresh();
      },
      onRefresh: _loadAnalytics,
    );
  }

  @override
  bool get wantKeepAlive => true;
}

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
        isWide
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
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
                  const SizedBox(width: 4),
                  _TopBarIconBtn(
                    icon: Icons.refresh_rounded,
                    onPressed: analyticsLoading ? null : onRefresh,
                    tooltip: 'Refresh',
                    color: kPrimaryGreen,
                  ),
                ],
              )
            : Column(
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
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _DateRangeDropdown(
                        value: selectedInsightsRange,
                        onChanged: onInsightsRangeChanged,
                      ),
                      const SizedBox(width: 8),
                      _AdminCsvExportButton(range: selectedInsightsRange),
                      const SizedBox(width: 4),
                      _TopBarIconBtn(
                        icon: Icons.refresh_rounded,
                        onPressed: analyticsLoading ? null : onRefresh,
                        tooltip: 'Refresh',
                        color: kPrimaryGreen,
                      ),
                    ],
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
