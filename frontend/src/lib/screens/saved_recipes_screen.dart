import 'package:flutter/material.dart';
import 'package:my_app/theme/app_spacing.dart';
import 'package:my_app/theme/app_theme.dart';
import 'package:my_app/widgets/animated_press_scale.dart';
import 'package:my_app/models/recipe.dart';
import 'package:my_app/screens/recipe_detail_screen.dart';
import 'package:my_app/widgets/wellnest_header.dart';
import 'package:my_app/services/saved_recipe_service.dart';

class SavedRecipesScreen extends StatefulWidget {
  const SavedRecipesScreen({super.key});

  @override
  State<SavedRecipesScreen> createState() => _SavedRecipesScreenState();
}

class _SavedRecipesScreenState extends State<SavedRecipesScreen> {
  static const Color wellGreen = Color(0xFF097333);
  static const Color nestOrange = Color(0xFFEF5026);
  static const Color accentYellow = Color(0xFFFDB813);

  List<Recipe> _recipes = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  int _page = 1;
  String? _error;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _load();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_loading || _loadingMore || !_hasMore) return;
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 220) {
      _loadMore();
    }
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
      _page = 1;
      _hasMore = true;
    });
    try {
      final data = await SavedRecipeService.instance.fetchSavedRecipes(page: 1);
      if (!mounted) return;
      setState(() {
        _recipes = data.recipes;
        _page = data.currentPage;
        _hasMore = data.currentPage < data.lastPage;
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

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    try {
      final nextPage = _page + 1;
      final data = await SavedRecipeService.instance.fetchSavedRecipes(
        page: nextPage,
      );
      if (!mounted) return;
      final existing = _recipes.map((r) => r.id).toSet();
      final incoming = data.recipes
          .where((r) => !existing.contains(r.id))
          .toList();
      setState(() {
        _recipes.addAll(incoming);
        _page = data.currentPage;
        _hasMore = data.currentPage < data.lastPage;
        _loadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 10),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: WellnestHeader(),
          ),
          AppSpacing.gapV16,
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              0,
              AppSpacing.md,
              AppSpacing.md,
            ),
            child: Text(
              'Saved Recipes',
              style: wellnestPageTitleStyle(color: wellGreen),
            ),
          ),
          Expanded(child: _buildContent()),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_loading && _recipes.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF097333)),
      );
    }
    if (_error != null && _recipes.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: nestOrange),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _load,
                style: FilledButton.styleFrom(backgroundColor: wellGreen),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }
    if (_recipes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bookmark_border, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'No saved recipes yet.\nSave recipes you like to find them here.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      color: wellGreen,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: 8,
        ),
        itemCount: _recipes.length + (_loadingMore ? 1 : 0),
        addRepaintBoundaries: true,
        itemBuilder: (context, index) {
          if (_loadingMore && index == _recipes.length) {
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
          final recipe = _recipes[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: RepaintBoundary(child: _buildRecipeCard(recipe)),
          );
        },
      ),
    );
  }

  Widget _buildRecipeCard(Recipe recipe) {
    final avg = recipe.averageRating ?? 0.0;
    final count = recipe.ratingsCount ?? 0;

    return AnimatedPressScale(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            fullscreenDialog: true,
            builder: (context) => RecipeDetailScreen(recipeId: recipe.id),
          ),
        );
        if (mounted) _load();
      },
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
                        color: const Color(0xFF097333),
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
