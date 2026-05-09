part of 'package:my_app/screens/admin_dashboard.dart';

class _ModerationSectionContainer extends StatefulWidget {
  final ThemeData theme;
  const _ModerationSectionContainer({super.key, required this.theme});

  @override
  State<_ModerationSectionContainer> createState() =>
      _ModerationSectionContainerState();
}

class _ModerationSectionContainerState
    extends State<_ModerationSectionContainer>
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
        _error = _adminErrorMessage(e);
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
      await _shareCsvRows(
        rows: rows,
        fileName: 'Content Reports Export.csv',
        subject: 'WellNest Content Reports Export',
      );
      if (!mounted) return;
      _showAdminSnack(context, 'Reports exported');
    } catch (e) {
      if (!mounted) return;
      _showAdminErrorSnack(context, e);
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
      _showAdminErrorSnack(context, e);
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
      _showAdminErrorSnack(context, e);
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
    final isDark = theme.brightness == Brightness.dark;
    final height = (reports.length * 84.0).clamp(240.0, 540.0);
    return Container(
      height: height,
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
      child: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: reports.length,
        separatorBuilder: (_, __) => Divider(
          height: 12,
          color: theme.colorScheme.outline.withValues(alpha: 0.12),
        ),
        itemBuilder: (_, index) {
          final r = reports[index];
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 46,
                child: Text(
                  '${r.id}',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              SizedBox(
                width: 90,
                child: _TypePill(type: r.reportable?.type ?? 'unknown'),
              ),
              Expanded(
                child: Text(
                  r.reportableLabel,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  r.reason ?? '—',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 78,
                child: Text(
                  _formatHumanDate(r.createdAt),
                  style: TextStyle(
                    fontSize: 11,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
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
            ],
          );
        },
      ),
    );
  }
}
