import 'package:flutter/material.dart';
import 'package:my_app/models/recipe.dart';
import 'package:my_app/screens/recipe_detail_screen.dart';
import 'package:my_app/services/content_update_notifier.dart';
import 'package:my_app/services/saved_recipe_service.dart';
import 'package:my_app/services/search_history_service.dart';
import 'package:my_app/theme/app_spacing.dart';
import 'package:my_app/theme/app_theme.dart';
import 'package:my_app/widgets/animated_press_scale.dart';

/// Full-screen search for the current user's saved recipes only.
class SavedRecipesSearchScreen extends StatefulWidget {
  const SavedRecipesSearchScreen({super.key});

  @override
  State<SavedRecipesSearchScreen> createState() =>
      _SavedRecipesSearchScreenState();
}

class _SavedRecipesSearchScreenState extends State<SavedRecipesSearchScreen> {
  static const Color wellGreen = Color(0xFF097333);
  static const Color nestOrange = Color(0xFFEF5026);
  static const Color accentYellow = Color(0xFFFDB813);

  final TextEditingController _queryController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<Recipe> _popular = [];
  List<Recipe> _results = [];
  List<String> _recent = [];
  bool _loadingPopular = true;
  Object? _popularError;
  bool _loadingResults = false;
  bool _loadingMore = false;
  bool _resultsMode = false;
  String? _resultsQuery;
  int _resultsPage = 1;
  bool _hasMoreResults = false;

  @override
  void initState() {
    super.initState();
    ContentUpdateNotifier.instance.addListener(_onContentUpdate);
    _scrollController.addListener(_onScroll);
    _bootstrap();
  }

  void _onContentUpdate() {
    final update = ContentUpdateNotifier.instance.lastUpdate;
    if (!mounted ||
        update == null ||
        update.kind != ContentUpdateKind.recipe ||
        update.action != ContentUpdateAction.saveChanged) {
      return;
    }

    if (update.isActive) {
      _bootstrap();
      return;
    }

    setState(() {
      _popular.removeWhere((recipe) => recipe.id == update.id);
      _results.removeWhere((recipe) => recipe.id == update.id);
    });
  }

  Future<void> _bootstrap() async {
    await Future.wait([_loadRecent(), _loadPopular()]);
  }

  Future<void> _loadRecent() async {
    final r = await SearchHistoryService.instance
        .recent(SearchHistoryArea.savedRecipes);
    if (mounted) setState(() => _recent = r);
  }

  Future<void> _loadPopular() async {
    setState(() {
      _loadingPopular = true;
      _popularError = null;
    });
    try {
      final res = await SavedRecipeService.instance.fetchSavedRecipes(
        page: 1,
        perPage: 10,
        sort: 'popular',
      );
      if (!mounted) return;
      setState(() {
        _popular = res.recipes;
        _loadingPopular = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _popularError = e;
        _loadingPopular = false;
      });
    }
  }

  void _onScroll() {
    if (!_resultsMode || !_hasMoreResults || _loadingResults || _loadingMore) {
      return;
    }
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 280) {
      _loadMoreResults();
    }
  }

  Future<void> _runSearch(String raw) async {
    final q = raw.trim();
    if (q.isEmpty) return;
    await SearchHistoryService.instance.record(
      SearchHistoryArea.savedRecipes,
      q,
    );
    await _loadRecent();
    if (!mounted) return;
    setState(() {
      _resultsMode = true;
      _loadingResults = true;
      _results = [];
      _resultsQuery = q;
      _resultsPage = 1;
      _hasMoreResults = false;
    });
    try {
      final res = await SavedRecipeService.instance.fetchSavedRecipes(
        page: 1,
        perPage: 15,
        search: q,
      );
      if (!mounted) return;
      setState(() {
        _results = res.recipes;
        _loadingResults = false;
        _resultsPage = res.currentPage;
        _hasMoreResults = res.currentPage < res.lastPage;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingResults = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    }
  }

  Future<void> _loadMoreResults() async {
    final q = _resultsQuery;
    if (q == null || q.isEmpty || _loadingMore) return;
    setState(() => _loadingMore = true);
    try {
      final next = _resultsPage + 1;
      final res = await SavedRecipeService.instance.fetchSavedRecipes(
        page: next,
        perPage: 15,
        search: q,
      );
      if (!mounted) return;
      final existing = _results.map((r) => r.id).toSet();
      final incoming =
          res.recipes.where((r) => !existing.contains(r.id)).toList();
      setState(() {
        _results.addAll(incoming);
        _resultsPage = res.currentPage;
        _hasMoreResults = res.currentPage < res.lastPage;
        _loadingMore = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  void _clearSearch() {
    _queryController.clear();
    setState(() {
      _resultsMode = false;
      _results = [];
      _resultsQuery = null;
    });
  }

  Future<void> _openRecipe(Recipe recipe) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (context) => RecipeDetailScreen(recipeId: recipe.id),
      ),
    );
    if (mounted) _loadPopular();
  }

  @override
  void dispose() {
    ContentUpdateNotifier.instance.removeListener(_onContentUpdate);
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _queryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Search saved recipes',
          style: georgiaProTextStyle(
            fontSize: 18,
            color: AppColors.primaryGreen,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              AppSpacing.md,
            ),
            sliver: SliverToBoxAdapter(
              child: TextField(
                controller: _queryController,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Search titles, ingredients, categories…',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _queryController.text.isNotEmpty
                      ? IconButton(
                          tooltip: 'Clear',
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            setState(() {});
                            _clearSearch();
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  isDense: true,
                ),
                onChanged: (_) => setState(() {}),
                onSubmitted: _runSearch,
              ),
            ),
          ),
          if (!_resultsMode) ...[
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              sliver: SliverToBoxAdapter(
                child: Text(
                  'Popular in your saves',
                  style: wellnestPageTitleStyleFor(context).copyWith(
                    fontSize: 18,
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(child: _buildPopularSection(colorScheme)),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.sm,
              ),
              sliver: SliverToBoxAdapter(
                child: Text(
                  'Recent searches',
                  style: wellnestPageTitleStyleFor(context).copyWith(
                    fontSize: 18,
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              sliver: SliverToBoxAdapter(child: _buildRecentSection()),
            ),
          ] else ...[
            if (_loadingResults && _results.isEmpty)
              const SliverFillRemaining(
                child: Center(
                  child: CircularProgressIndicator(color: wellGreen),
                ),
              )
            else if (_results.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'No saved recipes match “${_resultsQuery ?? ''}”.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: colorScheme.onSurfaceVariant),
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      if (index >= _results.length) {
                        if (!_loadingMore) return const SizedBox.shrink();
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Center(
                            child: SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: wellGreen,
                              ),
                            ),
                          ),
                        );
                      }
                      final recipe = _results[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _SavedRecipeHitTile(
                          recipe: recipe,
                          wellGreen: wellGreen,
                          nestOrange: nestOrange,
                          accentYellow: accentYellow,
                          onTap: () => _openRecipe(recipe),
                        ),
                      );
                    },
                    childCount: _results.length + (_loadingMore ? 1 : 0),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildPopularSection(ColorScheme colorScheme) {
    if (_loadingPopular) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(child: CircularProgressIndicator(color: wellGreen)),
      );
    }
    if (_popularError != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          children: [
            Text(
              'Could not load recipes.',
              style: TextStyle(color: colorScheme.error),
            ),
            TextButton(onPressed: _loadPopular, child: const Text('Retry')),
          ],
        ),
      );
    }
    if (_popular.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Text(
          'Save recipes to see popular picks here.',
          style: TextStyle(color: colorScheme.onSurfaceVariant),
        ),
      );
    }
    return SizedBox(
      height: 172,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _popular.length,
        itemBuilder: (context, i) {
          final recipe = _popular[i];
          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: SizedBox(
              width: 200,
              child: Material(
                color: colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.35,
                ),
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => _openRecipe(recipe),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(12),
                        ),
                        child: SizedBox(
                          height: 96,
                          width: double.infinity,
                          child: recipe.displayImageUrl != null &&
                                  recipe.displayImageUrl!.isNotEmpty
                              ? Image.network(
                                  recipe.displayImageUrl!,
                                  fit: BoxFit.cover,
                                )
                              : Container(
                                  color: AppColors.imagePlaceholderGreen,
                                  child: Icon(
                                    Icons.restaurant_menu,
                                    color: wellGreen,
                                  ),
                                ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: Text(
                          recipe.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: georgiaProTextStyle(
                            fontSize: 14,
                            color: wellGreen,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildRecentSection() {
    if (_recent.isEmpty) {
      return Text(
        'Your recent searches will appear here.',
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _recent.map((q) {
        return ActionChip(
          label: Text(q),
          onPressed: () {
            _queryController.text = q;
            setState(() {});
            _runSearch(q);
          },
        );
      }).toList(),
    );
  }
}

class _SavedRecipeHitTile extends StatelessWidget {
  const _SavedRecipeHitTile({
    required this.recipe,
    required this.wellGreen,
    required this.nestOrange,
    required this.accentYellow,
    required this.onTap,
  });

  final Recipe recipe;
  final Color wellGreen;
  final Color nestOrange;
  final Color accentYellow;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final avg = recipe.averageRating ?? 0.0;
    final count = recipe.ratingsCount ?? 0;

    return AnimatedPressScale(
      onTap: onTap,
      semanticLabel: 'View recipe, ${recipe.title}',
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: wellnestCardDecoration(context),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 90,
                height: 90,
                child:
                    recipe.displayImageUrl != null &&
                        recipe.displayImageUrl!.isNotEmpty
                    ? Image.network(
                        recipe.displayImageUrl!,
                        fit: BoxFit.cover,
                        alignment: Alignment.center,
                        cacheWidth: 180,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Container(
                            color: AppColors.imagePlaceholderGreen,
                            child: Center(
                              child: CircularProgressIndicator(
                                color: wellGreen,
                                value:
                                    loadingProgress.expectedTotalBytes != null
                                    ? loadingProgress.cumulativeBytesLoaded /
                                          loadingProgress.expectedTotalBytes!
                                    : null,
                              ),
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: AppColors.imagePlaceholderGreen,
                          child: Icon(
                            Icons.restaurant_menu,
                            size: 40,
                            color: wellGreen,
                          ),
                        ),
                      )
                    : Container(
                        color: AppColors.imagePlaceholderGreen,
                        child: Icon(
                          Icons.restaurant_menu,
                          size: 40,
                          color: wellGreen,
                        ),
                      ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      recipe.title,
                      style: georgiaProTextStyle(
                        fontSize: 16,
                        color: wellGreen,
                      ).copyWith(letterSpacing: 0),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'By ${recipe.userDisplayName}',
                      style: TextStyle(
                        fontFamily: 'HelveticaNow',
                        fontSize: 12,
                        color: Colors.grey.shade700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.star, size: 14, color: accentYellow),
                        const SizedBox(width: 4),
                        Text(
                          '${avg.toStringAsFixed(1)} ($count)',
                          style: TextStyle(
                            fontFamily: 'HelveticaNow',
                            fontSize: 12,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Icon(Icons.favorite, color: nestOrange, size: 24),
          ],
        ),
      ),
    );
  }
}
