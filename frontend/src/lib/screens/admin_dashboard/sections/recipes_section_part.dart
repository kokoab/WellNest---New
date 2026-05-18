part of 'package:my_app/screens/admin_dashboard.dart';

class _RecipesSectionContainer extends StatefulWidget {
  final ThemeData theme;
  const _RecipesSectionContainer({super.key, required this.theme});

  @override
  State<_RecipesSectionContainer> createState() =>
      _RecipesSectionContainerState();
}

class _RecipesSectionContainerState extends State<_RecipesSectionContainer>
    with AutomaticKeepAliveClientMixin {
  List<Recipe> _recipes = [];
  bool _loading = true;
  String? _error;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  Timer? _recipesSearchDebounce;
  _DateRangeFilter _recipesRange = _DateRangeFilter.monthly;
  DateTimeRange? _customDateRange;
  int _recipesPage = 1;
  final int _recipesPerPage = 10;
  bool _recipesLoadingPage = false;
  int _recipesQuerySerial = 0;
  int _recipesTotalCount = 0;

  @override
  void initState() {
    super.initState();
    refresh();
  }

  @override
  void dispose() {
    _recipesSearchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> refresh() => _loadRecipesPage(reset: true);

  int _getRecipesTotalPages() {
    if (_recipesTotalCount == 0) return 1;
    return (_recipesTotalCount / _recipesPerPage).ceil();
  }

  void _handleRecipesSearchChanged(String value) {
    setState(() => _searchQuery = value);
    _recipesSearchDebounce?.cancel();
    _recipesSearchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      _loadRecipesPage(reset: true);
    });
  }

  void _clearAllFilters() {
    _recipesSearchDebounce?.cancel();
    _searchController.clear();
    setState(() {
      _searchQuery = '';
      _recipesRange = _DateRangeFilter.monthly;
      _customDateRange = null;
    });
    _loadRecipesPage(reset: true);
  }

  Future<void> _loadRecipesPage({bool reset = false}) async {
    final querySerial = ++_recipesQuerySerial;
    if (reset) {
      _recipesPage = 1;
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final result = await RecipeService.instance.fetchRecipes(
        range: _customDateRange == null ? _recipesRange.apiValue : null,
        search: _searchQuery,
        startDate: _customDateRange?.start,
        endDate: _customDateRange?.end,
        page: _recipesPage,
        perPage: _recipesPerPage,
      );
      if (!mounted || querySerial != _recipesQuerySerial) return;
      setState(() {
        _recipes = result.recipes;
        _recipesTotalCount = result.total;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _adminErrorMessage(e);
        _loading = false;
      });
    }
  }

  Future<void> _handleRecipesPageChanged(int page) async {
    if (page < 1 || page > _getRecipesTotalPages()) return;
    setState(() => _recipesLoadingPage = true);
    try {
      final result = await RecipeService.instance.fetchRecipes(
        range: _customDateRange == null ? _recipesRange.apiValue : null,
        search: _searchQuery,
        startDate: _customDateRange?.start,
        endDate: _customDateRange?.end,
        page: page,
        perPage: _recipesPerPage,
      );
      if (!mounted) return;
      setState(() {
        _recipesPage = page;
        _recipes = result.recipes;
        _recipesTotalCount = result.total;
        _recipesLoadingPage = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _adminErrorMessage(e);
        _recipesLoadingPage = false;
      });
    }
  }

  Future<void> _openRecipePreviewModal(Recipe recipe) async {
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (ctx) => _WebModal(
        title: recipe.title.trim().isEmpty ? 'Recipe' : recipe.title,
        icon: Icons.restaurant_menu_outlined,
        iconColor: const Color(0xFFE6930A),
        child: _RecipePreviewModalContent(recipeId: recipe.id),
      ),
    );
  }

  Future<void> _confirmDelete(Recipe recipe) async {
    final ok = await _showAdminConfirmDialog(
      context: context,
      title: 'Delete recipe permanently?',
      content:
          'Permanently delete "${recipe.title}"? This cannot be undone.',
      actionLabel: 'Delete',
      actionColor: Colors.red,
    );
    if (ok != true) return;
    try {
      await RecipeService.instance.deleteRecipe(recipe.id);
      if (!mounted) return;
      _showAdminSnack(context, 'Recipe deleted');
      await refresh();
    } catch (e) {
      if (!mounted) return;
      _showAdminErrorSnack(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return _RecipesSection(
      theme: widget.theme,
      recipes: _recipes,
      loading: _loading,
      error: _error,
      searchQuery: _searchQuery,
      searchController: _searchController,
      onSearchChanged: _handleRecipesSearchChanged,
      selectedRange: _recipesRange,
      onRangeChanged: (range) {
        setState(() {
          _recipesRange = range;
          _customDateRange = null;
        });
        refresh();
      },
      customDateRange: _customDateRange,
      onCustomDateRangeChanged: (value) {
        setState(() => _customDateRange = value);
        refresh();
      },
      onClearAllFilters: _clearAllFilters,
      onRefresh: refresh,
      onOpenRecipe: _openRecipePreviewModal,
      onDelete: _confirmDelete,
      currentPage: _recipesPage,
      totalPages: _getRecipesTotalPages(),
      loadingPage: _recipesLoadingPage,
      onPageChanged: _handleRecipesPageChanged,
      totalCount: _recipesTotalCount,
    );
  }

  @override
  bool get wantKeepAlive => true;
}

class _RecipesSection extends StatelessWidget {
  final ThemeData theme;
  final List<Recipe> recipes;
  final bool loading;
  final String? error;
  final String searchQuery;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final _DateRangeFilter selectedRange;
  final ValueChanged<_DateRangeFilter> onRangeChanged;
  final DateTimeRange? customDateRange;
  final ValueChanged<DateTimeRange?> onCustomDateRangeChanged;
  final VoidCallback onClearAllFilters;
  final VoidCallback onRefresh;
  final void Function(Recipe) onOpenRecipe;
  final void Function(Recipe) onDelete;
  final int currentPage;
  final int totalPages;
  final bool loadingPage;
  final ValueChanged<int> onPageChanged;
  final int totalCount;

  const _RecipesSection({
    required this.theme,
    required this.recipes,
    required this.loading,
    required this.error,
    required this.searchQuery,
    required this.searchController,
    required this.onSearchChanged,
    required this.selectedRange,
    required this.onRangeChanged,
    required this.customDateRange,
    required this.onCustomDateRangeChanged,
    required this.onClearAllFilters,
    required this.onRefresh,
    required this.onOpenRecipe,
    required this.onDelete,
    required this.currentPage,
    required this.totalPages,
    required this.loadingPage,
    required this.onPageChanged,
    required this.totalCount,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _MinimalSectionLabel(
                theme: theme,
                label: 'Recipes',
                subtitle: loading
                    ? 'Loading…'
                    : '$totalCount recipe${totalCount == 1 ? '' : 's'}',
              ),
            ),
            _ClearFiltersButton(onPressed: onClearAllFilters),
            const SizedBox(width: 6),
            _DateRangeDropdown(value: selectedRange, onChanged: onRangeChanged),
            const SizedBox(width: 6),
            _CustomDateRangeButton(
              value: customDateRange,
              onChanged: onCustomDateRangeChanged,
            ),
            const SizedBox(width: 6),
            if (!loading) ...[
              _TopBarIconBtn(
                icon: Icons.refresh_rounded,
                onPressed: onRefresh,
                tooltip: 'Refresh',
                color: kPrimaryGreen,
              ),
              const SizedBox(width: 4),
              _AdminCsvExportButton(range: selectedRange),
            ],
          ],
        ),
        const SizedBox(height: 14),
        _SearchBar(
          theme: theme,
          controller: searchController,
          onChanged: onSearchChanged,
          hintText: 'Search by title, ingredient, or author…',
        ),
        const SizedBox(height: 14),
        if (loading && recipes.isEmpty)
          const _LoadingState()
        else if (error != null)
          _ErrorState(theme: theme, message: error!, onRetry: onRefresh)
        else if (recipes.isEmpty)
          _EmptyState(
            theme: theme,
            message: searchQuery.isEmpty
                ? 'No recipes yet'
                : 'No recipes match your search',
          )
        else ...[
          _RecipesTable(
            theme: theme,
            recipes: recipes,
            onOpenRecipe: onOpenRecipe,
            onDelete: onDelete,
          ),
          const SizedBox(height: 16),
          _PaginationControls(
            currentPage: currentPage,
            totalPages: totalPages,
            loading: loadingPage,
            onPageChanged: onPageChanged,
          ),
        ],
        const SizedBox(height: 32),
      ],
    );
  }
}

class _RecipesTable extends StatelessWidget {
  final ThemeData theme;
  final List<Recipe> recipes;
  final void Function(Recipe) onOpenRecipe;
  final void Function(Recipe) onDelete;

  const _RecipesTable({
    required this.theme,
    required this.recipes,
    required this.onOpenRecipe,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final tableWidth = math.max(constraints.maxWidth, 1100.0);
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: tableWidth,
            child: _flexTable(
              theme: theme,
              columnWidths: const {
                0: FlexColumnWidth(5),
                1: FlexColumnWidth(20),
                2: FlexColumnWidth(12),
                3: FlexColumnWidth(13),
                4: FlexColumnWidth(15),
                5: FlexColumnWidth(8),
                6: FlexColumnWidth(8),
                7: FlexColumnWidth(8),
                8: FlexColumnWidth(11),
              },
        headers: [
          'ID',
          'TITLE',
          'CATEGORY',
          'AUTHOR',
          'CREATED',
          'PREP',
          'RATING',
          'VIEWS',
          'ACTIONS',
        ],
        rows: recipes.map((recipe) {
          final ratingLabel = recipe.averageRating != null
              ? recipe.averageRating!.toStringAsFixed(1)
              : '—';
          final viewsLabel =
              recipe.viewsCount != null ? '${recipe.viewsCount}' : '—';
          return _tableRow(theme, [
            Text(
              '${recipe.id}',
              style: TextStyle(
                fontSize: 13,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            Text(
              recipe.title.isEmpty ? '—' : recipe.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.onSurface,
              ),
            ),
            Text(
              recipe.category?.name ?? '—',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            Text(
              recipe.userDisplayName,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            Text(
              _formatHumanDate(recipe.createdAt),
              style: TextStyle(
                fontSize: 11,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            Text(
              '${recipe.prepTime}m',
              style: TextStyle(
                fontSize: 13,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            Text(
              ratingLabel,
              style: TextStyle(
                fontSize: 13,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            Text(
              viewsLabel,
              style: TextStyle(
                fontSize: 13,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _ActionIconBtn(
                  icon: Icons.visibility_outlined,
                  color: kPrimaryGreen,
                  tooltip: 'Preview',
                  onPressed: () => onOpenRecipe(recipe),
                ),
                const SizedBox(width: 4),
                _ActionIconBtn(
                  icon: Icons.delete_outline_rounded,
                  color: Colors.red,
                  tooltip: 'Delete',
                  onPressed: () => onDelete(recipe),
                ),
              ],
            ),
          ], null);
        }).toList(),
      ),
          ),
        );
      },
    );
  }
}
