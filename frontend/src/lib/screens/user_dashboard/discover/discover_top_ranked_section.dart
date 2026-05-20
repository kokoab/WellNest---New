import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:wellnest/models/recipe_ranking_item.dart';
import 'package:wellnest/screens/recipe_detail_screen.dart';
import 'package:wellnest/screens/recipe_ranking_screen.dart';
import 'package:wellnest/services/auth_service.dart';
import 'package:wellnest/theme/app_spacing.dart';
import 'package:wellnest/theme/app_theme.dart';
import 'discover_colors.dart';
import 'discover_rank_badge.dart';

/// Top ranked recipes carousel on the Discover tab.
class DiscoverTopRankedSection extends StatelessWidget {
  const DiscoverTopRankedSection({
    super.key,
    required this.items,
    required this.loading,
    required this.pageController,
    required this.pageListenable,
    required this.savedByRecipeId,
    required this.savingRecipeIds,
    required this.onJumpBy,
    required this.onPageChanged,
    required this.onToggleSaved,
  });

  final List<RecipeRankingItem> items;
  final bool loading;
  final PageController pageController;
  final ValueListenable<int> pageListenable;
  final Map<int, bool> savedByRecipeId;
  final Set<int> savingRecipeIds;
  final ValueChanged<int> onJumpBy;
  final ValueChanged<int> onPageChanged;
  final Future<void> Function(RecipeRankingItem item) onToggleSaved;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Top Ranked Recipes',
                style: georgiaProTextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.w800,
                  color: DiscoverColors.wellGreen,
                ).copyWith(letterSpacing: 0),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  fullscreenDialog: true,
                  builder: (_) => const RecipeRankingScreen(),
                ),
              ),
              child: const Text('See all'),
            ),
          ],
        ),
        if (loading) ...[
          const SizedBox(height: 8),
          const LinearProgressIndicator(
            minHeight: 2,
            color: DiscoverColors.wellGreen,
          ),
        ] else if (items.isNotEmpty) ...[
          const SizedBox(height: 8),
          SizedBox(
            height: 264,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                PageView.builder(
                  controller: pageController,
                  padEnds: false,
                  itemCount: items.length,
                  onPageChanged: onPageChanged,
                  itemBuilder: (_, i) {
                    return _DiscoverTopRankedCarouselCard(
                      item: items[i],
                      rank: i + 1,
                      isSaved: savedByRecipeId[items[i].id] ?? false,
                      saving: savingRecipeIds.contains(items[i].id),
                      onToggleSaved: () => onToggleSaved(items[i]),
                    );
                  },
                ),
                if (items.length > 1)
                  Positioned.fill(
                    child: ValueListenableBuilder<int>(
                      valueListenable: pageListenable,
                      builder: (_, page, _) {
                        final last = items.length - 1;
                        return Stack(
                          clipBehavior: Clip.none,
                          children: [
                            if (page > 0)
                              Positioned(
                                left: 10,
                                top: 0,
                                bottom: 0,
                                child: Center(
                                  child: _CarouselArrow(
                                    icon: Icons.chevron_left_rounded,
                                    tooltip: 'Previous ranked recipe',
                                    onPressed: () => onJumpBy(-1),
                                  ),
                                ),
                              ),
                            if (page < last)
                              Positioned(
                                right: 10,
                                top: 0,
                                bottom: 0,
                                child: Center(
                                  child: _CarouselArrow(
                                    icon: Icons.chevron_right_rounded,
                                    tooltip: 'Next ranked recipe',
                                    onPressed: () => onJumpBy(1),
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          ValueListenableBuilder<int>(
            valueListenable: pageListenable,
            builder: (_, page, _) => Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(items.length, (i) {
                final active = i == page;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: active ? 18 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: active
                        ? DiscoverColors.wellGreen
                        : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(999),
                  ),
                );
              }),
            ),
          ),
        ] else ...[
          const SizedBox(height: 6),
          Text(
            'No ranked recipes in the last 7 days yet. View a recipe or add a rating — they will show up here.',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
          ),
        ],
      ],
    );
  }
}

class _CarouselArrow extends StatelessWidget {
  const _CarouselArrow({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.24),
        shape: BoxShape.circle,
      ),
      child: IconButton(
        onPressed: onPressed,
        tooltip: tooltip,
        icon: Icon(icon, color: Colors.white.withValues(alpha: 0.82), size: 20),
        splashRadius: 20,
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}

class _DiscoverTopRankedCarouselCard extends StatelessWidget {
  const _DiscoverTopRankedCarouselCard({
    required this.item,
    required this.rank,
    required this.isSaved,
    required this.saving,
    required this.onToggleSaved,
  });

  final RecipeRankingItem item;
  final int rank;
  final bool isSaved;
  final bool saving;
  final VoidCallback onToggleSaved;

  @override
  Widget build(BuildContext context) {
    final badge = discoverRankBadgeStyle(rank);
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.sm),
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            fullscreenDialog: true,
            builder: (_) => RecipeDetailScreen(recipeId: item.id),
          ),
        ),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            color: wellnestCardSurface(context),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: wellnestOutlineColor(context), width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(16),
                      ),
                      child: item.displayImageUrl != null
                          ? Image.network(
                              item.displayImageUrl!,
                              width: double.infinity,
                              height: double.infinity,
                              fit: BoxFit.cover,
                            )
                          : Container(
                              color: Theme.of(context).brightness ==
                                      Brightness.light
                                  ? const Color(0xFFE6F0EA)
                                  : Theme.of(context)
                                      .colorScheme
                                      .surfaceContainerHigh,
                              child: Center(
                                child: Icon(
                                  Icons.restaurant,
                                  size: 38,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ),
                    ),
                    Positioned(
                      top: 10,
                      left: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.35),
                            width: 0.5,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.star_rounded,
                              size: 15,
                              color: DiscoverColors.accentYellow,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              item.averageRating.toStringAsFixed(1),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                                height: 1,
                                letterSpacing: 0.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: IconButton.filledTonal(
                        onPressed: (!AuthService.instance.isLoggedIn || saving)
                            ? null
                            : onToggleSaved,
                        icon: saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Icon(
                                isSaved
                                    ? Icons.bookmark
                                    : Icons.bookmark_border,
                                color: isSaved
                                    ? DiscoverColors.nestOrange
                                    : DiscoverColors.wellGreen,
                              ),
                        tooltip: isSaved ? 'Remove favorite' : 'Save favorite',
                        style: IconButton.styleFrom(
                          backgroundColor: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest
                              .withValues(alpha: 0.94),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 3,
                            height: 44,
                            decoration: BoxDecoration(
                              color: badge.bgColor,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: georgiaProTextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface,
                                  ).copyWith(letterSpacing: 0.35),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'By ${item.authorName?.trim().isNotEmpty == true ? item.authorName!.trim() : 'WellNest Community'}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: wellnestCaptionColor(context),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.22,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.flatware_rounded,
                                      size: 13,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primary,
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        item.category?.trim().isNotEmpty == true
                                            ? item.category!
                                            : 'Uncategorized',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: wellnestCaptionColor(context),
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 0.2,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: badge.bgColor,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: Theme.of(context)
                                  .colorScheme
                                  .outline
                                  .withValues(alpha: 0.5),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                badge.icon,
                                size: 12,
                                color: badge.fgColor,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                badge.label,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: badge.fgColor,
                                  letterSpacing: 0.28,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.schedule_rounded,
                              size: 13,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${item.prepTime} min',
                              style: TextStyle(
                                color: wellnestCaptionColor(context),
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.18,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              Icons.visibility_outlined,
                              size: 13,
                              color: wellnestCaptionColor(context),
                            ),
                            const SizedBox(width: 2),
                            Text(
                              '${item.viewsCount}',
                              style: TextStyle(
                                color: wellnestCaptionColor(context),
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.18,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
