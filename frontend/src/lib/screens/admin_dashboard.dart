import 'package:flutter/material.dart';
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
import 'package:my_app/widgets/master_user_table.dart';
import 'package:my_app/theme/app_theme.dart';
import 'package:my_app/theme/app_spacing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:provider/provider.dart';
import 'package:my_app/providers/theme_provider.dart';
import 'package:simple_rich_text/simple_rich_text.dart';

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

class _AdminDashboardState extends State<AdminDashboard>
    with SingleTickerProviderStateMixin {
  // ── state ──────────────────────────────────────────────────────────────────
  _Section _currentSection = _Section.overview;
  bool _sidebarCollapsed = false;

  List<AdminUser> _users = [];
  bool _loading = true;
  String? _error;
  String _searchQuery = '';
  _DateRangeFilter _usersRange = _DateRangeFilter.monthly;

  List<Report> _reports = [];
  bool _reportsLoading = true;
  String? _reportsError;
  _DateRangeFilter _reportsRange = _DateRangeFilter.monthly;

  int _recipeTotal = 0;
  bool _recipeTotalLoading = true;

  List<ActivityLog> _auditLogs = [];
  bool _logsLoading = true;
  String? _logsError;
  _DateRangeFilter _logsRange = _DateRangeFilter.monthly;
  _DateRangeFilter _insightsRange = _DateRangeFilter.monthly;
  List<AdminStatPoint> _userGrowthPoints = [];
  List<AdminStatPoint> _postFrequencyPoints = [];
  List<AdminStatPoint> _chatbotInteractionPoints = [];
  bool _analyticsLoading = true;
  String? _analyticsError;

  bool _exportingReportsCsv = false;
  bool _exportingInsightsCsv = false;
  bool _exportingUsersCsv = false;
  bool _exportingAuditLogsCsv = false;
  bool _hasLoadedAllOnce = false;
  int _rankingsRefreshNonce = 0;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    await Future.wait<void>([
      _loadUsers(),
      _loadReports(),
      _loadRecipeTotal(),
      _loadAuditLogs(),
      _loadAnalytics(),
    ]);
    if (!mounted) return;
    if (_hasLoadedAllOnce) {
      setState(() => _rankingsRefreshNonce++);
    } else {
      _hasLoadedAllOnce = true;
    }
  }

  // ── loaders ────────────────────────────────────────────────────────────────
  Future<void> _loadReports() async {
    if (!mounted) return;
    setState(() {
      _reportsLoading = true;
      _reportsError = null;
    });
    try {
      final list = await AdminModerationService.instance.fetchReports(
        range: _reportsRange.apiValue,
      );
      if (!mounted) return;
      setState(() {
        _reports = list;
        _reportsLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _reportsError = e.toString().replaceFirst('Exception: ', '');
        _reportsLoading = false;
      });
    }
  }

  Future<void> _loadUsers() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await AdminUserService.instance.fetchUsers(
        range: _usersRange.apiValue,
      );
      if (!mounted) return;
      setState(() {
        _users = list;
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

  Future<void> _loadRecipeTotal() async {
    if (!mounted) return;
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
    if (!mounted) return;
    setState(() {
      _logsLoading = true;
      _logsError = null;
    });
    try {
      final res = await AdminAuditLogService.instance.fetchLogs(
        page: 1,
        range: _logsRange.apiValue,
      );
      if (!mounted) return;
      setState(() {
        _auditLogs = res.logs;
        _logsLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _logsError = e.toString().replaceFirst('Exception: ', '');
        _logsLoading = false;
      });
    }
  }

  Future<void> _loadAnalytics() async {
    if (!mounted) return;
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

  void _handleInsightsRangeChanged(_DateRangeFilter range) {
    setState(() => _insightsRange = range);
    _loadAnalytics();
  }

  // ── CSV helpers ────────────────────────────────────────────────────────────
  String _escapeCsv(String? s) {
    if (s == null || s.isEmpty) return '';
    if (s.contains(',') || s.contains('"') || s.contains('\n')) {
      return '"${s.replaceAll('"', '""')}"';
    }
    return s;
  }

  Future<void> _exportReportsCsv() async {
    if (_exportingReportsCsv) return;
    setState(() => _exportingReportsCsv = true);
    try {
      final rows = <String>[
        'id,reporter,reason,details,status,created_at,reportable_type,reportable_id,reportable_label',
      ];
      for (final r in _reports) {
        final type = r.reportable?.type ?? '';
        final id = r.reportable?.id ?? 0;
        final label = r.reportableLabel
            .replaceAll(',', ' ')
            .replaceAll('\n', ' ');
        rows.add(
          [
            r.id,
            _escapeCsv(r.reporter),
            _escapeCsv(r.reason),
            _escapeCsv(r.details),
            _escapeCsv(r.status),
            _escapeCsv(r.createdAt),
            _escapeCsv(type),
            id,
            _escapeCsv(label),
          ].join(','),
        );
      }
      final csv = rows.join('\n');
      final bytes = Uint8List.fromList(csv.codeUnits);
      final xfile = XFile.fromData(
        bytes,
        name: 'Content Reports Export.csv',
        mimeType: 'text/csv',
      );
      await Share.shareXFiles([xfile], subject: 'WellNest Content Reports Export');
      if (!mounted) return;
      _showSnack('Reports exported');
    } catch (e) {
      if (!mounted) return;
      _showSnack(e.toString().replaceFirst('Exception: ', ''), isError: true);
    } finally {
      if (mounted) setState(() => _exportingReportsCsv = false);
    }
  }

  Future<void> _exportInsightsCsv() async {
    if (_exportingInsightsCsv) return;
    setState(() => _exportingInsightsCsv = true);
    try {
      final filteredUsers = await AdminUserService.instance.fetchUsers(
        range: _insightsRange.apiValue,
      );
      final filteredReports = await AdminModerationService.instance
          .fetchReports(range: _insightsRange.apiValue);

      final totalUsers = filteredUsers.length;
      final activeUsers = filteredUsers.where((u) => u.isActive).length;

      final allRecipes = <Recipe>[];
      for (var page = 1; page <= 5; page++) {
        final res = await RecipeService.instance.fetchRecipes(
          page: page,
          range: _insightsRange.apiValue,
        );
        allRecipes.addAll(res.recipes);
        if (res.recipes.length < 10) break;
      }
      final totalRecipes = allRecipes.length;

      allRecipes.sort((a, b) {
        final aCount = a.ratingsCount ?? 0;
        final bCount = b.ratingsCount ?? 0;
        if (aCount != bCount) return bCount.compareTo(aCount);
        return (b.averageRating ?? 0).compareTo(a.averageRating ?? 0);
      });
      final topRecipes = allRecipes.take(25).toList();
      final rows = <String>[
        'Metric,Value',
        'Range,${_insightsRange.label}',
        'Total Users,$totalUsers',
        'Active Users,$activeUsers',
        'Total Recipes,$totalRecipes',
        'Open Reports,${filteredReports.length}',
        '',
        'Most Popular Recipes',
        'rank,id,title,category,average_rating,ratings_count',
      ];
      for (var i = 0; i < topRecipes.length; i++) {
        final r = topRecipes[i];
        final cat = r.category?.name ?? '';
        final avg = r.averageRating?.toStringAsFixed(1) ?? '0';
        final cnt = r.ratingsCount ?? 0;
        rows.add(
          '${i + 1},${r.id},${_escapeCsv(r.title)},${_escapeCsv(cat)},$avg,$cnt',
        );
      }
      final csv = rows.join('\n');
      final bytes = Uint8List.fromList(csv.codeUnits);
      final xfile = XFile.fromData(
        bytes,
        name: 'Admin Insights Export.csv',
        mimeType: 'text/csv',
      );
      await Share.shareXFiles([xfile], subject: 'WellNest Admin Insights Report');
      if (!mounted) return;
      _showSnack('Insights report exported');
    } catch (e) {
      if (!mounted) return;
      _showSnack(e.toString().replaceFirst('Exception: ', ''), isError: true);
    } finally {
      if (mounted) setState(() => _exportingInsightsCsv = false);
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
      final csv = rows.join('\n');
      final bytes = Uint8List.fromList(csv.codeUnits);
      final xfile = XFile.fromData(
        bytes,
        name: 'WellNest Users.csv',
        mimeType: 'text/csv',
      );
      await Share.shareXFiles([xfile], subject: 'WellNest Users Export');
      if (!mounted) return;
      _showSnack('Users exported');
    } catch (e) {
      if (!mounted) return;
      _showSnack(e.toString().replaceFirst('Exception: ', ''), isError: true);
    } finally {
      if (mounted) setState(() => _exportingUsersCsv = false);
    }
  }

  Future<void> _showUserActivitySheet(AdminUser user, {bool commentsOnly = false}) async {
    final postsFuture = ApiService().fetchPosts(userId: user.id);
    final comments = _mockUserComments(user);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.82,
        minChildSize: 0.6,
        maxChildSize: 0.92,
        builder: (context, scrollController) => _UserActivitySheet(
          user: user,
          postsFuture: postsFuture,
          comments: comments,
          commentsOnly: commentsOnly,
          scrollController: scrollController,
        ),
      ),
    );
  }

  List<PostComment> _mockUserComments(AdminUser user) {
    final now = DateTime.now();
    return [
      PostComment(
        id: 1,
        comment: 'Shared a note about balancing meal prep with busy schedules.',
        userName: user.name,
        createdAt: now.subtract(const Duration(days: 3)).toIso8601String(),
      ),
      PostComment(
        id: 2,
        comment: 'Answered a question about seasonal recipes in the community feed.',
        userName: user.name,
        createdAt: now.subtract(const Duration(days: 11)).toIso8601String(),
      ),
      PostComment(
        id: 3,
        comment: 'Reviewed a wellness post with a thoughtful suggestion.',
        userName: user.name,
        createdAt: now.subtract(const Duration(days: 18)).toIso8601String(),
      ),
    ];
  }

  Future<void> _exportAuditLogsCsv() async {
    if (_exportingAuditLogsCsv) return;
    setState(() => _exportingAuditLogsCsv = true);
    try {
      final bytes = await AdminAuditLogService.instance.exportCsv(
        range: _logsRange.apiValue,
      );
      final xfile = XFile.fromData(
        Uint8List.fromList(bytes),
        name: 'audit_logs_export.csv',
        mimeType: 'text/csv',
      );
      await Share.shareXFiles([xfile], subject: 'WellNest Audit Logs Export');
      if (!mounted) return;
      _showSnack('Audit logs exported');
    } catch (e) {
      if (!mounted) return;
      _showSnack(e.toString().replaceFirst('Exception: ', ''), isError: true);
    } finally {
      if (mounted) setState(() => _exportingAuditLogsCsv = false);
    }
  }

  // ── user actions ───────────────────────────────────────────────────────────
  List<AdminUser> get _filteredUsers {
    if (_searchQuery.trim().isEmpty) return _users;
    final q = _searchQuery.trim().toLowerCase();
    return _users
        .where(
          (u) =>
              u.email.toLowerCase().contains(q) ||
              u.name.toLowerCase().contains(q),
        )
        .toList();
  }

  Future<void> _confirmDeactivate(AdminUser user) async {
    final ok = await _showConfirmDialog(
      title: 'Suspend account?',
      content: SimpleRichText(
        'Suspend *${user.name}*? They will not be able to sign in until an admin reactivates the account.',
      ),
      actionLabel: 'Suspend',
      actionColor: kAccentOrange,
    );
    if (ok != true || !mounted) return;
    await _updateStatus(user.id, 'suspended');
  }

  Future<void> _confirmActivate(AdminUser user) async {
    final ok = await _showConfirmDialog(
      title: 'Unsuspend account?',
      content: SimpleRichText(
        'Unsuspend *${user.name}*? They will be able to sign in again.',
      ),
      actionLabel: 'Unsuspend',
      actionColor: kPrimaryGreen,
    );
    if (ok != true || !mounted) return;
    await _updateStatus(user.id, 'active');
  }

  Future<void> _updateStatus(int userId, String status) async {
    try {
      await AdminUserService.instance.updateUserStatus(userId, status);
      if (!mounted) return;
      _showSnack(
        status == 'active' ? 'Account unsuspended' : 'Account suspended',
      );
      _loadUsers();
    } catch (e) {
      if (!mounted) return;
      _showSnack(e.toString().replaceFirst('Exception: ', ''), isError: true);
    }
  }

  Future<void> _confirmDelete(AdminUser user) async {
    final ok = await _showConfirmDialog(
      title: 'Delete account permanently?',
      content: SimpleRichText(
        'Permanently delete *${user.name}*? This cannot be undone.\n'
        'If this account still has recipes, posts, or comments, deletion will be blocked.',
      ),
      actionLabel: 'Delete',
      actionColor: Colors.red,
    );
    if (ok != true || !mounted) return;
    try {
      await AdminUserService.instance.deleteUser(user.id);
      if (!mounted) return;
      _showSnack('Account deleted');
      _loadUsers();
    } catch (e) {
      if (!mounted) return;

      if (e is AdminApiException &&
          e.statusCode == 403 &&
          e.message.contains('existing contributions')) {
        await showDialog<void>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Delete blocked'),
            content: Text(e.message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        return;
      }

      _showSnack(e.toString().replaceFirst('Exception: ', ''), isError: true);
    }
  }

  Future<void> _confirmDeleteAllReports() async {
    final ok = await _showConfirmDialog(
      title: 'Delete all reports?',
      content: 'Permanently delete all pending reports? This cannot be undone.',
      actionLabel: 'Delete All',
      actionColor: Colors.red,
    );
    if (ok != true || !mounted) return;
    try {
      await AdminModerationService.instance.deleteAllReports();
      if (!mounted) return;
      _showSnack('All reports deleted');
      _loadReports();
    } catch (e) {
      if (!mounted) return;
      _showSnack(e.toString().replaceFirst('Exception: ', ''), isError: true);
    }
  }

  Future<bool?> _showConfirmDialog({
    required String title,
    required dynamic content,
    required String actionLabel,
    required Color actionColor,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: Theme.of(ctx).colorScheme.onSurfaceVariant)),
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

  Future<void> _handleReportAction(int reportId, String action) async {
    try {
      switch (action) {
        case 'dismiss':
          await AdminModerationService.instance.dismiss(reportId);
          if (!mounted) return;
          _showSnack('Report dismissed');
          break;
        case 'approve':
          await AdminModerationService.instance.approve(reportId);
          if (!mounted) return;
          _showSnack('Report approved');
          break;
        case 'remove-content':
          await AdminModerationService.instance.removeContent(reportId);
          if (!mounted) return;
          _showSnack('Content removed');
          break;
        case 'suspend-user':
          await AdminModerationService.instance.suspendUser(reportId);
          if (!mounted) return;
          _showSnack('User suspended');
          break;
      }
      _loadReports();
    } catch (e) {
      if (!mounted) return;
      _showSnack(e.toString().replaceFirst('Exception: ', ''), isError: true);
    }
  }

  void _showSnack(String message, {bool isError = false}) {
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

  // ── build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isWide = MediaQuery.sizeOf(context).width >= 800;
    final dashboardTextTheme = theme.textTheme.copyWith(
      bodySmall: (theme.textTheme.bodySmall ?? const TextStyle())
          .copyWith(fontSize: 13, fontWeight: FontWeight.w500),
      bodyMedium: (theme.textTheme.bodyMedium ?? const TextStyle())
          .copyWith(fontSize: 14, fontWeight: FontWeight.w500),
      bodyLarge: (theme.textTheme.bodyLarge ?? const TextStyle())
          .copyWith(fontSize: 16, fontWeight: FontWeight.w600),
      titleSmall: (theme.textTheme.titleSmall ?? const TextStyle())
          .copyWith(fontSize: 14, fontWeight: FontWeight.w600),
      titleMedium: (theme.textTheme.titleMedium ?? const TextStyle())
          .copyWith(fontSize: 16, fontWeight: FontWeight.w700),
      titleLarge: (theme.textTheme.titleLarge ?? const TextStyle())
          .copyWith(fontSize: 18, fontWeight: FontWeight.w700),
      labelMedium: (theme.textTheme.labelMedium ?? const TextStyle())
          .copyWith(fontSize: 13, fontWeight: FontWeight.w600),
      labelSmall: (theme.textTheme.labelSmall ?? const TextStyle())
          .copyWith(fontSize: 12, fontWeight: FontWeight.w600),
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

  // ── wide layout ────────────────────────────────────────────────────────────
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
                onRefresh: _loadAll,
                onToggleTheme: _toggleTheme,
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async => _loadAll(),
                  color: kPrimaryGreen,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(24),
                    child: _buildSectionContent(theme, isWide: true),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── narrow layout ──────────────────────────────────────────────────────────
  Widget _buildNarrowLayout(ThemeData theme) {
    return Column(
      children: [
        _TopBar(
          theme: theme,
          currentSection: _currentSection,
          onRefresh: _loadAll,
          showMenuButton: true,
          onMenuPressed: _handleLogout,
          onToggleTheme: _toggleTheme,
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async => _loadAll(),
            color: kPrimaryGreen,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: _buildSectionContent(theme, isWide: false),
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
    if (!context.mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/login', (r) => false);
  }

  void _toggleTheme() {
    context.read<ThemeProvider>().toggleTheme();
  }

  // ── section content router ─────────────────────────────────────────────────
  Widget _buildSectionContent(ThemeData theme, {required bool isWide}) {
    switch (_currentSection) {
      case _Section.overview:
        return _OverviewSection(
          theme: theme,
          isWide: isWide,
          users: _users,
          loading: _loading,
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
          onInsightsRangeChanged: _handleInsightsRangeChanged,
          onExportInsights: _exportInsightsCsv,
          rankingsRefreshNonce: _rankingsRefreshNonce,
        );
      case _Section.analytics:
        return _AnalyticsSection(
          theme: theme,
          isWide: isWide,
          users: _users,
          reports: _reports,
          auditLogs: _auditLogs,
          analyticsLoading: _analyticsLoading,
          analyticsError: _analyticsError,
          userGrowthPoints: _userGrowthPoints,
          postFrequencyPoints: _postFrequencyPoints,
          chatbotInteractionPoints: _chatbotInteractionPoints,
          selectedInsightsRange: _insightsRange,
          onInsightsRangeChanged: _handleInsightsRangeChanged,
          onRefresh: () => _loadAnalytics(),
        );
      case _Section.users:
        return _UsersSection(
          theme: theme,
          users: _filteredUsers,
          loading: _loading,
          error: _error,
          searchQuery: _searchQuery,
          onSearchChanged: (v) => setState(() => _searchQuery = v),
          selectedRange: _usersRange,
          onRangeChanged: (range) {
            setState(() => _usersRange = range);
            _loadUsers();
          },
          onRefresh: _loadUsers,
          onExport: _exportingUsersCsv ? null : _exportUsersCsv,
          exporting: _exportingUsersCsv,
          onDeactivate: _confirmDeactivate,
          onActivate: _confirmActivate,
          onDelete: _confirmDelete,
          onUserTap: _showUserActivitySheet,
          onViewPosts: (user) => _showUserActivitySheet(user, commentsOnly: false),
          onViewComments: (user) => _showUserActivitySheet(user, commentsOnly: true),
        );
      case _Section.moderation:
        return _ModerationSection(
          theme: theme,
          reports: _reports,
          loading: _reportsLoading,
          error: _reportsError,
          selectedRange: _reportsRange,
          onRangeChanged: (range) {
            setState(() => _reportsRange = range);
            _loadReports();
          },
          onRefresh: _loadReports,
          onExport: _exportingReportsCsv ? null : _exportReportsCsv,
          exporting: _exportingReportsCsv,
          onDeleteAll: _confirmDeleteAllReports,
          onReportAction: _handleReportAction,
        );
      case _Section.auditLogs:
        return _AuditLogsSection(
          theme: theme,
          logs: _auditLogs,
          loading: _logsLoading,
          error: _logsError,
          selectedRange: _logsRange,
          exporting: _exportingAuditLogsCsv,
          onRangeChanged: (range) {
            setState(() => _logsRange = range);
            _loadAuditLogs();
          },
          onRefresh: _loadAuditLogs,
          onExport: _exportAuditLogsCsv,
        );
    }
  }
}

// ─── Sidebar ──────────────────────────────────────────────────────────────────
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
                        child: const Icon(Icons.eco_rounded, color: Colors.white, size: 16),
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
                            style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    InkWell(
                      onTap: onToggleCollapsed,
                      borderRadius: BorderRadius.circular(6),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(Icons.chevron_left_rounded, size: 18, color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ),
                  ] else ...[
                    const Spacer(),
                    InkWell(
                      onTap: onToggleCollapsed,
                      borderRadius: BorderRadius.circular(6),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(Icons.chevron_right_rounded, size: 18, color: theme.colorScheme.onSurfaceVariant),
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
                  color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                ),
              ),
            ),
          _NavItem(section: _Section.overview, currentSection: currentSection, icon: Icons.grid_view_rounded, label: 'Overview', collapsed: collapsed, onTap: onSectionChanged, theme: theme),
          _NavItem(section: _Section.analytics, currentSection: currentSection, icon: Icons.insights_outlined, label: 'Analytics', collapsed: collapsed, onTap: onSectionChanged, theme: theme),
          _NavItem(section: _Section.users, currentSection: currentSection, icon: Icons.people_outline_rounded, label: 'Users', collapsed: collapsed, onTap: onSectionChanged, theme: theme),
          _NavItem(section: _Section.moderation, currentSection: currentSection, icon: Icons.shield_outlined, label: 'Moderation', collapsed: collapsed, onTap: onSectionChanged, theme: theme),
          _NavItem(section: _Section.auditLogs, currentSection: currentSection, icon: Icons.history_rounded, label: 'Audit Logs', collapsed: collapsed, onTap: onSectionChanged, theme: theme),
          const Spacer(),
          Divider(height: 0.5, color: borderColor),
          InkWell(
            onTap: onLogout,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: collapsed ? 0 : 16, vertical: 14),
              child: Row(
                mainAxisAlignment: collapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
                children: [
                  Icon(Icons.logout_rounded, size: 16, color: kAccentOrange),
                  if (!collapsed) ...[
                    const SizedBox(width: 10),
                    Text('Logout', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: kAccentOrange)),
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
          margin: EdgeInsets.symmetric(horizontal: collapsed ? 8 : 10, vertical: 1),
          padding: EdgeInsets.symmetric(horizontal: collapsed ? 0 : 12, vertical: 9),
          decoration: BoxDecoration(
            color: isActive ? kPrimaryGreen.withValues(alpha: isDark ? 0.18 : 0.08) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border(
              left: isActive
                  ? const BorderSide(color: kPrimaryGreen, width: 2.5)
                  : const BorderSide(color: Colors.transparent, width: 2.5),
            ),
          ),
          child: Row(
            mainAxisAlignment: collapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
            children: [
              Icon(
                icon,
                size: 17,
                color: isActive ? kPrimaryGreen : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
              ),
              if (!collapsed) ...[
                const SizedBox(width: 10),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                    color: isActive ? kPrimaryGreen : theme.colorScheme.onSurfaceVariant,
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

  const _BottomNav({required this.currentSection, required this.onSectionChanged, required this.theme});

  @override
  Widget build(BuildContext context) {
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161616) : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.07),
            width: 0.5,
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _BottomNavItem(icon: Icons.grid_view_rounded, label: 'Overview', section: _Section.overview, currentSection: currentSection, onTap: onSectionChanged),
          _BottomNavItem(icon: Icons.insights_outlined, label: 'Analytics', section: _Section.analytics, currentSection: currentSection, onTap: onSectionChanged),
          _BottomNavItem(icon: Icons.people_outline_rounded, label: 'Users', section: _Section.users, currentSection: currentSection, onTap: onSectionChanged),
          _BottomNavItem(icon: Icons.shield_outlined, label: 'Reports', section: _Section.moderation, currentSection: currentSection, onTap: onSectionChanged),
          _BottomNavItem(icon: Icons.history_rounded, label: 'Logs', section: _Section.auditLogs, currentSection: currentSection, onTap: onSectionChanged),
        ],
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: isActive ? kPrimaryGreen : Colors.grey.shade400),
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
      case _Section.overview: return 'Overview';
      case _Section.analytics: return 'Analytics';
      case _Section.users: return 'User Management';
      case _Section.moderation: return 'Content Moderation';
      case _Section.auditLogs: return 'Audit Logs';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = theme.brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF161616) : Colors.white;
    final borderColor = isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.07);

    return Container(
      height: _kTopBarHeight,
      decoration: BoxDecoration(color: bg, border: Border(bottom: BorderSide(color: borderColor, width: 0.5))),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          if (showMenuButton)
            IconButton(onPressed: onMenuPressed, icon: const Icon(Icons.logout_rounded, size: 18), color: kAccentOrange, tooltip: 'Logout')
          else
            Text(
              _title,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface, letterSpacing: -0.2),
            ),
          const Spacer(),
          _TopBarIconBtn(icon: Icons.refresh_rounded, onPressed: onRefresh, tooltip: 'Refresh', color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 2),
          _TopBarIconBtn(
            icon: isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
            onPressed: onToggleTheme,
            tooltip: isDark ? 'Light mode' : 'Dark mode',
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 2),
          NotificationsDropdown(
            iconColor: kAccentOrange,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                _TopBarIconBtn(icon: Icons.notifications_outlined, onPressed: null, tooltip: 'Notifications', color: kAccentOrange),
                Positioned(
                  top: 6, right: 6,
                  child: Container(width: 7, height: 7, decoration: const BoxDecoration(color: kAccentOrange, shape: BoxShape.circle)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 30, height: 30,
            decoration: BoxDecoration(color: kPrimaryGreen.withValues(alpha: 0.12), shape: BoxShape.circle),
            child: Center(
              child: Text('AD', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: kPrimaryGreen)),
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

  const _TopBarIconBtn({required this.icon, required this.onPressed, required this.tooltip, required this.color});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      icon: Icon(icon, size: 18, color: color),
      tooltip: tooltip,
      style: IconButton.styleFrom(minimumSize: const Size(34, 34), padding: EdgeInsets.zero),
    );
  }
}

// ─── Overview Section ─────────────────────────────────────────────────────────
class _OverviewSection extends StatelessWidget {
  final ThemeData theme;
  final bool isWide;
  final List<AdminUser> users;
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
    final activeUsers = users.where((u) => u.isActive).length;
    final openReports = reports.where((r) => _normalizeReportStatus(r.status) == 'open').length;
    final mealPlannerLogs = auditLogs.where((l) => l.category.toLowerCase() == 'meal_planner').toList();
    final mealPlannerActions = mealPlannerLogs.length;
    final userGrowthTrend = _formatTrend(_seriesPercentDelta(userGrowthPoints));
    final postGrowthTrend = _formatTrend(_seriesPercentDelta(postFrequencyPoints));
    final activeRatio = users.isEmpty ? 0 : ((activeUsers / users.length) * 100).round();
    final activeTrendText = users.isEmpty ? 'No data' : '$activeRatio% active';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Good day, Admin',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: theme.colorScheme.onSurface, letterSpacing: -0.4),
        ),
        const SizedBox(height: 3),
        Text(
          'Here\'s a snapshot of your WellNest community.',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 22),

        // ── Stat cards ──────────────────────────────────────────────────────
        isWide
            ? Row(children: [
                Expanded(child: _StatCard(theme: theme, title: 'Total Users', value: loading ? '—' : '${users.length}', icon: Icons.people_outline_rounded, color: const Color(0xFF3C6DF0), trend: userGrowthTrend, trendUp: _isTrendUp(userGrowthTrend))),
                const SizedBox(width: 12),
                Expanded(child: _StatCard(theme: theme, title: 'Active Users', value: loading ? '—' : '$activeUsers', icon: Icons.person_outline_rounded, color: kPrimaryGreen, trend: activeTrendText, trendUp: true)),
                const SizedBox(width: 12),
                Expanded(child: _StatCard(theme: theme, title: 'Total Recipes', value: recipeTotalLoading ? '—' : '$recipeTotal', icon: Icons.restaurant_menu_outlined, color: const Color(0xFFE6930A), trend: postGrowthTrend, trendUp: _isTrendUp(postGrowthTrend))),
                const SizedBox(width: 12),
                Expanded(child: _StatCard(theme: theme, title: 'Open Reports', value: reportsLoading ? '—' : '$openReports', icon: Icons.flag_outlined, color: kAccentOrange, trend: openReports > 0 ? 'Needs review' : 'All clear', trendUp: false)),
              ])
            : Column(children: [
                Row(children: [
                  Expanded(child: _StatCard(theme: theme, title: 'Total Users', value: loading ? '—' : '${users.length}', icon: Icons.people_outline_rounded, color: const Color(0xFF3C6DF0), trend: userGrowthTrend, trendUp: _isTrendUp(userGrowthTrend))),
                  const SizedBox(width: 10),
                  Expanded(child: _StatCard(theme: theme, title: 'Active Users', value: loading ? '—' : '$activeUsers', icon: Icons.person_outline_rounded, color: kPrimaryGreen, trend: activeTrendText, trendUp: true)),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: _StatCard(theme: theme, title: 'Total Recipes', value: recipeTotalLoading ? '—' : '$recipeTotal', icon: Icons.restaurant_menu_outlined, color: const Color(0xFFE6930A), trend: postGrowthTrend, trendUp: _isTrendUp(postGrowthTrend))),
                  const SizedBox(width: 10),
                  Expanded(child: _StatCard(theme: theme, title: 'Open Reports', value: reportsLoading ? '—' : '$openReports', icon: Icons.flag_outlined, color: kAccentOrange, trend: openReports > 0 ? 'Needs review' : 'All clear', trendUp: false)),
                ]),
              ]),

        const SizedBox(height: 24),

        // ── Charts section ──────────────────────────────────────────────────
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

        // ── Meal Planner summary ────────────────────────────────────────────
        _MinimalSectionLabel(theme: theme, label: 'Meal Planner Activity'),
        const SizedBox(height: 10),
        _SurfaceCard(
          theme: theme,
          child: Row(
            children: [
              Container(
                width: 38, height: 38,
                decoration: BoxDecoration(color: kPrimaryGreen.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.calendar_month_outlined, color: kPrimaryGreen, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Meal planner actions logged: $mealPlannerActions',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: theme.colorScheme.onSurface),
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

        // ── Export row ──────────────────────────────────────────────────────
        Row(children: [
          _DateRangeDropdown(value: selectedInsightsRange, onChanged: onInsightsRangeChanged),
          const SizedBox(width: 8),
          _GreenButton(
            label: exportingInsightsCsv ? 'Exporting…' : 'Export Insights',
            icon: Icons.download_rounded,
            loading: exportingInsightsCsv,
            onPressed: exportingInsightsCsv ? null : onExportInsights,
          ),
        ]),

        const SizedBox(height: 22),
        _MinimalSectionLabel(theme: theme, label: 'Recipe Rankings', subtitle: 'Views, ratings & combined score'),
        const SizedBox(height: 10),
        _OverviewRecipeRankingsCard(theme: theme, refreshNonce: rankingsRefreshNonce),

        const SizedBox(height: 22),
        _MinimalSectionLabel(theme: theme, label: 'Recent Activity', subtitle: 'Last 5 audit log events'),
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
class _ChartsSection extends StatelessWidget {
  final ThemeData theme;
  final List<AdminUser> users;
  final List<Report> reports;
  final List<ActivityLog> auditLogs;
  final bool analyticsLoading;
  final String? analyticsError;
  final List<AdminStatPoint> userGrowthPoints;
  final List<AdminStatPoint> postFrequencyPoints;
  final List<AdminStatPoint> chatbotInteractionPoints;
  final bool isWide;

  const _ChartsSection({
    required this.theme,
    required this.users,
    required this.reports,
    required this.auditLogs,
    required this.analyticsLoading,
    required this.analyticsError,
    required this.userGrowthPoints,
    required this.postFrequencyPoints,
    required this.chatbotInteractionPoints,
    required this.isWide,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = theme.brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _MinimalSectionLabel(theme: theme, label: 'Analytics', subtitle: 'Growth and platform activity trends'),
        const SizedBox(height: 12),
        isWide
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _UserGrowthCard(
                      theme: theme,
                      isDark: isDark,
                      userGrowthPoints: userGrowthPoints,
                      postFrequencyPoints: postFrequencyPoints,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _RecipeRatingsCard(
                      theme: theme,
                      isDark: isDark,
                      chatbotInteractionPoints: chatbotInteractionPoints,
                    ),
                  ),
                ],
              )
            : Column(children: [
                _UserGrowthCard(
                  theme: theme,
                  isDark: isDark,
                  userGrowthPoints: userGrowthPoints,
                  postFrequencyPoints: postFrequencyPoints,
                ),
                const SizedBox(height: 12),
                _RecipeRatingsCard(
                  theme: theme,
                  isDark: isDark,
                  chatbotInteractionPoints: chatbotInteractionPoints,
                ),
              ]),
        const SizedBox(height: 12),
        _HistoricalTrendsCard(theme: theme, isDark: isDark),
        const SizedBox(height: 12),
        isWide
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _ModerationDonutCard(theme: theme, isDark: isDark, reports: reports)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _AuditActivityCard(
                      theme: theme,
                      isDark: isDark,
                      userGrowthPoints: userGrowthPoints,
                      postFrequencyPoints: postFrequencyPoints,
                      chatbotInteractionPoints: chatbotInteractionPoints,
                    ),
                  ),
                ],
              )
            : Column(children: [
                _ModerationDonutCard(theme: theme, isDark: isDark, reports: reports),
                const SizedBox(height: 12),
                _AuditActivityCard(
                  theme: theme,
                  isDark: isDark,
                  userGrowthPoints: userGrowthPoints,
                  postFrequencyPoints: postFrequencyPoints,
                  chatbotInteractionPoints: chatbotInteractionPoints,
                ),
              ]),
        if (analyticsLoading) ...[
          const SizedBox(height: 10),
          LinearProgressIndicator(
            minHeight: 2,
            color: kPrimaryGreen,
            backgroundColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          ),
        ] else if (analyticsError != null && analyticsError!.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            analyticsError!,
            style: TextStyle(
              fontSize: 11,
              color: theme.colorScheme.error,
            ),
          ),
        ],
      ],
    );
  }
}

// ─── Chart Card Wrapper ───────────────────────────────────────────────────────
class _ChartCard extends StatelessWidget {
  final ThemeData theme;
  final String title;
  final String subtitle;
  final String badge;
  final bool badgeGreen;
  final List<Widget> legend;
  final Widget child;

  const _ChartCard({
    required this.theme,
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.badgeGreen,
    required this.legend,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = theme.brightness == Brightness.dark;
    // Use admin theme colors for better visual hierarchy
    final cardColor = isDark ? const Color(0xFF2D3748) : Colors.white;
    final borderColor = isDark
        ? const Color(0xFF4FD1C5).withValues(alpha: 0.12)
        : const Color(0xFF097333).withValues(alpha: 0.08);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(_kCardRadius),
        border: Border.all(
          color: borderColor,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.32)
                : const Color(0xFF097333).withValues(alpha: 0.08),
            blurRadius: isDark ? 20 : 14,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: isDark
                ? const Color(0xFF4FD1C5).withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.02),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Semantics(
        container: true,
        label: '$title - $subtitle',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.onSurface,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: theme.colorScheme.onSurfaceVariant,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: badgeGreen
                        ? const Color(0xFF48BB78).withValues(alpha: 0.12)
                        : const Color(0xFFECC94B).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: badgeGreen
                          ? const Color(0xFF48BB78).withValues(alpha: 0.3)
                          : const Color(0xFFECC94B).withValues(alpha: 0.3),
                      width: 0.8,
                    ),
                  ),
                  child: Text(
                    badge,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: badgeGreen ? const Color(0xFF48BB78) : const Color(0xFFECC94B),
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(spacing: 14, runSpacing: 8, children: legend),
            const SizedBox(height: 18),
            child,
          ],
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  final bool dashed;

  const _LegendDot({required this.color, required this.label, this.dashed = false});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Semantics(
      label: label,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dashed)
            CustomPaint(
              size: const Size(10, 9),
              painter: _DashedIndicatorPainter(color: color),
            )
          else
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2.5),
                border: Border.all(
                  color: isDark
                      ? color.withValues(alpha: 0.6)
                      : color.withValues(alpha: 0.3),
                  width: 0.5,
                ),
              ),
            ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Dashed indicator painter for legend ──────────────────────────────────────
class _DashedIndicatorPainter extends CustomPainter {
  final Color color;

  const _DashedIndicatorPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    const dashLen = 3.0;
    const gapLen = 2.0;
    double x = 0;

    while (x < size.width) {
      canvas.drawLine(
        Offset(x, size.height / 2),
        Offset(math.min(x + dashLen, size.width), size.height / 2),
        paint,
      );
      x += dashLen + gapLen;
    }
  }

  @override
  bool shouldRepaint(covariant _DashedIndicatorPainter old) => old.color != color;
}

// ─── User Growth Chart ────────────────────────────────────────────────────────
class _UserGrowthCard extends StatelessWidget {
  final ThemeData theme;
  final bool isDark;
  final List<AdminStatPoint> userGrowthPoints;
  final List<AdminStatPoint> postFrequencyPoints;
  const _UserGrowthCard({
    required this.theme,
    required this.isDark,
    required this.userGrowthPoints,
    required this.postFrequencyPoints,
  });

  @override
  Widget build(BuildContext context) {
    const pointsCount = 6;
    final chartPoints = userGrowthPoints.isNotEmpty
        ? userGrowthPoints
        : postFrequencyPoints;
    final labels = _buildDateLabels(chartPoints, pointsCount);
    final usersSeries = _normalizeSeries(userGrowthPoints, pointsCount);
    final postsSeries = _normalizeSeries(postFrequencyPoints, pointsCount);

    return _ChartCard(
      theme: theme,
      title: 'User growth',
      subtitle: 'Users and posts over time',
      badge: chartPoints.isEmpty ? 'No data' : 'Live',
      badgeGreen: true,
      legend: [
        const _LegendDot(color: Color(0xFF378ADD), label: 'New users'),
        _LegendDot(color: kPrimaryGreen, label: 'Posts', dashed: true),
      ],
      child: SizedBox(
        height: 160,
        child: CustomPaint(
          size: Size.infinite,
          painter: _LinePainter(
            seriesA: usersSeries,
            seriesB: postsSeries,
            colorA: const Color(0xFF378ADD),
            colorB: kPrimaryGreen,
            labels: labels,
            isDark: isDark,
          ),
        ),
      ),
    );
  }
}

// ─── Recipe Ratings Chart ─────────────────────────────────────────────────────
class _RecipeRatingsCard extends StatelessWidget {
  final ThemeData theme;
  final bool isDark;
  final List<AdminStatPoint> chatbotInteractionPoints;
  const _RecipeRatingsCard({
    required this.theme,
    required this.isDark,
    required this.chatbotInteractionPoints,
  });

  @override
  Widget build(BuildContext context) {
    const pointsCount = 5;
    final labels = _buildDateLabels(chatbotInteractionPoints, pointsCount);
    final values = _normalizeSeries(chatbotInteractionPoints, pointsCount);

    return _ChartCard(
      theme: theme,
      title: 'Chatbot interactions',
      subtitle: 'Messages started over time',
      badge: chatbotInteractionPoints.isEmpty ? 'No data' : 'Live',
      badgeGreen: true,
      legend: [
        const _LegendDot(color: Color(0xFF378ADD), label: 'Conversations'),
      ],
      child: SizedBox(
        height: 160,
        child: CustomPaint(
          size: Size.infinite,
          painter: _BarPainter(
            values: values,
            labels: labels,
            colors: const [
              Color(0xFF378ADD),
              Color(0xFF378ADD),
              Color(0xFF378ADD),
              Color(0xFF378ADD),
              Color(0xFF378ADD),
            ],
            isDark: isDark,
          ),
        ),
      ),
    );
  }
}

class _HistoricalTrendsCard extends StatelessWidget {
  final ThemeData theme;
  final bool isDark;

  const _HistoricalTrendsCard({required this.theme, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return _ChartCard(
      theme: theme,
      title: 'Historical trends',
      subtitle: 'Platform engagement over time',
      badge: 'Coming soon',
      badgeGreen: false,
      legend: const [
        _LegendDot(color: Color(0xFF4FD1C5), label: 'Platform engagement'),
      ],
      child: Container(
        height: 160,
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF1A2332).withValues(alpha: 0.5)
              : const Color(0xFFF9F8F5).withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark
                ? const Color(0xFF4FD1C5).withValues(alpha: 0.08)
                : const Color(0xFF097333).withValues(alpha: 0.06),
            width: 1,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.trending_up_rounded,
                size: 32,
                color: isDark
                    ? const Color(0xFF4FD1C5).withValues(alpha: 0.5)
                    : const Color(0xFF097333).withValues(alpha: 0.4),
              ),
              const SizedBox(height: 10),
              Text(
                'Historical data will be available',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: isDark
                      ? const Color(0xFF888780).withValues(alpha: 0.7)
                      : const Color(0xFF888780),
                  letterSpacing: 0.1,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'Connect a historical data source',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w400,
                  color: isDark
                      ? const Color(0xFF888780).withValues(alpha: 0.5)
                      : const Color(0xFF999999),
                  letterSpacing: 0.05,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Moderation Donut Chart ───────────────────────────────────────────────────
class _ModerationDonutCard extends StatelessWidget {
  final ThemeData theme;
  final bool isDark;
  final List<Report> reports;
  const _ModerationDonutCard({required this.theme, required this.isDark, required this.reports});

  @override
  Widget build(BuildContext context) {
    final buckets = _countModerationStatuses(reports);
    final donutValues = <double>[
      buckets.open.toDouble(),
      buckets.dismissed.toDouble(),
      buckets.approved.toDouble(),
      buckets.removed.toDouble(),
    ];
    final openCount = buckets.open;
    final total = reports.length;

    return _ChartCard(
      theme: theme,
      title: 'Moderation overview',
      subtitle: 'Report status breakdown',
      badge: total == 0 ? 'No reports' : '$openCount open',
      badgeGreen: false,
      legend: [
        const _LegendDot(color: Color(0xFFBA7517), label: 'Open'),
        _LegendDot(color: kPrimaryGreen, label: 'Dismissed'),
        const _LegendDot(color: Color(0xFF378ADD), label: 'Approved'),
        const _LegendDot(color: Color(0xFFE24B4A), label: 'Removed'),
      ],
      child: SizedBox(
        height: 150,
        child: CustomPaint(
          size: Size.infinite,
          painter: _DonutPainter(
            values: donutValues,
            labels: const ['Open', 'Dismissed', 'Approved', 'Removed'],
            colors: const [
              Color(0xFFBA7517),
              kPrimaryGreen,
              Color(0xFF378ADD),
              Color(0xFFE24B4A),
            ],
            isDark: isDark,
          ),
        ),
      ),
    );
  }
}

// ─── Audit Activity Stacked Bar Chart ─────────────────────────────────────────
class _AuditActivityCard extends StatelessWidget {
  final ThemeData theme;
  final bool isDark;
  final List<AdminStatPoint> userGrowthPoints;
  final List<AdminStatPoint> postFrequencyPoints;
  final List<AdminStatPoint> chatbotInteractionPoints;
  const _AuditActivityCard({
    required this.theme,
    required this.isDark,
    required this.userGrowthPoints,
    required this.postFrequencyPoints,
    required this.chatbotInteractionPoints,
  });

  @override
  Widget build(BuildContext context) {
    const pointsCount = 6;
    final labels = _buildDateLabels(
      userGrowthPoints.isNotEmpty
          ? userGrowthPoints
          : (postFrequencyPoints.isNotEmpty ? postFrequencyPoints : chatbotInteractionPoints),
      pointsCount,
    );
    final usersSeries = _normalizeSeries(userGrowthPoints, pointsCount);
    final postsSeries = _normalizeSeries(postFrequencyPoints, pointsCount);
    final chatbotSeries = _normalizeSeries(chatbotInteractionPoints, pointsCount);

    return _ChartCard(
      theme: theme,
      title: 'Platform activity',
      subtitle: 'Users, posts, and chatbot activity',
      badge: 'Live',
      badgeGreen: true,
      legend: [
        const _LegendDot(color: Color(0xFF378ADD), label: 'Users'),
        _LegendDot(color: kPrimaryGreen, label: 'Posts'),
        const _LegendDot(color: Color(0xFFBA7517), label: 'Chatbot'),
      ],
      child: SizedBox(
        height: 160,
        child: CustomPaint(
          size: Size.infinite,
          painter: _StackedBarPainter(
            seriesA: usersSeries,
            seriesB: postsSeries,
            seriesC: chatbotSeries,
            colorA: const Color(0xFF378ADD),
            colorB: kPrimaryGreen,
            colorC: const Color(0xFFBA7517),
            labels: labels,
            isDark: isDark,
          ),
        ),
      ),
    );
  }
}

List<double> _normalizeSeries(List<AdminStatPoint> source, int length) {
  final values = source.map((p) => p.count.toDouble()).toList();
  final tail = values.length > length
      ? values.sublist(values.length - length)
      : values;
  if (tail.length == length) return tail;
  return List<double>.filled(length - tail.length, 0) + tail;
}

List<String> _buildDateLabels(List<AdminStatPoint> source, int length) {
  final dates = source.map((p) => p.date).toList();
  final tail = dates.length > length
      ? dates.sublist(dates.length - length)
      : dates;
  final labels = tail
      .map((d) => '${d.month}/${d.day}')
      .toList(growable: true);
  while (labels.length < length) {
    labels.insert(0, '—');
  }
  return labels;
}

double? _seriesPercentDelta(List<AdminStatPoint> points) {
  if (points.length < 2) return null;
  final last = points[points.length - 1].count.toDouble();
  final prev = points[points.length - 2].count.toDouble();
  if (prev == 0 && last == 0) return 0;
  if (prev == 0) return 100;
  return ((last - prev) / prev) * 100;
}

String _formatTrend(double? delta) {
  if (delta == null) return 'No data';
  final sign = delta >= 0 ? '+' : '';
  return '$sign${delta.toStringAsFixed(1)}%';
}

bool _isTrendUp(String trend) => trend.startsWith('+');

String _formatHumanDate(String? raw) {
  if (raw == null || raw.trim().isEmpty) return '—';
  final parsed = DateTime.tryParse(raw);
  if (parsed == null) return raw;
  final local = parsed.toLocal();
  const months = <String>[
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];
  final month = months[local.month - 1];
  final hour12 = local.hour == 0 ? 12 : (local.hour > 12 ? local.hour - 12 : local.hour);
  final minute = local.minute.toString().padLeft(2, '0');
  final meridiem = local.hour >= 12 ? 'PM' : 'AM';
  return '$month ${local.day}, ${local.year} • $hour12:$minute $meridiem';
}

String _normalizeReportStatus(String status) {
  final normalized = status.trim().toLowerCase();
  if (normalized == 'pending') return 'open';
  return normalized;
}

({int open, int dismissed, int approved, int removed}) _countModerationStatuses(List<Report> reports) {
  var open = 0;
  var dismissed = 0;
  var approved = 0;
  var removed = 0;
  for (final report in reports) {
    switch (_normalizeReportStatus(report.status)) {
      case 'open':
        open++;
        break;
      case 'dismissed':
        dismissed++;
        break;
      case 'approved':
        approved++;
        break;
      case 'removed':
        removed++;
        break;
      default:
        open++;
        break;
    }
  }
  return (open: open, dismissed: dismissed, approved: approved, removed: removed);
}

// ─── CustomPainter: Line Chart ────────────────────────────────────────────────
class _LinePainter extends CustomPainter {
  final List<double> seriesA;
  final List<double> seriesB;
  final Color colorA;
  final Color colorB;
  final List<String> labels;
  final bool isDark;

  const _LinePainter({
    required this.seriesA,
    required this.seriesB,
    required this.colorA,
    required this.colorB,
    required this.labels,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const double padLeft = 42;
    const double padRight = 12;
    const double padTop = 12;
    const double padBottom = 28;

    final chartW = size.width - padLeft - padRight;
    final chartH = size.height - padTop - padBottom;

    final allValues = [...seriesA, ...seriesB];
    final minV = allValues.reduce(math.min);
    final maxV = allValues.reduce(math.max);
    final range = (maxV - minV) == 0 ? 1.0 : maxV - minV;

    final gridPaint = Paint()
      ..color = (isDark ? Colors.white : Colors.black).withOpacity(0.05)
      ..strokeWidth = 0.5;

    // Improved label styling
    final labelStyle = TextStyle(
      fontSize: 10,
      fontWeight: FontWeight.w500,
      color: isDark ? const Color(0xFFA0A09A) : const Color(0xFF888780),
      letterSpacing: 0.1,
      height: 1.2,
    );

    // Grid lines + Y labels with dynamic width calculation
    const gridCount = 4;
    for (int i = 0; i <= gridCount; i++) {
      final y = padTop + chartH - (i / gridCount) * chartH;
      canvas.drawLine(Offset(padLeft, y), Offset(padLeft + chartW, y), gridPaint);

      final val = minV + (i / gridCount) * range;
      late final String label;
      if (val >= 1000000) {
        label = '${(val / 1000000).toStringAsFixed(val >= 10000000 ? 0 : 1)}M';
      } else if (val >= 1000) {
        label = '${(val / 1000).toStringAsFixed(val >= 10000 ? 0 : 1)}k';
      } else {
        label = val.toInt().toString();
      }

      _drawText(canvas, label, Offset(2, y - 6), labelStyle, maxWidth: padLeft - 6, align: TextAlign.right);
    }

    // X labels
    for (int i = 0; i < labels.length; i++) {
      final x = padLeft + (i / (labels.length - 1)) * chartW;
      _drawText(
        canvas,
        labels[i],
        Offset(x - 16, size.height - padBottom + 8),
        labelStyle,
        maxWidth: 32,
        align: TextAlign.center,
      );
    }

    // Helper to build path
    Path buildPath(List<double> data) {
      final path = Path();
      for (int i = 0; i < data.length; i++) {
        final x = padLeft + (i / (data.length - 1)) * chartW;
        final y = padTop + chartH - ((data[i] - minV) / range) * chartH;
        i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
      }
      return path;
    }

    // Fill under line A
    void drawFill(List<double> data, Color color) {
      final path = buildPath(data);
      final fillPath = Path.from(path)
        ..lineTo(padLeft + chartW, padTop + chartH)
        ..lineTo(padLeft, padTop + chartH)
        ..close();
      canvas.drawPath(fillPath, Paint()..color = color.withOpacity(0.1)..style = PaintingStyle.fill);
    }

    drawFill(seriesA, colorA);
    drawFill(seriesB, colorB);

    // Lines with better styling
    void drawLine(List<double> data, Color color, {bool dashed = false}) {
      final path = buildPath(data);
      final paint = Paint()
        ..color = color
        ..strokeWidth = 2.2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      if (!dashed) {
        canvas.drawPath(path, paint);
      } else {
        _drawDashedPath(canvas, path, paint);
      }
    }

    drawLine(seriesA, colorA);
    drawLine(seriesB, colorB, dashed: true);

    // Dots with better styling
    void drawDots(List<double> data, Color color) {
      for (int i = 0; i < data.length; i++) {
        final x = padLeft + (i / (data.length - 1)) * chartW;
        final y = padTop + chartH - ((data[i] - minV) / range) * chartH;
        // Outer circle with subtle shadow effect
        canvas.drawCircle(Offset(x, y), 4.5, Paint()..color = color.withOpacity(0.2));
        // Main dot
        canvas.drawCircle(Offset(x, y), 3.5, Paint()..color = color);
        // Inner highlight
        canvas.drawCircle(Offset(x, y), 2, Paint()..color = isDark ? const Color(0xFF2D3748) : Colors.white);
      }
    }

    drawDots(seriesA, colorA);
    drawDots(seriesB, colorB);
  }

  void _drawDashedPath(Canvas canvas, Path path, Paint paint) {
    const dashLen = 5.0;
    const gapLen = 3.0;
    final metric = path.computeMetrics().first;
    double dist = 0;
    bool drawing = true;
    while (dist < metric.length) {
      final next = (dist + (drawing ? dashLen : gapLen))
          .clamp(0.0, metric.length)
          .toDouble();
      if (drawing) {
        canvas.drawPath(metric.extractPath(dist, next), paint);
      }
      dist = next;
      drawing = !drawing;
    }
  }

  void _drawText(Canvas canvas, String text, Offset offset, TextStyle style, {double maxWidth = 60, TextAlign align = TextAlign.left}) {
    final tp = TextPainter(text: TextSpan(text: text, style: style), textDirection: TextDirection.ltr, textAlign: align)
      ..layout(maxWidth: maxWidth);
    tp.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _LinePainter old) =>
      old.seriesA != seriesA || old.seriesB != seriesB || old.isDark != isDark;
}

// ─── CustomPainter: Bar Chart ─────────────────────────────────────────────────
class _BarPainter extends CustomPainter {
  final List<double> values;
  final List<String> labels;
  final List<Color> colors;
  final bool isDark;

  const _BarPainter({required this.values, required this.labels, required this.colors, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    const double padLeft = 42;
    const double padRight = 12;
    const double padTop = 12;
    const double padBottom = 28;

    final chartW = size.width - padLeft - padRight;
    final chartH = size.height - padTop - padBottom;
    final maxV = values.reduce(math.max);
    final n = values.length;
    final barW = (chartW / n) * 0.6;
    final gap = (chartW / n) * 0.4;

    final gridPaint = Paint()
      ..color = (isDark ? Colors.white : Colors.black).withOpacity(0.05)
      ..strokeWidth = 0.5;

    // Improved label styling
    final labelStyle = TextStyle(
      fontSize: 10,
      fontWeight: FontWeight.w500,
      color: isDark ? const Color(0xFFA0A09A) : const Color(0xFF888780),
      letterSpacing: 0.1,
      height: 1.2,
    );

    const gridCount = 4;
    for (int i = 0; i <= gridCount; i++) {
      final y = padTop + chartH - (i / gridCount) * chartH;
      canvas.drawLine(Offset(padLeft, y), Offset(padLeft + chartW, y), gridPaint);

      final val = (i / gridCount) * maxV;
      late final String label;
      if (val >= 1000000) {
        label = '${(val / 1000000).toStringAsFixed(val >= 10000000 ? 0 : 1)}M';
      } else if (val >= 1000) {
        label = '${(val / 1000).toStringAsFixed(val >= 10000 ? 0 : 1)}k';
      } else {
        label = val.toInt().toString();
      }

      _drawText(canvas, label, Offset(2, y - 6), labelStyle, maxWidth: padLeft - 6, align: TextAlign.right);
    }

    // Bars with improved styling
    for (int i = 0; i < n; i++) {
      final x = padLeft + i * (chartW / n) + gap / 2;
      final barH = (values[i] / maxV) * chartH;
      final y = padTop + chartH - barH;

      final rRect = RRect.fromRectAndCorners(
        Rect.fromLTWH(x, y, barW, barH),
        topLeft: const Radius.circular(5),
        topRight: const Radius.circular(5),
      );

      // Subtle shadow effect
      canvas.drawRRect(
        rRect,
        Paint()
          ..color = colors[i].withOpacity(0.15)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1),
      );

      // Main bar
      canvas.drawRRect(rRect, Paint()..color = colors[i]);

      // Subtle highlight on top
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          Rect.fromLTWH(x + 0.5, y + 0.5, barW - 1, 2),
          topLeft: const Radius.circular(3),
          topRight: const Radius.circular(3),
        ),
        Paint()..color = Colors.white.withOpacity(isDark ? 0.1 : 0.25),
      );

      _drawText(canvas, labels[i], Offset(x + barW / 2 - 16, size.height - padBottom + 8), labelStyle, maxWidth: 32, align: TextAlign.center);
    }
  }

  void _drawText(Canvas canvas, String text, Offset offset, TextStyle style, {double maxWidth = 60, TextAlign align = TextAlign.left}) {
    final tp = TextPainter(text: TextSpan(text: text, style: style), textDirection: TextDirection.ltr, textAlign: align)
      ..layout(maxWidth: maxWidth);
    tp.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _BarPainter old) => old.values != values || old.isDark != isDark;
}

// ─── CustomPainter: Donut Chart ───────────────────────────────────────────────
class _DonutPainter extends CustomPainter {
  final List<double> values;
  final List<String> labels;
  final List<Color> colors;
  final bool isDark;

  const _DonutPainter({required this.values, required this.labels, required this.colors, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final total = values.fold(0.0, (a, b) => a + b);
    final safeTotal = total <= 0 ? 1.0 : total;
    final cx = size.width * 0.38;
    final cy = size.height / 2;
    final radius = math.min(cx, cy) - 10;
    const strokeW = 26.0;

    // Draw donut segments with improved styling
    double startAngle = -math.pi / 2;
    for (int i = 0; i < values.length; i++) {
      final sweep = (values[i] / safeTotal) * 2 * math.pi;
      final paint = Paint()
        ..color = colors[i]
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeW
        ..strokeCap = StrokeCap.round;

      // Subtle shadow effect
      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: radius),
        startAngle + 0.05,
        sweep - 0.1,
        false,
        Paint()
          ..color = colors[i].withOpacity(0.2)
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeW + 2
          ..strokeCap = StrokeCap.round,
      );

      // Main arc
      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: radius),
        startAngle + 0.05,
        sweep - 0.1,
        false,
        paint,
      );
      startAngle += sweep;
    }

    // Center text with improved typography
    final totalInt = total.toInt().toString();
    final centerLabelStyle = TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w700,
      color: isDark ? Colors.white : const Color(0xFF1A2332),
      letterSpacing: 0.3,
      height: 1.2,
    );
    final subLabelStyle = TextStyle(
      fontSize: 10,
      fontWeight: FontWeight.w500,
      color: isDark ? const Color(0xFFA0A09A) : const Color(0xFF888780),
      letterSpacing: 0.1,
      height: 1.2,
    );

    _drawCenteredText(canvas, totalInt, Offset(cx, cy - 10), centerLabelStyle);
    _drawCenteredText(canvas, 'reports', Offset(cx, cy + 12), subLabelStyle);

    // Legend on the right side with improved styling
    final legendX = size.width * 0.62;
    const legendStartY = 18.0;
    const itemH = 28.0;

    final labelStyle = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: isDark ? const Color(0xFFE0DED7) : const Color(0xFF2C2C2A),
      letterSpacing: 0.1,
      height: 1.2,
    );
    final subStyle = TextStyle(
      fontSize: 10,
      fontWeight: FontWeight.w500,
      color: isDark ? const Color(0xFFA0A09A) : const Color(0xFF888780),
      letterSpacing: 0.05,
      height: 1.2,
    );

    for (int i = 0; i < values.length; i++) {
      final y = legendStartY + i * itemH;

      // Color indicator with subtle border
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(legendX, y + 4, 11, 11), const Radius.circular(3)),
        Paint()
          ..color = colors[i]
          ..style = PaintingStyle.fill,
      );

      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(legendX, y + 4, 11, 11), const Radius.circular(3)),
        Paint()
          ..color = isDark ? Colors.white.withOpacity(0.15) : Colors.black.withOpacity(0.08)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.5,
      );

      final pct = ((values[i] / safeTotal) * 100).toStringAsFixed(0);
      final count = values[i].toInt().toString();

      _drawText(canvas, labels[i], Offset(legendX + 16, y), labelStyle, maxWidth: size.width - legendX - 20);
      _drawText(
        canvas,
        '$pct%  •  $count',
        Offset(legendX + 16, y + 14),
        subStyle,
        maxWidth: size.width - legendX - 20,
      );
    }
  }

  void _drawCenteredText(Canvas canvas, String text, Offset center, TextStyle style) {
    final tp = TextPainter(text: TextSpan(text: text, style: style), textDirection: TextDirection.ltr)..layout();
    tp.paint(canvas, Offset(center.dx - tp.width / 2, center.dy - tp.height / 2));
  }

  void _drawText(Canvas canvas, String text, Offset offset, TextStyle style, {double maxWidth = 80}) {
    final tp = TextPainter(text: TextSpan(text: text, style: style), textDirection: TextDirection.ltr)
      ..layout(maxWidth: maxWidth);
    tp.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) => old.values != values || old.isDark != isDark;
}

// ─── CustomPainter: Stacked Bar Chart ────────────────────────────────────────
class _StackedBarPainter extends CustomPainter {
  final List<double> seriesA;
  final List<double> seriesB;
  final List<double> seriesC;
  final Color colorA;
  final Color colorB;
  final Color colorC;
  final List<String> labels;
  final bool isDark;

  const _StackedBarPainter({
    required this.seriesA,
    required this.seriesB,
    required this.seriesC,
    required this.colorA,
    required this.colorB,
    required this.colorC,
    required this.labels,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const double padLeft = 42;
    const double padRight = 12;
    const double padTop = 12;
    const double padBottom = 28;

    final chartW = size.width - padLeft - padRight;
    final chartH = size.height - padTop - padBottom;
    final n = seriesA.length;

    double maxV = 0;
    for (int i = 0; i < n; i++) {
      maxV = math.max(maxV, seriesA[i] + seriesB[i] + seriesC[i]);
    }
    maxV = (maxV * 1.1).ceilToDouble();

    final barW = (chartW / n) * 0.6;
    final gap = (chartW / n) * 0.4;

    final gridPaint = Paint()
      ..color = (isDark ? Colors.white : Colors.black).withOpacity(0.05)
      ..strokeWidth = 0.5;

    // Improved label styling
    final labelStyle = TextStyle(
      fontSize: 10,
      fontWeight: FontWeight.w500,
      color: isDark ? const Color(0xFFA0A09A) : const Color(0xFF888780),
      letterSpacing: 0.1,
      height: 1.2,
    );

    const gridCount = 4;
    for (int i = 0; i <= gridCount; i++) {
      final y = padTop + chartH - (i / gridCount) * chartH;
      canvas.drawLine(Offset(padLeft, y), Offset(padLeft + chartW, y), gridPaint);

      final val = (i / gridCount) * maxV;
      late final String label;
      if (val >= 1000000) {
        label = '${(val / 1000000).toStringAsFixed(val >= 10000000 ? 0 : 1)}M';
      } else if (val >= 1000) {
        label = '${(val / 1000).toStringAsFixed(val >= 10000 ? 0 : 1)}k';
      } else {
        label = val.toInt().toString();
      }

      _drawText(canvas, label, Offset(2, y - 6), labelStyle, maxWidth: padLeft - 6, align: TextAlign.right);
    }

    // Draw stacked bars with improved styling
    for (int i = 0; i < n; i++) {
      final x = padLeft + i * (chartW / n) + gap / 2;
      double currentY = padTop + chartH;

      void drawSegment(double val, Color color, {bool isTop = false, bool isBottom = false}) {
        if (val <= 0) return;
        final segH = (val / maxV) * chartH;
        final top = currentY - segH;

        final rRect = isTop
            ? RRect.fromRectAndCorners(
                Rect.fromLTWH(x, top, barW, segH),
                topLeft: const Radius.circular(5),
                topRight: const Radius.circular(5),
              )
            : isBottom
                ? RRect.fromRectAndCorners(
                    Rect.fromLTWH(x, top, barW, segH),
                    bottomLeft: const Radius.circular(5),
                    bottomRight: const Radius.circular(5),
                  )
                : RRect.fromRectAndRadius(Rect.fromLTWH(x, top, barW, segH), const Radius.circular(0));

        // Subtle shadow
        canvas.drawRRect(
          rRect,
          Paint()
            ..color = color.withOpacity(0.15)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1),
        );

        // Main segment
        canvas.drawRRect(rRect, Paint()..color = color);

        // Subtle highlight
        if (isTop) {
          canvas.drawRRect(
            RRect.fromRectAndCorners(
              Rect.fromLTWH(x + 0.5, top + 0.5, barW - 1, 2),
              topLeft: const Radius.circular(3),
              topRight: const Radius.circular(3),
            ),
            Paint()..color = Colors.white.withOpacity(isDark ? 0.1 : 0.2),
          );
        }

        currentY = top;
      }

      drawSegment(seriesC[i], colorC, isBottom: true);
      drawSegment(seriesB[i], colorB);
      drawSegment(seriesA[i], colorA, isTop: true);

      _drawText(
        canvas,
        labels[i],
        Offset(x + barW / 2 - 16, size.height - padBottom + 8),
        labelStyle,
        maxWidth: 32,
        align: TextAlign.center,
      );
    }
  }

  void _drawText(Canvas canvas, String text, Offset offset, TextStyle style, {double maxWidth = 60, TextAlign align = TextAlign.left}) {
    final tp = TextPainter(text: TextSpan(text: text, style: style), textDirection: TextDirection.ltr, textAlign: align)
      ..layout(maxWidth: maxWidth);
    tp.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _StackedBarPainter old) =>
      old.seriesA != seriesA || old.seriesB != seriesB || old.seriesC != seriesC || old.isDark != isDark;
}

// ─── Recipe Rankings Card ─────────────────────────────────────────────────────
class _OverviewRecipeRankingsCard extends StatefulWidget {
  final ThemeData theme;
  final int refreshNonce;

  const _OverviewRecipeRankingsCard({required this.theme, required this.refreshNonce});

  @override
  State<_OverviewRecipeRankingsCard> createState() => _OverviewRecipeRankingsCardState();
}

class _OverviewRecipeRankingsCardState extends State<_OverviewRecipeRankingsCard> {
  List<RecipeRankingItem> _rows = [];
  bool _loading = true;
  String? _error;
  String _window = '7d';
  int _sortIndex = 0;
  bool _ascending = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(_OverviewRecipeRankingsCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshNonce != widget.refreshNonce) _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final rows = await RecipeService.instance.fetchRankings(window: _window, mode: 'combined');
      if (!mounted) return;
      setState(() { _rows = rows; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString().replaceFirst('Exception: ', ''); _loading = false; });
    }
  }

  void _sort<T>(int column, T Function(RecipeRankingItem r) key) {
    setState(() {
      if (_sortIndex == column) {
        _ascending = !_ascending;
      } else {
        _sortIndex = column;
        _ascending = false;
      }
      _rows.sort((a, b) {
        final cmp = Comparable.compare(key(a) as Comparable, key(b) as Comparable);
        return _ascending ? cmp : -cmp;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    if (_loading) {
      return _SurfaceCard(theme: theme, child: const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator(color: kPrimaryGreen, strokeWidth: 2))));
    }
    if (_error != null) {
      return _SurfaceCard(theme: theme, child: Padding(padding: const EdgeInsets.all(16), child: Text(_error!, style: TextStyle(color: theme.colorScheme.error, fontSize: 13))));
    }

    return _SurfaceCard(
      theme: theme,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: _WindowTabs(current: _window, onChanged: (v) { setState(() => _window = v); _load(); }),
          ),
          LayoutBuilder(builder: (context, constraints) {
            return ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 380),
              child: Scrollbar(
                thumbVisibility: true,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SingleChildScrollView(
                    child: DataTable(
                      sortColumnIndex: _sortIndex,
                      sortAscending: _ascending,
                      headingRowHeight: 38,
                      dataRowMinHeight: 40,
                      dataRowMaxHeight: 48,
                      headingTextStyle: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 0.5, color: theme.colorScheme.onSurfaceVariant),
                      dataTextStyle: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface),
                      dividerThickness: 0.5,
                      columns: [
                        const DataColumn(label: Text('#')),
                        DataColumn(label: const Text('TITLE'), onSort: (_, __) => _sort(1, (r) => r.title)),
                        DataColumn(label: const Text('VIEWS'), numeric: true, onSort: (_, __) => _sort(2, (r) => r.viewsCount)),
                        DataColumn(label: const Text('AVG RATING'), numeric: true, onSort: (_, __) => _sort(3, (r) => r.averageRating)),
                        DataColumn(label: const Text('RATINGS'), numeric: true, onSort: (_, __) => _sort(4, (r) => r.ratingsCount)),
                        DataColumn(label: const Text('SCORE'), numeric: true, onSort: (_, __) => _sort(5, (r) => r.score)),
                      ],
                      rows: List.generate(_rows.length, (i) {
                        final r = _rows[i];
                        return DataRow(cells: [
                          DataCell(Text('${i + 1}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurfaceVariant))),
                          DataCell(Text(r.title, maxLines: 1, overflow: TextOverflow.ellipsis)),
                          DataCell(Text('${r.viewsCount}')),
                          DataCell(Text(r.averageRating.toStringAsFixed(2))),
                          DataCell(Text('${r.ratingsCount}')),
                          DataCell(Text(r.score.toStringAsFixed(3), style: const TextStyle(fontWeight: FontWeight.w600, color: kPrimaryGreen))),
                        ]);
                      }),
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _WindowTabs extends StatelessWidget {
  final String current;
  final ValueChanged<String> onChanged;

  const _WindowTabs({required this.current, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final items = [('7d', 'Last 7 days'), ('30d', 'Last 30 days'), ('all', 'All time')];
    return Container(
      height: 32,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: items.map((item) {
          final isSelected = item.$1 == current;
          return GestureDetector(
            onTap: () => onChanged(item.$1),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: isSelected ? (isDark ? const Color(0xFF2A2A2A) : Colors.white) : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
              ),
              alignment: Alignment.center,
              child: Text(
                item.$2,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: isSelected
                      ? (isDark ? Colors.white : Theme.of(context).colorScheme.onSurface)
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─── Recent Logs List ─────────────────────────────────────────────────────────
class _RecentLogsList extends StatelessWidget {
  final ThemeData theme;
  final List<ActivityLog> logs;

  const _RecentLogsList({required this.theme, required this.logs});

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      theme: theme,
      padding: EdgeInsets.zero,
      child: Column(
        children: logs.asMap().entries.map((e) {
          final log = e.value;
          final isLast = e.key == logs.length - 1;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                child: Row(
                  children: [
                    Container(
                      width: 32, height: 32,
                      decoration: BoxDecoration(color: kPrimaryGreen.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.history_rounded, size: 15, color: kPrimaryGreen),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(log.description, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: theme.colorScheme.onSurface), overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 2),
                          Text('${log.actorName ?? 'System'} · ${log.category}', style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(_formatHumanDate(log.createdAt), style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurfaceVariant)),
                  ],
                ),
              ),
              if (!isLast)
                Divider(height: 0.5, indent: 16, endIndent: 16, color: theme.colorScheme.outline.withValues(alpha: 0.08)),
            ],
          );
        }).toList(),
      ),
    );
  }
}

// ─── Users Section ────────────────────────────────────────────────────────────
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
  final void Function(AdminUser) onUserTap;
  final void Function(AdminUser) onViewPosts;
  final void Function(AdminUser) onViewComments;

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
    required this.onUserTap,
    required this.onViewPosts,
    required this.onViewComments,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Expanded(child: _MinimalSectionLabel(theme: theme, label: 'Registered Users', subtitle: loading ? 'Loading…' : '${users.length} users')),
          _DateRangeDropdown(value: selectedRange, onChanged: onRangeChanged),
          const SizedBox(width: 6),
          if (!loading) ...[
            _TopBarIconBtn(icon: Icons.refresh_rounded, onPressed: onRefresh, tooltip: 'Refresh', color: kPrimaryGreen),
            const SizedBox(width: 4),
            _GreenButton(label: exporting ? 'Exporting…' : 'Export', icon: Icons.download_rounded, loading: exporting, onPressed: exporting ? null : onExport, compact: true),
          ],
        ]),
        const SizedBox(height: 14),
        _SearchBar(theme: theme, onChanged: onSearchChanged, hintText: 'Search by name or email…'),
        const SizedBox(height: 14),
        if (loading && users.isEmpty)
          const _LoadingState()
        else if (error != null)
          _ErrorState(theme: theme, message: error!, onRetry: onRefresh)
        else if (users.isEmpty)
          _EmptyState(theme: theme, message: searchQuery.isEmpty ? 'No users yet' : 'No users match your search')
        else
          MasterUserTable(
            users: users,
            loading: false,
            error: null,
            onUserTap: onUserTap,
            onViewPosts: onViewPosts,
            onViewComments: onViewComments,
            onDeactivate: onDeactivate,
            onActivate: onActivate,
            onDelete: onDelete,
          ),
        const SizedBox(height: 32),
      ],
    );
  }
}

class _UserActivitySheet extends StatelessWidget {
  final AdminUser user;
  final Future<List<Post>> postsFuture;
  final List<PostComment> comments;
  final bool commentsOnly;
  final ScrollController scrollController;

  const _UserActivitySheet({
    required this.user,
    required this.postsFuture,
    required this.comments,
    required this.commentsOnly,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurface.withOpacity(0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user.name, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(user.email, style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant)),
                    ],
                  ),
                ),
                Chip(
                  label: Text(user.statusLabel),
                  backgroundColor: user.isActive ? kPrimaryGreen.withOpacity(0.12) : kAccentOrange.withOpacity(0.12),
                  labelStyle: TextStyle(color: user.isActive ? kPrimaryGreen : kAccentOrange, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _ActivitySummaryTile(label: 'Total posts', value: user.totalPosts.toString()),
                      const SizedBox(width: 12),
                      _ActivitySummaryTile(label: 'Last login', value: user.lastLogin == null ? 'Never' : user.lastLogin!),
                    ],
                  ),
                  const SizedBox(height: 18),
                  if (!commentsOnly) ...[
                    Text('User posts', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    FutureBuilder<List<Post>>(
                      future: postsFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState != ConnectionState.done) {
                          return const Center(child: CircularProgressIndicator(color: kPrimaryGreen));
                        }
                        if (snapshot.hasError) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            child: Text('Unable to load posts.', style: theme.textTheme.bodyMedium?.copyWith(color: kAccentOrange)),
                          );
                        }
                        final posts = snapshot.data ?? [];
                        if (posts.isEmpty) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            child: Text('No posts found for this user.', style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant)),
                          );
                        }
                        return Column(
                          children: posts.map((post) {
                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(post.content.isEmpty ? 'Post' : post.content, style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700)),
                                    const SizedBox(height: 8),
                                    Text(post.content, maxLines: 3, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant)),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        );
                      },
                    ),
                    const SizedBox(height: 18),
                  ],
                  Text('Comments', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  if (comments.isEmpty)
                    Text('No comments recorded for this user.', style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant))
                  else
                    Column(
                      children: comments.map((comment) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceVariant.withOpacity(0.4),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(comment.comment, style: theme.textTheme.bodyMedium),
                              const SizedBox(height: 10),
                              Text('Posted by ${comment.userName}', style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant)),
                              const SizedBox(height: 4),
                              Text(comment.createdAt, style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant)),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivitySummaryTile extends StatelessWidget {
  final String label;
  final String value;

  const _ActivitySummaryTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: theme.colorScheme.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 6),
            Text(value, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

// ─── Moderation Section ───────────────────────────────────────────────────────
class _ModerationSection extends StatelessWidget {
  final ThemeData theme;
  final List<Report> reports;
  final bool loading;
  final String? error;
  final _DateRangeFilter selectedRange;
  final ValueChanged<_DateRangeFilter> onRangeChanged;
  final VoidCallback onRefresh;
  final VoidCallback? onExport;
  final bool exporting;
  final VoidCallback onDeleteAll;
  final Future<void> Function(int, String) onReportAction;

  const _ModerationSection({
    required this.theme,
    required this.reports,
    required this.loading,
    required this.error,
    required this.selectedRange,
    required this.onRangeChanged,
    required this.onRefresh,
    required this.onExport,
    required this.exporting,
    required this.onDeleteAll,
    required this.onReportAction,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Expanded(child: _MinimalSectionLabel(theme: theme, label: 'Content Reports', subtitle: loading ? 'Loading…' : '${reports.length} pending')),
          _DateRangeDropdown(value: selectedRange, onChanged: onRangeChanged),
          const SizedBox(width: 6),
          if (!loading) ...[
            _TopBarIconBtn(icon: Icons.refresh_rounded, onPressed: onRefresh, tooltip: 'Refresh', color: kPrimaryGreen),
            const SizedBox(width: 4),
            _GreenButton(label: exporting ? 'Exporting…' : 'Export', icon: Icons.download_rounded, loading: exporting, onPressed: exporting ? null : onExport, compact: true),
            if (reports.isNotEmpty) ...[
              const SizedBox(width: 4),
              IconButton(
                onPressed: onDeleteAll,
                icon: const Icon(Icons.delete_sweep_rounded, size: 18, color: kAccentOrange),
                tooltip: 'Delete all reports',
                style: IconButton.styleFrom(minimumSize: const Size(34, 34), padding: EdgeInsets.zero),
              ),
            ],
          ],
        ]),
        const SizedBox(height: 14),
        if (loading && reports.isEmpty)
          const _LoadingState()
        else if (error != null)
          _ErrorState(theme: theme, message: error!, onRetry: onRefresh)
        else if (reports.isEmpty)
          _EmptyState(theme: theme, message: 'No pending reports — all clear ✓')
        else
          _ReportsTable(theme: theme, reports: reports, onAction: onReportAction),
        const SizedBox(height: 32),
      ],
    );
  }
}

// ─── Audit Logs Section ───────────────────────────────────────────────────────
class _AuditLogsSection extends StatelessWidget {
  final ThemeData theme;
  final List<ActivityLog> logs;
  final bool loading;
  final String? error;
  final bool exporting;
  final _DateRangeFilter selectedRange;
  final ValueChanged<_DateRangeFilter> onRangeChanged;
  final VoidCallback onRefresh;
  final VoidCallback onExport;

  const _AuditLogsSection({
    required this.theme,
    required this.logs,
    required this.loading,
    required this.error,
    required this.exporting,
    required this.selectedRange,
    required this.onRangeChanged,
    required this.onRefresh,
    required this.onExport,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Expanded(child: _MinimalSectionLabel(theme: theme, label: 'Audit Logs', subtitle: 'System & moderation events')),
          _DateRangeDropdown(value: selectedRange, onChanged: onRangeChanged),
          const SizedBox(width: 6),
          OutlinedButton.icon(
            onPressed: exporting ? null : onExport,
            style: OutlinedButton.styleFrom(
              foregroundColor: kPrimaryGreen,
              side: BorderSide(color: kPrimaryGreen.withValues(alpha: 0.4), width: 0.5),
              minimumSize: const Size(0, 34),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              textStyle: const TextStyle(fontSize: 12),
            ),
            icon: exporting
                ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 1.5, color: kPrimaryGreen))
                : const Icon(Icons.download_rounded, size: 14),
            label: Text(exporting ? 'Exporting…' : 'Export CSV'),
          ),
          const SizedBox(width: 6),
          if (!loading) _TopBarIconBtn(icon: Icons.refresh_rounded, onPressed: onRefresh, tooltip: 'Refresh', color: kPrimaryGreen),
        ]),
        const SizedBox(height: 14),
        if (loading && logs.isEmpty)
          const _LoadingState()
        else if (error != null)
          _ErrorState(theme: theme, message: error!, onRetry: onRefresh)
        else if (logs.isEmpty)
          _EmptyState(theme: theme, message: 'No audit logs yet')
        else
          _AuditLogsTable(theme: theme, logs: logs.take(20).toList()),
        const SizedBox(height: 32),
      ],
    );
  }
}

// ─── Tables ───────────────────────────────────────────────────────────────────
const _kRowH = 50.0;
const _kMinH = 240.0;
const _kMaxH = 500.0;

Widget _wrapTable(ThemeData theme, int rowCount, Widget child) {
  final height = (rowCount * _kRowH + 48.0).clamp(_kMinH, _kMaxH);
  final isDark = theme.brightness == Brightness.dark;
  return Container(
    width: double.infinity,
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      color: isDark ? const Color(0xFF1C1C1C) : Colors.white,
      borderRadius: BorderRadius.circular(_kCardRadius),
      border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.06), width: 0.5),
    ),
    child: LayoutBuilder(builder: (ctx, constraints) {
      return SizedBox(
        height: height,
        child: Scrollbar(
          thumbVisibility: true,
          child: SingleChildScrollView(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(constraints: BoxConstraints(minWidth: constraints.maxWidth), child: child),
            ),
          ),
        ),
      );
    }),
  );
}

Widget _flexTable({required ThemeData theme, required Map<int, TableColumnWidth> columnWidths, required List<String> headers, required List<TableRow> rows}) {
  final isDark = theme.brightness == Brightness.dark;
  return Table(
    columnWidths: columnWidths,
    defaultVerticalAlignment: TableCellVerticalAlignment.middle,
    border: TableBorder(
      horizontalInside: BorderSide(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04), width: 0.5),
    ),
    children: [
      TableRow(
        decoration: BoxDecoration(color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.02)),
        children: headers.map((h) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Text(h, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 9, color: theme.colorScheme.onSurfaceVariant, letterSpacing: 0.7)),
        )).toList(),
      ),
      ...rows,
    ],
  );
}

TableRow _tableRow(ThemeData theme, List<Widget> cells, Color? bg) {
  return TableRow(
    decoration: BoxDecoration(color: bg),
    children: cells.map((c) => Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), child: Align(alignment: Alignment.centerLeft, child: c))).toList(),
  );
}

class _UsersTable extends StatelessWidget {
  final ThemeData theme;
  final List<AdminUser> users;
  final void Function(AdminUser) onDeactivate;
  final void Function(AdminUser) onActivate;
  final void Function(AdminUser) onDelete;

  const _UsersTable({required this.theme, required this.users, required this.onDeactivate, required this.onActivate, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return _wrapTable(
      theme,
      users.length,
      _flexTable(
        theme: theme,
        columnWidths: const {
          0: FlexColumnWidth(0.4),
          1: FlexColumnWidth(1.4),
          2: FlexColumnWidth(2),
          3: FlexColumnWidth(0.9),
          4: FlexColumnWidth(1.2),
        },
        headers: ['ID', 'NAME', 'EMAIL', 'STATUS', 'ACTIONS'],
        rows: users.asMap().entries.map((e) {
          final user = e.value;
          final bg = e.key.isEven
              ? null
              : theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.15,
                );
          return _tableRow(theme, [
            Text(
              '${user.id}',
              style: TextStyle(
                fontSize: 13,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            Text(
              user.name.isEmpty ? '—' : user.name,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.onSurface,
              ),
            ),
            Text(
              user.email,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                color: theme.colorScheme.onSurface,
              ),
            ),
            _StatusChip(isActive: user.isActive),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (user.isActive)
                  _ActionIconBtn(
                    icon: Icons.person_off_rounded,
                    color: kAccentOrange,
                    tooltip: 'Deactivate',
                    onPressed: () => onDeactivate(user),
                  )
                else
                  _ActionIconBtn(
                    icon: Icons.person_add_rounded,
                    color: kPrimaryGreen,
                    tooltip: 'Activate',
                    onPressed: () => onActivate(user),
                  ),
                AppSpacing.gapH4,
                _ActionIconBtn(
                  icon: Icons.delete_outline,
                  color: Colors.red,
                  tooltip: 'Delete',
                  onPressed: () => onDelete(user),
                ),
              ],
            ),
          ], bg);
        }).toList(),
      ),
    );
  }
}

class _ReportsTable extends StatelessWidget {
  final ThemeData theme;
  final List<Report> reports;
  final Future<void> Function(int, String) onAction;

  const _ReportsTable({required this.theme, required this.reports, required this.onAction});

  @override
  Widget build(BuildContext context) {
    return _wrapTable(theme, reports.length, _flexTable(
      theme: theme,
      columnWidths: const {0: FlexColumnWidth(0.35), 1: FlexColumnWidth(0.7), 2: FlexColumnWidth(1.4), 3: FlexColumnWidth(1.1), 4: FlexColumnWidth(0.9), 5: FlexColumnWidth(0.85), 6: FlexColumnWidth(1.1)},
      headers: ['ID', 'TYPE', 'CONTENT', 'REPORTER', 'REASON', 'DATE', 'ACTIONS'],
      rows: reports.asMap().entries.map((e) {
        final r = e.value;
        return _tableRow(theme, [
          Text('${r.id}', style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant)),
          _TypePill(type: r.reportable?.type ?? 'unknown'),
          Text(r.reportableLabel, overflow: TextOverflow.ellipsis, maxLines: 2, style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface)),
          Text(r.reporter ?? '—', overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface)),
          Text(r.reason ?? '—', overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface)),
          Text(_formatHumanDate(r.createdAt), style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant)),
          Row(mainAxisSize: MainAxisSize.min, children: [
            _ActionIconBtn(icon: Icons.close_rounded, color: theme.colorScheme.onSurfaceVariant, tooltip: 'Dismiss', onPressed: () => onAction(r.id, 'dismiss'), size: 14),
            _ActionIconBtn(icon: Icons.check_rounded, color: kPrimaryGreen, tooltip: 'Approve', onPressed: () => onAction(r.id, 'approve'), size: 14),
            if (r.isRecipeReport || r.isPostReport)
              _ActionIconBtn(icon: Icons.delete_outline_rounded, color: kAccentOrange, tooltip: 'Remove content', onPressed: () => onAction(r.id, 'remove-content'), size: 14),
            if (r.isUserReport)
              _ActionIconBtn(icon: Icons.block_rounded, color: Colors.red, tooltip: 'Suspend user', onPressed: () => onAction(r.id, 'suspend-user'), size: 14),
          ]),
        ], null);
      }).toList(),
    ));
  }
}

class _AuditLogsTable extends StatelessWidget {
  final ThemeData theme;
  final List<ActivityLog> logs;

  const _AuditLogsTable({required this.theme, required this.logs});

  @override
  Widget build(BuildContext context) {
    return _wrapTable(theme, logs.length, _flexTable(
      theme: theme,
      columnWidths: const {0: FlexColumnWidth(0.35), 1: FlexColumnWidth(1), 2: FlexColumnWidth(0.9), 3: FlexColumnWidth(0.9), 4: FlexColumnWidth(2), 5: FlexColumnWidth(1)},
      headers: ['ID', 'DATE', 'CATEGORY', 'ACTION', 'DESCRIPTION', 'ACTOR'],
      rows: logs.asMap().entries.map((e) {
        final log = e.value;
        return _tableRow(theme, [
          Text('${log.id}', style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant)),
          Text(_formatHumanDate(log.createdAt), style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant)),
          _CategoryPill(theme: theme, label: log.category),
          Text(log.action, style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface)),
          Text(log.description, overflow: TextOverflow.ellipsis, maxLines: 2, style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface)),
          Text(log.actorName ?? '—', overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface)),
        ], null);
      }).toList(),
    ));
  }
}

// ─── Stat Card ────────────────────────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  final ThemeData theme;
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final String trend;
  final bool trendUp;

  const _StatCard({required this.theme, required this.title, required this.value, required this.icon, required this.color, required this.trend, required this.trendUp});

  @override
  Widget build(BuildContext context) {
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1C) : Colors.white,
        borderRadius: BorderRadius.circular(_kStatCardRadius),
        border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.06), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 34, height: 34,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(9)),
              child: Icon(icon, color: color, size: 16),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: trendUp ? kPrimaryGreen.withValues(alpha: 0.08) : kAccentOrange.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(trendUp ? Icons.trending_up_rounded : Icons.info_outline_rounded, size: 11, color: trendUp ? kPrimaryGreen : kAccentOrange),
                const SizedBox(width: 3),
                Text(trend, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: trendUp ? kPrimaryGreen : kAccentOrange)),
              ]),
            ),
          ]),
          const SizedBox(height: 14),
          Text(value, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: theme.colorScheme.onSurface, letterSpacing: -0.5)),
          const SizedBox(height: 3),
          Text(title, style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ─── Shared surface card ──────────────────────────────────────────────────────
class _SurfaceCard extends StatelessWidget {
  final ThemeData theme;
  final Widget child;
  final EdgeInsetsGeometry? padding;

  const _SurfaceCard({required this.theme, required this.child, this.padding});

  @override
  Widget build(BuildContext context) {
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1C) : Colors.white,
        borderRadius: BorderRadius.circular(_kCardRadius),
        border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.06), width: 0.5),
      ),
      child: child,
    );
  }
}

// ─── Minimal section label ────────────────────────────────────────────────────
class _MinimalSectionLabel extends StatelessWidget {
  final ThemeData theme;
  final String label;
  final String? subtitle;

  const _MinimalSectionLabel({required this.theme, required this.label, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface, letterSpacing: -0.2)),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(subtitle!, style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant)),
        ],
      ],
    );
  }
}

// ─── Search bar ───────────────────────────────────────────────────────────────
class _SearchBar extends StatelessWidget {
  final ThemeData theme;
  final ValueChanged<String> onChanged;
  final String hintText;

  const _SearchBar({required this.theme, required this.onChanged, required this.hintText});

  @override
  Widget build(BuildContext context) {
    final isDark = theme.brightness == Brightness.dark;
    return TextField(
      onChanged: onChanged,
      style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurface),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(fontSize: 13, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6)),
        prefixIcon: Icon(Icons.search_rounded, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5), size: 17),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.08), width: 0.5)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.08), width: 0.5)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kPrimaryGreen, width: 1)),
        filled: true,
        fillColor: isDark ? const Color(0xFF1C1C1C) : Colors.white,
        contentPadding: const EdgeInsets.symmetric(vertical: 11, horizontal: 12),
        isDense: true,
      ),
    );
  }
}

// ─── Empty / Error / Loading states ──────────────────────────────────────────
class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator(color: kPrimaryGreen, strokeWidth: 2)));
  }
}

class _EmptyState extends StatelessWidget {
  final ThemeData theme;
  final String message;

  const _EmptyState({required this.theme, required this.message});

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      theme: theme,
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Column(children: [
          Icon(Icons.inbox_outlined, size: 32, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4)),
          const SizedBox(height: 10),
          Text(message, style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurfaceVariant)),
        ]),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final ThemeData theme;
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.theme, required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      theme: theme,
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Column(children: [
          const Icon(Icons.error_outline_rounded, size: 28, color: kAccentOrange),
          const SizedBox(height: 10),
          Text(message, textAlign: TextAlign.center, style: const TextStyle(color: kAccentOrange, fontSize: 13)),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: onRetry,
            style: FilledButton.styleFrom(backgroundColor: kPrimaryGreen, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), minimumSize: const Size(80, 34), textStyle: const TextStyle(fontSize: 12)),
            child: const Text('Retry'),
          ),
        ]),
      ),
    );
  }
}

// ─── Date range dropdown ──────────────────────────────────────────────────────
class _DateRangeDropdown extends StatelessWidget {
  final _DateRangeFilter value;
  final ValueChanged<_DateRangeFilter> onChanged;

  const _DateRangeDropdown({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return PopupMenuButton<_DateRangeFilter>(
      tooltip: 'Date range',
      color: isDark ? const Color(0xFF222222) : Colors.white,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      onSelected: onChanged,
      itemBuilder: (context) => _DateRangeFilter.values.map((range) {
        final isSelected = range == value;
        return PopupMenuItem<_DateRangeFilter>(
          value: range,
          height: 38,
          child: Row(children: [
            SizedBox(width: 14, child: isSelected ? const Icon(Icons.check_rounded, size: 12, color: kPrimaryGreen) : null),
            const SizedBox(width: 6),
            Text(range.label, style: TextStyle(fontSize: 13, fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400, color: Theme.of(context).colorScheme.onSurface)),
          ]),
        );
      }).toList(),
      child: Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(border: Border.all(color: kPrimaryGreen.withValues(alpha: 0.4), width: 0.5), borderRadius: BorderRadius.circular(8)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.calendar_today_outlined, size: 12, color: kPrimaryGreen),
          const SizedBox(width: 6),
          Text(value.label, style: const TextStyle(color: kPrimaryGreen, fontSize: 12, fontWeight: FontWeight.w500)),
          const SizedBox(width: 4),
          const Icon(Icons.keyboard_arrow_down_rounded, size: 14, color: kPrimaryGreen),
        ]),
      ),
    );
  }
}

// ─── Green primary button ─────────────────────────────────────────────────────
class _GreenButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool loading;
  final VoidCallback? onPressed;
  final bool compact;

  const _GreenButton({required this.label, required this.icon, required this.loading, required this.onPressed, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: kPrimaryGreen,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        minimumSize: Size(0, compact ? 34 : 38),
        padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 16),
        textStyle: TextStyle(fontSize: compact ? 12 : 13),
      ),
      icon: loading
          ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 1.5))
          : Icon(icon, size: compact ? 14 : 16),
      label: Text(label),
    );
  }
}

// ─── Action icon button ───────────────────────────────────────────────────────
class _ActionIconBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onPressed;
  final double size;

  const _ActionIconBtn({required this.icon, required this.color, required this.tooltip, required this.onPressed, this.size = 15});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          width: 28, height: 28,
          decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(6)),
          child: Icon(icon, size: size, color: color),
        ),
      ),
    );
  }
}

// ─── User avatar initials ─────────────────────────────────────────────────────
class _UserAvatar extends StatelessWidget {
  final String name;
  const _UserAvatar({required this.name});

  String get _initials {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    if (name.isNotEmpty) return name[0].toUpperCase();
    return '?';
  }

  Color get _color {
    final colors = [const Color(0xFF3C6DF0), kPrimaryGreen, const Color(0xFFE6930A), const Color(0xFF9B59B6), const Color(0xFFE74C3C)];
    return colors[name.length % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 26, height: 26,
      decoration: BoxDecoration(color: _color.withValues(alpha: 0.12), shape: BoxShape.circle),
      child: Center(child: Text(_initials, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: _color))),
    );
  }
}

// ─── Pills ────────────────────────────────────────────────────────────────────
class _StatusChip extends StatelessWidget {
  final bool isActive;
  const _StatusChip({required this.isActive});

  @override
  Widget build(BuildContext context) {
    final color = isActive ? kPrimaryGreen : kAccentOrange;
    final label = isActive ? 'Active' : 'Inactive';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.15), width: 0.5),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _TypePill extends StatelessWidget {
  final String type;
  const _TypePill({required this.type});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        type.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _CategoryPill extends StatelessWidget {
  final ThemeData theme;
  final String label;
  const _CategoryPill({required this.theme, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        label,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.secondary, fontWeight: FontWeight.w600),
      ),
    );
  }
}