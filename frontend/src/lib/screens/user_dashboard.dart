import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:my_app/models/category.dart';
import 'package:my_app/models/recipe.dart';
import 'package:my_app/screens/custom_bottom_nav.dart';
import 'package:my_app/screens/profile_page.dart';
import 'package:my_app/screens/recipe_detail_screen.dart';
import 'package:my_app/screens/recipe_form_screen.dart';
import 'package:my_app/services/category_service.dart';
import 'package:my_app/services/recipe_service.dart';
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
  final Map<int, int> _recipeRatings = {};
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  Timer? _searchDebounce;

  @override
  void dispose() {
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

  int _ratingFor(int index) => _recipeRatings[_recipes[index].id] ?? 0;

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
                const Icon(Icons.notifications, color: nestOrange, size: 35),
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
    return RefreshIndicator(
      onRefresh: _load,
      color: wellGreen,
      child: MasonryGridView.count(
        crossAxisCount: 2,
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

  Widget _buildRecipeCard(Recipe recipe, int index, Color bgColor) {
    final isExpanded = _expandedIndex == index;
    final normalHeight = index.isEven ? 200.0 : 260.0;
    const expandedHeight = 380.0;
    final rating = _ratingFor(index);

    return GestureDetector(
      onTap: () {
        setState(() => _expandedIndex = isExpanded ? -1 : index);
      },
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
        child: Column(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: Container(
                  color: Colors.white24,
                  child: Center(
                    child: Icon(Icons.restaurant, size: 48, color: Colors.white.withOpacity(0.9)),
                  ),
                ),
              ),
            ),
            if (isExpanded) ...[
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => RecipeDetailScreen(recipeId: recipe.id),
                    ),
                  ).then((_) => setState(() {}));
                },
                child: Text(
                  recipe.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                'Prep: ${recipe.prepTime} mins | ${recipe.category?.name ?? ""}',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
              const SizedBox(height: 10),
            ],
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (starIndex) {
                return GestureDetector(
                  onTap: () {
                    setState(() => _recipeRatings[recipe.id] = starIndex + 1);
                  },
                  child: Icon(
                    Icons.star,
                    size: 18,
                    color: starIndex < rating ? Colors.yellowAccent : Colors.white70,
                  ),
                );
              }),
            ),
          ],
        ),
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