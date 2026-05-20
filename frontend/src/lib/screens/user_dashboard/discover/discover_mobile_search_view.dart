import 'package:flutter/material.dart';
import 'package:wellnest/theme/app_spacing.dart';

import 'discover_recipe_search_field.dart';
import 'discover_search_discovery_panel.dart';
import 'popular_cuisine_item.dart';

/// Full-screen mobile search overlay on the Discover tab.
class DiscoverMobileSearchView extends StatelessWidget {
  const DiscoverMobileSearchView({
    super.key,
    required this.searchController,
    required this.searchFocusNode,
    required this.popularCuisines,
    required this.loadingPopularCuisines,
    required this.recentSearches,
    required this.onBack,
    required this.onSubmitted,
    required this.onDebouncedQueryChanged,
    required this.onClearNonSearchMode,
    required this.onCuisineTap,
    required this.onRecentSearchTap,
    required this.onClearRecentSearches,
  });

  final TextEditingController searchController;
  final FocusNode searchFocusNode;
  final List<PopularCuisineItem> popularCuisines;
  final bool loadingPopularCuisines;
  final List<String> recentSearches;
  final VoidCallback onBack;
  final ValueChanged<String> onSubmitted;
  final ValueChanged<String> onDebouncedQueryChanged;
  final VoidCallback onClearNonSearchMode;
  final ValueChanged<String> onCuisineTap;
  final ValueChanged<String> onRecentSearchTap;
  final VoidCallback onClearRecentSearches;

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.paddingOf(context).top + AppSpacing.sm;
    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.fromLTRB(
        AppSpacing.sm,
        topPad,
        AppSpacing.md,
        AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back_rounded),
                color: Theme.of(context).colorScheme.onSurface,
                tooltip: 'Back to dashboard',
              ),
              const SizedBox(width: 4),
              Expanded(
                child: DiscoverRecipeSearchField(
                  controller: searchController,
                  focusNode: searchFocusNode,
                  searchOnlyMode: true,
                  autofocus: true,
                  onSubmitted: onSubmitted,
                  onDebouncedQueryChanged: onDebouncedQueryChanged,
                  onClearNonSearchMode: onClearNonSearchMode,
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          DiscoverSearchDiscoveryPanel(
            popularCuisines: popularCuisines,
            loadingPopularCuisines: loadingPopularCuisines,
            recentSearches: recentSearches,
            onCuisineTap: onCuisineTap,
            onRecentSearchTap: onRecentSearchTap,
            onClearRecentSearches: onClearRecentSearches,
            boxed: false,
            horizontalInset: 8,
          ),
        ],
      ),
    );
  }
}
