import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:my_app/theme/app_spacing.dart';
import 'package:my_app/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
import 'package:my_app/screens/create_post_screen.dart';
import 'package:my_app/services/conversation_service.dart';
import 'package:my_app/widgets/wellnest_discover_hero.dart';
import 'package:my_app/widgets/wellnest_recipe_card.dart';
import 'package:my_app/widgets/weekly_meal_planner_strip.dart';
import 'feed_page.dart';
import 'recipe_ranking_screen.dart';

class UserDashboard extends StatefulWidget {
  const UserDashboard({super.key});

  @override
  State<UserDashboard> createState() => _UserDashboardState();
}

class _UserDashboardState extends State<UserDashboard> {
  static const Color wellGreen = Color(0xFF097333);

  int _currentIndex = 0;
  int _feedRefreshKey = 0;
  int _savedRefreshKey = 0;
  final GlobalKey<_RecipeGridViewState> _recipeGridViewKey =
      GlobalKey<_RecipeGridViewState>();
  final List<bool> _tabHasBeenBuilt = [false, false, false, false];

  @override
  Widget build(BuildContext context) {
    _tabHasBeenBuilt[_currentIndex] = true;
    final pages = [
      _tabHasBeenBuilt[0]
          ? RecipeGridView(key: _recipeGridViewKey)
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
      extendBody: true,
      floatingActionButton: CustomBottomNav.fab(onPressed: _showQuickActionsSheet),
      floatingActionButtonLocation: CustomBottomNav.fabLocation,
      body: MediaQuery.removePadding(
        context: context,
        removeBottom: true,
        child: IndexedStack(index: _currentIndex, children: pages),
      ),
      bottomNavigationBar: MediaQuery.removePadding(
        context: context,
        removeBottom: true,
        child: RepaintBoundary(
          child: CustomBottomNav(
            currentIndex: _currentIndex,
            onTap: (index) {
              if (index == _currentIndex && index == 0) {
                _recipeGridViewKey.currentState?.scrollToTop();
                return;
              }
              setState(() {
                _currentIndex = index;
                if (index == 1) _feedRefreshKey++;
                if (index == 2) _savedRefreshKey++;
              });
            },
          ),
        ),
      ),
    );
  }

  Future<void> _showQuickActionsSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: const Color(0xFFE8E8E8),
                width: 1,
              ),
            ),
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
            child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _QuickActionTile(
                      icon: Icons.post_add_rounded,
                      label: 'Create new post',
                      onTap: () async {
                        Navigator.pop(sheetContext);
                        if (!mounted) return;
                        final created = await Navigator.of(context).push<bool>(
                          MaterialPageRoute(
                            builder: (_) => const CreatePostScreen(),
                          ),
                        );
                        if (created == true && mounted) {
                          setState(() {
                            _currentIndex = 1;
                            _feedRefreshKey++;
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Post created!'),
                              backgroundColor: wellGreen,
                            ),
                          );
                        }
                      },
                    ),
                    Divider(
                      height: 1,
                      thickness: 0.7,
                      color: const Color(0xFFE8E8E8),
                      indent: 16,
                      endIndent: 16,
                    ),
                    _QuickActionTile(
                      icon: Icons.restaurant_menu_rounded,
                      label: 'Create new recipe',
                      onTap: () async {
                        Navigator.pop(sheetContext);
                        if (!mounted) return;
                        final result =
                            await RecipeFormScreen.showAsModal(context);
                        if (result == true && mounted) {
                          setState(() => _currentIndex = 0);
                          await _recipeGridViewKey.currentState?._load();
                        }
                      },
                    ),
                    Divider(
                      height: 1,
                      thickness: 0.7,
                      color: const Color(0xFFE8E8E8),
                      indent: 16,
                      endIndent: 16,
                    ),
                    _QuickActionTile(
                      icon: Icons.auto_awesome_rounded,
                      label: 'Chat with WellNest AI',
                      onTap: () async {
                        Navigator.pop(sheetContext);
                        if (!mounted) return;
                        final svc = ConversationService();
                        try {
                          final conv = await svc.ensureAssistantConversation();
                          if (!mounted) return;
                          await Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (context) => ConversationChatScreen(
                                conversationId: conv.id,
                                otherUserName: conv.otherUser.name,
                                otherUserProfilePhotoUrl:
                                    conv.otherUser.displayProfilePhotoUrl,
                                isAssistant: true,
                              ),
                            ),
                          );
                        } catch (e) {
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                e.toString().replaceFirst('Exception: ', ''),
                              ),
                            ),
                          );
                        }
                      },
                    ),
                  ],
                ),
          ),
        ),
      ),
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.md),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm2,
          ),
          child: Row(
            children: [
              Icon(icon, color: AppColors.primaryGreen, size: 26),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.bodyText,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: Colors.grey.shade400,
              ),
            ],
          ),
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
  bool _expandedSaved = false;
  bool _expandedLoading = false;
  int? _pendingStars;
  bool _submittingRating = false;
  final Map<int, TextEditingController> _reviewControllers = {};
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _searchQuery = '';
  Timer? _searchDebounce;
  List<String> _recentSearches = [];
  bool _loadingPopularCuisines = false;
  List<_PopularCuisineItem> _popularCuisines = [];
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
  DateTime _plannerWeekStart = _startOfWeek(DateTime.now());
  bool _plannerExpanded = false;

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

  TextEditingController _getReviewController(int recipeId) {
    _reviewControllers[recipeId] ??= TextEditingController();
    return _reviewControllers[recipeId]!;
  }

  @override
  void dispose() {
    for (final c in _reviewControllers.values) {
      c.dispose();
    }
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
    _load();
    _loadTopRanked();
    _loadPopularCuisines();
    _loadRecentSearches();
    _searchFocusNode.addListener(() {
      if (mounted) setState(() {});
    });
    _scrollController.addListener(_onScroll);
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

  Future<void> _loadPopularCuisines() async {
    try {
      setState(() => _loadingPopularCuisines = true);
      final ranked = await RecipeService.instance.fetchRankings(
        window: '30d',
        mode: 'views',
      );
      final seen = <String>{};
      final cuisines = <_PopularCuisineItem>[];
      for (final item in ranked) {
        final baseLabel = (item.category ?? '').trim().isNotEmpty
            ? item.category!.trim()
            : item.title.trim().split(' ').first;
        final label = baseLabel.isEmpty ? 'Popular' : baseLabel;
        final normalized = label.toLowerCase();
        if (seen.contains(normalized)) continue;
        seen.add(normalized);
        cuisines.add(
          _PopularCuisineItem(
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
      // Clear list only when applying filters, so stale results don't flash
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
      // Ignore stale response: user may have typed/changed filter before this completed
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
                child: _buildMobileSearchView(),
              )
            : KeyedSubtree(
                key: const ValueKey('dashboard-view'),
                child: RefreshIndicator(
                  onRefresh: () async {
                    await Future.wait([
                      _load(),
                      _loadTopRanked(),
                    ]);
                  },
                  color: wellGreen,
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
                                        ? _buildMobileSearchTrigger()
                                        : _buildRecipeSearchField(
                                            searchOnlyMode: false,
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
                                      const SizedBox(height: AppSpacing.sm2),
                                      _buildSearchDiscoveryPanel(),
                                    ],
                                    const SizedBox(height: AppSpacing.xs),
                                    if (_categories.isNotEmpty) ...[
                                      SizedBox(
                                        height: 36,
                                        child: ListView(
                                          scrollDirection: Axis.horizontal,
                                          children: [
                                            _FilterChip(
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
                                              (c) => _FilterChip(
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
                                      const SizedBox(height: 4),
                                    ],
                                    // Only show these sections if the search box is empty
                                    if (_searchController.text.isEmpty) ...[
                                      if (_categories.isNotEmpty)
                                        const SizedBox(height: 4),
                                      if (_selectedCategoryId == null) ...[
                                        _buildTopRankedSection(),
                                        const SizedBox(height: 16),
                                        _buildMealPlannerSection(),
                                        const SizedBox(height: 16),
                                      ],
                                      const Text(
                                        'Discover',
                                        style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF097333),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                    ] else ...[
                                      // When searching, hide the above and show a "Search Results" title instead
                                      const SizedBox(height: 16),
                                      const Text(
                                        'Search Results',
                                        style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF097333),
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
                          ..._buildDiscoverGridSlivers(
                            crossAxisCount: crossAxisCount,
                            padding: padding,
                            gap: gap,
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

  /// Same gray stroke as [CustomBottomNav] outline (light mode).
  Color _searchBarOutlineColor(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    return isLight
        ? const Color(0xFFC5C5C5).withValues(alpha: 0.95)
        : Colors.white.withValues(alpha: 0.18);
  }

  OutlineInputBorder _recipeSearchOutline(BuildContext context) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(24),
      borderSide: BorderSide(color: _searchBarOutlineColor(context), width: 1),
    );
  }

  Widget _buildMobileSearchTrigger() {
    final value = _searchController.text.trim();
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _openMobileSearch,
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: _searchBarOutlineColor(context),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.search, color: kPrimaryGreen, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                value.isEmpty ? 'Search by name or ingredients...' : value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 16,
                  color: value.isEmpty ? Colors.grey.shade600 : Colors.black87,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileSearchView() {
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
                onPressed: _closeMobileSearch,
                icon: const Icon(Icons.arrow_back_rounded),
                color: Colors.black87,
                tooltip: 'Back to dashboard',
              ),
              const SizedBox(width: 4),
              Expanded(
                child: _buildRecipeSearchField(
                  searchOnlyMode: true,
                  autofocus: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          _buildSearchDiscoveryPanel(boxed: false, horizontalInset: 8),
        ],
      ),
    );
  }

  Widget _buildRecipeSearchField({
    required bool searchOnlyMode,
    bool autofocus = false,
  }) {
    return TextField(
      controller: _searchController,
      focusNode: _searchFocusNode,
      autofocus: autofocus,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'Search by name or ingredients...',
        prefixIcon: const Icon(Icons.search, color: kPrimaryGreen, size: 22),
        suffixIcon: _searchController.text.isNotEmpty
            ? IconButton(
                icon: Icon(Icons.clear, color: Colors.grey.shade600, size: 20),
                onPressed: () {
                  _searchController.clear();
                  _searchDebounce?.cancel();
                  if (searchOnlyMode) {
                    setState(() {});
                    return;
                  }
                  setState(() => _searchQuery = '');
                  _loadRecipes();
                },
              )
            : null,
        filled: true,
        fillColor: Colors.white,
        border: _recipeSearchOutline(context),
        enabledBorder: _recipeSearchOutline(context),
        focusedBorder: _recipeSearchOutline(context),
        disabledBorder: _recipeSearchOutline(context),
        errorBorder: _recipeSearchOutline(context),
        focusedErrorBorder: _recipeSearchOutline(context),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
      ),
      onChanged: (value) {
        setState(() {});
        _searchDebounce?.cancel();
        if (searchOnlyMode) return;
        _searchDebounce = Timer(const Duration(milliseconds: 400), () {
          if (!mounted) return;
          setState(() => _searchQuery = value.trim());
          _loadRecipes();
        });
      },
      onSubmitted: (value) => _applySearchQuery(value),
    );
  }

  Widget _buildMealPlannerSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _searchBarOutlineColor(context), width: 1),
      ),
      child: Column(
        children: [
          ListTile(
            dense: true,
            visualDensity: const VisualDensity(vertical: -2),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 2,
            ),
            leading: const Icon(Icons.calendar_month, color: kPrimaryGreen),
            title: const Text(
              'Weekly Meal Planner',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: kPrimaryGreen,
              ),
            ),
            subtitle: Text(
              _plannerExpanded ? 'Pick meals for each day' : 'Tap to expand.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            trailing: Icon(
              _plannerExpanded ? Icons.expand_less : Icons.expand_more,
              color: kPrimaryGreen,
            ),
            onTap: () => setState(() => _plannerExpanded = !_plannerExpanded),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 220),
            firstCurve: Curves.easeOut,
            secondCurve: Curves.easeOut,
            crossFadeState: _plannerExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: const SizedBox(height: 0),
            secondChild: _plannerExpanded
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                    child: WeeklyMealPlannerStrip(
                      weekStart: _plannerWeekStart,
                      onWeekChanged: (nextWeekStart) {
                        setState(() => _plannerWeekStart = nextWeekStart);
                      },
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchDiscoveryPanel({
    bool boxed = true,
    double horizontalInset = 0,
  }) {
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Popular Cuisines',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: wellGreen,
          ),
        ),
        const SizedBox(height: 10),
        if (_loadingPopularCuisines)
          const LinearProgressIndicator(minHeight: 2, color: wellGreen)
        else if (_popularCuisines.isEmpty)
          Text(
            'No popular cuisines yet.',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          )
        else
          SizedBox(
            height: 118,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _popularCuisines.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final item = _popularCuisines[index];
                return InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => _applySearchQuery(item.searchTerm),
                  child: SizedBox(
                    width: 110,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: item.imageUrl != null
                              ? Image.network(
                                  item.imageUrl!,
                                  height: 82,
                                  width: 110,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) =>
                                      _buildCuisinePlaceholder(item.label),
                                )
                              : _buildCuisinePlaceholder(item.label),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          item.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        const SizedBox(height: 14),
        Row(
          children: [
            const Expanded(
              child: Text(
                'Recent Searches',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: wellGreen,
                ),
              ),
            ),
            if (_recentSearches.isNotEmpty)
              TextButton(
                onPressed: _clearRecentSearches,
                child: const Text('Clear'),
              ),
          ],
        ),
        if (_recentSearches.isEmpty)
          Text(
            'Your recent searches will appear here.',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _recentSearches
                .map(
                  (query) => ActionChip(
                    label: Text(query),
                    onPressed: () => _applySearchQuery(query),
                    avatar: const Icon(
                      Icons.history_rounded,
                      size: 16,
                      color: wellGreen,
                    ),
                    labelStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
                .toList(),
          ),
      ],
    );

    if (!boxed) {
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: horizontalInset),
        child: SizedBox(width: double.infinity, child: content),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: content,
    );
  }

  Widget _buildCuisinePlaceholder(String label) {
    return Container(
      height: 82,
      width: 110,
      decoration: BoxDecoration(
        color: const Color(0xFFE7F1EA),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Text(
          label.isNotEmpty ? label.substring(0, 1).toUpperCase() : '🍽',
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: wellGreen,
          ),
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
    if (_loading && _recipes.isEmpty) {
      return [
        const SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: CircularProgressIndicator(color: Color(0xFF097333)),
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
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 16),
                Text(
                  _hasActiveFilters
                      ? 'No recipes match your filters'
                      : 'No recipes yet. Add one to get started.',
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 16),
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
            return RepaintBoundary(child: _buildRecipeCard(recipe));
          },
        ),
      ),
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Center(
            child: _recipesLoadingMore
                ? const SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF097333),
                    ),
                  )
                : const SizedBox(height: 100),
          ),
        ),
      ),
    ];
  }

  /// Shown for every user: header + "See all" always; preview row when data exists.
  Widget _buildTopRankedSection() {
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
                  color: wellGreen,
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
        if (_loadingRanked) ...[
          const SizedBox(height: 8),
          const LinearProgressIndicator(minHeight: 2, color: Color(0xFF097333)),
        ] else if (_topRanked.isNotEmpty) ...[
          const SizedBox(height: 8),
          SizedBox(
            height: 264,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                PageView.builder(
                  controller: _topRankedPageController,
                  padEnds: false,
                  itemCount: _topRanked.length,
                  onPageChanged: (i) => _topRankedPage.value = i,
                  itemBuilder: (_, i) {
                    return _buildTopRankedCarouselCard(
                      _topRanked[i],
                      i + 1,
                    );
                  },
                ),
                if (_topRanked.length > 1)
                  Positioned.fill(
                    child: ValueListenableBuilder<int>(
                      valueListenable: _topRankedPage,
                      builder: (_, page, _) {
                        final last = _topRanked.length - 1;
                        return Stack(
                          clipBehavior: Clip.none,
                          children: [
                            if (page > 0)
                              Positioned(
                                left: 10,
                                top: 0,
                                bottom: 0,
                                child: Center(
                                  child: _buildTopRankedArrow(
                                    icon: Icons.chevron_left_rounded,
                                    tooltip: 'Previous ranked recipe',
                                    onPressed: () => _jumpTopRankedBy(-1),
                                  ),
                                ),
                              ),
                            if (page < last)
                              Positioned(
                                right: 10,
                                top: 0,
                                bottom: 0,
                                child: Center(
                                  child: _buildTopRankedArrow(
                                    icon: Icons.chevron_right_rounded,
                                    tooltip: 'Next ranked recipe',
                                    onPressed: () => _jumpTopRankedBy(1),
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
            valueListenable: _topRankedPage,
            builder: (_, page, _) => Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_topRanked.length, (i) {
                final active = i == page;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: active ? 18 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: active ? wellGreen : Colors.grey.shade300,
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

  Widget _buildTopRankedArrow({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
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

  ({Color bgColor, Color fgColor, IconData icon, String label}) _rankBadgeStyle(
    int rank,
  ) {
    if (rank == 1) {
      return (
        bgColor: const Color(0xFFB8860B),
        fgColor: Colors.white,
        icon: Icons.emoji_events,
        label: 'Gold',
      );
    }
    if (rank == 2) {
      return (
        bgColor: const Color(0xFF607D8B),
        fgColor: Colors.white,
        icon: Icons.emoji_events,
        label: 'Silver',
      );
    }
    if (rank == 3) {
      return (
        bgColor: const Color(0xFF8D5524),
        fgColor: Colors.white,
        icon: Icons.emoji_events,
        label: 'Bronze',
      );
    }
    return (
      bgColor: const Color(0xFF455A64),
      fgColor: Colors.white,
      icon: Icons.workspace_premium,
      label: 'Top 10',
    );
  }

  Widget _buildTopRankedCarouselCard(RecipeRankingItem r, int rank) {
    final isSaved = _topRankedSaved[r.id] ?? false;
    final saving = _topRankedSaving.contains(r.id);
    final badge = _rankBadgeStyle(rank);
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.sm),
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            fullscreenDialog: true,
            builder: (_) => RecipeDetailScreen(recipeId: r.id),
          ),
        ),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _searchBarOutlineColor(context), width: 1),
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
                      child: r.displayImageUrl != null
                          ? Image.network(
                              r.displayImageUrl!,
                              width: double.infinity,
                              height: double.infinity,
                              fit: BoxFit.cover,
                            )
                          : Container(
                              color: const Color(0xFFE6F0EA),
                              child: const Center(
                                child: Icon(Icons.restaurant, size: 38),
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
                            Icon(
                              Icons.star_rounded,
                              size: 15,
                              color: accentYellow,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              r.averageRating.toStringAsFixed(1),
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
                            : () => _toggleTopRankedSaved(r),
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
                                color: isSaved ? nestOrange : wellGreen,
                              ),
                        tooltip: isSaved ? 'Remove favorite' : 'Save favorite',
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
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
                                      r.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: georgiaProTextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.grey.shade900,
                                      ).copyWith(letterSpacing: 0.35),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'By ${r.authorName?.trim().isNotEmpty == true ? r.authorName!.trim() : 'WellNest Community'}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: Colors.grey.shade700,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.22,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.flatware_rounded,
                                          size: 13,
                                          color: wellGreen.withValues(
                                            alpha: 0.85,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            r.category?.trim().isNotEmpty ==
                                                    true
                                                ? r.category!
                                                : 'Uncategorized',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: Colors.grey.shade700,
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
                                  color: Colors.black.withValues(alpha: 0.18),
                                ),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x22000000),
                                    blurRadius: 4,
                                    offset: Offset(0, 1),
                                  ),
                                ],
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
                                  color: wellGreen.withValues(alpha: 0.85),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${r.prepTime} min',
                                  style: TextStyle(
                                    color: Colors.grey.shade800,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.18,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Icon(
                                  Icons.visibility_outlined,
                                  size: 13,
                                  color: Colors.grey.shade600,
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  '${r.viewsCount}',
                                  style: TextStyle(
                                    color: Colors.grey.shade700,
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
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _toggleTopRankedSaved(RecipeRankingItem r) async {
    if (!AuthService.instance.isLoggedIn) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Sign in to save recipes')));
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Sign in to save recipes')));
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

  Widget _buildRecipeCard(Recipe recipe) {
    /// Image band width/height; card total height also grows with wrapped title text.
    const gridCardAspectRatio = 0.7;

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
        }
      },
      semanticLabel: 'View recipe, ${recipe.title}',
      child: WellnestRecipeCard(
        recipe: recipe,
        heroTag: 'recipe_${recipe.id}_image',
        aspectRatio: gridCardAspectRatio,
        bookmarkSaving: _recipeSaving.contains(recipe.id),
        isBookmarked: _recipeSaved[recipe.id] ?? false,
        onBookmarkTap: AuthService.instance.isLoggedIn
            ? () => _toggleRecipeSaved(recipe)
            : null,
      ),
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
                      errorBuilder: (_, _, _) =>
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
            _buildExpandedLikeButton(fullRecipe),
            _buildExpandedSaveButton(fullRecipe),
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
              _expandedLiked ? Icons.favorite : Icons.favorite_border,
              color: _expandedLiked ? nestOrange : Colors.grey.shade600,
              size: 24,
            ),
          ),
          Text(
            _expandedLiked ? 'Liked' : 'Like',
            style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildExpandedSaveButton(Recipe recipe) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          IconButton(
            onPressed: () async {
              if (!AuthService.instance.isLoggedIn) return;
              try {
                if (_expandedSaved) {
                  await SavedRecipeService.instance.unsaveRecipe(recipe.id);
                  if (mounted) setState(() => _expandedSaved = false);
                } else {
                  await SavedRecipeService.instance.saveRecipe(recipe.id);
                  if (mounted) setState(() => _expandedSaved = true);
                }
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        _expandedSaved
                            ? 'Saved to favorites'
                            : 'Removed from favorites',
                      ),
                      backgroundColor: wellGreen,
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
              _expandedSaved ? Icons.bookmark : Icons.bookmark_border,
              color: _expandedSaved ? wellGreen : Colors.grey.shade600,
              size: 24,
            ),
          ),
          Text(
            _expandedSaved ? 'Saved' : 'Save',
            style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
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

  static const Color wellGreen = Color(0xFF097333);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? wellGreen : Colors.grey.shade200,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : Colors.grey.shade700,
            ),
          ),
        ),
      ),
    );
  }
}

class _PopularCuisineItem {
  final String label;
  final String? imageUrl;
  final String searchTerm;

  const _PopularCuisineItem({
    required this.label,
    required this.imageUrl,
    required this.searchTerm,
  });
}
