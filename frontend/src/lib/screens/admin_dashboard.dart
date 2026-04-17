import 'package:flutter/material.dart';
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
import 'package:my_app/services/recipe_service.dart';
import 'package:my_app/theme/app_theme.dart';
import 'package:my_app/theme/app_spacing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:provider/provider.dart';
import 'package:my_app/providers/theme_provider.dart';

// ─── Nav sections ─────────────────────────────────────────────────────────────
enum _Section { overview, users, moderation, auditLogs }

enum _DateRangeFilter {
  weekly('weekly', 'Weekly'),
  monthly('monthly', 'Monthly'),
  yearly('yearly', 'Yearly');

  const _DateRangeFilter(this.apiValue, this.label);
  final String apiValue;
  final String label;
}

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
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: actionColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
            child: Text(actionLabel),
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
        content: Text(message),
        backgroundColor: isError ? kAccentOrange : kPrimaryGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(AppSpacing.md),
      ),
    );
  }

  // ── build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isWide = MediaQuery.sizeOf(context).width >= 800;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: isWide ? _buildWideLayout(theme) : _buildNarrowLayout(theme),
      ),
    );
  }

  // ── wide layout (sidebar + content) ───────────────────────────────────────
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
                    padding: const EdgeInsets.all(AppSpacing.lg),
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

  // ── narrow layout (bottom nav or drawer) ──────────────────────────────────
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
              padding: const EdgeInsets.all(AppSpacing.md),
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
          exportingInsightsCsv: _exportingInsightsCsv,
          selectedInsightsRange: _insightsRange,
          onInsightsRangeChanged: (range) =>
              setState(() => _insightsRange = range),
          onExportInsights: _exportInsightsCsv,
          rankingsRefreshNonce: _rankingsRefreshNonce,
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
    final bg = isDark ? const Color(0xFF1A1A1A) : Colors.white;
    final width = collapsed ? 72.0 : 220.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      width: width,
      decoration: BoxDecoration(
        color: bg,
        border: Border(
          right: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.06),
          ),
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: AppSpacing.lg),
          // Logo / collapse toggle
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: collapsed ? 12 : AppSpacing.md,
            ),
            child: Row(
              mainAxisAlignment: collapsed
                  ? MainAxisAlignment.center
                  : MainAxisAlignment.spaceBetween,
              children: [
                if (!collapsed)
                  Image.asset('lib/assets/images/logo1.png', height: 36),
                InkWell(
                  onTap: onToggleCollapsed,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Icon(
                      collapsed
                          ? Icons.chevron_right_rounded
                          : Icons.chevron_left_rounded,
                      color: theme.colorScheme.onSurfaceVariant,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          // Nav items
          _NavItem(
            section: _Section.overview,
            currentSection: currentSection,
            icon: Icons.dashboard_rounded,
            label: 'Overview',
            collapsed: collapsed,
            onTap: onSectionChanged,
            theme: theme,
          ),
          _NavItem(
            section: _Section.users,
            currentSection: currentSection,
            icon: Icons.people_alt_rounded,
            label: 'Users',
            collapsed: collapsed,
            onTap: onSectionChanged,
            theme: theme,
          ),
          _NavItem(
            section: _Section.moderation,
            currentSection: currentSection,
            icon: Icons.shield_rounded,
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
          // Logout
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: collapsed ? 12 : AppSpacing.md,
              vertical: AppSpacing.lg,
            ),
            child: InkWell(
              onTap: onLogout,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: collapsed ? 0 : AppSpacing.md,
                  vertical: 12,
                ),
                child: Row(
                  mainAxisAlignment: collapsed
                      ? MainAxisAlignment.center
                      : MainAxisAlignment.start,
                  children: [
                    Icon(Icons.logout_rounded, color: kAccentOrange, size: 20),
                    if (!collapsed) ...[
                      AppSpacing.gapH8,
                      Text(
                        'Logout',
                        style: TextStyle(
                          color: kAccentOrange,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ],
                ),
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

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: collapsed ? 8 : 12,
        vertical: 3,
      ),
      child: Tooltip(
        message: collapsed ? label : '',
        preferBelow: false,
        child: InkWell(
          onTap: () => onTap(section),
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: EdgeInsets.symmetric(
              horizontal: collapsed ? 0 : 14,
              vertical: 12,
            ),
            decoration: BoxDecoration(
              color: isActive
                  ? kPrimaryGreen.withValues(alpha: isDark ? 0.25 : 0.1)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
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
                      ? kPrimaryGreen
                      : theme.colorScheme.onSurfaceVariant,
                ),
                if (!collapsed) ...[
                  AppSpacing.gapH8,
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
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
      ),
    );
  }
}

// ─── Bottom nav (narrow screens) ──────────────────────────────────────────────
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
        color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.06),
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _BottomNavItem(
            icon: Icons.dashboard_rounded,
            label: 'Overview',
            section: _Section.overview,
            currentSection: currentSection,
            onTap: onSectionChanged,
          ),
          _BottomNavItem(
            icon: Icons.people_alt_rounded,
            label: 'Users',
            section: _Section.users,
            currentSection: currentSection,
            onTap: onSectionChanged,
          ),
          _BottomNavItem(
            icon: Icons.shield_rounded,
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
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 22, color: isActive ? kPrimaryGreen : Colors.grey),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
                color: isActive ? kPrimaryGreen : Colors.grey,
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
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.06),
          ),
        ),
      ),
      child: Row(
        children: [
          if (showMenuButton)
            IconButton(
              onPressed: onMenuPressed,
              icon: const Icon(Icons.logout_rounded),
              color: kAccentOrange,
            ),
          if (!showMenuButton)
            Image.asset('lib/assets/images/logo1.png', height: 32),
          AppSpacing.gapH16,
          Text(
            _title,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              fontSize: 18,
            ),
          ),
          const Spacer(),
          IconButton(
            onPressed: onRefresh,
            icon: Icon(Icons.refresh_rounded, color: kPrimaryGreen, size: 20),
            tooltip: 'Refresh',
          ),
          IconButton(
            onPressed: onToggleTheme,
            icon: Icon(
              isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              color: kPrimaryGreen,
              size: 20,
            ),
            tooltip: isDark ? 'Switch to light mode' : 'Switch to dark mode',
          ),
          NotificationsDropdown(
            iconColor: kAccentOrange,
            child: Icon(
              Icons.notifications_outlined,
              color: kAccentOrange,
              size: 22,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Recipe rankings (overview) ─────────────────────────────────────────────
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
    if (oldWidget.refreshNonce != widget.refreshNonce) {
      _load();
    }
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
        final av = key(a);
        final bv = key(b);
        final cmp = Comparable.compare(av as Comparable, bv as Comparable);
        return _ascending ? cmp : -cmp;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    if (_loading) {
      return _Card(
        theme: theme,
        child: const Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator(color: kPrimaryGreen)),
        ),
      );
    }
    if (_error != null) {
      return _Card(
        theme: theme,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            _error!,
            style: TextStyle(color: theme.colorScheme.error),
          ),
        ),
      );
    }

    return _Card(
      theme: theme,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: DropdownButtonFormField<String>(
              value: _window,
              decoration: const InputDecoration(
                labelText: 'Time window',
                border: OutlineInputBorder(),
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
              items: const [
                DropdownMenuItem(value: '7d', child: Text('Last 7 days')),
                DropdownMenuItem(value: '30d', child: Text('Last 30 days')),
                DropdownMenuItem(value: 'all', child: Text('All time')),
              ],
              onChanged: (v) {
                if (v == null) return;
                setState(() => _window = v);
                _load();
              },
            ),
          ),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, constraints) {
              return ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 400),
                child: Scrollbar(
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SingleChildScrollView(
                      child: DataTable(
                        sortColumnIndex: _sortIndex,
                        sortAscending: _ascending,
                        headingRowHeight: 40,
                        dataRowMinHeight: 36,
                        dataRowMaxHeight: 48,
                        columns: [
                          const DataColumn(label: Text('Rank')),
                          DataColumn(
                            label: const Text('Title'),
                            onSort: (_, __) => _sort(1, (r) => r.title),
                          ),
                          DataColumn(
                            label: const Text('Views'),
                            numeric: true,
                            onSort: (_, __) => _sort(2, (r) => r.viewsCount),
                          ),
                          DataColumn(
                            label: const Text('Avg Rating'),
                            numeric: true,
                            onSort: (_, __) => _sort(3, (r) => r.averageRating),
                          ),
                          DataColumn(
                            label: const Text('Ratings'),
                            numeric: true,
                            onSort: (_, __) => _sort(4, (r) => r.ratingsCount),
                          ),
                          DataColumn(
                            label: const Text('Score'),
                            numeric: true,
                            onSort: (_, __) => _sort(5, (r) => r.score),
                          ),
                        ],
                        rows: List.generate(_rows.length, (i) {
                          final r = _rows[i];
                          return DataRow(
                            cells: [
                              DataCell(Text('${i + 1}')),
                              DataCell(
                                Text(
                                  r.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              DataCell(Text('${r.viewsCount}')),
                              DataCell(
                                Text(r.averageRating.toStringAsFixed(2)),
                              ),
                              DataCell(Text('${r.ratingsCount}')),
                              DataCell(Text(r.score.toStringAsFixed(3))),
                            ],
                          );
                        }),
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
    required this.exportingInsightsCsv,
    required this.selectedInsightsRange,
    required this.onInsightsRangeChanged,
    required this.onExportInsights,
    required this.rankingsRefreshNonce,
  });

  @override
  Widget build(BuildContext context) {
    final activeUsers = users.where((u) => u.isActive).length;
    final mealPlannerLogs = auditLogs
        .where((l) => l.category.toLowerCase() == 'meal_planner')
        .toList();
    final mealPlannerActions = mealPlannerLogs.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Welcome
        Text(
          'Good day, Admin',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
        AppSpacing.gapV4,
        Text(
          'Here\'s a snapshot of your WellNest community.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        AppSpacing.gapV24,
        isWide
            ? Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      theme: theme,
                      title: 'Total Users',
                      value: loading ? '…' : '${users.length}',
                      icon: Icons.people_alt_rounded,
                      color: const Color(0xFF3C6DF0),
                    ),
                  ),
                  AppSpacing.gapH16,
                  Expanded(
                    child: _StatCard(
                      theme: theme,
                      title: 'Active Users',
                      value: loading ? '…' : '$activeUsers',
                      icon: Icons.person_rounded,
                      color: kPrimaryGreen,
                    ),
                  ),
                  AppSpacing.gapH16,
                  Expanded(
                    child: _StatCard(
                      theme: theme,
                      title: 'Total Recipes',
                      value: recipeTotalLoading ? '…' : '$recipeTotal',
                      icon: Icons.restaurant_menu_rounded,
                      color: const Color(0xFFFFC700),
                    ),
                  ),
                  AppSpacing.gapH16,
                  Expanded(
                    child: _StatCard(
                      theme: theme,
                      title: 'Open Reports',
                      value: reportsLoading ? '…' : '${reports.length}',
                      icon: Icons.flag_rounded,
                      color: const Color(0xFFEA4C89),
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
                          value: loading ? '…' : '${users.length}',
                          icon: Icons.people_alt_rounded,
                          color: const Color(0xFF3C6DF0),
                        ),
                      ),
                      AppSpacing.gapH12,
                      Expanded(
                        child: _StatCard(
                          theme: theme,
                          title: 'Active Users',
                          value: loading ? '…' : '$activeUsers',
                          icon: Icons.person_rounded,
                          color: kPrimaryGreen,
                        ),
                      ),
                    ],
                  ),
                  AppSpacing.gapV12,
                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          theme: theme,
                          title: 'Total Recipes',
                          value: recipeTotalLoading ? '…' : '$recipeTotal',
                          icon: Icons.restaurant_menu_rounded,
                          color: const Color(0xFFFFC700),
                        ),
                      ),
                      AppSpacing.gapH12,
                      Expanded(
                        child: _StatCard(
                          theme: theme,
                          title: 'Open Reports',
                          value: reportsLoading ? '…' : '${reports.length}',
                          icon: Icons.flag_rounded,
                          color: const Color(0xFFEA4C89),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
        AppSpacing.gapV24,
        _SectionHeader(
          theme: theme,
          title: 'Meal Planner Overview',
          subtitle: 'Recent user planning activity',
        ),
        AppSpacing.gapV12,
        _Card(
          theme: theme,
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: kPrimaryGreen.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.calendar_month_rounded,
                  color: kPrimaryGreen,
                ),
              ),
              AppSpacing.gapH12,
              Expanded(
                child: Text(
                  'Meal planner actions logged: $mealPlannerActions',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
        AppSpacing.gapV12,
        if (mealPlannerLogs.isEmpty)
          _EmptyState(
            theme: theme,
            message:
                'No meal planner activity yet. Plan meals on user dashboard to populate this section.',
          )
        else
          _RecentLogsList(theme: theme, logs: mealPlannerLogs.take(5).toList()),
        AppSpacing.gapV24,
        // Export insights button
        Row(
          children: [
            _DateRangeDropdown(
              value: selectedInsightsRange,
              onChanged: onInsightsRangeChanged,
            ),
            AppSpacing.gapH8,
            FilledButton.icon(
              onPressed: exportingInsightsCsv ? null : onExportInsights,
              style: FilledButton.styleFrom(
                backgroundColor: kPrimaryGreen,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
              ),
              icon: exportingInsightsCsv
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.download_rounded, size: 20),
              label: Text(
                exportingInsightsCsv ? 'Exporting…' : 'Export Insights Report',
              ),
            ),
          ],
        ),
        AppSpacing.gapV24,
        _SectionHeader(
          theme: theme,
          title: 'Recipe rankings',
          subtitle: 'Views, ratings, and combined score',
        ),
        AppSpacing.gapV12,
        _OverviewRecipeRankingsCard(
          theme: theme,
          refreshNonce: rankingsRefreshNonce,
        ),
        AppSpacing.gapV24,
        // Recent activity summary
        _SectionHeader(
          theme: theme,
          title: 'Recent Activity',
          subtitle: 'Last 5 activity logs',
        ),
        AppSpacing.gapV12,
        if (auditLogs.isEmpty)
          _EmptyState(theme: theme, message: 'No audit logs yet')
        else
          _RecentLogsList(theme: theme, logs: auditLogs.take(5).toList()),
        AppSpacing.gapV32,
      ],
    );
  }
}

class _RecentLogsList extends StatelessWidget {
  final ThemeData theme;
  final List<ActivityLog> logs;

  const _RecentLogsList({required this.theme, required this.logs});

  @override
  Widget build(BuildContext context) {
    return _Card(
      theme: theme,
      child: Column(
        children: logs.asMap().entries.map((e) {
          final log = e.value;
          final isLast = e.key == logs.length - 1;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: kPrimaryGreen.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.history_rounded,
                        size: 18,
                        color: kPrimaryGreen,
                      ),
                    ),
                    AppSpacing.gapH12,
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            log.description,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: theme.colorScheme.onSurface,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          AppSpacing.gapV4,
                          Text(
                            '${log.actorName ?? 'System'} • ${log.category}',
                            style: TextStyle(
                              fontSize: 11,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    AppSpacing.gapH8,
                    Text(
                      log.createdAt ?? '',
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (!isLast)
                Divider(
                  height: 1,
                  color: theme.colorScheme.outline.withValues(alpha: 0.1),
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
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _SectionHeader(
                theme: theme,
                title: 'Registered Users',
                subtitle: loading ? 'Loading…' : '${users.length} users total',
              ),
            ),
            _DateRangeDropdown(value: selectedRange, onChanged: onRangeChanged),
            AppSpacing.gapH8,
            if (!loading) ...[
              IconButton(
                onPressed: onRefresh,
                icon: Icon(
                  Icons.refresh_rounded,
                  color: kPrimaryGreen,
                  size: 20,
                ),
              ),
              FilledButton.icon(
                onPressed: exporting ? null : onExport,
                style: FilledButton.styleFrom(
                  backgroundColor: kPrimaryGreen,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                icon: exporting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.download_rounded, size: 18),
                label: Text(exporting ? 'Exporting…' : 'Export'),
              ),
            ],
          ],
        ),
        AppSpacing.gapV16,
        // Search bar
        TextField(
          onChanged: onSearchChanged,
          decoration: InputDecoration(
            hintText: 'Search by name or email…',
            prefixIcon: Icon(
              Icons.search_rounded,
              color: theme.colorScheme.onSurfaceVariant,
              size: 20,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            filled: true,
            fillColor: theme.brightness == Brightness.dark
                ? const Color(0xFF2A2A2A)
                : Colors.white,
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
        AppSpacing.gapV16,
        if (loading && users.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(40),
              child: CircularProgressIndicator(
                color: kPrimaryGreen,
                strokeWidth: 2,
              ),
            ),
          )
        else if (error != null)
          _ErrorState(theme: theme, message: error!, onRetry: onRefresh)
        else if (users.isEmpty)
          _EmptyState(
            theme: theme,
            message: searchQuery.isEmpty
                ? 'No users yet'
                : 'No users match your search',
          )
        else
          _UsersTable(
            theme: theme,
            users: users,
            onDeactivate: onDeactivate,
            onActivate: onActivate,
            onDelete: onDelete,
          ),
        AppSpacing.gapV32,
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
              child: _SectionHeader(
                theme: theme,
                title: 'Content Reports',
                subtitle: loading
                    ? 'Loading…'
                    : '${reports.length} pending reports',
              ),
            ),
            _DateRangeDropdown(value: selectedRange, onChanged: onRangeChanged),
            AppSpacing.gapH8,
            if (!loading) ...[
              IconButton(
                onPressed: onRefresh,
                icon: Icon(
                  Icons.refresh_rounded,
                  color: kPrimaryGreen,
                  size: 20,
                ),
              ),
              FilledButton.icon(
                onPressed: exporting ? null : onExport,
                style: FilledButton.styleFrom(
                  backgroundColor: kPrimaryGreen,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                icon: exporting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.download_rounded, size: 18),
                label: Text(exporting ? 'Exporting…' : 'Export'),
              ),
              if (reports.isNotEmpty) ...[
                AppSpacing.gapH8,
                IconButton(
                  onPressed: onDeleteAll,
                  icon: Icon(
                    Icons.delete_sweep_rounded,
                    color: kAccentOrange,
                    size: 20,
                  ),
                  tooltip: 'Delete all reports',
                ),
              ],
            ],
          ],
        ),
        AppSpacing.gapV16,
        if (loading && reports.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(40),
              child: CircularProgressIndicator(
                color: kPrimaryGreen,
                strokeWidth: 2,
              ),
            ),
          )
        else if (error != null)
          _ErrorState(theme: theme, message: error!, onRetry: onRefresh)
        else if (reports.isEmpty)
          _EmptyState(
            theme: theme,
            message: 'No pending reports — all clear! ✓',
          )
        else
          _ReportsTable(
            theme: theme,
            reports: reports,
            onAction: onReportAction,
          ),
        AppSpacing.gapV32,
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
              child: _SectionHeader(
                theme: theme,
                title: 'Audit Logs',
                subtitle: 'Recent system and moderation events',
              ),
            ),
            _DateRangeDropdown(value: selectedRange, onChanged: onRangeChanged),
            AppSpacing.gapH8,
            OutlinedButton.icon(
              onPressed: exporting ? null : onExport,
              style: OutlinedButton.styleFrom(
                foregroundColor: kPrimaryGreen,
                side: BorderSide(color: kPrimaryGreen.withValues(alpha: 0.35)),
                minimumSize: const Size(0, 38),
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              icon: exporting
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.download_rounded, size: 18),
              label: Text(exporting ? 'Exporting…' : 'Export CSV'),
            ),
            AppSpacing.gapH8,
            if (!loading)
              IconButton(
                onPressed: onRefresh,
                icon: Icon(
                  Icons.refresh_rounded,
                  color: kPrimaryGreen,
                  size: 20,
                ),
              ),
          ],
        ),
        AppSpacing.gapV16,
        if (loading && logs.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(40),
              child: CircularProgressIndicator(
                color: kPrimaryGreen,
                strokeWidth: 2,
              ),
            ),
          )
        else if (error != null)
          _ErrorState(theme: theme, message: error!, onRetry: onRefresh)
        else if (logs.isEmpty)
          _EmptyState(theme: theme, message: 'No audit logs yet')
        else
          _AuditLogsTable(theme: theme, logs: logs.take(20).toList()),
        AppSpacing.gapV32,
      ],
    );
  }
}

// ─── Shared table components ──────────────────────────────────────────────────
const _rowH = 52.0;
const _minH = 250.0;
const _maxH = 520.0;

Widget _wrapTable(ThemeData theme, int rowCount, Widget child) {
  final height = (rowCount * _rowH + 52.0).clamp(_minH, _maxH);
  final isDark = theme.brightness == Brightness.dark;
  return Container(
    width: double.infinity,
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      color: isDark ? theme.colorScheme.surface : Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: isDark
          ? null
          : [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
    ),
    child: LayoutBuilder(
      builder: (ctx, constraints) {
        return SizedBox(
          height: height,
          child: Scrollbar(
            thumbVisibility: true,
            child: SingleChildScrollView(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: constraints.maxWidth),
                  child: child,
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
  return Table(
    columnWidths: columnWidths,
    defaultVerticalAlignment: TableCellVerticalAlignment.middle,
    border: TableBorder(
      horizontalInside: BorderSide(
        color: theme.colorScheme.outline.withValues(alpha: 0.07),
      ),
    ),
    children: [
      TableRow(
        decoration: BoxDecoration(
          color: theme.brightness == Brightness.dark
              ? const Color(0xFF252525)
              : const Color(0xFFF9F9F9),
        ),
        children: headers
            .map(
              (h) => Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 13,
                ),
                child: Text(
                  h,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 10,
                    color: theme.colorScheme.onSurfaceVariant,
                    letterSpacing: 0.8,
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
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
            child: Align(alignment: Alignment.centerLeft, child: c),
          ),
        )
        .toList(),
  );
}

// Users table
class _UsersTable extends StatelessWidget {
  final ThemeData theme;
  final List<AdminUser> users;
  final void Function(AdminUser) onDeactivate;
  final void Function(AdminUser) onActivate;
  final void Function(AdminUser) onDelete;

  const _UsersTable({
    required this.theme,
    required this.users,
    required this.onDeactivate,
    required this.onActivate,
    required this.onDelete,
  });

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

// Reports table
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
          final bg = e.key.isEven
              ? null
              : theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.15,
                );
          return _tableRow(theme, [
            Text(
              '${r.id}',
              style: TextStyle(
                fontSize: 13,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            _TypeChip(type: r.reportable?.type ?? 'unknown'),
            Text(
              r.reportableLabel,
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
              style: TextStyle(
                fontSize: 13,
                color: theme.colorScheme.onSurface,
              ),
            ),
            Text(
              r.reporter ?? '—',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                color: theme.colorScheme.onSurface,
              ),
            ),
            Text(
              r.reason ?? '—',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                color: theme.colorScheme.onSurface,
              ),
            ),
            Text(
              r.createdAt,
              style: TextStyle(
                fontSize: 11,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _ActionIconBtn(
                  icon: Icons.close,
                  color: theme.colorScheme.onSurfaceVariant,
                  tooltip: 'Dismiss',
                  onPressed: () => onAction(r.id, 'dismiss'),
                  size: 16,
                ),
                _ActionIconBtn(
                  icon: Icons.check,
                  color: kPrimaryGreen,
                  tooltip: 'Approve',
                  onPressed: () => onAction(r.id, 'approve'),
                  size: 16,
                ),
                if (r.isRecipeReport || r.isPostReport)
                  _ActionIconBtn(
                    icon: Icons.delete_outline,
                    color: kAccentOrange,
                    tooltip: 'Remove content',
                    onPressed: () => onAction(r.id, 'remove-content'),
                    size: 16,
                  ),
                if (r.isUserReport)
                  _ActionIconBtn(
                    icon: Icons.block,
                    color: Colors.red,
                    tooltip: 'Suspend user',
                    onPressed: () => onAction(r.id, 'suspend-user'),
                    size: 16,
                  ),
              ],
            ),
          ], bg);
        }).toList(),
      ),
    );
  }
}

// Audit logs table
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
          final bg = e.key.isEven
              ? null
              : theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.15,
                );
          return _tableRow(theme, [
            Text(
              '${log.id}',
              style: TextStyle(
                fontSize: 13,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            Text(
              log.createdAt ?? '—',
              style: TextStyle(
                fontSize: 11,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            Text(
              log.category,
              style: TextStyle(
                fontSize: 13,
                color: theme.colorScheme.onSurface,
              ),
            ),
            Text(
              log.action,
              style: TextStyle(
                fontSize: 13,
                color: theme.colorScheme.onSurface,
              ),
            ),
            Text(
              log.description,
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
              style: TextStyle(
                fontSize: 13,
                color: theme.colorScheme.onSurface,
              ),
            ),
            Text(
              log.actorName ?? '—',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ], bg);
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

  const _StatCard({
    required this.theme,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: isDark ? theme.cardColor : Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
        border: Border.all(color: color.withValues(alpha: 0.12), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          AppSpacing.gapV12,
          Text(
            value,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: theme.colorScheme.onSurface,
              fontSize: 26,
            ),
          ),
          AppSpacing.gapV4,
          Text(
            title,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Shared small widgets ──────────────────────────────────────────────────────
class _Card extends StatelessWidget {
  final ThemeData theme;
  final Widget child;
  final EdgeInsetsGeometry? padding;

  const _Card({required this.theme, required this.child, this.padding});

  @override
  Widget build(BuildContext context) {
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding:
          padding ??
          const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
      decoration: BoxDecoration(
        color: isDark ? theme.cardColor : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: child,
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final ThemeData theme;
  final String title;
  final String subtitle;

  const _SectionHeader({
    required this.theme,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            fontSize: 17,
          ),
        ),
        AppSpacing.gapV4,
        Text(
          subtitle,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  final ThemeData theme;
  final String message;

  const _EmptyState({required this.theme, required this.message});

  @override
  Widget build(BuildContext context) {
    return _Card(
      theme: theme,
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.inbox_rounded,
              size: 40,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            AppSpacing.gapV12,
            Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
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
    return _Card(
      theme: theme,
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.error_outline_rounded, size: 36, color: kAccentOrange),
            AppSpacing.gapV12,
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: kAccentOrange, fontSize: 13),
            ),
            AppSpacing.gapV16,
            FilledButton(
              onPressed: onRetry,
              style: FilledButton.styleFrom(
                backgroundColor: kPrimaryGreen,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DateRangeDropdown extends StatelessWidget {
  final _DateRangeFilter value;
  final ValueChanged<_DateRangeFilter> onChanged;

  const _DateRangeDropdown({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final menuTextColor = Theme.of(context).colorScheme.onSurface;

    return PopupMenuButton<_DateRangeFilter>(
      tooltip: 'Date range',
      color: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF1F1F1F)
          : Colors.white,
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      onSelected: onChanged,
      itemBuilder: (context) => _DateRangeFilter.values.map((range) {
        final isSelected = range == value;
        return PopupMenuItem<_DateRangeFilter>(
          value: range,
          child: Row(
            children: [
              SizedBox(
                width: 16,
                child: isSelected
                    ? const Icon(
                        Icons.check_rounded,
                        size: 14,
                        color: kPrimaryGreen,
                      )
                    : null,
              ),
              AppSpacing.gapH8,
              Text(
                range.label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: menuTextColor,
                ),
              ),
            ],
          ),
        );
      }).toList(),
      child: Container(
        constraints: const BoxConstraints(minHeight: 40),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: kPrimaryGreen,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.event_rounded, size: 14, color: Colors.white),
            AppSpacing.gapH8,
            Text(
              value.label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                height: 1.1,
              ),
            ),
            const SizedBox(width: 2),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 18,
              color: Colors.white,
            ),
          ],
        ),
      ),
    );
  }
}

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
    this.size = 18,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton.filledTonal(
      onPressed: onPressed,
      icon: Icon(icon, size: size, color: color),
      tooltip: tooltip,
      style: IconButton.styleFrom(
        padding: const EdgeInsets.all(6),
        minimumSize: const Size(30, 30),
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  final String type;
  const _TypeChip({required this.type});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: kPrimaryGreen.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        type,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: kPrimaryGreen,
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final bool isActive;
  const _StatusChip({required this.isActive});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: isActive
            ? kPrimaryGreen.withValues(alpha: 0.1)
            : kAccentOrange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        isActive ? 'Active' : 'Inactive',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: isActive ? kPrimaryGreen : kAccentOrange,
        ),
      ),
    );
  }
}
