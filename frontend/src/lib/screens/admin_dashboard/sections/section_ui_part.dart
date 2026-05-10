part of 'package:my_app/screens/admin_dashboard.dart';

// ─── Design Tokens: WellNest Identity ───────────────────────────────────────
const Color _kSidebarDark = Color(0xFF042D14); // Deep Forest Green
const Color _kSidebarActiveBg = Color(0xFF0A4D23); // Muted Brand Green
const Color _kMainBgLight = kBackgroundCream;
const Color _kMainBgDark = Color(0xFF0C0E12);
const Color _kCardBgLight = Colors.white;
const Color _kCardBgDark = Color(0xFF161922);
const Color _kBorderLight = kSurfaceWarmGray;
const Color _kBorderDark = Color(0xFF1E242D);

Color _adminCardColor(bool isDark) => isDark ? _kCardBgDark : _kCardBgLight;
Color _adminBorderColor(bool isDark) => isDark ? _kBorderDark : _kBorderLight;
Color _adminScaffoldBg(bool isDark) => isDark ? _kMainBgDark : _kMainBgLight;

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
    final trendColor = trendUp ? kPrimaryGreen : kAccentOrange;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? _kCardBgDark : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? _kBorderDark : const Color(0xFFEAEFF5),
          width: 1,
        ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Row(
          children: [
            // Left color accent bar
            Container(
              width: 4,
              color: color,
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: isDark ? 0.15 : 0.08),
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: Icon(icon, color: color, size: 18),
                        ),
                        const Spacer(),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              trendUp
                                  ? Icons.arrow_upward_rounded
                                  : Icons.arrow_downward_rounded,
                              size: 11,
                              color: trendColor,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              trend,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: trendColor,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: theme.colorScheme.onSurface,
                        letterSpacing: -1,
                        height: 1,
                        fontFamily: kFontHelveticaNow,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
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
        color: isDark ? _kCardBgDark : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? _kBorderDark : const Color(0xFFEAEFF5),
          width: 1,
        ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Brand green left accent
        Container(
          width: 3,
          height: subtitle != null ? 36 : 20,
          margin: const EdgeInsets.only(right: 10),
          decoration: BoxDecoration(
            color: kPrimaryGreen,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurface,
                letterSpacing: -0.4,
                fontFamily: kFontHelveticaNow,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(
                subtitle!,
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ],
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
    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withValues(alpha: 0.15) : kPrimaryGreen.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: TextStyle(
          fontSize: 14,
          color: theme.colorScheme.onSurface,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(
            fontSize: 14,
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            fontWeight: FontWeight.w500,
          ),
          prefixIcon: Padding(
            padding: const EdgeInsets.only(left: 14, right: 10),
            child: Icon(
              Icons.search_rounded,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
              size: 20,
            ),
          ),
          prefixIconConstraints: const BoxConstraints(minWidth: 40, minHeight: 40),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: _adminBorderColor(isDark), width: 1.2),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: _adminBorderColor(isDark), width: 1.2),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: kPrimaryGreen, width: 1.5),
          ),
          filled: true,
          fillColor: _adminCardColor(isDark),
          contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          isDense: true,
        ),
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
            'SEARCH FIELDS',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
              letterSpacing: 1.2,
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
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: isActive
            ? kPrimaryGreen.withValues(alpha: 0.08)
            : kAccentOrange.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isActive
              ? kPrimaryGreen.withValues(alpha: 0.12)
              : kAccentOrange.withValues(alpha: 0.12),
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: isActive ? kPrimaryGreen : kAccentOrange,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            isActive ? 'Active' : 'Inactive',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: isActive ? kPrimaryGreen : kAccentOrange,
              letterSpacing: 0.2,
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
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: kPrimaryGreen.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: kPrimaryGreen.withValues(alpha: 0.15),
          width: 0.5,
        ),
      ),
      child: Text(
        type.toUpperCase(),
        style: const TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
          color: kPrimaryGreen,
          letterSpacing: 0.3,
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
