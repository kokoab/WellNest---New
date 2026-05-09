part of 'package:my_app/screens/admin_dashboard.dart';

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
              SizedBox(width: 90, child: _TypePill(type: r.reportable?.type ?? 'unknown')),
              Expanded(
                child: Text(
                  r.reportableLabel,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  r.reason ?? '—',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface),
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

