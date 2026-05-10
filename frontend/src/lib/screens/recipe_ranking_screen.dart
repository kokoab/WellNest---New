import 'package:flutter/material.dart';
import 'package:my_app/models/recipe_ranking_item.dart';
import 'package:my_app/screens/recipe_detail_screen.dart';
import 'package:my_app/services/recipe_service.dart';
import 'package:my_app/theme/app_spacing.dart';
import 'package:my_app/theme/app_theme.dart';

/// Selected row in dropdown menus — green at low opacity over light grey (Flutter uses
/// [ThemeData.focusColor] for that Ink layer on touch; see Material `dropdown.dart`).
Color _filterDropdownSelectedWash() => Color.alphaBlend(
      kPrimaryGreen.withValues(alpha: 0.12),
      Colors.grey.shade100,
    );

/// Public recipe leaderboard — aligned with recipe detail / instructions card styling.
class RecipeRankingScreen extends StatefulWidget {
  const RecipeRankingScreen({super.key});

  @override
  State<RecipeRankingScreen> createState() => _RecipeRankingScreenState();
}

class _RecipeRankingScreenState extends State<RecipeRankingScreen> {
  static const Color _reviewStarGold = Color(0xFFF9BD21);
  static const double _cardImageAspectRatio = 16 / 10;

  /// Trophy / numbered badge width — keep in sync with [_buildRankBadge].
  static const double _rankBadgeOuterSize = 44;
  static const double _rankBadgeSpacing = 12;

  static const int _pageSize = 20;

  String _window = '7d';
  String _mode = 'combined';
  bool _loading = true;
  String? _error;
  List<RecipeRankingItem> _items = [];
  int _visibleCount = _pageSize;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await RecipeService.instance.fetchRecipeRankings(
        window: _window,
        mode: _mode,
      );
      if (!mounted) return;
      setState(() {
        _items = items;
        _visibleCount = _pageSize;
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

  /// Same shell as instruction step cards on [RecipeDetailScreen].
  BoxDecoration _rankingCardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFBDBDBD)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    );
  }

  InputDecoration _filterDecoration(BuildContext context, String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: helveticaNow(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: kCaptionGray,
      ),
      floatingLabelStyle: helveticaNow(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppColors.primaryGreen,
      ),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.sm),
        borderSide: BorderSide(color: wellnestOutlineColor(context)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.sm),
        borderSide: BorderSide(color: wellnestOutlineColor(context)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.sm),
        borderSide: BorderSide(color: AppColors.primaryGreen, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    );
  }

  /// Softer surfaces + no primary tint on popup menus (matches WellNest cards).
  ThemeData _filterControlsTheme(BuildContext context) {
    final base = Theme.of(context);
    final outline = wellnestOutlineColor(context);
    final menuShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadii.sm),
      side: BorderSide(color: outline),
    );
    final wash = _filterDropdownSelectedWash();
    return base.copyWith(
      colorScheme: base.colorScheme.copyWith(
        primary: wash,
        onPrimary: kBodyTextDark,
        primaryContainer: wash,
        onPrimaryContainer: kBodyTextDark,
      ),
      // Critical for dropdown selected-row Ink on mobile (touch highlight mode).
      focusColor: wash,
      splashColor: AppColors.primaryGreen.withValues(alpha: 0.08),
      highlightColor: wash,
      canvasColor: Colors.white,
      popupMenuTheme: PopupMenuThemeData(
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 6,
        shadowColor: Colors.black.withValues(alpha: 0.08),
        shape: menuShape,
        textStyle: helveticaNow(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: kBodyTextDark,
        ),
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        menuStyle: MenuStyle(
          backgroundColor: WidgetStateProperty.all(Colors.white),
          surfaceTintColor: WidgetStateProperty.all(Colors.transparent),
          elevation: WidgetStateProperty.all(6),
          shadowColor: WidgetStateProperty.all(
            Colors.black.withValues(alpha: 0.08),
          ),
          shape: WidgetStateProperty.all(menuShape),
          padding: WidgetStateProperty.all(
            const EdgeInsets.symmetric(vertical: AppSpacing.xs),
          ),
        ),
      ),
    );
  }

  TextStyle get _filterValueTextStyle => helveticaNow(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: kPrimaryGreen,
      );

  /// Always dark text — reads on white rows and on the light green-gray selected wash.
  TextStyle get _filterMenuItemTextStyle => helveticaNow(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: kBodyTextDark,
      );

  /// Top 3: trophy + medal tones. Rank ≥ 4: numbered badge (stronger emphasis for 4–10).
  Widget _buildRankBadge(int rank) {
    if (rank <= 3) {
      final medal = switch (rank) {
        1 => (
            bg: const Color(0xFFFFF8E1),
            fg: const Color(0xFFFFB300),
          ),
        2 => (
            bg: const Color(0xFFECEFF1),
            fg: const Color(0xFF78909C),
          ),
        _ => (
            bg: const Color(0xFFFFF3E0),
            fg: const Color(0xFFB86125),
          ),
      };
      return Semantics(
        label: 'Rank $rank',
        child: Container(
          width: _rankBadgeOuterSize,
          height: _rankBadgeOuterSize,
          decoration: BoxDecoration(
            color: medal.bg,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Icon(
            Icons.emoji_events_rounded,
            color: medal.fg,
            size: 26,
          ),
        ),
      );
    }

    final bool emphasisBand = rank >= 4 && rank <= 10;
    final Color numColor = emphasisBand
        ? AppColors.primaryGreen
        : AppColors.primaryGreen.withValues(alpha: 0.82);

    return CircleAvatar(
      radius: 22,
      backgroundColor: AppColors.primaryGreen.withValues(
        alpha: emphasisBand ? 0.14 : 0.10,
      ),
      child: Text(
        '$rank',
        style: TextStyle(
          color: numColor,
          fontWeight: FontWeight.w800,
          fontSize: rank >= 10 ? 13 : 15,
          fontFamily: kFontHelveticaNow,
        ),
      ),
    );
  }

  /// Mirrors [_RecipeDetailScreenState._buildRatingSummaryPill] + compact views.
  Widget _buildRatingAndViewsRow(RecipeRankingItem item) {
    final avg = item.averageRating;
    final count = item.ratingsCount;
    const labelStyle = TextStyle(
      fontFamily: kFontHelveticaNow,
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: kPrimaryGreen,
    );
    return Transform.translate(
      // The rounded star glyph has built-in left whitespace inside its icon box.
      // Nudge the stats row so the visible star edge lines up with the title.
      offset: const Offset(-2, 0),
      child: Wrap(
        alignment: WrapAlignment.start,
        spacing: 10,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Icon(Icons.star_rounded, color: _reviewStarGold, size: 20),
              const SizedBox(width: 6),
              Text('${avg.toStringAsFixed(1)} • ', style: labelStyle),
              Icon(
                Icons.person_outline_rounded,
                size: 16,
                color: kPrimaryGreen.withValues(alpha: 0.9),
              ),
              const SizedBox(width: 3),
              Text('$count', style: labelStyle),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.visibility_outlined,
                size: 16,
                color: kCaptionGray,
              ),
              const SizedBox(width: 4),
              Text(
                '${item.viewsCount} views',
                style: const TextStyle(
                  fontFamily: kFontHelveticaNow,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: kCaptionGray,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  int get _maxViewsForScore {
    if (_items.isEmpty) return 1;
    return _items
        .map((item) => item.viewsCount)
        .fold<int>(1, (maxViews, views) => views > maxViews ? views : maxViews);
  }

  void _showScoreBreakdown(RecipeRankingItem item, int rank) {
    final maxViews = _maxViewsForScore;
    final ratingNorm = (item.averageRating / 5).clamp(0.0, 1.0);
    final viewsNorm = (item.viewsCount / maxViews).clamp(0.0, 1.0);
    final ratingContribution = ratingNorm * 0.6;
    final viewsContribution = viewsNorm * 0.4;
    final calculatedScore = ratingContribution + viewsContribution;

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final theme = Theme.of(context);
        final cs = theme.colorScheme;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              AppSpacing.lg,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildRankBadge(rank),
                    const SizedBox(width: AppSpacing.sm2),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: cs.onSurface,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Score breakdown',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      item.score.toStringAsFixed(2),
                      style: georgiaProDisplayStyle(
                        fontSize: 32,
                        color: kPrimaryGreen,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppRadii.md),
                    border: Border.all(color: wellnestOutlineColor(context)),
                  ),
                  child: Column(
                    children: [
                      _ScoreBreakdownRow(
                        icon: Icons.star_rounded,
                        iconColor: _reviewStarGold,
                        label: 'Stars',
                        value:
                            '${item.averageRating.toStringAsFixed(1)} / 5 from ${item.ratingsCount} ratings',
                        detail:
                            'Normalized ${(ratingNorm * 100).toStringAsFixed(0)}% × 60% = ${ratingContribution.toStringAsFixed(3)}',
                      ),
                      const Divider(height: AppSpacing.lg),
                      _ScoreBreakdownRow(
                        icon: Icons.visibility_outlined,
                        iconColor: kCaptionGray,
                        label: 'Views',
                        value: '${item.viewsCount} of $maxViews top views',
                        detail:
                            'Normalized ${(viewsNorm * 100).toStringAsFixed(0)}% × 40% = ${viewsContribution.toStringAsFixed(3)}',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.sm2),
                Text(
                  'Formula: (average stars ÷ 5 × 0.60) + '
                  '(views ÷ highest views in this ranking window × 0.40). '
                  'Backend score: ${item.score.toStringAsFixed(4)}. '
                  'Recalculated here: ${calculatedScore.toStringAsFixed(4)}.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRankingCard(BuildContext context, int index) {
    final item = _items[index];
    final rank = index + 1;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final imgUrl = item.displayImageUrl;
    final hasImage = imgUrl != null && imgUrl.trim().isNotEmpty;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm2),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => Navigator.push<void>(
            context,
            MaterialPageRoute<void>(
              fullscreenDialog: true,
              builder: (_) => RecipeDetailScreen(recipeId: item.id),
            ),
          ),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            decoration: _rankingCardDecoration(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (hasImage)
                  AspectRatio(
                    aspectRatio: _cardImageAspectRatio,
                    child: Image.network(
                      imgUrl.trim(),
                      fit: BoxFit.cover,
                      width: double.infinity,
                      alignment: Alignment.center,
                      errorBuilder: (_, __, ___) => ColoredBox(
                        color: cs.surfaceContainerHighest,
                        child: Icon(
                          Icons.image_not_supported_outlined,
                          color: cs.outline,
                          size: 40,
                        ),
                      ),
                    ),
                  )
                else
                  AspectRatio(
                    aspectRatio: _cardImageAspectRatio,
                    child: ColoredBox(
                      color: AppColors.imagePlaceholderGreen,
                      child: Icon(
                        Icons.restaurant_menu_rounded,
                        size: 44,
                        color: AppColors.primaryGreen.withValues(alpha: 0.35),
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildRankBadge(rank),
                      const SizedBox(width: _rankBadgeSpacing),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                                fontFamily: kFontHelveticaNow,
                                fontSize: 22,
                                height: 1.2,
                                color: cs.onSurface,
                              ),
                            ),
                            if (item.authorName != null &&
                                item.authorName!.trim().isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                'By ${item.authorName}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                            ],
                            SizedBox(
                              height: item.authorName != null &&
                                      item.authorName!.trim().isNotEmpty
                                  ? 4
                                  : 6,
                            ),
                            _buildRatingAndViewsRow(item),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: () => _showScoreBreakdown(item, rank),
                        borderRadius: BorderRadius.circular(AppRadii.sm),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.xs,
                            vertical: AppSpacing.xs,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'SCORE',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.8,
                                      color: cs.onSurfaceVariant,
                                    ),
                                  ),
                                  const SizedBox(width: 3),
                                  Icon(
                                    Icons.info_outline_rounded,
                                    size: 12,
                                    color: cs.onSurfaceVariant,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                item.score.toStringAsFixed(2),
                                style: georgiaProDisplayStyle(
                                  fontSize: 28,
                                  color: kPrimaryGreen,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Recipe Rankings',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: cs.onSurface,
          ),
        ),
        backgroundColor: cs.surface,
        foregroundColor: cs.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              AppSpacing.sm2,
            ),
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.sm2),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppRadii.sm),
                border: Border.all(color: wellnestOutlineColor(context)),
              ),
              child: Theme(
                data: _filterControlsTheme(context),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        isExpanded: true,
                        value: _window,
                        decoration: _filterDecoration(context, 'Window'),
                        dropdownColor: Colors.white,
                        borderRadius:
                            BorderRadius.circular(AppRadii.sm),
                        style: _filterValueTextStyle,
                        iconEnabledColor: kPrimaryGreen,
                        items: [
                          DropdownMenuItem(
                            value: '7d',
                            child: Text(
                              'Last 7 days',
                              style: _filterMenuItemTextStyle,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          DropdownMenuItem(
                            value: '30d',
                            child: Text(
                              'Last 30 days',
                              style: _filterMenuItemTextStyle,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'all',
                            child: Text(
                              'All time',
                              style: _filterMenuItemTextStyle,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                        onChanged: (v) {
                          if (v == null) return;
                          setState(() => _window = v);
                          _load();
                        },
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm2),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        isExpanded: true,
                        value: _mode,
                        decoration: _filterDecoration(context, 'Sort by'),
                        dropdownColor: Colors.white,
                        borderRadius:
                            BorderRadius.circular(AppRadii.sm),
                        style: _filterValueTextStyle,
                        iconEnabledColor: kPrimaryGreen,
                        items: [
                          DropdownMenuItem(
                            value: 'combined',
                            child: Text(
                              'Combined',
                              style: _filterMenuItemTextStyle,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'views',
                            child: Text(
                              'Views',
                              style: _filterMenuItemTextStyle,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'ratings',
                            child: Text(
                              'Ratings',
                              style: _filterMenuItemTextStyle,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                        onChanged: (v) {
                          if (v == null) return;
                          setState(() => _mode = v);
                          _load();
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: kPrimaryGreen),
                  )
                : _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _error!,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyLarge,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          FilledButton(
                            onPressed: _load,
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  )
                : _items.isEmpty
                ? Center(
                    child: Text(
                      'No ranking data yet.',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  )
                : Column(
                    children: [
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.md,
                            0,
                            AppSpacing.md,
                            AppSpacing.sm,
                          ),
                          itemCount: _items.take(_visibleCount).length,
                          itemBuilder: (context, i) =>
                              _buildRankingCard(context, i),
                        ),
                      ),
                      if (_visibleCount < _items.length)
                        Padding(
                          padding: const EdgeInsets.only(
                            bottom: AppSpacing.md,
                            top: AppSpacing.xs,
                          ),
                          child: OutlinedButton.icon(
                            onPressed: () => setState(() {
                              _visibleCount = (_visibleCount + _pageSize).clamp(
                                0,
                                _items.length,
                              );
                            }),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: kPrimaryGreen,
                              side: BorderSide(color: wellnestOutlineColor(context)),
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.lg,
                                vertical: AppSpacing.sm2,
                              ),
                            ),
                            icon: const Icon(Icons.expand_more_rounded),
                            label: const Text('Load more'),
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _ScoreBreakdownRow extends StatelessWidget {
  const _ScoreBreakdownRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.detail,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: iconColor, size: 22),
        const SizedBox(width: AppSpacing.sm2),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: cs.onSurface,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: kPrimaryGreen,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                detail,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
