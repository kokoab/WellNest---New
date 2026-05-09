import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:my_app/theme/app_spacing.dart';
import 'package:my_app/theme/app_theme.dart';
import 'package:my_app/models/recipe.dart';
import 'package:my_app/screens/recipe_form_screen.dart';
import 'package:my_app/services/recipe_service.dart';
import 'package:my_app/services/auth_service.dart';
import 'package:my_app/services/report_service.dart';
import 'package:my_app/services/vote_service.dart';
import 'package:my_app/models/recipe_rating.dart';
import 'package:my_app/services/rating_service.dart';
import 'package:my_app/services/saved_recipe_service.dart';
import 'package:my_app/screens/user_profile_screen.dart';
import 'package:my_app/widgets/georgia_pro_display_squish.dart';
import 'package:my_app/widgets/wellnest_glass.dart';

class RecipeDetailScreen extends StatefulWidget {
  final int recipeId;

  const RecipeDetailScreen({super.key, required this.recipeId});

  @override
  State<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends State<RecipeDetailScreen> {
  static const Color wellGreen = Color(0xFF097333);
  static const Color nestOrange = Color(0xFFEF5026);
  static const double _kImageExpandedHeight = 280;

  Recipe? _recipe;
  bool _loading = true;
  String? _error;
  bool _liked = false;
  bool _saved = false;
  bool _liking = false;
  bool _saving = false;
  RecipeRatingsResponse? _ratings;
  RecipeRating? _userRating;
  int? _pendingStars;
  bool _submittingRating = false;
  final TextEditingController _reviewController = TextEditingController();
  final ScrollController _detailScrollController = ScrollController();
  final GlobalKey _instructionsAnchorKey = GlobalKey();
  final Set<int> _checkedIngredients = <int>{};
  int? _currentUserId;
  bool _appBarCollapsed = false;
  bool get _isOwner =>
      _recipe != null &&
      _currentUserId != null &&
      _recipe!.userId == _currentUserId;

  @override
  void dispose() {
    _detailScrollController.removeListener(_onDetailScroll);
    _detailScrollController.dispose();
    _reviewController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _detailScrollController.addListener(_onDetailScroll);
    _load();
  }

  void _onDetailScroll() {
    final collapsed = _computeAppBarCollapsed();
    if (collapsed != _appBarCollapsed && mounted) {
      setState(() => _appBarCollapsed = collapsed);
    }
  }

  bool _computeAppBarCollapsed() {
    if (!_detailScrollController.hasClients) return false;
    final range = _kImageExpandedHeight - kToolbarHeight;
    if (range <= 0) return false;
    return _detailScrollController.offset >= range - 8;
  }

  void _scrollToInstructions() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _instructionsAnchorKey.currentContext;
      if (!mounted || ctx == null) return;
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
        alignment: 0.04,
      );
    });
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final recipe = await RecipeService.instance.fetchRecipe(widget.recipeId);
      final isLoggedIn = AuthService.instance.isLoggedIn;
      final userId = AuthService.instance.userId;

      final ratingsFuture = RatingService.instance.fetchRatings(
        widget.recipeId,
      );
      final userRatingFuture = isLoggedIn
          ? RatingService.instance.fetchUserRating(widget.recipeId)
          : Future<RecipeRating?>.value(null);
      final savedFuture = isLoggedIn
          ? SavedRecipeService.instance.isSaved(widget.recipeId)
          : Future<bool>.value(false);

      final results = await Future.wait([
        Future<RecipeRatingsResponse?>(() async {
          try {
            return await ratingsFuture;
          } catch (_) {
            return null;
          }
        }),
        Future<RecipeRating?>(() async {
          try {
            return await userRatingFuture;
          } catch (_) {
            return null;
          }
        }),
        Future<bool>(() async {
          try {
            return await savedFuture;
          } catch (_) {
            return false;
          }
        }),
      ]);

      if (!mounted) return;
      setState(() {
        _recipe = recipe;
        _ratings = results[0] as RecipeRatingsResponse?;
        _userRating = results[1] as RecipeRating?;
        _saved = results[2] as bool;
        _currentUserId = userId;
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

  Future<void> _reportRecipe() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Report recipe?'),
        content: const Text('Report this recipe to moderators?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Report'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await ReportService.instance.reportRecipe(_recipe!.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Report submitted'),
            backgroundColor: wellGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: nestOrange,
          ),
        );
      }
    }
  }

  Future<void> _deleteRecipe() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete recipe?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await RecipeService.instance.deleteRecipe(widget.recipeId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Recipe deleted'),
          backgroundColor: wellGreen,
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: nestOrange,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final recipe = _recipe;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: AppGradients.softScaffold),
        child: _loading
          ? CustomScrollView(
              physics: const NeverScrollableScrollPhysics(),
              slivers: [
                SliverAppBar(
                  pinned: true,
                  leadingWidth: 52,
                  leading: _RecipeDetailCircularBackButton(
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                const SliverFillRemaining(
                  child: Center(
                    child: CircularProgressIndicator(color: wellGreen),
                  ),
                ),
              ],
            )
          : _error != null
          ? CustomScrollView(
              slivers: [
                SliverAppBar(
                  pinned: true,
                  leadingWidth: 52,
                  leading: _RecipeDetailCircularBackButton(
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                SliverFillRemaining(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: nestOrange),
                        ),
                        AppSpacing.gapV16,
                        FilledButton(
                          onPressed: _load,
                          style: FilledButton.styleFrom(
                            backgroundColor: wellGreen,
                          ),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            )
          : CustomScrollView(
              controller: _detailScrollController,
              slivers: [
                SliverAppBar(
                  expandedHeight: _kImageExpandedHeight,
                  pinned: true,
                  stretch: true,
                  elevation: 0,
                  scrolledUnderElevation: 0,
                  leadingWidth: 52,
                  backgroundColor: _appBarCollapsed
                      ? const Color(0xFFFAF9F6)
                      : Colors.transparent,
                  surfaceTintColor: Colors.transparent,
                  foregroundColor: _appBarCollapsed
                      ? colorScheme.onSurface
                      : Colors.white,
                  iconTheme: IconThemeData(
                    color: _appBarCollapsed
                        ? colorScheme.onSurface
                        : Colors.white,
                  ),
                  actionsIconTheme: IconThemeData(
                    color: _appBarCollapsed
                        ? colorScheme.onSurface
                        : Colors.white,
                  ),
                  leading: _RecipeDetailCircularBackButton(
                    onPressed: () => Navigator.pop(context),
                  ),
                  title: _appBarCollapsed
                      ? Text(
                          recipe!.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurface,
                          ),
                        )
                      : null,
                  actions: [
                    if (recipe != null && AuthService.instance.isLoggedIn)
                      PopupMenuButton<String>(
                        icon: Icon(
                          Icons.more_vert_rounded,
                          color: _appBarCollapsed
                              ? colorScheme.onSurface
                              : Colors.white,
                        ),
                        onSelected: (v) async {
                          if (v == 'edit') {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    RecipeFormScreen(recipe: _recipe),
                              ),
                            ).then((_) => _load());
                          } else if (v == 'report' &&
                              AuthService.instance.isLoggedIn) {
                            await _reportRecipe();
                          } else if (v == 'delete') {
                            await _deleteRecipe();
                          }
                        },
                        itemBuilder: (context) => [
                          if (_isOwner)
                            const PopupMenuItem(
                              value: 'delete',
                              child: Text('Delete'),
                            ),
                          if (_isOwner)
                            const PopupMenuItem(
                              value: 'edit',
                              child: Text('Edit'),
                            ),
                          if (AuthService.instance.isLoggedIn)
                            const PopupMenuItem(
                              value: 'report',
                              child: Text('Report'),
                            ),
                        ],
                      ),
                  ],
                  flexibleSpace: FlexibleSpaceBar(
                    stretchModes: const [StretchMode.zoomBackground],
                    background: Stack(
                      fit: StackFit.expand,
                      children: [
                        Hero(
                          tag: 'recipe_${recipe!.id}_image',
                          child: Material(
                            color: Colors.transparent,
                            child: _buildExpandedRecipeImageFill(),
                          ),
                        ),
                        Positioned(
                          left: 0,
                          right: 0,
                          top: 0,
                          height: 120,
                          child: IgnorePointer(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.black.withValues(alpha: 0.55),
                                    Colors.black.withValues(alpha: 0),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          height: 100,
                          child: IgnorePointer(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                  colors: [
                                    Colors.black.withValues(alpha: 0.45),
                                    Colors.black.withValues(alpha: 0),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.lg,
                      AppSpacing.lg,
                      AppSpacing.xl,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GeorgiaProDisplaySquish(
                          child: Text(
                            recipe.title,
                            style: georgiaProTextStyle(
                              fontSize: 28,
                              color: wellGreen,
                            ),
                          ),
                        ),
                        if (recipe.description != null &&
                            recipe.description!.trim().isNotEmpty) ...[
                          AppSpacing.gapV12,
                          Text(
                            recipe.description!.trim(),
                            style: TextStyle(
                              fontFamily: kFontHelveticaNow,
                              fontSize: 16,
                              height: 1.5,
                              color: Colors.grey.shade800,
                            ),
                          ),
                        ],
                        AppSpacing.gapV8,
                        GestureDetector(
                          onTap: recipe.userId != null
                              ? () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => UserProfileScreen(
                                      userId: recipe.userId!,
                                    ),
                                  ),
                                )
                              : null,
                          child: Text(
                            recipe.user != null
                                ? 'By ${recipe.userDisplayName}'
                                : 'By Unknown',
                            style: TextStyle(
                              fontFamily: kFontHelveticaNow,
                              color: AppColors.captionText,
                              fontSize: 14,
                              decoration: recipe.userId != null
                                  ? TextDecoration.underline
                                  : TextDecoration.none,
                              decorationColor: AppColors.captionText,
                            ),
                          ),
                        ),
                        AppSpacing.gapV16,
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _buildMetaStrip(),
                              AppSpacing.gapH16,
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.star_rounded,
                                    color: Colors.amber.shade700,
                                    size: 18,
                                  ),
                                  AppSpacing.gapH4,
                                  Text(
                                    '${(_ratings?.averageRating ?? recipe.averageRating ?? 0.0).toStringAsFixed(1)} (${_ratings?.ratingsCount ?? recipe.ratingsCount ?? 0})',
                                    style: TextStyle(
                                      fontFamily: kFontHelveticaNow,
                                      fontSize: 14,
                                      color: AppColors.captionText,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        AppSpacing.gapV24,
                        Divider(height: 1, color: Colors.grey.shade300),
                        AppSpacing.gapV16,
                        _buildReviewsExpansion(theme),
                        AppSpacing.gapV8,
                        _buildIngredientsExpansion(theme),
                        AppSpacing.gapV24,
                        Divider(height: 1, color: Colors.grey.shade300),
                        AppSpacing.gapV16,
                        KeyedSubtree(
                          key: _instructionsAnchorKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildSectionTitle('Instructions'),
                              AppSpacing.gapV12,
                              _buildInstructions(),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
        ),
      bottomNavigationBar:
          (!_loading && _error == null && recipe != null)
          ? SafeArea(
              top: false,
              minimum: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.sm,
                  AppSpacing.lg,
                  AppSpacing.md,
                ),
                child: WellnestGlass(
                  borderRadius: BorderRadius.circular(24),
                  fillOpacity: 0.4,
                  strokeOpacity: 0.8,
                  strokeWidth: 1.5,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        IconButton.filledTonal(
                          onPressed:
                              AuthService.instance.isLoggedIn && !_liking
                              ? _handleLikeTap
                              : null,
                          style: IconButton.styleFrom(
                            backgroundColor:
                                nestOrange.withValues(alpha: 0.14),
                            foregroundColor: nestOrange,
                          ),
                          icon: _liking
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: nestOrange,
                                  ),
                                )
                              : Icon(
                                  _liked
                                      ? Icons.favorite_rounded
                                      : Icons.favorite_border_rounded,
                                ),
                          tooltip: _liked ? 'Unlike' : 'Like',
                        ),
                        IconButton.filledTonal(
                          onPressed:
                              AuthService.instance.isLoggedIn && !_saving
                              ? _handleSaveTap
                              : null,
                          style: IconButton.styleFrom(
                            backgroundColor:
                                wellGreen.withValues(alpha: 0.12),
                            foregroundColor: wellGreen,
                          ),
                          icon: _saving
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: wellGreen,
                                  ),
                                )
                              : Icon(
                                  _saved
                                      ? Icons.bookmark_rounded
                                      : Icons.bookmark_border_rounded,
                                ),
                          tooltip: _saved
                              ? 'Remove from saved'
                              : 'Save recipe',
                        ),
                        AppSpacing.gapH12,
                        Expanded(
                          child: FilledButton(
                            onPressed: _scrollToInstructions,
                            style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(48),
                              backgroundColor: wellGreen,
                            ),
                            child: const Text('Start cooking'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildExpandedRecipeImageFill() {
    if (_recipe!.displayImageUrl != null &&
        _recipe!.displayImageUrl!.isNotEmpty) {
      return Image.network(
        _recipe!.displayImageUrl!,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        alignment: Alignment.center,
        errorBuilder: (_, _, _) => _buildExpandedPlaceholderFill(),
      );
    }
    return _buildExpandedPlaceholderFill();
  }

  Widget _buildExpandedPlaceholderFill() {
    return ColoredBox(
      color: AppColors.imagePlaceholderGreen,
      child: Center(child: Icon(Icons.restaurant_menu, size: 72, color: wellGreen)),
    );
  }

  Future<void> _handleLikeTap() async {
    setState(() => _liking = true);
    try {
      if (_liked) {
        await VoteService.instance.unlikeRecipe(_recipe!.id);
        if (mounted) setState(() => _liked = false);
      } else {
        await VoteService.instance.likeRecipe(_recipe!.id);
        if (mounted) setState(() => _liked = true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => _liking = false);
    }
  }

  Future<void> _handleSaveTap() async {
    setState(() => _saving = true);
    try {
      if (_saved) {
        await SavedRecipeService.instance.unsaveRecipe(_recipe!.id);
        if (mounted) setState(() => _saved = false);
      } else {
        await SavedRecipeService.instance.saveRecipe(_recipe!.id);
        if (mounted) setState(() => _saved = true);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _saved ? 'Saved to favorites' : 'Removed from favorites',
            ),
            backgroundColor: wellGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _buildReviewsExpansion(ThemeData theme) {
    final count = _ratings?.ratings.length ?? 0;

    return Theme(
      data: theme.copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        maintainState: true,
        initiallyExpanded: false,
        tilePadding: EdgeInsets.zero,
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        collapsedIconColor: AppColors.captionText,
        iconColor: wellGreen,
        title: Text(
          'Reviews',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: wellGreen,
            letterSpacing: 0.3,
            fontFamily: kFontHelveticaNow,
          ),
        ),
        subtitle: Text(
          count == 0
              ? 'No reviews yet'
              : '$count review${count == 1 ? '' : 's'}',
          style: TextStyle(
            fontFamily: kFontHelveticaNow,
            fontSize: 13,
            color: AppColors.captionText,
          ),
        ),
        shape: const Border(),
        collapsedShape: const Border(),
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInteractiveRating(),
                AppSpacing.gapV8,
                _buildReviewsList(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIngredientsExpansion(ThemeData theme) {
    final ingredients = _recipe!.ingredients ?? [];
    final n = ingredients.length;

    return Theme(
      data: theme.copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        maintainState: true,
        initiallyExpanded: false,
        tilePadding: EdgeInsets.zero,
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        collapsedIconColor: AppColors.captionText,
        iconColor: wellGreen,
        title: Text(
          'Ingredients',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: wellGreen,
            letterSpacing: 0.3,
            fontFamily: kFontHelveticaNow,
          ),
        ),
        subtitle: Text(
          n == 0 ? 'None listed' : '$n items',
          style: TextStyle(
            fontFamily: kFontHelveticaNow,
            fontSize: 13,
            color: AppColors.captionText,
          ),
        ),
        shape: const Border(),
        collapsedShape: const Border(),
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: _buildIngredientsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildMetaStrip() {
    final muted = AppColors.captionText;
    final style = TextStyle(
      fontFamily: kFontHelveticaNow,
      fontSize: 14,
      height: 1.35,
      color: muted,
    );
    final recipe = _recipe!;
    final ingredientsCount = recipe.ingredients?.length ?? 0;
    final views = recipe.viewsCount ?? 0;

    final parts = <Widget>[
      _metaInline(Icons.schedule_outlined, '${recipe.prepTime} mins', style),
      if (recipe.category != null)
        _metaInline(
          Icons.restaurant_menu_outlined,
          recipe.category!.name,
          style,
        ),
      if (ingredientsCount > 0)
        _metaInline(
          Icons.inventory_2_outlined,
          '$ingredientsCount ingredients',
          style,
        ),
      _metaInline(Icons.visibility_outlined, '$views views', style),
    ];

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < parts.length; i++) ...[
          if (i > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              child: Text(
                '|',
                style: style.copyWith(color: muted.withValues(alpha: 0.35)),
              ),
            ),
          parts[i],
        ],
      ],
    );
  }

  Widget _metaInline(IconData icon, String label, TextStyle style) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 17,
          color: AppColors.captionText.withValues(alpha: 0.88),
        ),
        const SizedBox(width: 6),
        Text(label, style: style),
      ],
    );
  }

  Widget _buildReviewsList() {
    final ratings = _ratings?.ratings ?? [];
    if (ratings.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(
          'No reviews yet. Be the first to rate!',
          style: TextStyle(
            fontFamily: 'HelveticaNow',
            color: Colors.grey.shade600,
            fontSize: 15,
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: ratings.map((r) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                r.userDisplayName,
                style: const TextStyle(
                  fontFamily: 'HelveticaNow',
                  fontWeight: FontWeight.w600,
                  color: wellGreen,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                r.comment ?? '',
                style: TextStyle(
                  fontFamily: 'HelveticaNow',
                  fontSize: 14,
                  color: Colors.grey.shade800,
                  height: 1.4,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildInteractiveRating() {
    final hasUserRating = _userRating != null;
    final canRate = AuthService.instance.isLoggedIn && !hasUserRating;

    if (!canRate) {
      if (hasUserRating) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            'You rated this ${_userRating!.rating}/5${_userRating!.comment != null && _userRating!.comment!.isNotEmpty ? ': "${_userRating!.comment}"' : ''}',
            style: TextStyle(
              fontFamily: 'HelveticaNow',
              color: Colors.grey.shade700,
              fontSize: 14,
              fontStyle: FontStyle.italic,
            ),
          ),
        );
      }
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'Tap to rate: ',
                style: TextStyle(
                  fontFamily: 'HelveticaNow',
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(5, (i) {
                  final star = i + 1;
                  final selected = (_pendingStars ?? 0) >= star;
                  return IconButton(
                    onPressed: () => setState(() => _pendingStars = star),
                    icon: Icon(
                      selected ? Icons.star : Icons.star_border,
                      color: selected
                          ? const Color(0xFFF9BD21)
                          : Colors.grey.shade300,
                      size: 28,
                    ),
                    padding: const EdgeInsets.all(4),
                    constraints: const BoxConstraints(
                      minWidth: 36,
                      minHeight: 36,
                    ),
                  );
                }),
              ),
            ],
          ),
          if ((_pendingStars ?? 0) >= 1) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _reviewController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Write a review (optional)...',
                hintStyle: TextStyle(
                  fontFamily: 'HelveticaNow',
                  color: Colors.grey.shade500,
                ),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
              ),
            ),
            const SizedBox(height: 10),
            FilledButton(
              onPressed: _submittingRating
                  ? null
                  : () async {
                      if (_pendingStars == null) return;
                      setState(() => _submittingRating = true);
                      try {
                        await RatingService.instance.submitRating(
                          recipeId: _recipe!.id,
                          rating: _pendingStars!,
                          comment: _reviewController.text.trim().isEmpty
                              ? null
                              : _reviewController.text.trim(),
                        );
                        if (!mounted) return;
                        _reviewController.clear();
                        setState(() {
                          _submittingRating = false;
                          _pendingStars = null;
                        });
                        _load();
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
              style: FilledButton.styleFrom(
                backgroundColor: wellGreen,
                minimumSize: const Size(double.infinity, 44),
              ),
              child: _submittingRating
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Submit rating'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: wellGreen,
        letterSpacing: 0.3,
      ),
    );
  }

  Widget _buildIngredientsList() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final ingredients = _recipe!.ingredients;
    if (ingredients == null || ingredients.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(
          'No ingredients listed.',
          style: TextStyle(
            fontFamily: kFontHelveticaNow,
            color: Colors.grey.shade600,
            fontSize: 15,
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: ingredients.asMap().entries.map((entry) {
          final i = entry.key;
          final ing = entry.value;
          final qty = ing.quantity.toInt() == ing.quantity
              ? ing.quantity.toInt().toString()
              : ing.quantity.toString();
          final amount = ing.unit.isEmpty ? qty : '$qty ${ing.unit}';
          final checked = _checkedIngredients.contains(i);
          return Container(
            margin: const EdgeInsets.only(bottom: AppSpacing.sm),
            decoration: BoxDecoration(
              color: checked
                  ? colorScheme.primary.withValues(alpha: 0.08)
                  : const Color(0xFFF1F4F1),
              borderRadius: BorderRadius.circular(AppRadii.sm),
            ),
            child: CheckboxListTile(
              value: checked,
              onChanged: (selected) {
                setState(() {
                  if (selected == true) {
                    _checkedIngredients.add(i);
                  } else {
                    _checkedIngredients.remove(i);
                  }
                });
              },
              dense: true,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadii.sm),
              ),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: const EdgeInsets.symmetric(horizontal: 8),
              title: Text(
                amount.isNotEmpty ? '$amount ${ing.name}' : ing.name,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurface,
                  height: 1.4,
                  decoration: checked
                      ? TextDecoration.lineThrough
                      : TextDecoration.none,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildInstructions() {
    final theme = Theme.of(context);
    final steps = _recipe!.instructions
        .split(RegExp(r'\r?\n'))
        .map((step) => step.trim())
        .where((step) => step.isNotEmpty)
        .toList();

    if (steps.length <= 1) {
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: SelectableText(
          _recipe!.instructions,
          style: theme.textTheme.bodyLarge?.copyWith(height: 1.75),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List.generate(steps.length, (index) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              '${index + 1}. ${steps[index]}',
              style: theme.textTheme.bodyLarge?.copyWith(height: 1.75),
            ),
          );
        }),
      ),
    );
  }
}

/// Circular frosted back control — readable on bright hero imagery.
class _RecipeDetailCircularBackButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _RecipeDetailCircularBackButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 2),
      child: Center(
        child: ClipOval(
          clipBehavior: Clip.antiAlias,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Material(
              color: Colors.black.withValues(alpha: 0.45),
              child: InkWell(
                onTap: onPressed,
                customBorder: const CircleBorder(),
                child: const SizedBox(
                  width: 40,
                  height: 40,
                  child: Icon(
                    Icons.arrow_back_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
