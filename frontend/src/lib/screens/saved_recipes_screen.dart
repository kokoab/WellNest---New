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
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await SavedRecipeService.instance.fetchSavedRecipes();
      if (!mounted) return;
      setState(() {
        _recipes = data.recipes;
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
            padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
            child: const Text(
              'Saved Recipes',
              style: TextStyle(
                fontFamily: 'Recoleta',
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: wellGreen,
              ),
            ),
          ),
          Expanded(child: _buildContent()),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_loading && _recipes.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF097333)));
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
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 8),
        itemCount: _recipes.length,
        itemBuilder: (context, index) {
          final recipe = _recipes[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildRecipeCard(recipe),
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
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Color(0x14097333),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 90,
                height: 90,
                child: recipe.displayImageUrl != null && recipe.displayImageUrl!.isNotEmpty
                    ? Image.network(
                        recipe.displayImageUrl!,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Container(
                            color: AppColors.imagePlaceholderGreen,
                            child: Center(
                              child: CircularProgressIndicator(
                                color: wellGreen,
                                value: loadingProgress.expectedTotalBytes != null
                                    ? loadingProgress.cumulativeBytesLoaded /
                                        loadingProgress.expectedTotalBytes!
                                    : null,
                              ),
                            ),
                          );
                        },
                        errorBuilder: (_, __, ___) => Container(
                          color: AppColors.imagePlaceholderGreen,
                          child: Icon(Icons.restaurant_menu, size: 40, color: wellGreen),
                        ),
                      )
                    : Container(
                        color: AppColors.imagePlaceholderGreen,
                        child: Icon(Icons.restaurant_menu, size: 40, color: wellGreen),
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
                      style: const TextStyle(
                        fontFamily: 'Recoleta',
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: Color(0xFF097333),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'By ${recipe.userDisplayName}',
                      style: TextStyle(
                        fontFamily: 'HelveticaNow',
                        fontSize: 14,
                        color: Colors.grey.shade700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.star, size: 16, color: accentYellow),
                        const SizedBox(width: 4),
                        Text(
                          '${avg.toStringAsFixed(1)} ($count)',
                          style: TextStyle(
                            fontFamily: 'HelveticaNow',
                            fontSize: 13,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Icon(
              Icons.favorite,
              color: nestOrange,
              size: 24,
            ),
          ],
        ),
      ),
    );
  }
}
