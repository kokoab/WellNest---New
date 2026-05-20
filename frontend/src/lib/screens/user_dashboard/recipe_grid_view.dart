import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wellnest/models/category.dart';
import 'package:wellnest/models/recipe.dart';
import 'package:wellnest/models/recipe_ranking_item.dart';
import 'package:wellnest/screens/recipe_detail_screen.dart';
import 'package:wellnest/services/auth_service.dart';
import 'package:wellnest/services/category_service.dart';
import 'package:wellnest/services/content_update_notifier.dart';
import 'package:wellnest/services/recipe_service.dart';
import 'package:wellnest/services/saved_recipe_service.dart';
import 'package:wellnest/theme/app_spacing.dart';
import 'package:wellnest/theme/app_theme.dart';
import 'package:wellnest/widgets/wellnest_discover_hero.dart';

import 'discover/discover_colors.dart';
import 'discover/discover_filter_chip.dart';
import 'discover/discover_meal_planner_promo.dart';
import 'discover/discover_mobile_search_trigger.dart';
import 'discover/discover_mobile_search_view.dart';
import 'discover/discover_recipe_grid_slivers.dart';
import 'discover/discover_recipe_search_field.dart';
import 'discover/discover_search_discovery_panel.dart';
import 'discover/discover_top_ranked_section.dart';
import 'discover/popular_cuisine_item.dart';

/// Discover tab: search, rankings, category filters, and recipe grid.
class RecipeGridView extends StatefulWidget {
  const RecipeGridView({super.key});

  @override
  State<RecipeGridView> createState() => RecipeGridViewState();
}

class RecipeGridViewState extends State<RecipeGridView> {
  List<Recipe> _recipes = [];
  List<Category> _categories = [];
  bool _loading = true;
  String? _error;
  int? _selectedCategoryId;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _searchQuery = '';
  Timer? _searchDebounce;
  List<String> _recentSearches = [];
  bool _loadingPopularCuisines = false;
  List<PopularCuisineItem> _popularCuisines = [];
  bool _mobileSearchActive = false;
  int _loadRecipesGeneration = 0;
  int _recipesPage = 1;
  final int _recipesPerPage = 10;
  bool _recipesHasMore = true;
  bool _recipesLoadingMore = false;
  List<RecipeRankingItem> _topRanked = [];
  bool _loadingRanked = false;
  final Map<int, bool> _topRankedSaved = {};
  final Set<int> _topRankedSaving = <int>{};
  final Map<int, bool> _recipeSaved = {};
  final Set<int> _recipeSaving = <int>{};
  final PageController _topRankedPageController = PageController(
    viewportFraction: 0.88,
  );
  final ValueNotifier<int> _topRankedPage = ValueNotifier<int>(0);
  final ScrollController _scrollController = ScrollController();

  Future<void> _jumpTopRankedBy(int delta) async {
    if (_topRanked.length <= 1 || !_topRankedPageController.hasClients) return;
    final current = _topRankedPageController.page?.round() ?? 0;
    final last = _topRanked.length - 1;
    final nextPage = (current + delta).clamp(0, last);
    if (nextPage == current) return;
    await _topRankedPageController.animateToPage(
      nextPage,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
    _topRankedPage.value = nextPage;
  }

  @override
  void dispose() {
    ContentUpdateNotifier.instance.removeListener(_onContentUpdate);
    _searchController.dispose();
    _searchFocusNode.dispose();
    _searchDebounce?.cancel();
    _topRankedPageController.dispose();
    _topRankedPage.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    ContentUpdateNotifier.instance.addListener(_onContentUpdate);
    _load();
    _loadTopRanked();
    _loadPopularCuisines();
    _loadRecentSearches();
    _searchFocusNode.addListener(() {
      if (mounted) setState(() {});
    });
    _scrollController.addListener(_onScroll);
  }

  void _onContentUpdate() {
    final update = ContentUpdateNotifier.instance.lastUpdate;
    if (!mounted ||
        update == null ||
        update.kind != ContentUpdateKind.recipe) {
      return;
    }

    if (update.action == ContentUpdateAction.saveChanged) {
      if (_recipeSaving.contains(update.id)) return;
      setState(() {
        _recipeSaved[update.id] = update.isActive;
        _topRankedSaved[update.id] = update.isActive;
      });
    }
  }

  Future<void> _loadRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _recentSearches =
          prefs.getStringList('recent_recipe_searches') ?? <String>[];
    });
  }

  Future<void> _persistRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('recent_recipe_searches', _recentSearches);
  }

  Future<void> _addRecentSearch(String query) async {
    final normalized = query.trim();
    if (normalized.isEmpty) return;
    setState(() {
      _recentSearches = [
        normalized,
        ..._recentSearches.where(
          (item) => item.toLowerCase() != normalized.toLowerCase(),
        ),
      ].take(10).toList();
    });
    await _persistRecentSearches();
  }

  Future<void> _clearRecentSearches() async {
    setState(() => _recentSearches = []);
    await _persistRecentSearches();
  }

  Future<void> _applySearchQuery(String query, {bool keepFocus = false}) async {
    final normalized = query.trim();
    _searchDebounce?.cancel();
    _searchController.value = TextEditingValue(
      text: normalized,
      selection: TextSelection.collapsed(offset: normalized.length),
    );
    setState(() {
      _searchQuery = normalized;
      _mobileSearchActive = false;
    });
    if (normalized.isNotEmpty) {
      await _addRecentSearch(normalized);
    }
    await _loadRecipes();
    if (!keepFocus && mounted) {
      FocusScope.of(context).unfocus();
    }
  }

  void _closeMobileSearch() {
    _searchDebounce?.cancel();
    _searchController.value = TextEditingValue(
      text: _searchQuery,
      selection: TextSelection.collapsed(offset: _searchQuery.length),
    );
    FocusScope.of(context).unfocus();
    setState(() => _mobileSearchActive = false);
  }

  void _openMobileSearch() {
    _searchDebounce?.cancel();
    setState(() => _mobileSearchActive = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_mobileSearchActive) return;
      _searchFocusNode.requestFocus();
      Future<void>.delayed(const Duration(milliseconds: 80), () {
        if (mounted && _mobileSearchActive) {
          _searchFocusNode.requestFocus();
        }
      });
    });
  }

  void scrollToTop() {
    if (_mobileSearchActive) {
      _closeMobileSearch();
    }
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> reload() => _load();

  Future<void> refreshAfterRoutePop() async {
    await _load();
  }

  Future<void> _loadPopularCuisines() async {
    try {
      setState(() => _loadingPopularCuisines = true);
      final ranked = await RecipeService.instance.fetchRankings(
        window: '30d',
        mode: 'views',
      );
      final seen = <String>{};
      final cuisines = <PopularCuisineItem>[];
      for (final item in ranked) {
        final baseLabel = (item.category ?? '').trim().isNotEmpty
            ? item.category!.trim()
            : item.title.trim().split(' ').first;
        final label = baseLabel.isEmpty ? 'Popular' : baseLabel;
        final normalized = label.toLowerCase();
        if (seen.contains(normalized)) continue;
        seen.add(normalized);
        cuisines.add(
          PopularCuisineItem(
            label: label,
            imageUrl: item.displayImageUrl,
            searchTerm: label,
          ),
        );
        if (cuisines.length >= 8) break;
      }
      if (!mounted) return;
      setState(() {
        _popularCuisines = cuisines;
        _loadingPopularCuisines = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingPopularCuisines = false);
    }
  }

  void _onScroll() {
    if (!_recipesHasMore || _recipesLoadingMore || _loading) return;
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 300) {
      _loadMoreRecipes();
    }
  }

  Future<void> _loadTopRanked() async {
    try {
      setState(() => _loadingRanked = true);
      final all = await RecipeService.instance.fetchRankings(
        window: '7d',
        mode: 'combined',
      );
      final top = all.take(10).toList();
      final savedState = <int, bool>{};
      if (AuthService.instance.isLoggedIn) {
        final savedResults = await Future.wait(
          top.map((r) async {
            try {
              return MapEntry(
                r.id,
                await SavedRecipeService.instance.isSaved(r.id),
              );
            } catch (_) {
              return MapEntry(r.id, false);
            }
          }),
        );
        savedState.addEntries(savedResults);
      }
      if (!mounted) return;
      setState(() {
        _topRanked = top;
        _topRankedSaved
          ..clear()
          ..addAll(savedState);
        _recipeSaved.addAll(savedState);
        _topRankedPage.value = 0;
        _loadingRanked = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_topRankedPageController.hasClients || top.isEmpty) {
          return;
        }
        _topRankedPageController.jumpToPage(0);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingRanked = false);
    }
  }

  Future<void> _load() async {
    if (!mounted) return;
    _searchQuery = _searchController.text.trim();
    _loadRecipesGeneration++;
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
          page: 1,
        ),
      ]);
      if (!mounted) return;
      setState(() {
        _categories = results[0] as List<Category>;
        final resp = results[1] as RecipeListResponse;
        _recipes = resp.recipes;
        _recipesPage = resp.currentPage;
        _recipesHasMore = resp.recipes.length >= _recipesPerPage;
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
      if (_searchQuery.isNotEmpty || _selectedCategoryId != null) {
        _recipes = [];
      }
    });
    try {
      final resp = await RecipeService.instance.fetchRecipes(
        categoryId: categoryAtRequest,
        search: searchAtRequest.isEmpty ? null : searchAtRequest,
        page: 1,
      );
      if (!mounted) return;
      if (generation != _loadRecipesGeneration) return;
      setState(() {
        _recipes = resp.recipes;
        _recipesPage = resp.currentPage;
        _recipesHasMore = resp.recipes.length >= _recipesPerPage;
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

  Future<void> _loadMoreRecipes() async {
    if (!mounted || !_recipesHasMore || _recipesLoadingMore) return;
    final generation = ++_loadRecipesGeneration;
    setState(() => _recipesLoadingMore = true);
    try {
      final nextPage = _recipesPage + 1;
      final resp = await RecipeService.instance.fetchRecipes(
        categoryId: _selectedCategoryId,
        search: _searchQuery.isEmpty ? null : _searchQuery,
        page: nextPage,
      );
      if (!mounted) return;
      if (generation != _loadRecipesGeneration) return;
      setState(() {
        _recipes.addAll(resp.recipes);
        _recipesPage = resp.currentPage;
        if (resp.recipes.length < _recipesPerPage) _recipesHasMore = false;
        _recipesLoadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _recipesLoadingMore = false);
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

  void _onDebouncedSearchChanged(String trimmed) {
    setState(() => _searchQuery = trimmed);
    _loadRecipes();
  }

  void _onSearchClearNonSearchMode() {
    setState(() => _searchQuery = '');
    _loadRecipes();
  }

  Future<void> _toggleTopRankedSaved(RecipeRankingItem r) async {
    if (!AuthService.instance.isLoggedIn) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in to save recipes')),
      );
      return;
    }
    final currentlySaved = _topRankedSaved[r.id] ?? false;
    setState(() => _topRankedSaving.add(r.id));
    try {
      if (currentlySaved) {
        await SavedRecipeService.instance.unsaveRecipe(r.id);
      } else {
        await SavedRecipeService.instance.saveRecipe(r.id);
      }
      if (!mounted) return;
      setState(() {
        _topRankedSaved[r.id] = !currentlySaved;
        _recipeSaved[r.id] = !currentlySaved;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _topRankedSaving.remove(r.id));
    }
  }

  Future<void> _toggleRecipeSaved(Recipe recipe) async {
    if (!AuthService.instance.isLoggedIn) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in to save recipes')),
      );
      return;
    }
    if (_recipeSaving.contains(recipe.id)) return;

    setState(() => _recipeSaving.add(recipe.id));
    try {
      final currentlySaved =
          _recipeSaved[recipe.id] ??
          await SavedRecipeService.instance.isSaved(recipe.id);
      if (currentlySaved) {
        await SavedRecipeService.instance.unsaveRecipe(recipe.id);
      } else {
        await SavedRecipeService.instance.saveRecipe(recipe.id);
      }
      if (!mounted) return;
      setState(() => _recipeSaved[recipe.id] = !currentlySaved);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _recipeSaving.remove(recipe.id));
    }
  }

  Future<void> _openRecipeDetail(Recipe recipe) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => RecipeDetailScreen(recipeId: recipe.id),
      ),
    );
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final crossAxisCount = width > 900 ? 5 : (width > 600 ? 3 : 2);
    const padding = AppSpacing.md;
    const gap = 16.0;
    final mobileSearchActive = width <= 600 && _mobileSearchActive;

    return SafeArea(
      top: false,
      bottom: false,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 460),
        reverseDuration: const Duration(milliseconds: 380),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        layoutBuilder: (currentChild, previousChildren) {
          return Stack(
            alignment: Alignment.topCenter,
            children: [
              if (currentChild != null) currentChild,
              ...previousChildren,
            ],
          );
        },
        transitionBuilder: (child, animation) {
          final isSearchView =
              child.key == const ValueKey('mobile-search-view');
          final slideAnimation = Tween<Offset>(
            begin: isSearchView ? const Offset(0, 0.10) : Offset.zero,
            end: Offset.zero,
          ).animate(animation);
          final fadeAnimation = CurvedAnimation(
            parent: animation,
            curve: const Interval(0.15, 1, curve: Curves.easeOut),
          );

          return FadeTransition(
            opacity: fadeAnimation,
            child: SlideTransition(position: slideAnimation, child: child),
          );
        },
        child: mobileSearchActive
            ? KeyedSubtree(
                key: const ValueKey('mobile-search-view'),
                child: DiscoverMobileSearchView(
                  searchController: _searchController,
                  searchFocusNode: _searchFocusNode,
                  popularCuisines: _popularCuisines,
                  loadingPopularCuisines: _loadingPopularCuisines,
                  recentSearches: _recentSearches,
                  onBack: _closeMobileSearch,
                  onSubmitted: _applySearchQuery,
                  onDebouncedQueryChanged: (_) {},
                  onClearNonSearchMode: _onSearchClearNonSearchMode,
                  onCuisineTap: (term) => _applySearchQuery(term),
                  onRecentSearchTap: (q) => _applySearchQuery(q),
                  onClearRecentSearches: _clearRecentSearches,
                ),
              )
            : KeyedSubtree(
                key: const ValueKey('dashboard-view'),
                child: RefreshIndicator(
                  onRefresh: () async {
                    await Future.wait([_load(), _loadTopRanked()]);
                  },
                  color: DiscoverColors.wellGreen,
                  child: Stack(
                    children: [
                      CustomScrollView(
                        controller: _scrollController,
                        physics: const AlwaysScrollableScrollPhysics(),
                        slivers: [
                          SliverToBoxAdapter(
                            child: RepaintBoundary(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  WellnestDiscoverHero(
                                    searchSlot: width <= 600
                                        ? DiscoverMobileSearchTrigger(
                                            displayText:
                                                _searchController.text.trim(),
                                            onTap: _openMobileSearch,
                                          )
                                        : DiscoverRecipeSearchField(
                                            controller: _searchController,
                                            focusNode: _searchFocusNode,
                                            searchOnlyMode: false,
                                            onSubmitted: _applySearchQuery,
                                            onDebouncedQueryChanged:
                                                _onDebouncedSearchChanged,
                                            onClearNonSearchMode:
                                                _onSearchClearNonSearchMode,
                                          ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      AppSpacing.md,
                                      AppSpacing.xs,
                                      AppSpacing.md,
                                      0,
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        if (_searchFocusNode.hasFocus) ...[
                                          const SizedBox(
                                            height: AppSpacing.sm2,
                                          ),
                                          DiscoverSearchDiscoveryPanel(
                                            popularCuisines: _popularCuisines,
                                            loadingPopularCuisines:
                                                _loadingPopularCuisines,
                                            recentSearches: _recentSearches,
                                            onCuisineTap: (term) =>
                                                _applySearchQuery(term),
                                            onRecentSearchTap: (q) =>
                                                _applySearchQuery(q),
                                            onClearRecentSearches:
                                                _clearRecentSearches,
                                          ),
                                        ],
                                        const SizedBox(height: AppSpacing.xs),
                                        if (_categories.isNotEmpty) ...[
                                          SizedBox(
                                            height: 36,
                                            child: ListView(
                                              scrollDirection: Axis.horizontal,
                                              children: [
                                                DiscoverFilterChip(
                                                  label: 'All',
                                                  selected:
                                                      _selectedCategoryId ==
                                                      null,
                                                  onTap: () {
                                                    setState(() {
                                                      _selectedCategoryId =
                                                          null;
                                                      _searchQuery =
                                                          _searchController
                                                              .text
                                                              .trim();
                                                    });
                                                    _loadRecipes();
                                                  },
                                                ),
                                                ..._categories.map(
                                                  (c) => DiscoverFilterChip(
                                                    label: c.name,
                                                    selected:
                                                        _selectedCategoryId ==
                                                        c.id,
                                                    onTap: () {
                                                      setState(() {
                                                        _selectedCategoryId =
                                                            c.id;
                                                        _searchQuery =
                                                            _searchController
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
                                          if (_hasActiveFilters) ...[
                                            const SizedBox(height: 8),
                                            Align(
                                              alignment: Alignment.centerLeft,
                                              child: TextButton.icon(
                                                onPressed: _clearAllFilters,
                                                icon: const Icon(
                                                  Icons.filter_list_off,
                                                  size: 18,
                                                  color: DiscoverColors
                                                      .nestOrange,
                                                ),
                                                label: const Text(
                                                  'Clear filters',
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w600,
                                                    color: DiscoverColors
                                                        .nestOrange,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                          const SizedBox(height: 4),
                                        ],
                                        if (_searchController.text.isEmpty) ...[
                                          if (_categories.isNotEmpty)
                                            const SizedBox(height: 4),
                                          if (_selectedCategoryId == null) ...[
                                            DiscoverTopRankedSection(
                                              items: _topRanked,
                                              loading: _loadingRanked,
                                              pageController:
                                                  _topRankedPageController,
                                              pageListenable: _topRankedPage,
                                              savedByRecipeId: _topRankedSaved,
                                              savingRecipeIds: _topRankedSaving,
                                              onJumpBy: _jumpTopRankedBy,
                                              onPageChanged: (i) =>
                                                  _topRankedPage.value = i,
                                              onToggleSaved:
                                                  _toggleTopRankedSaved,
                                            ),
                                            const SizedBox(height: 16),
                                            const DiscoverMealPlannerPromo(),
                                            const SizedBox(height: 16),
                                          ],
                                          Text(
                                            'Discover',
                                            style:
                                                wellnestSectionTitleStyleFor(
                                              context,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                        ] else ...[
                                          const SizedBox(height: 16),
                                          Text(
                                            'Search Results',
                                            style:
                                                wellnestSectionTitleStyleFor(
                                              context,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          ...buildDiscoverRecipeGridSlivers(
                            context: context,
                            recipes: _recipes,
                            loading: _loading,
                            error: _error,
                            hasActiveFilters: _hasActiveFilters,
                            recipesLoadingMore: _recipesLoadingMore,
                            crossAxisCount: crossAxisCount,
                            padding: padding,
                            gap: gap,
                            onRetry: () async {
                              await Future.wait([_load(), _loadTopRanked()]);
                            },
                            onClearFilters: _clearAllFilters,
                            recipeCardBuilder: (recipe) => buildDiscoverRecipeCard(
                              context: context,
                              recipe: recipe,
                              isBookmarked: _recipeSaved[recipe.id] ?? false,
                              bookmarkSaving:
                                  _recipeSaving.contains(recipe.id),
                              canBookmark: AuthService.instance.isLoggedIn,
                              onBookmarkTap: () => _toggleRecipeSaved(recipe),
                              onOpenDetail: () => _openRecipeDetail(recipe),
                            ),
                          ),
                        ],
                      ),
                      if (_recipesLoadingMore)
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 14,
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.72),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'Loading more...',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}
