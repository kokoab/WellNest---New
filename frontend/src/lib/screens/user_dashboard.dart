import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:my_app/models/category.dart';
import 'package:my_app/models/recipe.dart';
import 'package:my_app/models/recipe_rating.dart';
import 'package:my_app/screens/custom_bottom_nav.dart';
import 'package:my_app/widgets/notifications_dropdown.dart';
import 'package:my_app/screens/profile_page.dart';
import 'package:my_app/screens/recipe_form_screen.dart';
import 'package:my_app/services/category_service.dart';
import 'package:my_app/services/recipe_service.dart';
import 'package:my_app/services/auth_service.dart';
import 'package:my_app/services/rating_service.dart';
import 'package:my_app/services/vote_service.dart';
import 'feed_page.dart';

class UserDashboard extends StatefulWidget {
  const UserDashboard({super.key});

  @override
  State<UserDashboard> createState() => _UserDashboardState();
}

class _UserDashboardState extends State<UserDashboard> {
  int _currentIndex = 0; 
  int _recipeGridKey = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      RecipeGridView(key: ValueKey(_recipeGridKey)), 
      const FeedPage(),
      const ProfilePage(),
    ];
    return Scaffold(
      backgroundColor: Colors.white,
      extendBody: true, // Allows the floating nav bar to look transparent at the edges
      body: IndexedStack(
        index: _currentIndex,
        children: pages,
      ),
      floatingActionButton: _currentIndex == 0
          ? FloatingActionButton(
              onPressed: () async {
                final result = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(builder: (context) => RecipeFormScreen()),
                );
                if (result == true && mounted) setState(() => _recipeGridKey++);
              },
              backgroundColor: const Color(0xFF097333),
              child: const Icon(Icons.add),
            )
          : null,
      bottomNavigationBar: CustomBottomNav(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index; // Swaps the visible page and updates the nav UI
          });
        },
      ),
    );
  }
}

// --- PART A: THE RECIPE GRID VIEW WITH EXPANSION ---
class RecipeGridView extends StatefulWidget {
  const RecipeGridView({super.key});

  @override
  State<RecipeGridView> createState() => _RecipeGridViewState();
}

class _RecipeGridViewState extends State<RecipeGridView> {
  static const Color wellGreen = Color(0xFF097333);
  static const Color nestOrange = Color(0xFFEF5026);
  static const Color accentYellow = Color(0xFFFDB813);

  List<Recipe> _recipes = [];
  List<Category> _categories = [];
  bool _loading = true;
  String? _error;
  int? _selectedCategoryId;
  int _expandedIndex = -1;
  Recipe? _expandedRecipe;
  RecipeRatingsResponse? _expandedRatings;
  RecipeRating? _expandedUserRating;
  bool _expandedLiked = false;
  bool _expandedLoading = false;
  int? _pendingStars;
  bool _submittingRating = false;
  final Map<int, TextEditingController> _reviewControllers = {};
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  Timer? _searchDebounce;

  TextEditingController _getReviewController(int recipeId) {
    _reviewControllers[recipeId] ??= TextEditingController();
    return _reviewControllers[recipeId]!;
  }

  @override
  void dispose() {
    for (final c in _reviewControllers.values) c.dispose();
    _searchController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

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
      final results = await Future.wait([
        CategoryService.instance.fetchCategories(admin: false),
        RecipeService.instance.fetchRecipes(
          categoryId: _selectedCategoryId,
          search: _searchQuery.isEmpty ? null : _searchQuery,
        ),
      ]);
      if (!mounted) return;
      setState(() {
        _categories = results[0] as List<Category>;
        final resp = results[1] as RecipeListResponse;
        _recipes = resp.recipes;
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

  Future<void> _loadRecipes() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      // Clear list so only search/filter results appear (no stale recipes)
      if (_searchQuery.isNotEmpty || _selectedCategoryId != null) {
        _recipes = [];
      }
    });
    try {
      final resp = await RecipeService.instance.fetchRecipes(
        categoryId: _selectedCategoryId,
        search: _searchQuery.isEmpty ? null : _searchQuery,
      );
      if (!mounted) return;
      setState(() {
        _recipes = resp.recipes;
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

  Widget _buildRecipeImagePlaceholder() {
    return Container(
      color: Colors.white24,
      child: Center(
        child: Icon(Icons.restaurant, size: 48, color: Colors.white.withOpacity(0.9)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Icon(Icons.menu, color: nestOrange, size: 35),
                Image.asset('lib/assets/images/logo1.png', height: 50),
                NotificationsDropdown(
                  iconColor: nestOrange,
                  child: const Icon(Icons.notifications, color: nestOrange, size: 35),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Search
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search recipes or ingredients...',
                prefixIcon: const Icon(Icons.search, color: wellGreen),
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
              onChanged: (value) {
                _searchDebounce?.cancel();
                _searchDebounce = Timer(const Duration(milliseconds: 400), () {
                  if (!mounted) return;
                  setState(() => _searchQuery = value.trim());
                  _loadRecipes();
                });
              },
            ),
            const SizedBox(height: 16),
            // Smart filters (dietary)
            if (_categories.isNotEmpty) ...[
              Text(
                'Dietary',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 8),
            ],
            if (_categories.isNotEmpty)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _FilterChip(
                      label: 'All',
                      selected: _selectedCategoryId == null,
                      onTap: () {
                        setState(() => _selectedCategoryId = null);
                        _loadRecipes();
                      },
                    ),
                    ..._categories.map((c) => _FilterChip(
                          label: c.name,
                          selected: _selectedCategoryId == c.id,
                          onTap: () {
                            setState(() => _selectedCategoryId = c.id);
                            _loadRecipes();
                          },
                        )),
                  ],
                ),
              ),
            if (_categories.isNotEmpty) const SizedBox(height: 15),
            const Text(
              'Discover',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: wellGreen),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: _buildContent(),
            ),
          ],
        ),
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
              Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: nestOrange)),
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
        child: Text(
          _searchQuery.isNotEmpty || _selectedCategoryId != null
              ? 'No recipes match your search or filter.'
              : 'No recipes yet. Add one to get started.',
          style: const TextStyle(color: Colors.grey),
          textAlign: TextAlign.center,
        ),
      );
    }
    final width = MediaQuery.of(context).size.width;
    final crossAxisCount = width > 900 ? 4 : (width > 600 ? 3 : 2);

    return RefreshIndicator(
      onRefresh: _load,
      color: wellGreen,
      child: MasonryGridView.count(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: 15,
        crossAxisSpacing: 15,
        itemCount: _recipes.length,
        itemBuilder: (context, index) {
          final recipe = _recipes[index];
          final isGreen = (index % 3 == 1) || (index == _recipes.length - 1 && _recipes.length % 2 == 1);
          return _buildRecipeCard(recipe, index, isGreen ? wellGreen : accentYellow);
        },
      ),
    );
  }

  Future<void> _onCardTap(Recipe recipe, int index) async {
    final isExpanded = _expandedIndex == index;
    if (isExpanded) {
      setState(() {
        _expandedIndex = -1;
        _expandedRecipe = null;
        _expandedRatings = null;
        _expandedUserRating = null;
        _pendingStars = null;
      });
      return;
    }
    setState(() {
      _expandedIndex = index;
      _expandedLoading = true;
      _expandedRecipe = null;
      _expandedRatings = null;
      _expandedUserRating = null;
    });
    try {
      final fullRecipe = await RecipeService.instance.fetchRecipe(recipe.id);
      RecipeRatingsResponse? ratings;
      RecipeRating? userRating;
      bool liked = false;
      try {
        ratings = await RatingService.instance.fetchRatings(recipe.id);
        if (AuthService.instance.isLoggedIn) {
          userRating = await RatingService.instance.fetchUserRating(recipe.id);
        }
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _expandedRecipe = fullRecipe;
        _expandedRatings = ratings;
        _expandedUserRating = userRating;
        _expandedLiked = liked;
        _expandedLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _expandedLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', '')), backgroundColor: nestOrange),
      );
    }
  }

  Widget _buildRecipeCard(Recipe recipe, int index, Color bgColor) {
    final isExpanded = _expandedIndex == index;
    final width = MediaQuery.of(context).size.width;
    final crossAxisCount = width > 900 ? 4 : (width > 600 ? 3 : 2);
    final cardWidth = (width - 40 - (crossAxisCount - 1) * 15) / crossAxisCount;
    final normalHeight = cardWidth * (index.isEven ? 1.0 : 1.3);
    const expandedHeight = 620.0;
    final ratingsCount = recipe.ratingsCount ?? 0;

    return GestureDetector(
      onTap: () => _onCardTap(recipe, index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
        height: isExpanded ? expandedHeight : normalHeight,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(25),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 4))],
        ),
        padding: const EdgeInsets.all(12),
        child: isExpanded
            ? _buildExpandedCard(recipe, bgColor)
            : _buildCollapsedCard(recipe, normalHeight, ratingsCount, bgColor),
      ),
    );
  }

  Widget _buildCollapsedCard(Recipe recipe, double normalHeight, int ratingsCount, Color bgColor) {
    return Column(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(15),
            child: recipe.displayImageUrl != null && recipe.displayImageUrl!.isNotEmpty
                ? Image.network(
                    recipe.displayImageUrl!,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        color: Colors.white24,
                        child: Center(
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded /
                                    loadingProgress.expectedTotalBytes!
                                : null,
                          ),
                        ),
                      );
                    },
                    errorBuilder: (_, __, ___) => _buildRecipeImagePlaceholder(),
                  )
                : _buildRecipeImagePlaceholder(),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          recipe.title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
        Text(
          'Prep: ${recipe.prepTime} mins | ${recipe.category?.name ?? ""}',
          style: const TextStyle(color: Colors.white70, fontSize: 11),
        ),
        if (ratingsCount > 0)
          Text(
            '$ratingsCount ${ratingsCount == 1 ? 'rating' : 'ratings'}',
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
      ],
    );
  }

  Widget _buildExpandedCard(Recipe recipe, Color bgColor) {
    final fullRecipe = _expandedRecipe ?? recipe;
    if (_expandedLoading) {
      return Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 140,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: fullRecipe.displayImageUrl != null && fullRecipe.displayImageUrl!.isNotEmpty
                  ? Image.network(
                      fullRecipe.displayImageUrl!,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      errorBuilder: (_, __, ___) => _buildRecipeImagePlaceholder(),
                    )
                  : _buildRecipeImagePlaceholder(),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            fullRecipe.title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            'Prep: ${fullRecipe.prepTime} mins | ${fullRecipe.category?.name ?? ""}',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          if (fullRecipe.user != null)
            Text(
              'By ${fullRecipe.userDisplayName}',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          if (AuthService.instance.isLoggedIn) _buildExpandedLikeButton(fullRecipe),
          const SizedBox(height: 12),
          _buildExpandedRatingSection(fullRecipe),
          const SizedBox(height: 12),
          _buildExpandedReviewsList(),
          const SizedBox(height: 12),
          _buildExpandedSectionTitle('Ingredients'),
          _buildExpandedIngredientsList(fullRecipe),
          const SizedBox(height: 12),
          _buildExpandedSectionTitle('Instructions'),
          _buildExpandedInstructions(fullRecipe),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildExpandedLikeButton(Recipe recipe) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () async {
              if (!AuthService.instance.isLoggedIn) return;
              try {
                if (_expandedLiked) {
                  await VoteService.instance.unlikeRecipe(recipe.id);
                  if (mounted) setState(() => _expandedLiked = false);
                } else {
                  await VoteService.instance.likeRecipe(recipe.id);
                  if (mounted) setState(() => _expandedLiked = true);
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
                  );
                }
              }
            },
            icon: Icon(
              _expandedLiked ? Icons.favorite : Icons.favorite_border,
              color: _expandedLiked ? Colors.pink : Colors.white,
              size: 24,
            ),
          ),
          Text(
            _expandedLiked ? 'Liked' : 'Like',
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildExpandedRatingSection(Recipe recipe) {
    final avg = _expandedRatings?.averageRating ?? recipe.averageRating ?? 0.0;
    final count = _expandedRatings?.ratingsCount ?? recipe.ratingsCount ?? 0;
    final hasUserRating = _expandedUserRating != null;
    final canRate = AuthService.instance.isLoggedIn && !hasUserRating;
    final ctrl = _getReviewController(recipe.id);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildStarDisplay(avg),
              const SizedBox(width: 8),
              Text(
                avg > 0 ? avg.toStringAsFixed(1) : '—',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: wellGreen),
              ),
              const SizedBox(width: 4),
              Text(
                '($count ${count == 1 ? 'rating' : 'ratings'})',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              ),
            ],
          ),
          if (canRate) ...[
            const SizedBox(height: 12),
            Row(
              children: List.generate(5, (i) {
                final star = i + 1;
                final selected = (_pendingStars ?? 0) >= star;
                return GestureDetector(
                  onTap: () => setState(() => _pendingStars = star),
                  child: Padding(
                    padding: const EdgeInsets.only(right: 2),
                    child: Icon(Icons.star, size: 28, color: selected ? accentYellow : Colors.grey.shade300),
                  ),
                );
              }),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: ctrl,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'Write a review (optional)...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _submittingRating || (_pendingStars ?? 0) < 1
                  ? null
                  : () async {
                      if (_pendingStars == null) return;
                      setState(() => _submittingRating = true);
                      try {
                        await RatingService.instance.submitRating(
                          recipeId: recipe.id,
                          rating: _pendingStars!,
                          comment: ctrl.text.trim().isEmpty ? null : ctrl.text.trim(),
                        );
                        if (!mounted) return;
                        ctrl.clear();
                        setState(() {
                          _submittingRating = false;
                          _pendingStars = null;
                        });
                        await _onCardTap(recipe, _expandedIndex);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Thanks for your rating!'), backgroundColor: wellGreen),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          setState(() => _submittingRating = false);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(e.toString().replaceFirst('Exception: ', '')), backgroundColor: nestOrange),
                          );
                        }
                      }
                    },
              style: FilledButton.styleFrom(backgroundColor: wellGreen),
              child: _submittingRating
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Submit rating'),
            ),
          ],
          if (hasUserRating)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'You rated ${_expandedUserRating!.rating}/5${_expandedUserRating!.comment != null && _expandedUserRating!.comment!.isNotEmpty ? ': "${_expandedUserRating!.comment}"' : ''}',
                style: TextStyle(color: Colors.grey.shade700, fontSize: 13, fontStyle: FontStyle.italic),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStarDisplay(double avg) {
    final full = avg.floor();
    final half = (avg - full) >= 0.5;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        IconData icon;
        Color color;
        if (i < full) {
          icon = Icons.star;
          color = accentYellow;
        } else if (i == full && half) {
          icon = Icons.star_half;
          color = accentYellow;
        } else {
          icon = Icons.star_border;
          color = Colors.grey.shade300;
        }
        return Icon(icon, size: 20, color: color);
      }),
    );
  }

  Widget _buildExpandedReviewsList() {
    final ratings = _expandedRatings?.ratings ?? [];
    if (ratings.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.95),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          'No reviews yet. Be the first to rate!',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
        ),
      );
    }
    return Container(
      constraints: const BoxConstraints(maxHeight: 120),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: ratings.length,
        itemBuilder: (context, i) {
          final r = ratings[i];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _buildStarDisplay(r.rating.toDouble()),
                    const SizedBox(width: 6),
                    Text(r.userDisplayName, style: const TextStyle(fontWeight: FontWeight.w600, color: wellGreen, fontSize: 12)),
                  ],
                ),
                if (r.comment != null && r.comment!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(r.comment!, style: TextStyle(fontSize: 12, color: Colors.grey.shade800), maxLines: 2, overflow: TextOverflow.ellipsis),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildExpandedSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        title,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white),
      ),
    );
  }

  Widget _buildExpandedIngredientsList(Recipe recipe) {
    final ingredients = recipe.ingredients;
    if (ingredients == null || ingredients.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.95), borderRadius: BorderRadius.circular(12)),
        child: Text('No ingredients listed.', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
      );
    }
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.95), borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: ingredients.map((ing) {
          final qty = ing.quantity.toInt() == ing.quantity ? ing.quantity.toInt().toString() : ing.quantity.toString();
          final amount = ing.unit.isEmpty ? qty : '$qty ${ing.unit}';
          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 5),
                  width: 5,
                  height: 5,
                  decoration: const BoxDecoration(color: wellGreen, shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade800),
                      children: [
                        if (amount.isNotEmpty) TextSpan(text: '$amount ', style: const TextStyle(fontWeight: FontWeight.w600, color: wellGreen)),
                        TextSpan(text: ing.name),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildExpandedInstructions(Recipe recipe) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.95), borderRadius: BorderRadius.circular(12)),
      child: Text(
        recipe.instructions,
        style: TextStyle(fontSize: 14, height: 1.5, color: Colors.grey.shade800),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({required this.label, required this.selected, required this.onTap});

  static const Color wellGreen = Color(0xFF097333);
  static const Color accentYellow = Color(0xFFFDB813);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        selectedColor: wellGreen.withOpacity(0.3),
        checkmarkColor: wellGreen,
      ),
    );
  }
}