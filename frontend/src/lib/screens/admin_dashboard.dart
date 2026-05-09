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
  _Section _currentSection = _Section.overview;
  bool _sidebarCollapsed = false;

  final ScrollController _mainScrollController = ScrollController();
  final ScrollController _horizontalScrollController = ScrollController();
  final ScrollController _verticalScrollController = ScrollController();

  List<AdminUser> _users = [];
  bool _loading = true;
  String? _error;
  String _searchQuery = '';
  _DateRangeFilter _usersRange = _DateRangeFilter.monthly;
  Timer? _usersSearchDebounce;
  // Pagination state for users
  int _usersPage = 1;
  final int _usersPerPage = 10;
  bool _usersHasMore = true;
  bool _usersLoadingMore = false;
  int _usersQuerySerial = 0;
  int _usersTotalCount = 0;
  int _usersActiveTotalCount = 0;

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

  @override
  void dispose() {
    _usersSearchDebounce?.cancel();
    _mainScrollController.dispose();
    _horizontalScrollController.dispose();
    _verticalScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    await Future.wait<void>([
      _loadUsersPage(reset: true),
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
      final result = await AdminUserService.instance.fetchUsers(
        range: _usersRange.apiValue,
      );
      if (!mounted) return;
      setState(() {
        _users = result.users;
        _usersTotalCount = result.total;
        _usersActiveTotalCount = result.activeTotal;
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

  void _handleUsersSearchChanged(String value) {
    setState(() => _searchQuery = value);
    _usersSearchDebounce?.cancel();
    _usersSearchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      _loadUsersPage(reset: true);
    });
  }

  Future<void> _loadUsersPage({bool reset = false}) async {
    if (!mounted) return;
    final querySerial = ++_usersQuerySerial;
    if (reset) {
      _usersPage = 1;
      _usersHasMore = true;
      _usersLoadingMore = false;
    }
    if (!_usersHasMore) return;
    if (!reset) {
      setState(() => _usersLoadingMore = true);
    } else {
      setState(() {
        _loading = true;
        _error = null;
        _users = [];
      });
    }

    try {
      final result = await AdminUserService.instance.fetchUsers(
        range: _usersRange.apiValue,
        search: _searchQuery,
        page: _usersPage,
        perPage: _usersPerPage,
      );
      if (!mounted) return;
      if (querySerial != _usersQuerySerial) return;
      setState(() {
        if (reset) {
          _users = result.users;
          _loading = false;
        } else {
          _users.addAll(result.users);
          _usersLoadingMore = false;
        }
        _usersTotalCount = result.total;
        _usersActiveTotalCount = result.activeTotal;
        if (result.users.length < _usersPerPage) {
          _usersHasMore = false;
        } else {
          _usersPage += 1;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
        _usersLoadingMore = false;
      });
    }
  }

  // ── Web modals ────────────────────────────────────────────────────────────

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
            if (snapshot.hasError) {
              return _ModalError(message: snapshot.error.toString());
            }
            final posts = snapshot.data ?? [];
            if (posts.isEmpty) {
              return const _ModalEmpty(
                message: 'This user has not created any posts yet.',
              );
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
      await Share.shareXFiles([
        xfile,
      ], subject: 'WellNest Content Reports Export');
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
      final filteredUsersResult = await AdminUserService.instance.fetchUsers(
        range: _insightsRange.apiValue,
      );
      final filteredReports = await AdminModerationService.instance
          .fetchReports(range: _insightsRange.apiValue);
      final totalUsers = _usersTotalCount;
      final activeUsers = filteredUsersResult.users.where((u) => u.isActive).length;
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
      await Share.shareXFiles([
        xfile,
      ], subject: 'WellNest Admin Insights Report');
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

  Future<void> _confirmDeactivate(AdminUser user) async {
    final ok = await _showConfirmDialog(
      title: 'Deactivate account?',
      content:
          'Deactivate "${user.name}" (${user.email})? They will not be able to sign in until reactivated.',
      actionLabel: 'Deactivate',
      actionColor: kAccentOrange,
    );
    if (ok != true || !mounted) return;
    await _updateStatus(user.id, 'inactive');
  }

  Future<void> _confirmActivate(AdminUser user) async {
    final ok = await _showConfirmDialog(
      title: 'Activate account?',
      content:
          'Reactivate "${user.name}" (${user.email})? They will be able to sign in again.',
      actionLabel: 'Activate',
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
        status == 'active' ? 'Account activated' : 'Account deactivated',
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
      content:
          'Permanently delete "${user.name}" (${user.email})? This cannot be undone.',
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
              style: TextStyle(
                color: Theme.of(ctx).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: actionColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
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
                onRefresh: _loadAll,
                onToggleTheme: _toggleTheme,
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async => _loadAll(),
                  color: kPrimaryGreen,
                  child: Scrollbar(
                    controller: _mainScrollController,
                    thumbVisibility: true,
                    child: SingleChildScrollView(
                      controller: _mainScrollController,
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(24),
                      child: _buildSectionContent(theme, isWide: true),
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
          onRefresh: _loadAll,
          showMenuButton: true,
          onMenuPressed: _handleLogout,
          onToggleTheme: _toggleTheme,
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async => _loadAll(),
            color: kPrimaryGreen,
            child: Scrollbar(
              controller: _mainScrollController,
              thumbVisibility: true,
              child: SingleChildScrollView(
                controller: _mainScrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: _buildSectionContent(theme, isWide: false),
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
    if (!context.mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/login', (r) => false);
  }

  void _toggleTheme() => context.read<ThemeProvider>().toggleTheme();

  Widget _buildSectionContent(ThemeData theme, {required bool isWide}) {
    switch (_currentSection) {
      case _Section.overview:
        return _OverviewSection(
          theme: theme,
          isWide: isWide,
          users: _users,
          totalUsers: _usersTotalCount,
          activeUsers: _usersActiveTotalCount,
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
          users: _users,
          loading: _loading,
          error: _error,
          searchQuery: _searchQuery,
          onSearchChanged: _handleUsersSearchChanged,
          selectedRange: _usersRange,
          onRangeChanged: (range) {
            setState(() => _usersRange = range);
            _loadUsersPage(reset: true);
          },
          onRefresh: () => _loadUsersPage(reset: true),
          onExport: _exportingUsersCsv ? null : _exportUsersCsv,
          exporting: _exportingUsersCsv,
          onDeactivate: _confirmDeactivate,
          onActivate: _confirmActivate,
          onDelete: _confirmDelete,
          onViewPosts: _showUserPostsModal,
          onViewComments: _showUserCommentsModal,
          onViewRecipes: _showUserRecipesModal,
          hasMore: _usersHasMore,
          isLoadingMore: _usersLoadingMore,
          onLoadMore: () => _loadUsersPage(reset: false),
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

// ─── Web Modal Shell ──────────────────────────────────────────────────────────
class _WebModal extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color iconColor;
  final Widget child;

  const _WebModal({
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final screenSize = MediaQuery.sizeOf(context);
    final modalWidth = (screenSize.width * 0.88).clamp(340.0, 760.0);
    final modalMaxHeight = screenSize.height * 0.84;
    final cardBg = isDark ? const Color(0xFF1C1C1C) : Colors.white;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.07)
        : Colors.black.withValues(alpha: 0.07);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: modalWidth,
          maxHeight: modalMaxHeight,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor, width: 0.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.14),
                blurRadius: 48,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 14),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: iconColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(icon, size: 16, color: iconColor),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      style: IconButton.styleFrom(
                        minimumSize: const Size(34, 34),
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(color: borderColor, width: 0.5),
                        ),
                      ),
                      tooltip: 'Close',
                    ),
                  ],
                ),
              ),
              Divider(height: 0.5, color: borderColor),
              // Scrollable body
              Flexible(
                child: Scrollbar(
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                    child: child,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Modal shared states ──────────────────────────────────────────────────────
class _ModalLoading extends StatelessWidget {
  const _ModalLoading();
  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.all(48),
    child: Center(
      child: CircularProgressIndicator(color: kPrimaryGreen, strokeWidth: 2),
    ),
  );
}

class _ModalError extends StatelessWidget {
  final String message;
  const _ModalError({required this.message});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(32),
    child: Center(
      child: Text(
        message.replaceFirst('Exception: ', ''),
        style: const TextStyle(color: kAccentOrange, fontSize: 13),
        textAlign: TextAlign.center,
      ),
    ),
  );
}

class _ModalEmpty extends StatelessWidget {
  final String message;
  const _ModalEmpty({required this.message});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 36,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.35),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              style: TextStyle(
                fontSize: 13,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Posts Modal Content ──────────────────────────────────────────────────────
class _PostsModalContent extends StatelessWidget {
  final List<Post> posts;
  const _PostsModalContent({required this.posts});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: List.generate(posts.length, (i) {
        final post = posts[i];
        final cardBg = isDark
            ? const Color(0xFF252525)
            : const Color(0xFFF9F9F9);
        final borderColor = isDark
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.black.withValues(alpha: 0.06);
        return Padding(
          padding: EdgeInsets.only(bottom: i == posts.length - 1 ? 0 : 10),
          child: Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor, width: 0.5),
            ),
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  post.content.isEmpty ? 'No text content' : post.content,
                  maxLines: 5,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    color: theme.colorScheme.onSurface,
                    height: 1.5,
                  ),
                ),
                if (post.displayImageUrl != null) ...[
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(
                      post.displayImageUrl!,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: 160,
                      errorBuilder: (_, __, ___) => Container(
                        height: 60,
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.04)
                              : Colors.black.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.broken_image_outlined,
                              size: 16,
                              color: theme.colorScheme.onSurfaceVariant
                                  .withValues(alpha: 0.4),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Image unavailable',
                              style: TextStyle(
                                fontSize: 11,
                                color: theme.colorScheme.onSurfaceVariant
                                    .withValues(alpha: 0.5),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(
                      Icons.chat_bubble_outline_rounded,
                      size: 12,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${post.commentsCount}',
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Icon(
                      Icons.favorite_border_rounded,
                      size: 12,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${post.likesCount}',
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      post.createdAt != null
                          ? post.createdAt!.split('T').first
                          : 'Unknown',
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}

// ─── Comments Modal Content ───────────────────────────────────────────────────
class _CommentsModalContent extends StatefulWidget {
  final AdminUser user;
  const _CommentsModalContent({required this.user});
  @override
  State<_CommentsModalContent> createState() => _CommentsModalContentState();
}

class _CommentsModalContentState extends State<_CommentsModalContent> {
  final Map<int, Future<List<PostComment>>> _commentFutures = {};
  int? _expandedPostId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return FutureBuilder<List<Post>>(
      future: ApiService().fetchPosts(userId: widget.user.id),
      builder: (ctx, snapshot) {
        if (snapshot.connectionState != ConnectionState.done)
          return const _ModalLoading();
        if (snapshot.hasError)
          return _ModalError(message: snapshot.error.toString());
        final posts = snapshot.data ?? [];
        if (posts.isEmpty)
          return const _ModalEmpty(
            message: 'This user has no posts to show comments for.',
          );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: List.generate(posts.length, (i) {
            final post = posts[i];
            final isExpanded = _expandedPostId == post.id;
            final cardBg = isDark
                ? const Color(0xFF252525)
                : const Color(0xFFF9F9F9);
            final borderColor = isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.06);

            return Padding(
              padding: EdgeInsets.only(bottom: i == posts.length - 1 ? 0 : 10),
              child: Container(
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderColor, width: 0.5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Post header row
                    InkWell(
                      onTap: () => setState(() {
                        if (isExpanded) {
                          _expandedPostId = null;
                        } else {
                          _expandedPostId = post.id;
                          _commentFutures[post.id] ??= PostService.instance
                              .fetchComments(post.id);
                        }
                      }),
                      borderRadius: isExpanded
                          ? const BorderRadius.vertical(
                              top: Radius.circular(12),
                            )
                          : BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    post.content.isEmpty
                                        ? 'Untitled post'
                                        : post.content,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: theme.colorScheme.onSurface,
                                      height: 1.4,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${post.commentsCount} comment${post.commentsCount == 1 ? '' : 's'}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: kPrimaryGreen.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Icon(
                                isExpanded
                                    ? Icons.expand_less_rounded
                                    : Icons.expand_more_rounded,
                                size: 16,
                                color: kPrimaryGreen,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Expanded comments
                    if (isExpanded) ...[
                      Divider(height: 0.5, color: borderColor),
                      FutureBuilder<List<PostComment>>(
                        future: _commentFutures[post.id],
                        builder: (ctx, cs) {
                          if (cs.connectionState != ConnectionState.done)
                            return const Padding(
                              padding: EdgeInsets.all(24),
                              child: Center(
                                child: CircularProgressIndicator(
                                  color: kPrimaryGreen,
                                  strokeWidth: 2,
                                ),
                              ),
                            );
                          if (cs.hasError)
                            return Padding(
                              padding: const EdgeInsets.all(16),
                              child: Text(
                                cs.error.toString(),
                                style: const TextStyle(
                                  color: kAccentOrange,
                                  fontSize: 12,
                                ),
                              ),
                            );
                          final comments = cs.data ?? [];
                          if (comments.isEmpty)
                            return const Padding(
                              padding: EdgeInsets.all(20),
                              child: Text(
                                'No comments on this post yet.',
                                style: TextStyle(fontSize: 12),
                              ),
                            );
                          return Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              children: comments.map((comment) {
                                final cBg = isDark
                                    ? const Color(0xFF1E1E1E)
                                    : Colors.white;
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  decoration: BoxDecoration(
                                    color: cBg,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: borderColor,
                                      width: 0.5,
                                    ),
                                  ),
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          _UserAvatar(name: comment.userName),
                                          const SizedBox(width: 8),
                                          Text(
                                            comment.userName,
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color:
                                                  theme.colorScheme.onSurface,
                                            ),
                                          ),
                                          const Spacer(),
                                          Text(
                                            comment.createdAt.isEmpty
                                                ? 'Unknown'
                                                : comment.createdAt
                                                      .split('T')
                                                      .first,
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: theme
                                                  .colorScheme
                                                  .onSurfaceVariant,
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (comment.comment.isNotEmpty) ...[
                                        const SizedBox(height: 6),
                                        Text(
                                          comment.comment,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: theme.colorScheme.onSurface,
                                            height: 1.4,
                                          ),
                                        ),
                                      ],
                                      if (comment.imageUrl != null) ...[
                                        const SizedBox(height: 8),
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          child: Image.network(
                                            comment.imageUrl!,
                                            fit: BoxFit.cover,
                                            width: double.infinity,
                                            height: 100,
                                            errorBuilder: (_, __, ___) =>
                                                Container(
                                                  height: 40,
                                                  color: isDark
                                                      ? Colors.white.withValues(
                                                          alpha: 0.04,
                                                        )
                                                      : Colors.black.withValues(
                                                          alpha: 0.04,
                                                        ),
                                                  child: Center(
                                                    child: Text(
                                                      'Image unavailable',
                                                      style: TextStyle(
                                                        fontSize: 10,
                                                        color: theme
                                                            .colorScheme
                                                            .onSurfaceVariant,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

// ─── Recipes Modal Content ────────────────────────────────────────────────────
class _RecipesModalContent extends StatefulWidget {
  final int userId;
  const _RecipesModalContent({required this.userId});
  @override
  State<_RecipesModalContent> createState() => _RecipesModalContentState();
}

class _RecipesModalContentState extends State<_RecipesModalContent> {
  bool _cardView = true; // toggle: card vs list

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return FutureBuilder<List<Recipe>>(
      future: RecipeService.instance.fetchRecipes(userId: widget.userId).then((res) => res.recipes),
      builder: (ctx, snapshot) {
        if (snapshot.connectionState != ConnectionState.done)
          return const _ModalLoading();
        if (snapshot.hasError)
          return _ModalError(message: snapshot.error.toString());
        final recipes = snapshot.data ?? [];
        if (recipes.isEmpty)
          return const _ModalEmpty(
            message: 'This user has not created any recipes yet.',
          );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Toolbar: count + view toggle
            Row(
              children: [
                Text(
                  '${recipes.length} recipe${recipes.length == 1 ? '' : 's'}',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                _ViewToggle(
                  isCard: _cardView,
                  onChanged: (v) => setState(() => _cardView = v),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Card grid view
            if (_cardView)
              _RecipeCardGrid(recipes: recipes, isDark: isDark, theme: theme)
            else
              _RecipeListView(recipes: recipes, isDark: isDark, theme: theme),
          ],
        );
      },
    );
  }
}

// ─── View toggle button ───────────────────────────────────────────────────────
class _ViewToggle extends StatelessWidget {
  final bool isCard;
  final ValueChanged<bool> onChanged;
  const _ViewToggle({required this.isCard, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: 30,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.black.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ToggleBtn(
            icon: Icons.grid_view_rounded,
            active: isCard,
            onTap: () => onChanged(true),
            tooltip: 'Card view',
          ),
          const SizedBox(width: 2),
          _ToggleBtn(
            icon: Icons.view_list_rounded,
            active: !isCard,
            onTap: () => onChanged(false),
            tooltip: 'List view',
          ),
        ],
      ),
    );
  }
}

class _ToggleBtn extends StatelessWidget {
  final IconData icon;
  final bool active;
  final VoidCallback onTap;
  final String tooltip;
  const _ToggleBtn({
    required this.icon,
    required this.active,
    required this.onTap,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 26,
          height: 24,
          decoration: BoxDecoration(
            color: active
                ? (isDark ? const Color(0xFF2A2A2A) : Colors.white)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(5),
          ),
          child: Icon(
            icon,
            size: 14,
            color: active
                ? kPrimaryGreen
                : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

// ─── Recipe Card Grid ─────────────────────────────────────────────────────────
class _RecipeCardGrid extends StatelessWidget {
  final List<Recipe> recipes;
  final bool isDark;
  final ThemeData theme;
  const _RecipeCardGrid({
    required this.recipes,
    required this.isDark,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    // Responsive: 2 columns on wide modal, 1 on narrow
    final width = MediaQuery.sizeOf(context).width;
    final cols = width >= 600 ? 2 : 1;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.07)
        : Colors.black.withValues(alpha: 0.07);
    final cardBg = isDark ? const Color(0xFF252525) : const Color(0xFFF9F9F9);

    return LayoutBuilder(
      builder: (ctx, constraints) {
        final colWidth = (constraints.maxWidth - (cols - 1) * 12) / cols;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: recipes.map((recipe) {
            final imageUrl = recipe.displayImageUrl;
            final rating = recipe.averageRating;
            final ratingsCount = recipe.ratingsCount ?? 0;
            final category = recipe.category?.name;

            return SizedBox(
              width: colWidth,
              child: Container(
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderColor, width: 0.5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Image
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(12),
                      ),
                      child: imageUrl != null
                          ? Image.network(
                              imageUrl,
                              height: 140,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  _RecipeImagePlaceholder(
                                    isDark: isDark,
                                    theme: theme,
                                  ),
                            )
                          : _RecipeImagePlaceholder(
                              isDark: isDark,
                              theme: theme,
                            ),
                    ),
                    // Info
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (category != null) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: kPrimaryGreen.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                category,
                                style: const TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                  color: kPrimaryGreen,
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                          ],
                          Text(
                            recipe.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurface,
                              height: 1.3,
                            ),
                          ),
                          if (recipe.description?.isNotEmpty == true) ...[
                            const SizedBox(height: 4),
                            Text(
                              recipe.description!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                color: theme.colorScheme.onSurfaceVariant,
                                height: 1.4,
                              ),
                            ),
                          ],
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              if (rating != null) ...[
                                const Icon(
                                  Icons.star_rounded,
                                  size: 13,
                                  color: Color(0xFFE6930A),
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  rating.toStringAsFixed(1),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFFE6930A),
                                  ),
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  '($ratingsCount)',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                              const Spacer(),
                              if (recipe.prepTime != null) ...[
                                Icon(
                                  Icons.schedule_rounded,
                                  size: 12,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  '${recipe.prepTime} min',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

// ─── Recipe List View ─────────────────────────────────────────────────────────
class _RecipeListView extends StatelessWidget {
  final List<Recipe> recipes;
  final bool isDark;
  final ThemeData theme;
  const _RecipeListView({
    required this.recipes,
    required this.isDark,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.07)
        : Colors.black.withValues(alpha: 0.07);
    final cardBg = isDark ? const Color(0xFF252525) : const Color(0xFFF9F9F9);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: List.generate(recipes.length, (i) {
        final recipe = recipes[i];
        final imageUrl = recipe.displayImageUrl;
        final rating = recipe.averageRating;
        final ratingsCount = recipe.ratingsCount ?? 0;
        final category = recipe.category?.name;

        return Padding(
          padding: EdgeInsets.only(bottom: i == recipes.length - 1 ? 0 : 8),
          child: Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor, width: 0.5),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Thumbnail
                ClipRRect(
                  borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(12),
                  ),
                  child: SizedBox(
                    width: 88,
                    height: 88,
                    child: imageUrl != null
                        ? Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                _RecipeImagePlaceholder(
                                  isDark: isDark,
                                  theme: theme,
                                  small: true,
                                ),
                          )
                        : _RecipeImagePlaceholder(
                            isDark: isDark,
                            theme: theme,
                            small: true,
                          ),
                  ),
                ),
                // Details
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            if (category != null) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 1,
                                ),
                                decoration: BoxDecoration(
                                  color: kPrimaryGreen.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  category,
                                  style: const TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w600,
                                    color: kPrimaryGreen,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                            ],
                            if (recipe.prepTime != null)
                              Text(
                                '${recipe.prepTime} min',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          recipe.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        if (recipe.description?.isNotEmpty == true) ...[
                          const SizedBox(height: 3),
                          Text(
                            recipe.description!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              color: theme.colorScheme.onSurfaceVariant,
                              height: 1.4,
                            ),
                          ),
                        ],
                        const SizedBox(height: 6),
                        if (rating != null)
                          Row(
                            children: [
                              const Icon(
                                Icons.star_rounded,
                                size: 12,
                                color: Color(0xFFE6930A),
                              ),
                              const SizedBox(width: 3),
                              Text(
                                rating.toStringAsFixed(1),
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFFE6930A),
                                ),
                              ),
                              const SizedBox(width: 3),
                              Text(
                                '($ratingsCount)',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}

class _RecipeImagePlaceholder extends StatelessWidget {
  final bool isDark;
  final ThemeData theme;
  final bool small;
  const _RecipeImagePlaceholder({
    required this.isDark,
    required this.theme,
    this.small = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: isDark
          ? Colors.white.withValues(alpha: 0.04)
          : Colors.black.withValues(alpha: 0.04),
      child: Center(
        child: Icon(
          Icons.restaurant_menu_outlined,
          size: small ? 20 : 28,
          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
        ),
      ),
    );
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
                size: 17,
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
          NotificationsDropdown(
            iconColor: kAccentOrange,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                _TopBarIconBtn(
                  icon: Icons.notifications_outlined,
                  onPressed: null,
                  tooltip: 'Notifications',
                  color: kAccentOrange,
                ),
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: kAccentOrange,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ),
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
  Widget build(BuildContext context) => IconButton(
    onPressed: onPressed,
    icon: Icon(icon, size: 18, color: color),
    tooltip: tooltip,
    style: IconButton.styleFrom(
      minimumSize: const Size(34, 34),
      padding: EdgeInsets.zero,
    ),
  );
}

// ─── Overview Section ─────────────────────────────────────────────────────────
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
        _MinimalSectionLabel(
          theme: theme,
          label: 'Analytics',
          subtitle: 'Growth and platform activity trends',
        ),
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
            : Column(
                children: [
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
                ],
              ),
        const SizedBox(height: 12),
        isWide
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _ModerationDonutCard(
                      theme: theme,
                      isDark: isDark,
                      reports: reports,
                    ),
                  ),
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
            : Column(
                children: [
                  _ModerationDonutCard(
                    theme: theme,
                    isDark: isDark,
                    reports: reports,
                  ),
                  const SizedBox(height: 12),
                  _AuditActivityCard(
                    theme: theme,
                    isDark: isDark,
                    userGrowthPoints: userGrowthPoints,
                    postFrequencyPoints: postFrequencyPoints,
                    chatbotInteractionPoints: chatbotInteractionPoints,
                  ),
                ],
              ),
        if (analyticsLoading) ...[
          const SizedBox(height: 10),
          LinearProgressIndicator(
            minHeight: 2,
            color: kPrimaryGreen,
            backgroundColor: theme.colorScheme.surfaceContainerHighest
                .withValues(alpha: 0.5),
          ),
        ] else if (analyticsError != null && analyticsError!.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            analyticsError!,
            style: TextStyle(fontSize: 11, color: theme.colorScheme.error),
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
    final cardColor = isDark ? const Color(0xFF1F2329) : Colors.white;
    final borderColor = isDark
        ? kPrimaryGreen.withValues(alpha: 0.22)
        : kPrimaryGreen.withValues(alpha: 0.14);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(_kCardRadius),
        border: Border.all(color: borderColor, width: 1),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.26)
                : kPrimaryGreen.withValues(alpha: 0.06),
            blurRadius: isDark ? 16 : 12,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: isDark
                ? kPrimaryGreen.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.03),
            blurRadius: 1,
          ),
        ],
      ),
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
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeGreen
                      ? kPrimaryGreen.withValues(alpha: 0.08)
                      : theme.colorScheme.surfaceContainerHighest.withValues(
                          alpha: 0.5,
                        ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  badge,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: badgeGreen
                        ? kPrimaryGreen
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(spacing: 12, runSpacing: 6, children: legend),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  final bool dashed;
  const _LegendDot({
    required this.color,
    required this.label,
    this.dashed = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

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

class _ModerationDonutCard extends StatelessWidget {
  final ThemeData theme;
  final bool isDark;
  final List<Report> reports;
  const _ModerationDonutCard({
    required this.theme,
    required this.isDark,
    required this.reports,
  });

  @override
  Widget build(BuildContext context) {
    final buckets = _countModerationStatuses(reports);
    final donutValues = <double>[
      buckets.open.toDouble(),
      buckets.dismissed.toDouble(),
      buckets.approved.toDouble(),
      buckets.removed.toDouble(),
    ];
    final total = reports.length;
    return _ChartCard(
      theme: theme,
      title: 'Moderation overview',
      subtitle: 'Report status breakdown',
      badge: total == 0 ? 'No reports' : '${buckets.open} open',
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
          : (postFrequencyPoints.isNotEmpty
                ? postFrequencyPoints
                : chatbotInteractionPoints),
      pointsCount,
    );
    final usersSeries = _normalizeSeries(userGrowthPoints, pointsCount);
    final postsSeries = _normalizeSeries(postFrequencyPoints, pointsCount);
    final chatbotSeries = _normalizeSeries(
      chatbotInteractionPoints,
      pointsCount,
    );
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
  final labels = tail.map((d) => '${d.month}/${d.day}').toList(growable: true);
  while (labels.length < length) labels.insert(0, '—');
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
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final month = months[local.month - 1];
  final hour12 = local.hour == 0
      ? 12
      : (local.hour > 12 ? local.hour - 12 : local.hour);
  final minute = local.minute.toString().padLeft(2, '0');
  final meridiem = local.hour >= 12 ? 'PM' : 'AM';
  return '$month ${local.day}, ${local.year} • $hour12:$minute $meridiem';
}

String _normalizeReportStatus(String status) {
  final normalized = status.trim().toLowerCase();
  if (normalized == 'pending') return 'open';
  return normalized;
}

({int open, int dismissed, int approved, int removed}) _countModerationStatuses(
  List<Report> reports,
) {
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
  return (
    open: open,
    dismissed: dismissed,
    approved: approved,
    removed: removed,
  );
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
    const double padLeft = 36;
    const double padRight = 12;
    const double padTop = 10;
    const double padBottom = 24;
    final chartW = size.width - padLeft - padRight;
    final chartH = size.height - padTop - padBottom;
    final allValues = [...seriesA, ...seriesB];
    final dataMin = allValues.isNotEmpty ? allValues.reduce(math.min) : 0.0;
    final dataMax = allValues.isNotEmpty ? allValues.reduce(math.max) : 0.0;
    final minV = dataMin;
    final maxV = dataMax;
    final range = (maxV - minV) == 0 ? (maxV == 0 ? 1.0 : maxV) : maxV - minV;
    final gridPaint = Paint()
      ..color = (isDark ? Colors.white : Colors.black).withOpacity(0.06)
      ..strokeWidth = 0.5;
    final labelStyle = TextStyle(
      fontSize: 9,
      color: isDark ? const Color(0xFF888780) : const Color(0xFF888780),
    );
    const gridCount = 4;
    for (int i = 0; i <= gridCount; i++) {
      final y = padTop + chartH - (i / gridCount) * chartH;
      canvas.drawLine(
        Offset(padLeft, y),
        Offset(padLeft + chartW, y),
        gridPaint,
      );
      final val = minV + (i / gridCount) * range;
      final label = val >= 1000
          ? '${(val / 1000).toStringAsFixed(1)}k'
          : val.toInt().toString();
      _drawText(
        canvas,
        label,
        Offset(0, y - 5),
        labelStyle,
        maxWidth: padLeft - 4,
        align: TextAlign.right,
      );
    }
    if (labels.length > 1) {
      for (int i = 0; i < labels.length; i++) {
        final x = padLeft + (i / (labels.length - 1)) * chartW;
        _drawText(
          canvas,
          labels[i],
          Offset(x - 14, size.height - padBottom + 6),
          labelStyle,
          maxWidth: 28,
        );
      }
    }
    Path buildPath(List<double> data) {
      final path = Path();
      if (data.isEmpty) return path;
      for (int i = 0; i < data.length; i++) {
        final x = data.length > 1
            ? padLeft + (i / (data.length - 1)) * chartW
            : padLeft + chartW / 2;
        final y = padTop + chartH - ((data[i] - minV) / range) * chartH;
        i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
      }
      return path;
    }

    void drawFill(List<double> data, Color color) {
      final path = buildPath(data);
      final fillPath = Path.from(path)
        ..lineTo(padLeft + chartW, padTop + chartH)
        ..lineTo(padLeft, padTop + chartH)
        ..close();
      canvas.drawPath(
        fillPath,
        Paint()
          ..color = color.withOpacity(0.08)
          ..style = PaintingStyle.fill,
      );
    }

    drawFill(seriesA, colorA);
    drawFill(seriesB, colorB);
    void drawLine(List<double> data, Color color, {bool dashed = false}) {
      final path = buildPath(data);
      final paint = Paint()
        ..color = color
        ..strokeWidth = 2
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
    void drawDots(List<double> data, Color color) {
      for (int i = 0; i < data.length; i++) {
        final x = padLeft + (i / (data.length - 1)) * chartW;
        final y = padTop + chartH - ((data[i] - minV) / range) * chartH;
        canvas.drawCircle(Offset(x, y), 3.5, Paint()..color = color);
        canvas.drawCircle(
          Offset(x, y),
          2,
          Paint()..color = isDark ? const Color(0xFF1C1C1C) : Colors.white,
        );
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
      if (drawing) canvas.drawPath(metric.extractPath(dist, next), paint);
      dist = next;
      drawing = !drawing;
    }
  }

  void _drawText(
    Canvas canvas,
    String text,
    Offset offset,
    TextStyle style, {
    double maxWidth = 60,
    TextAlign align = TextAlign.left,
  }) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textAlign: align,
    )..layout(maxWidth: maxWidth);
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
  const _BarPainter({
    required this.values,
    required this.labels,
    required this.colors,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const double padLeft = 36;
    const double padRight = 12;
    const double padTop = 10;
    const double padBottom = 24;
    final chartW = size.width - padLeft - padRight;
    final chartH = size.height - padTop - padBottom;
    final dataMax = values.isNotEmpty ? values.reduce(math.max) : 0.0;
    final maxV = dataMax <= 0 ? 1.0 : dataMax;
    final n = values.length;
    final barW = n > 0 ? (chartW / n) * 0.55 : 0.0;
    final gap = n > 0 ? (chartW / n) * 0.45 : 0.0;
    final gridPaint = Paint()
      ..color = (isDark ? Colors.white : Colors.black).withOpacity(0.06)
      ..strokeWidth = 0.5;
    final labelStyle = TextStyle(
      fontSize: 9,
      color: isDark ? const Color(0xFF888780) : const Color(0xFF888780),
    );
    const gridCount = 4;
    for (int i = 0; i <= gridCount; i++) {
      final y = padTop + chartH - (i / gridCount) * chartH;
      canvas.drawLine(
        Offset(padLeft, y),
        Offset(padLeft + chartW, y),
        gridPaint,
      );
      final val = (i / gridCount) * maxV;
      final label = val >= 1000
          ? '${(val / 1000).toStringAsFixed(1)}k'
          : val.toInt().toString();
      _drawText(
        canvas,
        label,
        Offset(0, y - 5),
        labelStyle,
        maxWidth: padLeft - 4,
        align: TextAlign.right,
      );
    }
    for (int i = 0; i < n; i++) {
      final x = padLeft + i * (chartW / n) + gap / 2;
      final barH = (values[i] / maxV) * chartH;
      final y = padTop + chartH - barH;
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          Rect.fromLTWH(x, y, barW, barH),
          topLeft: const Radius.circular(4),
          topRight: const Radius.circular(4),
        ),
        Paint()..color = colors[i],
      );
      _drawText(
        canvas,
        labels[i],
        Offset(x - 2, size.height - padBottom + 6),
        labelStyle,
        maxWidth: barW + 8,
      );
    }
  }

  void _drawText(
    Canvas canvas,
    String text,
    Offset offset,
    TextStyle style, {
    double maxWidth = 60,
    TextAlign align = TextAlign.left,
  }) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textAlign: align,
    )..layout(maxWidth: maxWidth);
    tp.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _BarPainter old) =>
      old.values != values || old.isDark != isDark;
}

// ─── CustomPainter: Donut Chart ───────────────────────────────────────────────
class _DonutPainter extends CustomPainter {
  final List<double> values;
  final List<String> labels;
  final List<Color> colors;
  final bool isDark;
  const _DonutPainter({
    required this.values,
    required this.labels,
    required this.colors,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final total = values.fold(0.0, (a, b) => a + b);
    final safeTotal = total <= 0 ? 1.0 : total;
    final cx = size.width * 0.38;
    final cy = size.height / 2;
    final radius = math.min(cx, cy) - 8;
    const strokeW = 26.0;
    double startAngle = -math.pi / 2;
    for (int i = 0; i < values.length; i++) {
      final sweep = (values[i] / safeTotal) * 2 * math.pi;
      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: radius),
        startAngle + 0.03,
        sweep - 0.06,
        false,
        Paint()
          ..color = colors[i]
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeW
          ..strokeCap = StrokeCap.butt,
      );
      startAngle += sweep;
    }
    _drawCenteredText(
      canvas,
      total.toInt().toString(),
      Offset(cx, cy - 8),
      TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: isDark ? Colors.white : const Color(0xFF2C2C2A),
      ),
    );
    _drawCenteredText(
      canvas,
      'reports',
      Offset(cx, cy + 10),
      TextStyle(
        fontSize: 9,
        color: isDark ? const Color(0xFF888780) : const Color(0xFF888780),
      ),
    );
    final legendX = size.width * 0.62;
    const legendStartY = 20.0;
    const itemH = 26.0;
    final labelStyle = TextStyle(
      fontSize: 11,
      color: isDark ? const Color(0xFFD3D1C7) : const Color(0xFF444441),
    );
    final subStyle = TextStyle(
      fontSize: 10,
      color: isDark ? const Color(0xFF888780) : const Color(0xFF888780),
    );
    for (int i = 0; i < values.length; i++) {
      final y = legendStartY + i * itemH;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(legendX, y + 3, 9, 9),
          const Radius.circular(2),
        ),
        Paint()..color = colors[i],
      );
      final pct = ((values[i] / safeTotal) * 100).toStringAsFixed(0);
      _drawText(
        canvas,
        labels[i],
        Offset(legendX + 14, y),
        labelStyle,
        maxWidth: size.width - legendX - 14,
      );
      _drawText(
        canvas,
        '$pct%  ·  ${values[i].toInt()}',
        Offset(legendX + 14, y + 13),
        subStyle,
        maxWidth: size.width - legendX - 14,
      );
    }
  }

  void _drawCenteredText(
    Canvas canvas,
    String text,
    Offset center,
    TextStyle style,
  ) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(
      canvas,
      Offset(center.dx - tp.width / 2, center.dy - tp.height / 2),
    );
  }

  void _drawText(
    Canvas canvas,
    String text,
    Offset offset,
    TextStyle style, {
    double maxWidth = 80,
  }) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: maxWidth);
    tp.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) =>
      old.values != values || old.isDark != isDark;
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
    const double padLeft = 36;
    const double padRight = 12;
    const double padTop = 10;
    const double padBottom = 24;
    final chartW = size.width - padLeft - padRight;
    final chartH = size.height - padTop - padBottom;
    final n = seriesA.length;
    double maxV = 0;
    for (int i = 0; i < n; i++)
      maxV = math.max(maxV, seriesA[i] + seriesB[i] + seriesC[i]);
    maxV = (maxV * 1.1).ceilToDouble();
    final barW = (chartW / n) * 0.55;
    final gap = (chartW / n) * 0.45;
    final gridPaint = Paint()
      ..color = (isDark ? Colors.white : Colors.black).withOpacity(0.06)
      ..strokeWidth = 0.5;
    final labelStyle = TextStyle(
      fontSize: 9,
      color: isDark ? const Color(0xFF888780) : const Color(0xFF888780),
    );
    const gridCount = 4;
    for (int i = 0; i <= gridCount; i++) {
      final y = padTop + chartH - (i / gridCount) * chartH;
      canvas.drawLine(
        Offset(padLeft, y),
        Offset(padLeft + chartW, y),
        gridPaint,
      );
      _drawText(
        canvas,
        ((i / gridCount) * maxV).toInt().toString(),
        Offset(0, y - 5),
        labelStyle,
        maxWidth: padLeft - 4,
        align: TextAlign.right,
      );
    }
    for (int i = 0; i < n; i++) {
      final x = padLeft + i * (chartW / n) + gap / 2;
      double currentY = padTop + chartH;
      void drawSegment(double val, Color color, {bool isTop = false}) {
        if (val <= 0) return;
        final segH = (val / maxV) * chartH;
        final top = currentY - segH;
        final rRect = isTop
            ? RRect.fromRectAndCorners(
                Rect.fromLTWH(x, top, barW, segH),
                topLeft: const Radius.circular(3),
                topRight: const Radius.circular(3),
              )
            : RRect.fromRectAndCorners(Rect.fromLTWH(x, top, barW, segH));
        canvas.drawRRect(rRect, Paint()..color = color);
        currentY = top;
      }

      drawSegment(seriesC[i], colorC);
      drawSegment(seriesB[i], colorB);
      drawSegment(seriesA[i], colorA, isTop: true);
      _drawText(
        canvas,
        labels[i],
        Offset(x - 2, size.height - padBottom + 6),
        labelStyle,
        maxWidth: barW + 12,
      );
    }
  }

  void _drawText(
    Canvas canvas,
    String text,
    Offset offset,
    TextStyle style, {
    double maxWidth = 60,
    TextAlign align = TextAlign.left,
  }) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textAlign: align,
    )..layout(maxWidth: maxWidth);
    tp.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _StackedBarPainter old) =>
      old.seriesA != seriesA ||
      old.seriesB != seriesB ||
      old.seriesC != seriesC ||
      old.isDark != isDark;
}

// ─── Recipe Rankings Card ─────────────────────────────────────────────────────
class _OverviewRecipeRankingsCard extends StatefulWidget {
  final ThemeData theme;
  final int refreshNonce;
  const _OverviewRecipeRankingsCard({
    required this.theme,
    required this.refreshNonce,
  });
  @override
  State<_OverviewRecipeRankingsCard> createState() =>
      _OverviewRecipeRankingsCardState();
}

class _OverviewRecipeRankingsCardState
    extends State<_OverviewRecipeRankingsCard> {
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
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await RecipeService.instance.fetchRankings(
        window: _window,
        mode: 'combined',
      );
      if (!mounted) return;
      setState(() {
        _rows = rows;
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

  void _sort<T>(int column, T Function(RecipeRankingItem r) key) {
    setState(() {
      if (_sortIndex == column) {
        _ascending = !_ascending;
      } else {
        _sortIndex = column;
        _ascending = false;
      }
      _rows.sort((a, b) {
        final cmp = Comparable.compare(
          key(a) as Comparable,
          key(b) as Comparable,
        );
        return _ascending ? cmp : -cmp;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    if (_loading)
      return _SurfaceCard(
        theme: theme,
        child: const Padding(
          padding: EdgeInsets.all(32),
          child: Center(
            child: CircularProgressIndicator(
              color: kPrimaryGreen,
              strokeWidth: 2,
            ),
          ),
        ),
      );
    if (_error != null)
      return _SurfaceCard(
        theme: theme,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            _error!,
            style: TextStyle(color: theme.colorScheme.error, fontSize: 13),
          ),
        ),
      );

    return _SurfaceCard(
      theme: theme,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: _WindowTabs(
              current: _window,
              onChanged: (v) {
                setState(() => _window = v);
                _load();
              },
            ),
          ),
          LayoutBuilder(
            builder: (context, constraints) {
              final hScroll = ScrollController();
              final vScroll = ScrollController();
              return ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 380),
                child: Scrollbar(
                  controller: vScroll,
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    controller: vScroll,
                    child: Scrollbar(
                      controller: hScroll,
                      notificationPredicate: (n) => n.depth == 1,
                      thumbVisibility: true,
                      child: SingleChildScrollView(
                        controller: hScroll,
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          sortColumnIndex: _sortIndex,
                          sortAscending: _ascending,
                          headingRowHeight: 38,
                          dataRowMinHeight: 40,
                          dataRowMaxHeight: 48,
                          headingTextStyle: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          dataTextStyle: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurface,
                          ),
                          dividerThickness: 0.5,
                          columns: [
                            const DataColumn(label: Text('#')),
                            DataColumn(
                              label: const Text('TITLE'),
                              onSort: (_, __) => _sort(1, (r) => r.title),
                            ),
                            DataColumn(
                              label: const Text('VIEWS'),
                              numeric: true,
                              onSort: (_, __) => _sort(2, (r) => r.viewsCount),
                            ),
                            DataColumn(
                              label: const Text('AVG RATING'),
                              numeric: true,
                              onSort: (_, __) =>
                                  _sort(3, (r) => r.averageRating),
                            ),
                            DataColumn(
                              label: const Text('RATINGS'),
                              numeric: true,
                              onSort: (_, __) =>
                                  _sort(4, (r) => r.ratingsCount),
                            ),
                            DataColumn(
                              label: const Text('SCORE'),
                              numeric: true,
                              onSort: (_, __) => _sort(5, (r) => r.score),
                            ),
                          ],
                          rows: List.generate(_rows.length, (i) {
                            final r = _rows[i];
                            return DataRow(
                              cells: [
                                DataCell(
                                  Text(
                                    '${i + 1}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    r.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                DataCell(Text('${r.viewsCount}')),
                                DataCell(
                                  Text(r.averageRating.toStringAsFixed(2)),
                                ),
                                DataCell(Text('${r.ratingsCount}')),
                                DataCell(
                                  Text(
                                    r.score.toStringAsFixed(3),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: kPrimaryGreen,
                                    ),
                                  ),
                                ),
                              ],
                            );
                          }),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
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
    final items = [
      ('7d', 'Last 7 days'),
      ('30d', 'Last 30 days'),
      ('all', 'All time'),
    ];
    return Container(
      height: 32,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.black.withValues(alpha: 0.05),
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
                color: isSelected
                    ? (isDark ? const Color(0xFF2A2A2A) : Colors.white)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
              ),
              alignment: Alignment.center,
              child: Text(
                item.$2,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: isSelected
                      ? (isDark
                            ? Colors.white
                            : Theme.of(context).colorScheme.onSurface)
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 11,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: kPrimaryGreen.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.history_rounded,
                        size: 15,
                        color: kPrimaryGreen,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            log.description,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: theme.colorScheme.onSurface,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${log.actorName ?? 'System'} · ${log.category}',
                            style: TextStyle(
                              fontSize: 11,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _formatHumanDate(log.createdAt),
                      style: TextStyle(
                        fontSize: 10,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (!isLast)
                Divider(
                  height: 0.5,
                  indent: 16,
                  endIndent: 16,
                  color: theme.colorScheme.outline.withValues(alpha: 0.08),
                ),
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
  final void Function(AdminUser) onViewPosts;
  final void Function(AdminUser) onViewComments;
  final void Function(AdminUser) onViewRecipes; // ← NEW
  final bool hasMore;
  final bool isLoadingMore;
  final VoidCallback onLoadMore;

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
    required this.hasMore,
    required this.isLoadingMore,
    required this.onLoadMore,
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
          const SizedBox(height: 12),
          if (hasMore)
            Align(
              alignment: Alignment.centerLeft,
              child: _GreenButton(
                label: isLoadingMore ? 'Loading…' : 'Load more users',
                icon: Icons.expand_more_rounded,
                loading: isLoadingMore,
                onPressed: isLoadingMore ? null : onLoadMore,
              ),
            ),
        ],
        const SizedBox(height: 32),
      ],
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
        Row(
          children: [
            Expanded(
              child: _MinimalSectionLabel(
                theme: theme,
                label: 'Content Reports',
                subtitle: loading ? 'Loading…' : '${reports.length} pending',
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
              if (reports.isNotEmpty) ...[
                const SizedBox(width: 4),
                IconButton(
                  onPressed: onDeleteAll,
                  icon: const Icon(
                    Icons.delete_sweep_rounded,
                    size: 18,
                    color: kAccentOrange,
                  ),
                  tooltip: 'Delete all reports',
                  style: IconButton.styleFrom(
                    minimumSize: const Size(34, 34),
                    padding: EdgeInsets.zero,
                  ),
                ),
              ],
            ],
          ],
        ),
        const SizedBox(height: 14),
        if (loading && reports.isEmpty)
          const _LoadingState()
        else if (error != null)
          _ErrorState(theme: theme, message: error!, onRetry: onRefresh)
        else if (reports.isEmpty)
          _EmptyState(theme: theme, message: 'No pending reports — all clear ✓')
        else
          _ReportsTable(
            theme: theme,
            reports: reports,
            onAction: onReportAction,
          ),
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
        Row(
          children: [
            Expanded(
              child: _MinimalSectionLabel(
                theme: theme,
                label: 'Audit Logs',
                subtitle: 'System & moderation events',
              ),
            ),
            _DateRangeDropdown(value: selectedRange, onChanged: onRangeChanged),
            const SizedBox(width: 6),
            OutlinedButton.icon(
              onPressed: exporting ? null : onExport,
              style: OutlinedButton.styleFrom(
                foregroundColor: kPrimaryGreen,
                side: BorderSide(
                  color: kPrimaryGreen.withValues(alpha: 0.4),
                  width: 0.5,
                ),
                minimumSize: const Size(0, 34),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                textStyle: const TextStyle(fontSize: 12),
              ),
              icon: exporting
                  ? const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        color: kPrimaryGreen,
                      ),
                    )
                  : const Icon(Icons.download_rounded, size: 14),
              label: Text(exporting ? 'Exporting…' : 'Export CSV'),
            ),
            const SizedBox(width: 6),
            if (!loading)
              _TopBarIconBtn(
                icon: Icons.refresh_rounded,
                onPressed: onRefresh,
                tooltip: 'Refresh',
                color: kPrimaryGreen,
              ),
          ],
        ),
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
      border: Border.all(
        color: isDark
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.black.withValues(alpha: 0.06),
        width: 0.5,
      ),
    ),
    child: LayoutBuilder(
      builder: (ctx, constraints) {
        final horizontalController = ScrollController();
        final verticalController = ScrollController();
        return SizedBox(
          height: height,
          child: Scrollbar(
            controller: verticalController,
            thumbVisibility: true,
            child: SingleChildScrollView(
              controller: verticalController,
              child: Scrollbar(
                controller: horizontalController,
                notificationPredicate: (notif) => notif.depth == 1,
                thumbVisibility: true,
                child: SingleChildScrollView(
                  controller: horizontalController,
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minWidth: constraints.maxWidth),
                    child: child,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    ),
  );
}

Widget _flexTable({
  required ThemeData theme,
  required Map<int, TableColumnWidth> columnWidths,
  required List<String> headers,
  required List<TableRow> rows,
}) {
  final isDark = theme.brightness == Brightness.dark;
  return Table(
    columnWidths: columnWidths,
    defaultVerticalAlignment: TableCellVerticalAlignment.middle,
    border: TableBorder(
      horizontalInside: BorderSide(
        color: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.black.withValues(alpha: 0.04),
        width: 0.5,
      ),
    ),
    children: [
      TableRow(
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.03)
              : Colors.black.withValues(alpha: 0.02),
        ),
        children: headers
            .map(
              (h) => Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Text(
                  h,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 9,
                    color: theme.colorScheme.onSurfaceVariant,
                    letterSpacing: 0.7,
                  ),
                ),
              ),
            )
            .toList(),
      ),
      ...rows,
    ],
  );
}

TableRow _tableRow(ThemeData theme, List<Widget> cells, Color? bg) {
  return TableRow(
    decoration: BoxDecoration(color: bg),
    children: cells
        .map(
          (c) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Align(alignment: Alignment.centerLeft, child: c),
          ),
        )
        .toList(),
  );
}

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

class _ReportsTable extends StatelessWidget {
  final ThemeData theme;
  final List<Report> reports;
  final Future<void> Function(int, String) onAction;
  const _ReportsTable({
    required this.theme,
    required this.reports,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return _wrapTable(
      theme,
      reports.length,
      _flexTable(
        theme: theme,
        columnWidths: const {
          0: FlexColumnWidth(0.35),
          1: FlexColumnWidth(0.7),
          2: FlexColumnWidth(1.4),
          3: FlexColumnWidth(1.1),
          4: FlexColumnWidth(0.9),
          5: FlexColumnWidth(0.85),
          6: FlexColumnWidth(1.1),
        },
        headers: [
          'ID',
          'TYPE',
          'CONTENT',
          'REPORTER',
          'REASON',
          'DATE',
          'ACTIONS',
        ],
        rows: reports.asMap().entries.map((e) {
          final r = e.value;
          return _tableRow(theme, [
            Text(
              '${r.id}',
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            _TypePill(type: r.reportable?.type ?? 'unknown'),
            Text(
              r.reportableLabel,
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurface,
              ),
            ),
            Text(
              r.reporter ?? '—',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurface,
              ),
            ),
            Text(
              r.reason ?? '—',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurface,
              ),
            ),
            Text(
              _formatHumanDate(r.createdAt),
              style: TextStyle(
                fontSize: 11,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _ActionIconBtn(
                  icon: Icons.close_rounded,
                  color: theme.colorScheme.onSurfaceVariant,
                  tooltip: 'Dismiss',
                  onPressed: () => onAction(r.id, 'dismiss'),
                  size: 14,
                ),
                _ActionIconBtn(
                  icon: Icons.check_rounded,
                  color: kPrimaryGreen,
                  tooltip: 'Approve',
                  onPressed: () => onAction(r.id, 'approve'),
                  size: 14,
                ),
                if (r.isRecipeReport || r.isPostReport)
                  _ActionIconBtn(
                    icon: Icons.delete_outline_rounded,
                    color: kAccentOrange,
                    tooltip: 'Remove content',
                    onPressed: () => onAction(r.id, 'remove-content'),
                    size: 14,
                  ),
                if (r.isUserReport)
                  _ActionIconBtn(
                    icon: Icons.block_rounded,
                    color: Colors.red,
                    tooltip: 'Suspend user',
                    onPressed: () => onAction(r.id, 'suspend-user'),
                    size: 14,
                  ),
              ],
            ),
          ], null);
        }).toList(),
      ),
    );
  }
}

class _AuditLogsTable extends StatelessWidget {
  final ThemeData theme;
  final List<ActivityLog> logs;
  const _AuditLogsTable({required this.theme, required this.logs});

  @override
  Widget build(BuildContext context) {
    return _wrapTable(
      theme,
      logs.length,
      _flexTable(
        theme: theme,
        columnWidths: const {
          0: FlexColumnWidth(0.35),
          1: FlexColumnWidth(1),
          2: FlexColumnWidth(0.9),
          3: FlexColumnWidth(0.9),
          4: FlexColumnWidth(2),
          5: FlexColumnWidth(1),
        },
        headers: ['ID', 'DATE', 'CATEGORY', 'ACTION', 'DESCRIPTION', 'ACTOR'],
        rows: logs.asMap().entries.map((e) {
          final log = e.value;
          return _tableRow(theme, [
            Text(
              '${log.id}',
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            Text(
              _formatHumanDate(log.createdAt),
              style: TextStyle(
                fontSize: 11,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            _CategoryPill(theme: theme, label: log.category),
            Text(
              log.action,
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurface,
              ),
            ),
            Text(
              log.description,
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurface,
              ),
            ),
            Text(
              log.actorName ?? '—',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ], null);
        }).toList(),
      ),
    );
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

  const _StatCard({
    required this.theme,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.trend,
    required this.trendUp,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1C) : Colors.white,
        borderRadius: BorderRadius.circular(_kStatCardRadius),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.black.withValues(alpha: 0.06),
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, color: color, size: 16),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: trendUp
                      ? kPrimaryGreen.withValues(alpha: 0.08)
                      : kAccentOrange.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      trendUp
                          ? Icons.trending_up_rounded
                          : Icons.info_outline_rounded,
                      size: 11,
                      color: trendUp ? kPrimaryGreen : kAccentOrange,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      trend,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: trendUp ? kPrimaryGreen : kAccentOrange,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            value,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurface,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
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
      padding:
          padding ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1C) : Colors.white,
        borderRadius: BorderRadius.circular(_kCardRadius),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.black.withValues(alpha: 0.06),
          width: 0.5,
        ),
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
  const _MinimalSectionLabel({
    required this.theme,
    required this.label,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface,
            letterSpacing: -0.2,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(
            subtitle!,
            style: TextStyle(
              fontSize: 12,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
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
  const _SearchBar({
    required this.theme,
    required this.onChanged,
    required this.hintText,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = theme.brightness == Brightness.dark;
    return TextField(
      onChanged: onChanged,
      style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurface),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(
          fontSize: 13,
          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
        ),
        prefixIcon: Icon(
          Icons.search_rounded,
          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
          size: 17,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.08),
            width: 0.5,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.08),
            width: 0.5,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: kPrimaryGreen, width: 1),
        ),
        filled: true,
        fillColor: isDark ? const Color(0xFF1C1C1C) : Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          vertical: 11,
          horizontal: 12,
        ),
        isDense: true,
      ),
    );
  }
}

// ─── Empty / Error / Loading states ──────────────────────────────────────────
class _LoadingState extends StatelessWidget {
  const _LoadingState();
  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.all(40),
    child: Center(
      child: CircularProgressIndicator(color: kPrimaryGreen, strokeWidth: 2),
    ),
  );
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
        child: Column(
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 32,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 10),
            Text(
              message,
              style: TextStyle(
                fontSize: 13,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final ThemeData theme;
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({
    required this.theme,
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      theme: theme,
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Column(
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 28,
              color: kAccentOrange,
            ),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: kAccentOrange, fontSize: 13),
            ),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: onRetry,
              style: FilledButton.styleFrom(
                backgroundColor: kPrimaryGreen,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                minimumSize: const Size(80, 34),
                textStyle: const TextStyle(fontSize: 12),
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
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
          child: Row(
            children: [
              SizedBox(
                width: 14,
                child: isSelected
                    ? const Icon(
                        Icons.check_rounded,
                        size: 12,
                        color: kPrimaryGreen,
                      )
                    : null,
              ),
              const SizedBox(width: 6),
              Text(
                range.label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
        );
      }).toList(),
      child: Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          border: Border.all(
            color: kPrimaryGreen.withValues(alpha: 0.4),
            width: 0.5,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.calendar_today_outlined,
              size: 12,
              color: kPrimaryGreen,
            ),
            const SizedBox(width: 6),
            Text(
              value.label,
              style: const TextStyle(
                color: kPrimaryGreen,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 14,
              color: kPrimaryGreen,
            ),
          ],
        ),
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
  const _GreenButton({
    required this.label,
    required this.icon,
    required this.loading,
    required this.onPressed,
    this.compact = false,
  });

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
          ? const SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 1.5,
              ),
            )
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
  const _ActionIconBtn({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onPressed,
    this.size = 15,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(6),
          ),
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
    final colors = [
      const Color(0xFF3C6DF0),
      kPrimaryGreen,
      const Color(0xFFE6930A),
      const Color(0xFF9B59B6),
      const Color(0xFFE74C3C),
    ];
    return colors[name.length % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          _initials,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w600,
            color: _color,
          ),
        ),
      ),
    );
  }
}

// ─── Pills ────────────────────────────────────────────────────────────────────
class _StatusPill extends StatelessWidget {
  final bool isActive;
  const _StatusPill({required this.isActive});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isActive
            ? kPrimaryGreen.withValues(alpha: 0.08)
            : kAccentOrange.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              color: isActive ? kPrimaryGreen : kAccentOrange,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            isActive ? 'Active' : 'Inactive',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: isActive ? kPrimaryGreen : kAccentOrange,
            ),
          ),
        ],
      ),
    );
  }
}

class _TypePill extends StatelessWidget {
  final String type;
  const _TypePill({required this.type});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: kPrimaryGreen.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: kPrimaryGreen.withValues(alpha: 0.15),
          width: 0.5,
        ),
      ),
      child: Text(
        type,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: kPrimaryGreen,
        ),
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
