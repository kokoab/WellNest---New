import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:my_app/models/activity_log.dart';
import 'package:my_app/models/admin_user.dart';
import 'package:my_app/models/recipe.dart';
import 'package:my_app/models/recipe_ranking_item.dart';
import 'package:my_app/models/report.dart';
import 'package:my_app/widgets/notifications_dropdown.dart';
import 'package:my_app/services/admin_auth_service.dart';
import 'package:my_app/services/auth_service.dart';
import 'package:my_app/services/admin_user_service.dart';
import 'package:my_app/services/admin_moderation_service.dart';
import 'package:my_app/services/admin_activity_log_service.dart';
import 'package:my_app/services/admin_dashboard_service.dart';
import 'package:my_app/services/api_service.dart';
import 'package:my_app/services/post_service.dart';
import 'package:my_app/services/recipe_service.dart';
import 'package:my_app/models/post.dart';
import 'package:my_app/theme/app_theme.dart';
import 'package:share_plus/share_plus.dart';
import 'package:provider/provider.dart';
import 'package:my_app/providers/theme_provider.dart';

part 'admin_dashboard/sections/section_ui_part.dart';
part 'admin_dashboard/sections/overview_section_part.dart';
part 'admin_dashboard/sections/analytics_section_part.dart';
part 'admin_dashboard/sections/users_section_part.dart';
part 'admin_dashboard/sections/moderation_section_part.dart';
part 'admin_dashboard/sections/audit_logs_section_part.dart';
part 'admin_dashboard/widgets/pagination_controls.dart';
part 'admin_dashboard/navigation/navigation_part.dart';
part 'admin_dashboard/modals/modals_part.dart';
part 'admin_dashboard/charts/charts_part.dart';
// ─── Nav sections ─────────────────────────────────────────────────────────────
enum _Section { overview, analytics, users, moderation, auditLogs }

enum _DateRangeFilter {
  weekly('weekly', 'Weekly'),
  monthly('monthly', 'Monthly'),
  yearly('yearly', 'Yearly');

  const _DateRangeFilter(this.apiValue, this.label);
  final String apiValue;
  final String label;
}

// ─── Design tokens ────────────────────────────────────────────────────────────
const double _kSidebarWidth = 228.0;
const double _kSidebarCollapsedWidth = 64.0;
const double _kTopBarHeight = 56.0;
const double _kCardRadius = 14.0;
const double _kStatCardRadius = 14.0;

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  _Section _currentSection = _Section.overview;
  bool _sidebarCollapsed = false;
  final ScrollController _mainScrollController = ScrollController();

  final _overviewKey = GlobalKey<_OverviewSectionContainerState>();
  final _analyticsKey = GlobalKey<_AnalyticsSectionContainerState>();
  final _usersKey = GlobalKey<_UsersSectionContainerState>();
  final _moderationKey = GlobalKey<_ModerationSectionContainerState>();
  final _auditLogsKey = GlobalKey<_AuditLogsSectionContainerState>();

  @override
  void dispose() {
    _mainScrollController.dispose();
    super.dispose();
  }

  Future<void> _refreshCurrentSection() async {
    switch (_currentSection) {
      case _Section.overview:
        await _overviewKey.currentState?.refresh();
        break;
      case _Section.analytics:
        await _analyticsKey.currentState?.refresh();
        break;
      case _Section.users:
        await _usersKey.currentState?.refresh();
        break;
      case _Section.moderation:
        await _moderationKey.currentState?.refresh();
        break;
      case _Section.auditLogs:
        await _auditLogsKey.currentState?.refresh();
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isWide = MediaQuery.sizeOf(context).width >= 800;
    final dashboardTextTheme = theme.textTheme.copyWith(
      bodySmall: (theme.textTheme.bodySmall ?? const TextStyle()).copyWith(
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
      bodyMedium: (theme.textTheme.bodyMedium ?? const TextStyle()).copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
      bodyLarge: (theme.textTheme.bodyLarge ?? const TextStyle()).copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
      titleSmall: (theme.textTheme.titleSmall ?? const TextStyle()).copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
      titleMedium: (theme.textTheme.titleMedium ?? const TextStyle()).copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w700,
      ),
      titleLarge: (theme.textTheme.titleLarge ?? const TextStyle()).copyWith(
        fontSize: 18,
        fontWeight: FontWeight.w700,
      ),
      labelMedium: (theme.textTheme.labelMedium ?? const TextStyle()).copyWith(
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
      labelSmall: (theme.textTheme.labelSmall ?? const TextStyle()).copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
    );
    return Theme(
      data: theme.copyWith(textTheme: dashboardTextTheme),
      child: Scaffold(
        backgroundColor: theme.colorScheme.surface,
        body: SafeArea(
          child: isWide ? _buildWideLayout(theme) : _buildNarrowLayout(theme),
        ),
      ),
    );
  }

  Widget _buildWideLayout(ThemeData theme) {
    return Row(
      children: [
        _Sidebar(
          collapsed: _sidebarCollapsed,
          currentSection: _currentSection,
          onSectionChanged: (s) => setState(() => _currentSection = s),
          onToggleCollapsed: () =>
              setState(() => _sidebarCollapsed = !_sidebarCollapsed),
          onLogout: _handleLogout,
          theme: theme,
        ),
        Expanded(
          child: Column(
            children: [
              _TopBar(
                theme: theme,
                currentSection: _currentSection,
                onRefresh: _refreshCurrentSection,
                onToggleTheme: _toggleTheme,
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _refreshCurrentSection,
                  color: kPrimaryGreen,
                  child: Scrollbar(
                    controller: _mainScrollController,
                    thumbVisibility: true,
                    child: SingleChildScrollView(
                      controller: _mainScrollController,
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(24),
                      child: _buildSectionStack(theme, isWide: true),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNarrowLayout(ThemeData theme) {
    return Column(
      children: [
        _TopBar(
          theme: theme,
          currentSection: _currentSection,
          onRefresh: _refreshCurrentSection,
          showMenuButton: true,
          onMenuPressed: _handleLogout,
          onToggleTheme: _toggleTheme,
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _refreshCurrentSection,
            color: kPrimaryGreen,
            child: Scrollbar(
              controller: _mainScrollController,
              thumbVisibility: true,
              child: SingleChildScrollView(
                controller: _mainScrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: _buildSectionStack(theme, isWide: false),
              ),
            ),
          ),
        ),
        _BottomNav(
          currentSection: _currentSection,
          onSectionChanged: (s) => setState(() => _currentSection = s),
          theme: theme,
        ),
      ],
    );
  }

  Future<void> _handleLogout() async {
    await AdminAuthService.instance.logoutAdmin();
    AuthService.instance.clearToken();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (r) => false);
  }

  void _toggleTheme() => context.read<ThemeProvider>().toggleTheme();

  Widget _buildSectionStack(ThemeData theme, {required bool isWide}) {
    return IndexedStack(
      index: _currentSection.index,
      children: [
        _OverviewSectionContainer(key: _overviewKey, theme: theme, isWide: isWide),
        _AnalyticsSectionContainer(
          key: _analyticsKey,
          theme: theme,
          isWide: isWide,
        ),
        _UsersSectionContainer(key: _usersKey, theme: theme),
        _ModerationSectionContainer(key: _moderationKey, theme: theme),
        _AuditLogsSectionContainer(key: _auditLogsKey, theme: theme),
      ],
    );
  }
}

String _escapeCsv(String? s) {
  if (s == null || s.isEmpty) return '';
  if (s.contains(',') || s.contains('"') || s.contains('\n')) {
    return '"${s.replaceAll('"', '""')}"';
  }
  return s;
}

void _showAdminSnack(
  BuildContext context,
  String message, {
  bool isError = false,
}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message, style: const TextStyle(fontSize: 13)),
      backgroundColor: isError ? kAccentOrange : kPrimaryGreen,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.all(16),
      duration: const Duration(seconds: 2),
    ),
  );
}

Future<bool?> _showAdminConfirmDialog({
  required BuildContext context,
  required String title,
  required String content,
  required String actionLabel,
  required Color actionColor,
}) {
  return showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        title,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
      content: Text(content, style: const TextStyle(fontSize: 13)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(
            'Cancel',
            style: TextStyle(color: Theme.of(ctx).colorScheme.onSurfaceVariant),
          ),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: FilledButton.styleFrom(
            backgroundColor: actionColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          ),
          child: Text(actionLabel, style: const TextStyle(fontSize: 13)),
        ),
      ],
    ),
  );
}

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

  _DateRangeFilter _insightsRange = _DateRangeFilter.monthly;
  List<AdminStatPoint> _userGrowthPoints = [];
  List<AdminStatPoint> _postFrequencyPoints = [];
  List<AdminStatPoint> _chatbotInteractionPoints = [];
  bool _analyticsLoading = true;
  String? _analyticsError;
  bool _exportingInsightsCsv = false;
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
      final res = await AdminAuditLogService.instance.fetchLogs(page: 1);
      if (!mounted) return;
      setState(() {
        _auditLogs = res.logs;
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
        _analyticsError = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _exportInsightsCsv() async {
    if (_exportingInsightsCsv) return;
    setState(() => _exportingInsightsCsv = true);
    try {
      final filteredUsersResult = await AdminUserService.instance.fetchUsers(
        range: _insightsRange.apiValue,
      );
      final filteredReports = await AdminModerationService.instance.fetchReports(
        range: _insightsRange.apiValue,
      );
      final allRecipes = <Recipe>[];
      for (var page = 1; page <= 5; page++) {
        final res = await RecipeService.instance.fetchRecipes(
          page: page,
          range: _insightsRange.apiValue,
        );
        allRecipes.addAll(res.recipes);
        if (res.recipes.length < 10) break;
      }
      allRecipes.sort((a, b) {
        final aCount = a.ratingsCount ?? 0;
        final bCount = b.ratingsCount ?? 0;
        if (aCount != bCount) return bCount.compareTo(aCount);
        return (b.averageRating ?? 0).compareTo(a.averageRating ?? 0);
      });
      final rows = <String>[
        'Metric,Value',
        'Range,${_insightsRange.label}',
        'Total Users,${filteredUsersResult.total}',
        'Active Users,${filteredUsersResult.activeTotal}',
        'Total Recipes,${allRecipes.length}',
        'Open Reports,${filteredReports.length}',
      ];
      final bytes = Uint8List.fromList(rows.join('\n').codeUnits);
      final xfile = XFile.fromData(
        bytes,
        name: 'Admin Insights Export.csv',
        mimeType: 'text/csv',
      );
      await Share.shareXFiles([xfile], subject: 'WellNest Admin Insights Report');
      if (!mounted) return;
      _showAdminSnack(context, 'Insights report exported');
    } catch (e) {
      if (!mounted) return;
      _showAdminSnack(
        context,
        e.toString().replaceFirst('Exception: ', ''),
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _exportingInsightsCsv = false);
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
      analyticsLoading: _analyticsLoading,
      analyticsError: _analyticsError,
      userGrowthPoints: _userGrowthPoints,
      postFrequencyPoints: _postFrequencyPoints,
      chatbotInteractionPoints: _chatbotInteractionPoints,
      exportingInsightsCsv: _exportingInsightsCsv,
      selectedInsightsRange: _insightsRange,
      onInsightsRangeChanged: (range) {
        setState(() => _insightsRange = range);
        _loadAnalytics();
      },
      onExportInsights: _exportInsightsCsv,
      rankingsRefreshNonce: _rankingsRefreshNonce,
    );
  }

  @override
  bool get wantKeepAlive => true;
}

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
  _DateRangeFilter _insightsRange = _DateRangeFilter.monthly;
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
    await Future.wait<void>([_loadAnalytics(), _loadReports(), _loadAuditLogs(), _loadUsers()]);
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
        _analyticsError = e.toString().replaceFirst('Exception: ', '');
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
  bool _exportingUsersCsv = false;

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
        _error = e.toString().replaceFirst('Exception: ', '');
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
        _error = e.toString().replaceFirst('Exception: ', '');
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
        child: FutureBuilder<List<Post>>(
          future: ApiService().fetchPosts(userId: user.id),
          builder: (ctx, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const _ModalLoading();
            }
            if (snapshot.hasError) return _ModalError(message: snapshot.error.toString());
            final posts = snapshot.data ?? [];
            if (posts.isEmpty) {
              return const _ModalEmpty(message: 'This user has not created any posts yet.');
            }
            return _PostsModalContent(posts: posts);
          },
        ),
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
      _showAdminSnack(
        context,
        e.toString().replaceFirst('Exception: ', ''),
        isError: true,
      );
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
      _showAdminSnack(context, e.toString().replaceFirst('Exception: ', ''), isError: true);
    }
  }

  Future<void> _exportUsersCsv() async {
    if (_exportingUsersCsv) return;
    setState(() => _exportingUsersCsv = true);
    try {
      final rows = <String>['id,name,email,status'];
      for (final u in _users) {
        rows.add(
          '${u.id},${_escapeCsv(u.name)},${_escapeCsv(u.email)},${_escapeCsv(u.status)}',
        );
      }
      final xfile = XFile.fromData(
        Uint8List.fromList(rows.join('\n').codeUnits),
        name: 'WellNest Users.csv',
        mimeType: 'text/csv',
      );
      await Share.shareXFiles([xfile], subject: 'WellNest Users Export');
      if (!mounted) return;
      _showAdminSnack(context, 'Users exported');
    } catch (e) {
      if (!mounted) return;
      _showAdminSnack(context, e.toString().replaceFirst('Exception: ', ''), isError: true);
    } finally {
      if (mounted) setState(() => _exportingUsersCsv = false);
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
      onExport: _exportingUsersCsv ? null : _exportUsersCsv,
      exporting: _exportingUsersCsv,
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

class _ModerationSectionContainer extends StatefulWidget {
  final ThemeData theme;
  const _ModerationSectionContainer({super.key, required this.theme});

  @override
  State<_ModerationSectionContainer> createState() =>
      _ModerationSectionContainerState();
}

class _ModerationSectionContainerState extends State<_ModerationSectionContainer>
    with AutomaticKeepAliveClientMixin {
  List<Report> _reports = [];
  bool _loading = true;
  String? _error;
  _DateRangeFilter _range = _DateRangeFilter.monthly;
  bool _exportingReportsCsv = false;

  @override
  void initState() {
    super.initState();
    refresh();
  }

  Future<void> refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final reports = await AdminModerationService.instance.fetchReports(
        range: _range.apiValue,
      );
      if (!mounted) return;
      setState(() {
        _reports = reports;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _exportReportsCsv() async {
    if (_exportingReportsCsv) return;
    setState(() => _exportingReportsCsv = true);
    try {
      final rows = <String>[
        'id,reporter,reason,details,status,created_at,reportable_type,reportable_id,reportable_label',
      ];
      for (final r in _reports) {
        rows.add(
          [
            r.id,
            _escapeCsv(r.reporter),
            _escapeCsv(r.reason),
            _escapeCsv(r.details),
            _escapeCsv(r.status),
            _escapeCsv(r.createdAt),
            _escapeCsv(r.reportable?.type ?? ''),
            r.reportable?.id ?? 0,
            _escapeCsv(r.reportableLabel),
          ].join(','),
        );
      }
      final xfile = XFile.fromData(
        Uint8List.fromList(rows.join('\n').codeUnits),
        name: 'Content Reports Export.csv',
        mimeType: 'text/csv',
      );
      await Share.shareXFiles([xfile], subject: 'WellNest Content Reports Export');
      if (!mounted) return;
      _showAdminSnack(context, 'Reports exported');
    } catch (e) {
      if (!mounted) return;
      _showAdminSnack(context, e.toString().replaceFirst('Exception: ', ''), isError: true);
    } finally {
      if (mounted) setState(() => _exportingReportsCsv = false);
    }
  }

  Future<void> _confirmDeleteAllReports() async {
    final ok = await _showAdminConfirmDialog(
      context: context,
      title: 'Delete all reports?',
      content: 'Permanently delete all pending reports? This cannot be undone.',
      actionLabel: 'Delete All',
      actionColor: Colors.red,
    );
    if (ok != true) return;
    try {
      await AdminModerationService.instance.deleteAllReports();
      if (!mounted) return;
      _showAdminSnack(context, 'All reports deleted');
      await refresh();
    } catch (e) {
      if (!mounted) return;
      _showAdminSnack(context, e.toString().replaceFirst('Exception: ', ''), isError: true);
    }
  }

  Future<void> _handleReportAction(int reportId, String action) async {
    try {
      switch (action) {
        case 'dismiss':
          await AdminModerationService.instance.dismiss(reportId);
          break;
        case 'approve':
          await AdminModerationService.instance.approve(reportId);
          break;
        case 'remove-content':
          await AdminModerationService.instance.removeContent(reportId);
          break;
        case 'suspend-user':
          await AdminModerationService.instance.suspendUser(reportId);
          break;
      }
      if (!mounted) return;
      _showAdminSnack(context, 'Report updated');
      await refresh();
    } catch (e) {
      if (!mounted) return;
      _showAdminSnack(context, e.toString().replaceFirst('Exception: ', ''), isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return _ModerationSection(
      theme: widget.theme,
      reports: _reports,
      loading: _loading,
      error: _error,
      selectedRange: _range,
      onRangeChanged: (range) {
        setState(() => _range = range);
        refresh();
      },
      onRefresh: refresh,
      onExport: _exportingReportsCsv ? null : _exportReportsCsv,
      exporting: _exportingReportsCsv,
      onDeleteAll: _confirmDeleteAllReports,
      onReportAction: _handleReportAction,
    );
  }

  @override
  bool get wantKeepAlive => true;
}

class _AuditLogsSectionContainer extends StatefulWidget {
  final ThemeData theme;
  const _AuditLogsSectionContainer({super.key, required this.theme});

  @override
  State<_AuditLogsSectionContainer> createState() =>
      _AuditLogsSectionContainerState();
}

class _AuditLogsSectionContainerState extends State<_AuditLogsSectionContainer>
    with AutomaticKeepAliveClientMixin {
  List<ActivityLog> _logs = [];
  bool _loading = true;
  String? _error;
  _DateRangeFilter _range = _DateRangeFilter.monthly;
  bool _exportingAuditLogsCsv = false;

  @override
  void initState() {
    super.initState();
    refresh();
  }

  Future<void> refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await AdminAuditLogService.instance.fetchLogs(
        page: 1,
        range: _range.apiValue,
      );
      if (!mounted) return;
      setState(() {
        _logs = res.logs;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _exportAuditLogsCsv() async {
    if (_exportingAuditLogsCsv) return;
    setState(() => _exportingAuditLogsCsv = true);
    try {
      final bytes = await AdminAuditLogService.instance.exportCsv(
        range: _range.apiValue,
      );
      final xfile = XFile.fromData(
        Uint8List.fromList(bytes),
        name: 'audit_logs_export.csv',
        mimeType: 'text/csv',
      );
      await Share.shareXFiles([xfile], subject: 'WellNest Audit Logs Export');
      if (!mounted) return;
      _showAdminSnack(context, 'Audit logs exported');
    } catch (e) {
      if (!mounted) return;
      _showAdminSnack(context, e.toString().replaceFirst('Exception: ', ''), isError: true);
    } finally {
      if (mounted) setState(() => _exportingAuditLogsCsv = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return _AuditLogsSection(
      theme: widget.theme,
      logs: _logs,
      loading: _loading,
      error: _error,
      exporting: _exportingAuditLogsCsv,
      selectedRange: _range,
      onRangeChanged: (range) {
        setState(() => _range = range);
        refresh();
      },
      onRefresh: refresh,
      onExport: _exportAuditLogsCsv,
    );
  }

  @override
  bool get wantKeepAlive => true;
}

// ─── Web Modal Shell ──────────────────────────────────────────────────────────
