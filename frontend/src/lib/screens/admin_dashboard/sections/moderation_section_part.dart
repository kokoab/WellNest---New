part of 'package:wellnest/screens/admin_dashboard.dart';

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
  String _searchQuery = '';
  final Set<String> _selectedSearchFields = <String>{};
  static const List<_SearchFieldOption> _searchFieldOptions = [
    _SearchFieldOption(key: 'reporter', label: 'Reporter'),
    _SearchFieldOption(key: 'reason', label: 'Reason'),
    _SearchFieldOption(key: 'details', label: 'Details'),
    _SearchFieldOption(key: 'reportable_type', label: 'Report type'),
    _SearchFieldOption(key: 'reportable_name', label: 'Reported user'),
    _SearchFieldOption(key: 'reportable_email', label: 'Reported email'),
    _SearchFieldOption(key: 'reportable_title', label: 'Recipe title'),
    _SearchFieldOption(key: 'reportable_content', label: 'Post content'),
  ];
  Timer? _searchDebounce;
  final TextEditingController _searchController = TextEditingController();
  _DateRangeFilter _range = _DateRangeFilter.monthly;
  DateTimeRange? _customDateRange;
  int _page = 1;
  int _lastPage = 1;
  bool _loadingPage = false;
  static const int _perPage = 20;

  @override
  void initState() {
    super.initState();
    refresh();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await AdminModerationService.instance
          .fetchReportsPaginated(
            range: _range.apiValue,
            search: _searchQuery,
            searchFields: _selectedSearchFields.toList(),
            startDate: _customDateRange?.start,
            endDate: _customDateRange?.end,
            page: 1,
            perPage: _perPage,
          );
      if (!mounted) return;
      setState(() {
        _reports = response.reports;
        _page = response.currentPage;
        _lastPage = response.lastPage;
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
      final response = await AdminModerationService.instance
          .fetchReportsPaginated(
            range: _range.apiValue,
            search: _searchQuery,
            searchFields: _selectedSearchFields.toList(),
            startDate: _customDateRange?.start,
            endDate: _customDateRange?.end,
            page: page,
            perPage: _perPage,
          );
      if (!mounted) return;
      setState(() {
        _reports = response.reports;
        _page = response.currentPage;
        _lastPage = response.lastPage;
        _loadingPage = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingPage = false);
      _showAdminErrorSnack(context, e);
    }
  }

  void _handleSearchChanged(String value) {
    setState(() => _searchQuery = value.trim());
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      refresh();
    });
  }

  void _clearAllFilters() {
    _searchDebounce?.cancel();
    _searchController.clear();
    setState(() {
      _searchQuery = '';
      _selectedSearchFields.clear();
      _range = _DateRangeFilter.monthly;
      _customDateRange = null;
    });
    refresh();
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
      searchQuery: _searchQuery,
      searchController: _searchController,
      onSearchChanged: _handleSearchChanged,
      searchFieldOptions: _searchFieldOptions,
      selectedSearchFields: _selectedSearchFields,
      onSearchFieldToggled: (fieldKey) {
        setState(() {
          if (_selectedSearchFields.contains(fieldKey)) {
            _selectedSearchFields.remove(fieldKey);
          } else {
            _selectedSearchFields.add(fieldKey);
          }
        });
        refresh();
      },
      selectedRange: _range,
      onRangeChanged: (range) {
        setState(() {
          _range = range;
          _customDateRange = null;
        });
        refresh();
      },
      customDateRange: _customDateRange,
      onCustomDateRangeChanged: (value) {
        setState(() => _customDateRange = value);
        refresh();
      },
      onClearAllFilters: _clearAllFilters,
      onRefresh: refresh,
      onDeleteAll: _confirmDeleteAllReports,
      onReportAction: _handleReportAction,
      currentPage: _page,
      totalPages: _lastPage,
      loadingPage: _loadingPage,
      onPageChanged: _handlePageChanged,
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
  final String searchQuery;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final List<_SearchFieldOption> searchFieldOptions;
  final Set<String> selectedSearchFields;
  final ValueChanged<String> onSearchFieldToggled;
  final _DateRangeFilter selectedRange;
  final ValueChanged<_DateRangeFilter> onRangeChanged;
  final DateTimeRange? customDateRange;
  final ValueChanged<DateTimeRange?> onCustomDateRangeChanged;
  final VoidCallback onClearAllFilters;
  final VoidCallback onRefresh;
  final VoidCallback onDeleteAll;
  final Future<void> Function(int, String) onReportAction;
  final int currentPage;
  final int totalPages;
  final bool loadingPage;
  final ValueChanged<int> onPageChanged;

  const _ModerationSection({
    required this.theme,
    required this.reports,
    required this.loading,
    required this.error,
    required this.searchQuery,
    required this.searchController,
    required this.onSearchChanged,
    required this.searchFieldOptions,
    required this.selectedSearchFields,
    required this.onSearchFieldToggled,
    required this.selectedRange,
    required this.onRangeChanged,
    required this.customDateRange,
    required this.onCustomDateRangeChanged,
    required this.onClearAllFilters,
    required this.onRefresh,
    required this.onDeleteAll,
    required this.onReportAction,
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
        _AdminSectionHeadingRow(
          title: _MinimalSectionLabel(
            theme: theme,
            label: 'Content Reports',
            subtitle: loading ? 'Loading…' : '${reports.length} pending',
          ),
          actions: [
            _ClearFiltersButton(onPressed: onClearAllFilters),
            const SizedBox(width: 6),
            _DateRangeDropdown(value: selectedRange, onChanged: onRangeChanged),
            const SizedBox(width: 6),
            _CustomDateRangeButton(
              value: customDateRange,
              onChanged: onCustomDateRangeChanged,
            ),
            const SizedBox(width: 6),
            if (!loading) ...[
              _TopBarIconBtn(
                icon: Icons.refresh_rounded,
                onPressed: onRefresh,
                tooltip: 'Refresh',
                color: kPrimaryGreen,
              ),
              const SizedBox(width: 4),
              _AdminCsvExportButton(range: selectedRange),
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
                    minimumSize: const Size(
                      _kAdminControlHeight,
                      _kAdminControlHeight,
                    ),
                    maximumSize: const Size(
                      _kAdminControlHeight,
                      _kAdminControlHeight,
                    ),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    padding: EdgeInsets.zero,
                  ),
                ),
              ],
            ],
          ],
        ),
        const SizedBox(height: 14),
        _SearchBar(
          theme: theme,
          controller: searchController,
          onChanged: onSearchChanged,
          hintText: 'Search reports...',
        ),
        const SizedBox(height: 10),
        _AdvancedSearchPanel(
          theme: theme,
          options: searchFieldOptions,
          selectedKeys: selectedSearchFields,
          onToggleField: onSearchFieldToggled,
        ),
        const SizedBox(height: 14),
        if (loading && reports.isEmpty)
          const _LoadingState()
        else if (error != null)
          _ErrorState(theme: theme, message: error!, onRetry: onRefresh)
        else if (reports.isEmpty)
          _EmptyState(
            theme: theme,
            message: searchQuery.isEmpty
                ? 'No pending reports — all clear'
                : 'No reports match your search',
          )
        else
          _ReportsTable(
            theme: theme,
            reports: reports,
            onAction: onReportAction,
          ),
        if (reports.isNotEmpty) ...[
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

// ─── Reports table ────────────────────────────────────────────────────────────

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
    return _adminBoundedFlexTable(
      theme: theme,
      buildColumnWidths: (w) => {
        0: FlexColumnWidth(w * 0.08),
        1: FlexColumnWidth(w * 0.12),
        2: FlexColumnWidth(w * 0.25),
        3: FlexColumnWidth(w * 0.23),
        4: FlexColumnWidth(w * 0.12),
        5: FlexColumnWidth(w * 0.20),
      },
      headers: ['ID', 'TAG', 'REPORTED ITEM', 'REASON', 'DATE', 'ACTIONS'],
      rows: reports.map((r) {
        return _tableRow(theme, [
          Text(
            '${r.id}',
            style: TextStyle(
              fontSize: 13,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          _TypePill(type: r.reportable?.type ?? 'unknown'),
          Text(
            r.reportableLabel,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurface),
          ),
          Text(
            r.reason ?? '—',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurface),
          ),
          Text(
            _formatHumanDate(r.createdAt),
            style: TextStyle(
              fontSize: 12,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          ClipRect(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _ActionIconBtn(
                    icon: Icons.close_rounded,
                    color: theme.colorScheme.onSurfaceVariant,
                    tooltip: 'Dismiss',
                    onPressed: () => onAction(r.id, 'dismiss'),
                    size: 14,
                  ),
                  const SizedBox(width: 4),
                  _ActionIconBtn(
                    icon: Icons.check_rounded,
                    color: kPrimaryGreen,
                    tooltip: 'Approve',
                    onPressed: () => onAction(r.id, 'approve'),
                    size: 14,
                  ),
                  if (r.isRecipeReport || r.isPostReport) ...[
                    const SizedBox(width: 4),
                    _ActionIconBtn(
                      icon: Icons.delete_outline_rounded,
                      color: kAccentOrange,
                      tooltip: 'Remove content',
                      onPressed: () => onAction(r.id, 'remove-content'),
                      size: 14,
                    ),
                  ],
                  if (r.isUserReport) ...[
                    const SizedBox(width: 4),
                    _ActionIconBtn(
                      icon: Icons.block_rounded,
                      color: Colors.red,
                      tooltip: 'Suspend user',
                      onPressed: () => onAction(r.id, 'suspend-user'),
                      size: 14,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ], null);
      }).toList(),
    );
  }
}
