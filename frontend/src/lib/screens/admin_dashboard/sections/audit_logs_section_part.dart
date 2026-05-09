part of 'package:my_app/screens/admin_dashboard.dart';

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
  int _page = 1;
  int _lastPage = 1;
  bool _loadingPage = false;

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
        _page = res.currentPage;
        _lastPage = res.lastPage;
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

  Future<void> _handlePageChanged(int page) async {
    if (page < 1 || page > _lastPage || page == _page) return;
    setState(() => _loadingPage = true);
    try {
      final res = await AdminAuditLogService.instance.fetchLogs(
        page: page,
        range: _range.apiValue,
      );
      if (!mounted) return;
      setState(() {
        _logs = res.logs;
        _page = res.currentPage;
        _lastPage = res.lastPage;
        _loadingPage = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingPage = false);
      _showAdminErrorSnack(context, e);
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
      selectedRange: _range,
      onRangeChanged: (range) {
        setState(() => _range = range);
        refresh();
      },
      onRefresh: refresh,
      currentPage: _page,
      totalPages: _lastPage,
      loadingPage: _loadingPage,
      onPageChanged: _handlePageChanged,
    );
  }

  @override
  bool get wantKeepAlive => true;
}

class _AuditLogsSection extends StatelessWidget {
  final ThemeData theme;
  final List<ActivityLog> logs;
  final bool loading;
  final String? error;
  final _DateRangeFilter selectedRange;
  final ValueChanged<_DateRangeFilter> onRangeChanged;
  final VoidCallback onRefresh;
  final int currentPage;
  final int totalPages;
  final bool loadingPage;
  final ValueChanged<int> onPageChanged;

  const _AuditLogsSection({
    required this.theme,
    required this.logs,
    required this.loading,
    required this.error,
    required this.selectedRange,
    required this.onRangeChanged,
    required this.onRefresh,
    required this.currentPage,
    required this.totalPages,
    required this.loadingPage,
    required this.onPageChanged,
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
            _AdminCsvExportButton(range: selectedRange),
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
          _AuditLogsTable(theme: theme, logs: logs),
        if (logs.isNotEmpty) ...[
          const SizedBox(height: 14),
          _PaginationControls(
            currentPage: currentPage,
            totalPages: totalPages,
            loading: loadingPage,
            onPageChanged: onPageChanged,
          ),
        ],
        const SizedBox(height: 32),
      ],
    );
  }
}

// ─── Tables ───────────────────────────────────────────────────────────────────
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

class _AuditLogsTable extends StatelessWidget {
  final ThemeData theme;
  final List<ActivityLog> logs;
  const _AuditLogsTable({required this.theme, required this.logs});

  @override
  Widget build(BuildContext context) {
    final isDark = theme.brightness == Brightness.dark;
    final height = (logs.length * 74.0).clamp(240.0, 540.0);
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
        itemCount: logs.length,
        separatorBuilder: (_, __) => Divider(
          height: 10,
          color: theme.colorScheme.outline.withValues(alpha: 0.12),
        ),
        itemBuilder: (_, index) {
          final log = logs[index];
          return Row(
            children: [
              SizedBox(
                width: 40,
                child: Text(
                  '${log.id}',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              SizedBox(
                width: 88,
                child: Text(
                  _formatHumanDate(log.createdAt),
                  style: TextStyle(
                    fontSize: 11,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              SizedBox(
                width: 90,
                child: _CategoryPill(theme: theme, label: log.category),
              ),
              SizedBox(
                width: 120,
                child: Text(
                  log.action,
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  log.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 130,
                child: Text(
                  log.actorName ?? '—',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ─── Stat Card ────────────────────────────────────────────────────────────────
