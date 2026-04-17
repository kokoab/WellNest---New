import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:my_app/theme/app_spacing.dart';
import 'package:my_app/theme/app_theme.dart';
import 'package:my_app/widgets/animated_press_scale.dart';
import 'package:my_app/models/category.dart';
import 'package:my_app/models/recipe.dart';
import 'package:my_app/models/recipe_ranking_item.dart';
import 'package:my_app/models/recipe_rating.dart';
import 'package:my_app/screens/custom_bottom_nav.dart';
import 'package:my_app/screens/profile_page.dart';
import 'package:my_app/screens/recipe_form_screen.dart';
import 'package:my_app/services/category_service.dart';
import 'package:my_app/services/recipe_service.dart';
import 'package:my_app/services/auth_service.dart';
import 'package:my_app/services/rating_service.dart';
import 'package:my_app/services/vote_service.dart';
import 'package:my_app/services/saved_recipe_service.dart';
import 'package:my_app/screens/saved_recipes_screen.dart';
import 'package:my_app/screens/recipe_detail_screen.dart';
import 'package:my_app/screens/conversation_chat_screen.dart';
import 'package:my_app/services/conversation_service.dart';
import 'package:my_app/widgets/wellnest_header.dart';
import 'package:my_app/widgets/weekly_meal_planner_strip.dart';
import 'package:my_app/widgets/skeleton_loaders.dart';
import 'feed_page.dart';
import 'recipe_ranking_screen.dart';

class UserDashboard extends StatefulWidget {
  const UserDashboard({super.key});

  @override
  State<UserDashboard> createState() => _UserDashboardState();
}

class _UserDashboardState extends State<UserDashboard> {
  int _currentIndex = 0;
  int _recipeGridKey = 0;
  int _feedRefreshKey = 0;
  int _savedRefreshKey = 0;
  final List<bool> _tabHasBeenBuilt = [false, false, false, false];

  @override
  Widget build(BuildContext context) {
    _tabHasBeenBuilt[_currentIndex] = true;
    final pages = [
      _tabHasBeenBuilt[0]
          ? RecipeGridView(key: ValueKey(_recipeGridKey))
          : const SizedBox.shrink(),
      _tabHasBeenBuilt[1]
          ? FeedPage(key: ValueKey('feed_$_feedRefreshKey'))
          : const SizedBox.shrink(),
      _tabHasBeenBuilt[2]
          ? SavedRecipesScreen(key: ValueKey('saved_$_savedRefreshKey'))
          : const SizedBox.shrink(),
      _tabHasBeenBuilt[3] ? const ProfilePage() : const SizedBox.shrink(),
    ];
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      extendBody:
          true, // Allows the floating nav bar to look transparent at the edges
      body: IndexedStack(index: _currentIndex, children: pages),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.small(
            heroTag: 'wellnest_assistant_fab',
            onPressed: () async {
              final svc = ConversationService();
              try {
                final conv = await svc.ensureAssistantConversation();
                if (!context.mounted) return;
                await Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (context) => ConversationChatScreen(
                      conversationId: conv.id,
                      otherUserName: conv.otherUser.name,
                      otherUserProfilePhotoUrl: conv.otherUser.displayProfilePhotoUrl,
                      isAssistant: true,
                    ),
                  ),
                );
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      e.toString().replaceFirst('Exception: ', ''),
                    ),
                  ),
                );
              }
            },
            backgroundColor: AppColors.primaryGreen,
            foregroundColor: Colors.white,
            child: const Icon(Icons.chat_bubble_outline),
          ),
          if (_currentIndex == 0) ...[
            const SizedBox(height: 12),
            FloatingActionButton(
              heroTag: 'recipe_add_fab',
              onPressed: () async {
                final result = await RecipeFormScreen.showAsModal(context);
                if (result == true && mounted) setState(() => _recipeGridKey++);
              },
              backgroundColor: AppColors.accentOrange,
              foregroundColor: Colors.white,
              shape: const CircleBorder(),
              child: const Icon(Icons.add),
            ),
          ],
        ],
      ),
      bottomNavigationBar: RepaintBoundary(
        child: CustomBottomNav(
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
              if (index == 1) _feedRefreshKey++;
              if (index == 2) _savedRefreshKey++;
            });
          },
        ),
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
  static const Color wellGreen = kPrimaryGreen;
  static const Color nestOrange = kAccentOrange;
  static const Color accentYellow = kAccentYellow;

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
  bool _expandedSaved = false;
  bool _expandedLoading = false;
  int? _pendingStars;
  bool _submittingRating = false;
  final Map<int, TextEditingController> _reviewControllers = {};
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  Timer? _searchDebounce;
  int _loadRecipesGeneration = 0;
  List<RecipeRankingItem> _topRanked = [];
  bool _loadingRanked = false;
  DateTime _plannerWeekStart = _startOfWeek(DateTime.now());
  late final PageController _carouselController;
  int _carouselPage = 0;
  Timer? _carouselAutoPlay;
  Set<int> _savedRecipeIds = {};

  TextEditingController _getReviewController(int recipeId) {
    _reviewControllers[recipeId] ??= TextEditingController();
    return _reviewControllers[recipeId]!;
  }

  @override
  void dispose() {
    for (final c in _reviewControllers.values) c.dispose();
    _searchController.dispose();
    _searchDebounce?.cancel();
    _carouselAutoPlay?.cancel();
    _carouselController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _carouselController = PageController(viewportFraction: 0.85);
    _load();
    _loadTopRanked();
    _loadSavedIds();
  }

  Future<void> _loadTopRanked() async {
    try {
      setState(() => _loadingRanked = true);
      final all = await RecipeService.instance.fetchRankings(
        window: '7d',
        mode: 'combined',
      );
      if (!mounted) return;
      setState(() {
        _topRanked = all.take(10).toList();
        _loadingRanked = false;
        _carouselPage = 0;
      });
      if (_carouselController.hasClients) {
        _carouselController.jumpToPage(0);
      }
      _startCarouselAutoPlay();
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingRanked = false);
    }
  }

  void _startCarouselAutoPlay() {
    _carouselAutoPlay?.cancel();
    if (_topRanked.length <= 1) return;
    _carouselAutoPlay = Timer.periodic(
      const Duration(seconds: 4),
      (_) {
        if (!mounted || !_carouselController.hasClients) return;
        try {
          final next = (_carouselPage + 1) % _topRanked.length;
          _carouselController.animateToPage(
            next,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOut,
          );
        } catch (_) {}
      },
    );
  }

  Future<void> _loadSavedIds() async {
    if (!AuthService.instance.isLoggedIn) return;
    try {
      final ids = await SavedRecipeService.instance.fetchAllSavedRecipeIds();
      if (!mounted) return;
      setState(() => _savedRecipeIds = ids);
    } catch (_) {}
  }

  Future<void> _load() async {
    if (!mounted) return;
    _searchQuery = _searchController.text
        .trim(); // Sync with text field (e.g. before debounce fired)
    _loadRecipesGeneration++; // Invalidate any in-flight _loadRecipes
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
    final generation = ++_loadRecipesGeneration;
    final searchAtRequest = _searchQuery;
    final categoryAtRequest = _selectedCategoryId;
    setState(() {
      _loading = true;
      // Clear list only when applying filters, so stale results don't flash
      if (_searchQuery.isNotEmpty || _selectedCategoryId != null) {
        _recipes = [];
      }
    });
    try {
      final resp = await RecipeService.instance.fetchRecipes(
        categoryId: categoryAtRequest,
        search: searchAtRequest.isEmpty ? null : searchAtRequest,
      );
      if (!mounted) return;
      // Ignore stale response: user may have typed/changed filter before this completed
      if (generation != _loadRecipesGeneration) return;
      setState(() {
        _recipes = resp.recipes;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      if (generation != _loadRecipesGeneration) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  bool get _hasActiveFilters =>
      _searchQuery.isNotEmpty || _selectedCategoryId != null;

  void _clearAllFilters() {
    _searchController.clear();
    setState(() {
      _searchQuery = '';
      _selectedCategoryId = null;
    });
    _loadRecipes();
  }

  Future<void> _toggleSaved(int recipeId) async {
    if (!AuthService.instance.isLoggedIn) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in to save recipes')),
      );
      return;
    }
    final wasSaved = _savedRecipeIds.contains(recipeId);
    setState(() {
      if (wasSaved) {
        _savedRecipeIds.remove(recipeId);
      } else {
        _savedRecipeIds.add(recipeId);
      }
    });
    try {
      if (wasSaved) {
        await SavedRecipeService.instance.unsaveRecipe(recipeId);
      } else {
        await SavedRecipeService.instance.saveRecipe(recipeId);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        if (wasSaved) {
          _savedRecipeIds.add(recipeId);
        } else {
          _savedRecipeIds.remove(recipeId);
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
        ),
      );
    }
  }

  Widget _buildRecipeImagePlaceholder(BuildContext context) {
    return Container(
      color: AppColors.imagePlaceholderGreen,
      child: Center(
        child: Icon(Icons.restaurant_menu, size: 48, color: kPrimaryGreen),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final crossAxisCount = width > 900 ? 5 : (width > 600 ? 3 : 2);
    const padding = AppSpacing.md;
    const gap = 16.0;

    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: () async {
          await Future.wait([_load(), _loadTopRanked(), _loadSavedIds()]);
        },
        color: colorScheme.primary,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: RepaintBoundary(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.sm,
                    AppSpacing.md,
                    0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const WellnestHeader(),
                      AppSpacing.gapV8,
                      TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search by name or ingredients...',
                          prefixIcon: Icon(
                            Icons.search,
                            color: colorScheme.primary,
                            size: 22,
                          ),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: Icon(
                                    Icons.clear,
                                    color: colorScheme.onSurfaceVariant,
                                    size: 20,
                                  ),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _searchQuery = '');
                                    _loadRecipes();
                                  },
                                )
                              : null,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                            vertical: AppSpacing.sm,
                          ),
                        ),
                        onChanged: (value) {
                          setState(() {});
                          _searchDebounce?.cancel();
                          _searchDebounce = Timer(
                            const Duration(milliseconds: 400),
                            () {
                              if (!mounted) return;
                              setState(() => _searchQuery = value.trim());
                              _loadRecipes();
                            },
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      if (_categories.isNotEmpty) ...[
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              'Category',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: SizedBox(
                                height: 36,
                                child: ListView(
                                  scrollDirection: Axis.horizontal,
                                  children: [
                                    _FilterChip(
                                      label: 'All',
                                      selected: _selectedCategoryId == null,
                                      onTap: () {
                                        setState(() {
                                          _selectedCategoryId = null;
                                          _searchQuery = _searchController.text
                                              .trim();
                                        });
                                        _loadRecipes();
                                      },
                                    ),
                                    ..._categories.map(
                                      (c) => _FilterChip(
                                        label: c.name,
                                        selected: _selectedCategoryId == c.id,
                                        onTap: () {
                                          setState(() {
                                            _selectedCategoryId = c.id;
                                            _searchQuery = _searchController
                                                .text
                                                .trim();
                                          });
                                          _loadRecipes();
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (_hasActiveFilters) ...[
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton.icon(
                              onPressed: _clearAllFilters,
                              icon: Icon(
                                Icons.filter_list_off,
                                size: 18,
                                color: nestOrange,
                              ),
                              label: Text(
                                'Clear filters',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: nestOrange,
                                ),
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
                      ],
                      if (_categories.isNotEmpty) const SizedBox(height: 10),
                      _buildTopRankedSection(),
                      const SizedBox(height: 16),
                      WeeklyMealPlannerStrip(
                        weekStart: _plannerWeekStart,
                        onWeekChanged: (nextWeekStart) {
                          setState(() => _plannerWeekStart = nextWeekStart);
                        },
                      ),
                      const SizedBox(height: 20),
                      Text('Discover', style: theme.textTheme.titleLarge),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            ),
            ..._buildDiscoverGridSlivers(
              crossAxisCount: crossAxisCount,
              padding: padding,
              gap: gap,
            ),
          ],
        ),
      ),
    );
  }

  static DateTime _startOfWeek(DateTime date) {
    final normalized = DateTime(date.year, date.month, date.day);
    return normalized.subtract(Duration(days: normalized.weekday - 1));
  }

  /// Grid / loading / error below the header; kept as slivers for one scroll + pull-to-refresh.
  List<Widget> _buildDiscoverGridSlivers({
    required int crossAxisCount,
    required double padding,
    required double gap,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    if (_loading && _recipes.isEmpty) {
      final skeletonAspects = [0.85, 1.05, 1.25, 1.0, 1.2, 0.85, 1.05, 1.25];
      return [
        SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: padding),
          sliver: SliverMasonryGrid.count(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: gap,
            crossAxisSpacing: gap,
            childCount: skeletonAspects.length,
            itemBuilder: (context, index) {
              return RecipeCardSkeleton(
                aspectRatio: skeletonAspects[index % skeletonAspects.length],
              );
            },
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ];
    }
    if (_error != null && _recipes.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
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
                  onPressed: () async {
                    await Future.wait([_load(), _loadTopRanked()]);
                  },
                  style: FilledButton.styleFrom(backgroundColor: wellGreen),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ];
    }
    if (_recipes.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _hasActiveFilters ? Icons.search_off : Icons.restaurant_menu,
                  size: 56,
                  color: colorScheme.onSurfaceVariant.withOpacity(0.6),
                ),
                const SizedBox(height: 16),
                Text(
                  _hasActiveFilters
                      ? 'No recipes match your filters'
                      : 'No recipes yet. Add one to get started.',
                  style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                if (_hasActiveFilters) ...[
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _clearAllFilters,
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Clear filters'),
                    style: FilledButton.styleFrom(
                      backgroundColor: wellGreen,
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
          childCount: _recipes.length,
          itemBuilder: (context, index) {
            final recipe = _recipes[index];
            return RepaintBoundary(child: _buildRecipeCard(recipe, index));
          },
        ),
      ),
      const SliverToBoxAdapter(child: SizedBox(height: 100)),
    ];
  }

  /// Shown for every user: header + "See all" always; carousel when data exists.
  Widget _buildTopRankedSection() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text('Top Ranked', style: theme.textTheme.titleLarge),
            ),
            IconButton(
              onPressed: _loadingRanked ? null : _loadTopRanked,
              icon: Icon(
                Icons.refresh_rounded,
                size: 20,
                color: _loadingRanked
                    ? colorScheme.outlineVariant
                    : colorScheme.onSurfaceVariant,
              ),
              tooltip: 'Refresh rankings',
              style: IconButton.styleFrom(
                padding: const EdgeInsets.all(8),
                minimumSize: const Size(36, 36),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
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
        if (_loadingRanked) ...[
          const SizedBox(height: 8),
          SizedBox(
            height: 200,
            child: PageView.builder(
              controller: PageController(viewportFraction: 0.85),
              itemCount: 3,
              itemBuilder: (_, __) => const Padding(
                padding: EdgeInsets.symmetric(horizontal: 6),
                child: CarouselSlideSkeleton(),
              ),
            ),
          ),
        ] else if (_topRanked.isNotEmpty) ...[
          const SizedBox(height: 8),
          SizedBox(
            height: 200,
            child: PageView.builder(
              controller: _carouselController,
              onPageChanged: (i) {
                setState(() => _carouselPage = i);
                _startCarouselAutoPlay();
              },
              itemCount: _topRanked.length,
              itemBuilder: (_, i) {
                final r = _topRanked[i];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: _buildCarouselSlide(r, i, isDark, colorScheme),
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_topRanked.length, (i) {
              final active = i == _carouselPage;
              return AnimatedContainer(
                duration: AppDurations.short,
                width: active ? 18 : 6,
                height: 6,
                margin: const EdgeInsets.symmetric(horizontal: 2.5),
                decoration: BoxDecoration(
                  color: active
                      ? colorScheme.primary
                      : colorScheme.outline.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(3),
                ),
              );
            }),
          ),
        ] else ...[
          const SizedBox(height: 6),
          Text(
            'No ranked recipes yet. View or rate a recipe and they will appear here.',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ],
    );
  }

  Widget _buildCarouselSlide(
    RecipeRankingItem r,
    int index,
    bool isDark,
    ColorScheme colorScheme,
  ) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => RecipeDetailScreen(recipeId: r.id),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadii.lg),
          color: Theme.of(context).cardColor,
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.35)
                  : Colors.black.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            r.displayImageUrl != null
                ? Image.network(
                    r.displayImageUrl!,
                    fit: BoxFit.cover,
                    cacheWidth: 600,
                    cacheHeight: 400,
                    errorBuilder: (_, __, ___) => Container(
                      color: isDark
                          ? colorScheme.surfaceContainerHighest
                          : AppColors.imagePlaceholderGreen,
                      child: Icon(
                        Icons.restaurant_menu,
                        size: 48,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  )
                : Container(
                    color: isDark
                        ? colorScheme.surfaceContainerHighest
                        : AppColors.imagePlaceholderGreen,
                    child: Icon(
                      Icons.restaurant_menu,
                      size: 48,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(14, 36, 14, 14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.75),
                    ],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.primary,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '#${index + 1}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      r.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.star_rounded, size: 16, color: kAccentYellow),
                        const SizedBox(width: 4),
                        Text(
                          r.averageRating.toStringAsFixed(1),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          ' (${r.ratingsCount})',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 12,
                          ),
                        ),
                        const Spacer(),
                        Icon(
                          Icons.visibility_outlined,
                          size: 14,
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                        const SizedBox(width: 3),
                        Text(
                          '${r.viewsCount}',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 12,
                          ),
                        ),
                      ],
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

  Future<void> _onCardTap(Recipe recipe, int index) async {
    final isExpanded = _expandedIndex == index;
    if (isExpanded) {
      setState(() {
        _expandedIndex = -1;
        _expandedRecipe = null;
        _expandedRatings = null;
        _expandedUserRating = null;
        _expandedSaved = false;
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
          _expandedSaved = await SavedRecipeService.instance.isSaved(recipe.id);
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
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: nestOrange,
        ),
      );
    }
  }

  Widget _buildRecipeCard(Recipe recipe, int index) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final width = MediaQuery.of(context).size.width;
    final crossAxisCount = width > 900 ? 5 : (width > 600 ? 3 : 2);
    const horizontalPadding = AppSpacing.md;
    const gap = 12.0;
    final cardWidth =
        (width - 2 * horizontalPadding - (crossAxisCount - 1) * gap) /
        crossAxisCount;
    final aspectRatios = [0.85, 1.05, 1.25, 1.0, 1.2];
    final aspect = aspectRatios[index % aspectRatios.length];

    return AnimatedPressScale(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            fullscreenDialog: true,
            builder: (context) => RecipeDetailScreen(recipeId: recipe.id),
          ),
        );
        if (mounted) {
          _load();
          _loadSavedIds();
        }
      },
      semanticLabel: 'View recipe, ${recipe.title}',
      child: Container(
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(AppRadii.lg),
          border: isDark
              ? Border.all(
                  color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                )
              : null,
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.3)
                  : Colors.black.withValues(alpha: 0.06),
              blurRadius: isDark ? 8 : 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: _buildCollapsedCard(recipe, cardWidth, aspect),
      ),
    );
  }

  Widget _buildCollapsedCard(
    Recipe recipe,
    double cardWidth,
    double aspect,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final avgRating = recipe.averageRating;
    final ratingsCount = recipe.ratingsCount ?? 0;
    final isSaved = _savedRecipeIds.contains(recipe.id);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(
          children: [
            AspectRatio(
              aspectRatio: 1 / aspect,
              child: recipe.displayImageUrl != null &&
                      recipe.displayImageUrl!.isNotEmpty
                  ? Image.network(
                      recipe.displayImageUrl!,
                      fit: BoxFit.cover,
                      alignment: Alignment.center,
                      cacheWidth: 600,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          color: AppColors.imagePlaceholderGreen,
                          child: Center(
                            child: CircularProgressIndicator(
                              color: colorScheme.primary,
                              strokeWidth: 2,
                              value:
                                  loadingProgress.expectedTotalBytes != null
                                      ? loadingProgress
                                              .cumulativeBytesLoaded /
                                          loadingProgress.expectedTotalBytes!
                                      : null,
                            ),
                          ),
                        );
                      },
                      errorBuilder: (_, __, ___) =>
                          _buildRecipeImagePlaceholder(context),
                    )
                  : _buildRecipeImagePlaceholder(context),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: Material(
                color: (isDark ? Colors.black : Colors.white).withValues(alpha: 0.7),
                shape: const CircleBorder(),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => _toggleSaved(recipe.id),
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Icon(
                      isSaved
                          ? Icons.bookmark_rounded
                          : Icons.bookmark_border_rounded,
                      size: 20,
                      color: isSaved
                          ? colorScheme.primary
                          : colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                recipe.title,
                style: TextStyle(
                  fontFamily: kFontAppFamily,
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              AppSpacing.gapV4,
              if (recipe.category != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    recipe.category!.name,
                    style: TextStyle(
                      color: colorScheme.primary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                AppSpacing.gapV4,
              ],
              Row(
                children: [
                  Icon(
                    Icons.schedule,
                    size: 12,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  AppSpacing.gapH4,
                  Text(
                    '${recipe.prepTime} min',
                    style: TextStyle(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                  const Spacer(),
                  Icon(Icons.star_rounded, size: 14, color: kAccentYellow),
                  const SizedBox(width: 3),
                  Text(
                    avgRating != null && avgRating > 0
                        ? avgRating.toStringAsFixed(1)
                        : 'New',
                    style: TextStyle(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (ratingsCount > 0)
                    Text(
                      ' ($ratingsCount)',
                      style: TextStyle(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ignore: unused_element - kept for potential future use
  Widget _buildExpandedCard(Recipe recipe, Color bgColor) {
    final fullRecipe = _expandedRecipe ?? recipe;
    if (_expandedLoading) {
      return Center(child: CircularProgressIndicator(color: wellGreen));
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 140,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child:
                  fullRecipe.displayImageUrl != null &&
                      fullRecipe.displayImageUrl!.isNotEmpty
                  ? Image.network(
                      fullRecipe.displayImageUrl!,
                      fit: BoxFit.cover,
                      alignment: Alignment.center,
                      width: double.infinity,
                      cacheWidth: 600,
                      cacheHeight: 280,
                      errorBuilder: (_, __, ___) =>
                          _buildRecipeImagePlaceholder(context),
                    )
                  : _buildRecipeImagePlaceholder(context),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            fullRecipe.title,
            style: TextStyle(
              color: Colors.grey.shade900,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            'Prep: ${fullRecipe.prepTime} mins | ${fullRecipe.category?.name ?? ""}',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
          ),
          if (fullRecipe.user != null)
            Text(
              'By ${fullRecipe.userDisplayName}',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
          if (AuthService.instance.isLoggedIn) ...[
            _ExpandedLikeButton(recipeId: fullRecipe.id, initialLiked: _expandedLiked),
            _ExpandedSaveButton(recipeId: fullRecipe.id, initialSaved: _expandedSaved),
          ],
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
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: wellGreen,
                ),
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
                    child: Icon(
                      Icons.star,
                      size: 28,
                      color: selected ? accentYellow : Colors.grey.shade300,
                    ),
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
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
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
                          comment: ctrl.text.trim().isEmpty
                              ? null
                              : ctrl.text.trim(),
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
                            const SnackBar(
                              content: Text('Thanks for your rating!'),
                              backgroundColor: wellGreen,
                            ),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          setState(() => _submittingRating = false);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                e.toString().replaceFirst('Exception: ', ''),
                              ),
                              backgroundColor: nestOrange,
                            ),
                          );
                        }
                      }
                    },
              style: FilledButton.styleFrom(backgroundColor: wellGreen),
              child: _submittingRating
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Submit rating'),
            ),
          ],
          if (hasUserRating)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'You rated ${_expandedUserRating!.rating}/5${_expandedUserRating!.comment != null && _expandedUserRating!.comment!.isNotEmpty ? ': "${_expandedUserRating!.comment}"' : ''}',
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                ),
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
                    Text(
                      r.userDisplayName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: wellGreen,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                if (r.comment != null && r.comment!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      r.comment!,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade800,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
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
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: wellGreen,
        ),
      ),
    );
  }

  Widget _buildExpandedIngredientsList(Recipe recipe) {
    final ingredients = recipe.ingredients;
    if (ingredients == null || ingredients.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.95),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          'No ingredients listed.',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: ingredients.map((ing) {
          final qty = ing.quantity.toInt() == ing.quantity
              ? ing.quantity.toInt().toString()
              : ing.quantity.toString();
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
                  decoration: const BoxDecoration(
                    color: wellGreen,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade800,
                      ),
                      children: [
                        if (amount.isNotEmpty)
                          TextSpan(
                            text: '$amount ',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: wellGreen,
                            ),
                          ),
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
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        recipe.instructions,
        style: TextStyle(
          fontSize: 14,
          height: 1.5,
          color: Colors.grey.shade800,
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: AppDurations.short,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? colorScheme.primary
                : colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: selected
                  ? colorScheme.onPrimary
                  : colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

/// Self-contained like button for the expanded recipe card.
/// Owns its own toggle state so a like/unlike does not rebuild the entire grid.
class _ExpandedLikeButton extends StatefulWidget {
  final int recipeId;
  final bool initialLiked;

  const _ExpandedLikeButton({
    required this.recipeId,
    this.initialLiked = false,
  });

  @override
  State<_ExpandedLikeButton> createState() => _ExpandedLikeButtonState();
}

class _ExpandedLikeButtonState extends State<_ExpandedLikeButton> {
  late bool _liked;

  @override
  void initState() {
    super.initState();
    _liked = widget.initialLiked;
  }

  @override
  void didUpdateWidget(covariant _ExpandedLikeButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.recipeId != widget.recipeId) {
      _liked = widget.initialLiked;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () async {
              if (!AuthService.instance.isLoggedIn) return;
              try {
                if (_liked) {
                  await VoteService.instance.unlikeRecipe(widget.recipeId);
                  if (mounted) setState(() => _liked = false);
                } else {
                  await VoteService.instance.likeRecipe(widget.recipeId);
                  if (mounted) setState(() => _liked = true);
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        e.toString().replaceFirst('Exception: ', ''),
                      ),
                    ),
                  );
                }
              }
            },
            icon: Icon(
              _liked ? Icons.favorite : Icons.favorite_border,
              color: _liked
                  ? Theme.of(context).colorScheme.secondary
                  : Theme.of(context).colorScheme.onSurfaceVariant,
              size: 24,
            ),
          ),
          Text(
            _liked ? 'Liked' : 'Like',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

/// Self-contained save button for the expanded recipe card.
class _ExpandedSaveButton extends StatefulWidget {
  final int recipeId;
  final bool initialSaved;

  const _ExpandedSaveButton({
    required this.recipeId,
    this.initialSaved = false,
  });

  @override
  State<_ExpandedSaveButton> createState() => _ExpandedSaveButtonState();
}

class _ExpandedSaveButtonState extends State<_ExpandedSaveButton> {
  late bool _saved;

  @override
  void initState() {
    super.initState();
    _saved = widget.initialSaved;
  }

  @override
  void didUpdateWidget(covariant _ExpandedSaveButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.recipeId != widget.recipeId) {
      _saved = widget.initialSaved;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          IconButton(
            onPressed: () async {
              if (!AuthService.instance.isLoggedIn) return;
              try {
                if (_saved) {
                  await SavedRecipeService.instance.unsaveRecipe(widget.recipeId);
                  if (mounted) setState(() => _saved = false);
                } else {
                  await SavedRecipeService.instance.saveRecipe(widget.recipeId);
                  if (mounted) setState(() => _saved = true);
                }
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        _saved ? 'Saved to favorites' : 'Removed from favorites',
                      ),
                      backgroundColor: Theme.of(context).colorScheme.primary,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        e.toString().replaceFirst('Exception: ', ''),
                      ),
                    ),
                  );
                }
              }
            },
            icon: Icon(
              _saved ? Icons.bookmark : Icons.bookmark_border,
              color: _saved
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.onSurfaceVariant,
              size: 24,
            ),
          ),
          Text(
            _saved ? 'Saved' : 'Save',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
