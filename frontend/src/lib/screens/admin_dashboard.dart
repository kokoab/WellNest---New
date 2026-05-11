import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:my_app/models/activity_log.dart';
import 'package:my_app/models/admin_user.dart';
import 'package:my_app/models/recipe.dart';
import 'package:my_app/models/recipe_ranking_item.dart';
import 'package:my_app/models/report.dart';
import 'package:my_app/widgets/notifications_bell_button.dart';
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
part 'admin_dashboard/sections/recipes_section_part.dart';
part 'admin_dashboard/sections/moderation_section_part.dart';
part 'admin_dashboard/sections/audit_logs_section_part.dart';
part 'admin_dashboard/widgets/pagination_controls.dart';
part 'admin_dashboard/navigation/navigation_part.dart';
part 'admin_dashboard/modals/modals_part.dart';
part 'admin_dashboard/charts/charts_part.dart';

// ─── Nav sections ─────────────────────────────────────────────────────────────
enum _Section { overview, analytics, users, recipes, moderation, auditLogs }

enum _DateRangeFilter {
  weekly('weekly', 'Weekly'),
  monthly('monthly', 'Monthly'),
  yearly('yearly', 'Yearly'),
  all('all', 'All time');

  const _DateRangeFilter(this.apiValue, this.label);
  final String apiValue;
  final String label;
}

enum _AdminCsvDataset {
  overview,
  analytics,
  users,
  moderation,
  auditLogs,
  recipes,
}

extension _AdminCsvDatasetMeta on _AdminCsvDataset {
  String get label {
    switch (this) {
      case _AdminCsvDataset.overview:
        return 'Overview Summary';
      case _AdminCsvDataset.analytics:
        return 'Analytics Trends';
      case _AdminCsvDataset.users:
        return 'Users';
      case _AdminCsvDataset.moderation:
        return 'Moderation Reports';
      case _AdminCsvDataset.auditLogs:
        return 'Audit Logs';
      case _AdminCsvDataset.recipes:
        return 'Recipes';
    }
  }

  String get fileName {
    switch (this) {
      case _AdminCsvDataset.overview:
        return 'overview_summary.csv';
      case _AdminCsvDataset.analytics:
        return 'analytics_trends.csv';
      case _AdminCsvDataset.users:
        return 'users.csv';
      case _AdminCsvDataset.moderation:
        return 'moderation_reports.csv';
      case _AdminCsvDataset.auditLogs:
        return 'audit_logs.csv';
      case _AdminCsvDataset.recipes:
        return 'recipes.csv';
    }
  }
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
  final _recipesKey = GlobalKey<_RecipesSectionContainerState>();
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
      case _Section.recipes:
        await _recipesKey.currentState?.refresh();
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
    final scaffoldBg = theme.brightness == Brightness.dark
        ? theme.colorScheme.surface
        : Color.lerp(theme.colorScheme.surface, Colors.white, 0.14)!;

    return Theme(
      data: theme.copyWith(textTheme: dashboardTextTheme),
      child: Scaffold(
        backgroundColor: scaffoldBg,
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
        _OverviewSectionContainer(
          key: _overviewKey,
          theme: theme,
          isWide: isWide,
        ),
        _AnalyticsSectionContainer(
          key: _analyticsKey,
          theme: theme,
          isWide: isWide,
        ),
        _UsersSectionContainer(key: _usersKey, theme: theme),
        _RecipesSectionContainer(key: _recipesKey, theme: theme),
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

String _formatCsvDateTime(String? raw) {
  if (raw == null || raw.trim().isEmpty) return '';
  final parsed = DateTime.tryParse(raw);
  if (parsed == null) return raw;
  return _formatCsvDateTimeFromDate(parsed);
}

String _formatCsvDateTimeFromDate(DateTime dateTime) {
  final local = dateTime.toLocal();
  const months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  final month = months[local.month - 1];
  final hour12 = local.hour == 0
      ? 12
      : (local.hour > 12 ? local.hour - 12 : local.hour);
  final minute = local.minute.toString().padLeft(2, '0');
  final meridiem = local.hour >= 12 ? 'PM' : 'AM';
  return '$month ${local.day}, ${local.year}. $hour12:$minute$meridiem';
}

String _adminErrorMessage(Object error) {
  return error.toString().replaceFirst('Exception: ', '');
}

String _toTitleCase(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return '';
  return trimmed[0].toUpperCase() + trimmed.substring(1);
}

void _showAdminErrorSnack(BuildContext context, Object error) {
  _showAdminSnack(context, _adminErrorMessage(error), isError: true);
}

Future<void> _shareCsvBytes({
  required List<int> bytes,
  required String fileName,
  required String subject,
}) async {
  final xfile = XFile.fromData(
    Uint8List.fromList(bytes),
    name: fileName,
    mimeType: 'text/csv',
  );
  await Share.shareXFiles([xfile], subject: subject);
}

class _AdminCsvFile {
  final String name;
  final List<int> bytes;

  const _AdminCsvFile({required this.name, required this.bytes});
}

final Set<_AdminCsvDataset> _allAdminCsvDatasets = Set<_AdminCsvDataset>.from(
  _AdminCsvDataset.values,
);

Future<void> _exportAdminCsvBundle({
  required BuildContext context,
  required _DateRangeFilter range,
  required Set<_AdminCsvDataset> datasets,
}) async {
  if (datasets.isEmpty) {
    _showAdminSnack(context, 'Select at least one CSV file', isError: true);
    return;
  }
  final sorted = datasets.toList()..sort((a, b) => a.index.compareTo(b.index));
  final files = await Future.wait<_AdminCsvFile>(
    sorted.map((dataset) => _buildAdminCsv(dataset: dataset, range: range)),
  );
  final archive = Archive();
  for (final file in files) {
    archive.addFile(ArchiveFile(file.name, file.bytes.length, file.bytes));
  }
  final zipBytes = ZipEncoder().encode(archive);
  final stamp = DateTime.now().toIso8601String().replaceAll(':', '-');
  await _shareCsvBytes(
    bytes: zipBytes,
    fileName: 'wellnest_admin_exports_$stamp.zip',
    subject: 'WellNest Admin CSV Export Bundle',
  );
}

Future<_AdminCsvFile> _buildAdminCsv({
  required _AdminCsvDataset dataset,
  required _DateRangeFilter range,
}) async {
  switch (dataset) {
    case _AdminCsvDataset.overview:
      return _buildOverviewCsv(range);
    case _AdminCsvDataset.analytics:
      return _buildAnalyticsCsv(range);
    case _AdminCsvDataset.users:
      return _buildUsersCsv(range);
    case _AdminCsvDataset.moderation:
      return _buildModerationCsv(range);
    case _AdminCsvDataset.auditLogs:
      return _buildAuditLogsCsv(range);
    case _AdminCsvDataset.recipes:
      return _buildRecipesCsv(range);
  }
}

Future<_AdminCsvFile> _buildOverviewCsv(_DateRangeFilter range) async {
  final usersRes = await AdminUserService.instance.fetchUsers(
    range: range.apiValue,
    page: 1,
    perPage: 1,
  );
  final reportsRes = await AdminModerationService.instance
      .fetchReportsPaginated(range: range.apiValue, page: 1, perPage: 1);
  final recipesRes = await RecipeService.instance.fetchRecipes(
    page: 1,
    range: range.apiValue,
  );
  final rows = <String>[
    'Metric,Value',
    'Date Range,${_escapeCsv(range.label)}',
    'Total Users,${usersRes.total}',
    'Active Users,${usersRes.activeTotal}',
    'Total Recipes,${recipesRes.total}',
    'Open Reports,${reportsRes.total}',
  ];
  return _AdminCsvFile(
    name: _AdminCsvDataset.overview.fileName,
    bytes: utf8.encode(rows.join('\n')),
  );
}

Future<_AdminCsvFile> _buildAnalyticsCsv(_DateRangeFilter range) async {
  final results = await Future.wait<List<AdminStatPoint>>([
    AdminDashboardService.instance.fetchUserGrowth(range: range.apiValue),
    AdminDashboardService.instance.fetchPostFrequency(range: range.apiValue),
    AdminDashboardService.instance.fetchChatbotInteractions(
      range: range.apiValue,
    ),
  ]);
  final rows = <String>['Series,Date and Time,Count'];
  for (final point in results[0]) {
    rows.add(
      'User Growth,${_formatCsvDateTimeFromDate(point.date)},${point.count}',
    );
  }
  for (final point in results[1]) {
    rows.add(
      'Post Frequency,${_formatCsvDateTimeFromDate(point.date)},${point.count}',
    );
  }
  for (final point in results[2]) {
    rows.add(
      'Chatbot Interactions,${_formatCsvDateTimeFromDate(point.date)},${point.count}',
    );
  }
  return _AdminCsvFile(
    name: _AdminCsvDataset.analytics.fileName,
    bytes: utf8.encode(rows.join('\n')),
  );
}

Future<_AdminCsvFile> _buildUsersCsv(_DateRangeFilter range) async {
  final users = <AdminUser>[];
  var page = 1;
  var lastPage = 1;
  do {
    final res = await AdminUserService.instance.fetchUsers(
      range: range.apiValue,
      page: page,
      perPage: 100,
    );
    users.addAll(res.users);
    lastPage = res.lastPage;
    page++;
  } while (page <= lastPage);
  final rows = <String>['User ID,Name,Email Address,Account Status'];
  for (final user in users) {
    rows.add(
      '${user.id},${_escapeCsv(user.name)},${_escapeCsv(user.email)},${_escapeCsv(user.statusLabel)}',
    );
  }
  return _AdminCsvFile(
    name: _AdminCsvDataset.users.fileName,
    bytes: utf8.encode(rows.join('\n')),
  );
}

Future<_AdminCsvFile> _buildModerationCsv(_DateRangeFilter range) async {
  final reports = <Report>[];
  var page = 1;
  var lastPage = 1;
  do {
    final res = await AdminModerationService.instance.fetchReportsPaginated(
      range: range.apiValue,
      page: page,
      perPage: 100,
    );
    reports.addAll(res.reports);
    lastPage = res.lastPage;
    page++;
  } while (page <= lastPage);
  final rows = <String>[
    'Report ID,Reporter,Reason,Details,Status,Reported At,Content Type,Content ID,Reported Content',
  ];
  for (final report in reports) {
    rows.add(
      [
        report.id,
        _escapeCsv(report.reporter),
        _escapeCsv(report.reason),
        _escapeCsv(report.details),
        _escapeCsv(_toTitleCase(_normalizeReportStatus(report.status))),
        _escapeCsv(_formatCsvDateTime(report.createdAt)),
        _escapeCsv(report.reportable?.type ?? ''),
        report.reportable?.id ?? 0,
        _escapeCsv(report.reportableLabel),
      ].join(','),
    );
  }
  return _AdminCsvFile(
    name: _AdminCsvDataset.moderation.fileName,
    bytes: utf8.encode(rows.join('\n')),
  );
}

Future<_AdminCsvFile> _buildAuditLogsCsv(_DateRangeFilter range) async {
  final logs = <ActivityLog>[];
  var page = 1;
  var lastPage = 1;
  do {
    final res = await AdminAuditLogService.instance.fetchLogs(
      page: page,
      range: range.apiValue,
    );
    logs.addAll(res.logs);
    lastPage = res.lastPage;
    page++;
  } while (page <= lastPage);
  final rows = <String>[
    'Log ID,Date and Time,Category,Action,Description,Actor,Subject Type,Subject ID,Login Type,Email Address,IP Address',
  ];
  for (final log in logs) {
    rows.add(
      [
        log.id,
        _escapeCsv(_formatCsvDateTime(log.createdAt)),
        _escapeCsv(log.category),
        _escapeCsv(log.action),
        _escapeCsv(log.description),
        _escapeCsv(log.actorName ?? ''),
        _escapeCsv(log.subjectType ?? ''),
        log.subjectId ?? '',
        _escapeCsv(log.loginType ?? ''),
        _escapeCsv(log.email ?? ''),
        _escapeCsv(log.ipAddress ?? ''),
      ].join(','),
    );
  }
  return _AdminCsvFile(
    name: _AdminCsvDataset.auditLogs.fileName,
    bytes: utf8.encode(rows.join('\n')),
  );
}

Future<_AdminCsvFile> _buildRecipesCsv(_DateRangeFilter range) async {
  final recipes = <Recipe>[];
  var page = 1;
  var lastPage = 1;
  do {
    final res = await RecipeService.instance.fetchRecipes(
      page: page,
      range: range.apiValue,
      perPage: 100,
    );
    recipes.addAll(res.recipes);
    lastPage = res.lastPage;
    page++;
  } while (page <= lastPage);
  final rows = <String>[
    'Recipe ID,Title,Description,Category,Author,Preparation Time (Minutes),Average Rating,Total Ratings,Total Views,Created At',
  ];
  for (final recipe in recipes) {
    rows.add(
      [
        recipe.id,
        _escapeCsv(recipe.title),
        _escapeCsv(recipe.description ?? ''),
        _escapeCsv(recipe.category?.name ?? ''),
        _escapeCsv(recipe.userDisplayName),
        recipe.prepTime,
        recipe.averageRating?.toStringAsFixed(2) ?? '',
        recipe.ratingsCount ?? '',
        recipe.viewsCount ?? '',
        _escapeCsv(_formatCsvDateTime(recipe.createdAt)),
      ].join(','),
    );
  }
  return _AdminCsvFile(
    name: _AdminCsvDataset.recipes.fileName,
    bytes: utf8.encode(rows.join('\n')),
  );
}

class _AdminCsvExportButton extends StatefulWidget {
  final _DateRangeFilter range;

  const _AdminCsvExportButton({required this.range});

  @override
  State<_AdminCsvExportButton> createState() => _AdminCsvExportButtonState();
}

class _AdminCsvExportButtonState extends State<_AdminCsvExportButton> {
  bool _exporting = false;

  Future<void> _onPressed() async {
    final selected = await _showAdminCsvDatasetDialog(
      context,
      initialSelection: _allAdminCsvDatasets,
    );
    if (!mounted || selected == null || selected.isEmpty) return;
    setState(() => _exporting = true);
    try {
      await _exportAdminCsvBundle(
        context: context,
        range: widget.range,
        datasets: selected,
      );
      if (!mounted) return;
      _showAdminSnack(context, 'CSV bundle exported');
    } catch (e) {
      if (!mounted) return;
      _showAdminErrorSnack(context, e);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _kAdminControlHeight,
      child: FilledButton.icon(
        onPressed: _exporting ? null : _onPressed,
        style: FilledButton.styleFrom(
          foregroundColor: Colors.white,
          backgroundColor: kPrimaryGreen,
          minimumSize: const Size(0, _kAdminControlHeight),
          maximumSize: const Size(double.infinity, _kAdminControlHeight),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          side: BorderSide(
            color: kPrimaryGreen.withValues(alpha: 0.65),
            width: 1.2,
          ),
          textStyle: const TextStyle(fontSize: 12),
        ),
        icon: _exporting
            ? const SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.download_rounded, size: 14, color: Colors.white),
        label: Text(_exporting ? 'Exporting…' : 'Export CSV'),
      ),
    );
  }
}

Future<Set<_AdminCsvDataset>?> _showAdminCsvDatasetDialog(
  BuildContext context, {
  required Set<_AdminCsvDataset> initialSelection,
}) {
  return showDialog<Set<_AdminCsvDataset>>(
    context: context,
    builder: (ctx) {
      final selected = Set<_AdminCsvDataset>.from(initialSelection);
      return StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Download CSV files',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CheckboxListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('All datasets'),
                  tristate: true,
                  value: selected.length == _allAdminCsvDatasets.length
                      ? true
                      : (selected.isEmpty ? false : null),
                  onChanged: (value) {
                    setState(() {
                      if (value == true) {
                        selected
                          ..clear()
                          ..addAll(_allAdminCsvDatasets);
                      } else {
                        selected.clear();
                      }
                    });
                  },
                ),
                const Divider(height: 12),
                ..._AdminCsvDataset.values.map(
                  (dataset) => CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    value: selected.contains(dataset),
                    title: Text(dataset.label),
                    onChanged: (checked) {
                      setState(() {
                        if (checked == true) {
                          selected.add(dataset);
                        } else {
                          selected.remove(dataset);
                        }
                      });
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: selected.isEmpty
                  ? null
                  : () => Navigator.pop(
                      ctx,
                      Set<_AdminCsvDataset>.from(selected),
                    ),
              style: FilledButton.styleFrom(backgroundColor: kPrimaryGreen),
              child: const Text('Download ZIP'),
            ),
          ],
        ),
      );
    },
  );
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
