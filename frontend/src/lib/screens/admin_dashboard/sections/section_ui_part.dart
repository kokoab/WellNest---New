part of 'package:my_app/screens/admin_dashboard.dart';

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

/// Title on the left, toolbar controls in a horizontally scrollable row on the
/// right so narrow viewports do not overflow.
class _AdminSectionHeadingRow extends StatelessWidget {
  final Widget title;
  final List<Widget> actions;

  const _AdminSectionHeadingRow({required this.title, required this.actions});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: title),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: actions,
          ),
        ),
      ],
    );
  }
}

// ─── Search bar ───────────────────────────────────────────────────────────────
class _SearchBar extends StatelessWidget {
  final ThemeData theme;
  final TextEditingController? controller;
  final ValueChanged<String> onChanged;
  final String hintText;
  const _SearchBar({
    required this.theme,
    this.controller,
    required this.onChanged,
    required this.hintText,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = theme.brightness == Brightness.dark;
    return TextField(
      controller: controller,
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

class _SearchFieldOption {
  final String key;
  final String label;
  const _SearchFieldOption({required this.key, required this.label});
}

const double _kAdminControlHeight = 40;

class _ClearFiltersButton extends StatelessWidget {
  final VoidCallback onPressed;
  const _ClearFiltersButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _kAdminControlHeight,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.filter_alt_off_rounded, size: 14),
        label: const Text('Clear all filters'),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.red,
          side: BorderSide(
            color: Colors.red.withValues(alpha: 0.5),
            width: 1.2,
          ),
          minimumSize: const Size(0, _kAdminControlHeight),
          maximumSize: const Size(double.infinity, _kAdminControlHeight),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

class _AdvancedSearchPanel extends StatelessWidget {
  final ThemeData theme;
  final List<_SearchFieldOption> options;
  final Set<String> selectedKeys;
  final ValueChanged<String> onToggleField;

  const _AdvancedSearchPanel({
    required this.theme,
    required this.options,
    required this.selectedKeys,
    required this.onToggleField,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.22,
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.18),
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Search fields',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: options.map((option) {
              final isSelected = selectedKeys.contains(option.key);
              return FilterChip(
                label: Text(option.label),
                selected: isSelected,
                onSelected: (_) => onToggleField(option.key),
                selectedColor: kPrimaryGreen.withValues(alpha: 0.18),
                checkmarkColor: kPrimaryGreen,
                labelStyle: TextStyle(
                  fontSize: 12,
                  color: isSelected
                      ? kPrimaryGreen
                      : theme.colorScheme.onSurfaceVariant,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                ),
                side: BorderSide(
                  color: isSelected
                      ? kPrimaryGreen.withValues(alpha: 0.45)
                      : theme.colorScheme.outline.withValues(alpha: 0.2),
                  width: 0.6,
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _CustomDateRangeButton extends StatelessWidget {
  final DateTimeRange? value;
  final ValueChanged<DateTimeRange?> onChanged;
  const _CustomDateRangeButton({required this.value, required this.onChanged});

  Future<void> _pickRange(BuildContext context) async {
    final now = DateTime.now();
    final initialRange =
        value ??
        DateTimeRange(start: now.subtract(const Duration(days: 29)), end: now);
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 1),
      initialDateRange: initialRange,
      helpText: 'Select date range',
    );
    if (picked != null) {
      onChanged(picked);
    }
  }

  String _formatDate(DateTime d) {
    final month = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '${d.year}-$month-$day';
  }

  @override
  Widget build(BuildContext context) {
    final hasValue = value != null;
    final label = hasValue
        ? '${_formatDate(value!.start)} to ${_formatDate(value!.end)}'
        : 'Custom range';
    return SizedBox(
      height: _kAdminControlHeight,
      child: OutlinedButton.icon(
        onPressed: () => _pickRange(context),
        icon: const Icon(Icons.date_range_rounded, size: 14),
        label: Text(label, overflow: TextOverflow.ellipsis),
        style: OutlinedButton.styleFrom(
          foregroundColor: kPrimaryGreen,
          side: BorderSide(
            color: kPrimaryGreen.withValues(alpha: 0.45),
            width: 1.2,
          ),
          minimumSize: const Size(0, _kAdminControlHeight),
          maximumSize: const Size(double.infinity, _kAdminControlHeight),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        ),
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

  Future<void> _openMenu(BuildContext context) async {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (overlay == null) return;

    final topLeft = box.localToGlobal(Offset.zero, ancestor: overlay);
    final bottomRight = box.localToGlobal(
      box.size.bottomRight(Offset.zero),
      ancestor: overlay,
    );
    final position = RelativeRect.fromRect(
      Rect.fromPoints(topLeft, bottomRight),
      Offset.zero & overlay.size,
    );

    final selected = await showMenu<_DateRangeFilter>(
      context: context,
      position: position,
      color: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF222222)
          : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      items: _DateRangeFilter.values.map((range) {
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
    );

    if (selected != null) onChanged(selected);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _kAdminControlHeight,
      child: OutlinedButton(
        onPressed: () => _openMenu(context),
        style: OutlinedButton.styleFrom(
          foregroundColor: kPrimaryGreen,
          side: BorderSide(
            color: kPrimaryGreen.withValues(alpha: 0.4),
            width: 1.2,
          ),
          minimumSize: const Size(0, _kAdminControlHeight),
          maximumSize: const Size(double.infinity, _kAdminControlHeight),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.calendar_today_outlined, size: 12),
            const SizedBox(width: 6),
            Text(value.label),
            const SizedBox(width: 4),
            const Icon(Icons.keyboard_arrow_down_rounded, size: 14),
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

// ─── Pagination Controls ──────────────────────────────────────────────────────
