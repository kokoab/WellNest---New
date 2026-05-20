import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:wellnest/models/recipe.dart';
import 'package:wellnest/widgets/animated_press_scale.dart';
import 'package:wellnest/widgets/wellnest_recipe_card.dart';

import 'discover_colors.dart';

/// Masonry grid + loading/error/empty states for the Discover recipe list.
List<Widget> buildDiscoverRecipeGridSlivers({
  required BuildContext context,
  required List<Recipe> recipes,
  required bool loading,
  required String? error,
  required bool hasActiveFilters,
  required bool recipesLoadingMore,
  required int crossAxisCount,
  required double padding,
  required double gap,
  required Future<void> Function() onRetry,
  required VoidCallback onClearFilters,
  required Widget Function(Recipe recipe) recipeCardBuilder,
}) {
  if (loading && recipes.isEmpty) {
    return [
      const SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: CircularProgressIndicator(color: DiscoverColors.wellGreen),
        ),
      ),
      const SliverToBoxAdapter(child: SizedBox(height: 100)),
    ];
  }
  if (error != null && recipes.isEmpty) {
    return [
      SliverFillRemaining(
        hasScrollBody: false,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                error,
                textAlign: TextAlign.center,
                style: const TextStyle(color: DiscoverColors.nestOrange),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: onRetry,
                style: FilledButton.styleFrom(
                  backgroundColor: DiscoverColors.wellGreen,
                ),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
      const SliverToBoxAdapter(child: SizedBox(height: 100)),
    ];
  }
  if (recipes.isEmpty) {
    return [
      SliverFillRemaining(
        hasScrollBody: false,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                hasActiveFilters ? Icons.search_off : Icons.restaurant_menu,
                size: 56,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 16),
              Text(
                hasActiveFilters
                    ? 'No recipes match your filters'
                    : 'No recipes yet. Add one to get started.',
                style: TextStyle(color: Colors.grey.shade700, fontSize: 16),
                textAlign: TextAlign.center,
              ),
              if (hasActiveFilters) ...[
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: onClearFilters,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Clear filters'),
                  style: FilledButton.styleFrom(
                    backgroundColor: DiscoverColors.wellGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      const SliverToBoxAdapter(child: SizedBox(height: 100)),
    ];
  }

  return [
    SliverPadding(
      padding: EdgeInsets.symmetric(horizontal: padding),
      sliver: SliverMasonryGrid.count(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: gap,
        crossAxisSpacing: gap,
        childCount: recipes.length,
        itemBuilder: (context, index) {
          return RepaintBoundary(
            child: recipeCardBuilder(recipes[index]),
          );
        },
      ),
    ),
    SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: recipesLoadingMore
              ? const SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: DiscoverColors.wellGreen,
                  ),
                )
              : const SizedBox(height: 100),
        ),
      ),
    ),
  ];
}

/// Default Discover grid card: opens recipe detail and supports bookmark.
Widget buildDiscoverRecipeCard({
  required BuildContext context,
  required Recipe recipe,
  required bool isBookmarked,
  required bool bookmarkSaving,
  required bool canBookmark,
  required VoidCallback onBookmarkTap,
  required Future<void> Function() onOpenDetail,
}) {
  const gridCardAspectRatio = 0.7;
  return AnimatedPressScale(
    onTap: onOpenDetail,
    semanticLabel: 'View recipe, ${recipe.title}',
    child: WellnestRecipeCard(
      recipe: recipe,
      heroTag: 'recipe_${recipe.id}_image',
      aspectRatio: gridCardAspectRatio,
      bookmarkSaving: bookmarkSaving,
      isBookmarked: isBookmarked,
      onBookmarkTap: canBookmark ? onBookmarkTap : null,
    ),
  );
}
