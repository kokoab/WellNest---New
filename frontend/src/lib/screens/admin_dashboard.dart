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

String _adminErrorMessage(Object error) {
  return error.toString().replaceFirst('Exception: ', '');
}

void _showAdminErrorSnack(BuildContext context, Object error) {
  _showAdminSnack(context, _adminErrorMessage(error), isError: true);
}

Future<void> _shareCsvRows({
  required List<String> rows,
  required String fileName,
  required String subject,
}) async {
  final xfile = XFile.fromData(
    Uint8List.fromList(rows.join('\n').codeUnits),
    name: fileName,
    mimeType: 'text/csv',
  );
  await Share.shareXFiles([xfile], subject: subject);
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
