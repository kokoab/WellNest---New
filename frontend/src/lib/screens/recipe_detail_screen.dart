import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wellnest/theme/app_theme.dart';
import 'package:wellnest/models/recipe.dart';
import 'package:wellnest/screens/recipe_cook_mode_screen.dart';
import 'package:wellnest/screens/recipe_form_screen.dart';
import 'package:wellnest/services/recipe_service.dart';
import 'package:wellnest/services/auth_service.dart';
import 'package:wellnest/services/report_service.dart';
import 'package:wellnest/services/vote_service.dart';
import 'package:wellnest/models/recipe_rating.dart';
import 'package:wellnest/services/rating_service.dart';
import 'package:wellnest/services/saved_recipe_service.dart';
import 'package:wellnest/screens/user_profile_screen.dart';
import 'package:wellnest/widgets/full_screen_photo_gallery.dart';
import 'package:wellnest/widgets/wellnest_popup_menu.dart';

class RecipeDetailScreen extends StatefulWidget {
  final int recipeId;

  const RecipeDetailScreen({super.key, required this.recipeId});

  @override
  State<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends State<RecipeDetailScreen> {
  static const Color wellGreen = Color(0xFF097333);
  static const Color nestOrange = Color(0xFFEF5026);
  static const Color _reviewStarGold = Color(0xFFF9BD21);

  /// Matches [SliverAppBar.expandedHeight], [kToolbarHeight], and bottom inset (curve).
  static const double _recipeHeroExpandedHeight = 350;

  /// Taller overlap so the gradient + rounded shadow blend reads softer against the hero.
  static const double _recipeAppBarBottomInset = 36;
  static const double _recipeTitleAppearScrollOffset =
      _recipeHeroExpandedHeight -
      kToolbarHeight -
      _recipeAppBarBottomInset -
      12;

  static const int _kIngredientsCollapsedMaxLines = 5;
  static const int _kInstructionsCollapsedMaxSteps = 3;

  /// Bottom fade + chevron when content is clipped (“more below”).
  static const double _kCollapsedMoreBelowBandHeight = 48;

  final ScrollController _recipeScrollController = ScrollController();
  bool _showCollapsedRecipeTitle = false;

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

  /// Expands star picker + review text after tapping "Write a review".
  bool _writeReviewExpanded = false;
  final TextEditingController _reviewController = TextEditingController();
  final PageController _galleryPageController = PageController();
  int _galleryIndex = 0;

  /// Collapsed sections: ingredients (max 5 text lines), instructions (max 3 steps / lines).
  bool _ingredientsExpanded = false;
  bool _instructionsExpanded = false;

  int? _currentUserId;
  bool get _isOwner =>
      _recipe != null &&
      _currentUserId != null &&
      _recipe!.userId == _currentUserId;

  @override
  void dispose() {
    _recipeScrollController.removeListener(_onRecipeScrollForPinnedTitle);
    _recipeScrollController.dispose();
    _galleryPageController.dispose();
    _reviewController.dispose();
    super.dispose();
  }

  void _onRecipeScrollForPinnedTitle() {
    if (!_recipeScrollController.hasClients || !mounted) return;
    final show =
        _recipeScrollController.offset >= _recipeTitleAppearScrollOffset;
    if (show != _showCollapsedRecipeTitle) {
      setState(() => _showCollapsedRecipeTitle = show);
    }
  }

  @override
  void initState() {
    super.initState();
    _recipeScrollController.addListener(_onRecipeScrollForPinnedTitle);
    _load();
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
        _galleryIndex = 0;
        _recipe = recipe;
        _ratings = results[0] as RecipeRatingsResponse?;
        _userRating = results[1] as RecipeRating?;
        _saved = results[2] as bool;
        _currentUserId = userId;
        _liked = recipe.isLiked;
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

  Future<void> _toggleLike() async {
    if (!AuthService.instance.isLoggedIn || _recipe == null || _liking) return;
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

  Future<void> _toggleSave() async {
    if (!AuthService.instance.isLoggedIn || _recipe == null || _saving) return;
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

  void _openCookMode() {
    if (_recipe == null) return;
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (ctx) => RecipeCookModeScreen(recipe: _recipe!),
      ),
    ).then((_) {
      if (mounted) _load();
    });
  }

  Widget _buildGlassBackButton() {
    return Container(
      margin: const EdgeInsets.all(8),
      child: ClipOval(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Material(
            color: Colors.black.withValues(alpha: 0.45),
            child: InkWell(
              onTap: () => Navigator.maybePop(context),
              child: const SizedBox(
                width: 40,
                height: 40,
                child: Icon(Icons.arrow_back, color: Colors.white, size: 22),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRatingSummaryPill() {
    final avg = _ratings?.averageRating ?? _recipe?.averageRating ?? 0.0;
    final count = _ratings?.ratingsCount ?? _recipe?.ratingsCount ?? 0;
    const labelStyle = TextStyle(
      fontFamily: 'HelveticaNow',
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: wellGreen,
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Icon(Icons.star_rounded, color: Color(0xFFF9BD21), size: 20),
        const SizedBox(width: 6),
        Text('${avg.toStringAsFixed(1)} • ', style: labelStyle),
        Icon(
          Icons.person_outline_rounded,
          size: 16,
          color: wellGreen.withValues(alpha: 0.9),
        ),
        const SizedBox(width: 3),
        Text('$count', style: labelStyle),
      ],
    );
  }

  Widget _buildCreatorAndPostedRow() {
    final posted = _postedDateLabel(context);
    final cs = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: GestureDetector(
            onTap: _recipe!.userId != null
                ? () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => UserProfileScreen(
                          userId: _recipe!.userId!,
                        ),
                      ),
                    )
                : null,
            child: Text(
              _recipe!.user != null
                  ? 'By ${_recipe!.userDisplayName}'
                  : 'By Unknown',
              style: TextStyle(
                fontFamily: 'HelveticaNow',
                color: cs.onSurfaceVariant,
                fontSize: 14,
                decoration: _recipe!.userId != null
                    ? TextDecoration.underline
                    : TextDecoration.none,
              ),
            ),
          ),
        ),
        if (posted != null) ...[
          const SizedBox(width: 12),
          Text(
            posted,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontFamily: 'HelveticaNow',
              color: cs.onSurfaceVariant,
              fontSize: 14,
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (_loading) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          title: Text(
            'Recipe',
            style: TextStyle(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        body: const Center(child: CircularProgressIndicator(color: wellGreen)),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          title: Text(
            'Recipe',
            style: TextStyle(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        body: Center(
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
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      bottomNavigationBar: _buildBottomRecipeActions(),
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: AppGradients.discoverHeroFor(context),
        ),
        child: CustomScrollView(
            controller: _recipeScrollController,
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            slivers: [
              SliverAppBar(
                pinned: true,
                stretch: true,
                expandedHeight: _recipeHeroExpandedHeight,
                elevation: 0,
                scrolledUnderElevation: 0,
                backgroundColor: colorScheme.surface,
                surfaceTintColor: Colors.transparent,
                systemOverlayStyle: SystemUiOverlayStyle.light,
                automaticallyImplyLeading: false,
                leading: _buildGlassBackButton(),
                title: _showCollapsedRecipeTitle
                    ? Text(
                        _recipe!.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colorScheme.onSurface,
                          fontWeight: FontWeight.w600,
                          fontSize: 18,
                        ),
                      )
                    : null,
                actions: [
                  if (_recipe != null && AuthService.instance.isLoggedIn)
                    PopupMenuButton<String>(
                      tooltip: 'More options',
                      icon: Icon(
                        Icons.more_vert_rounded,
                        color: wellGreen,
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
                      itemBuilder: (ctx) => [
                        if (_isOwner) ...[
                          wellnestPopupMenuItem(
                            ctx,
                            value: 'edit',
                            icon: Icons.edit_outlined,
                            label: 'Edit',
                          ),
                          wellnestPopupMenuItem(
                            ctx,
                            value: 'delete',
                            icon: Icons.delete_outline_rounded,
                            label: 'Delete',
                            iconColor: nestOrange,
                          ),
                        ],
                        if (AuthService.instance.isLoggedIn && !_isOwner)
                          wellnestPopupMenuItem(
                            ctx,
                            value: 'report',
                            icon: Icons.flag_outlined,
                            label: 'Report',
                          ),
                      ],
                    ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  stretchModes: const [StretchMode.zoomBackground],
                  background: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _openRecipePhotoGallery,
                    child: _buildHeroImageBackground(),
                  ),
                ),
              // Rounded overlap from hero → body while expanded only. When collapsed,
              // this strip is hidden (see [_showCollapsedRecipeTitle]).
                bottom: PreferredSize(
                  preferredSize: Size.fromHeight(
                    _showCollapsedRecipeTitle ? 0 : _recipeAppBarBottomInset,
                  ),
                  child: _showCollapsedRecipeTitle
                      ? const SizedBox.shrink()
                      : _buildHeroToBodyCurve(),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 32),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                _recipe!.title,
                                style: const TextStyle(
                                  fontFamily: kFontHelveticaNow,
                                  fontSize: 26,
                                  fontWeight: FontWeight.w800,
                                  color: wellGreen,
                                  height: 1.2,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: _buildRatingSummaryPill(),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _buildCreatorAndPostedRow(),
                        const SizedBox(height: 10),
                        _buildMetaRow(),
                        if (_recipe!.description != null &&
                            _recipe!.description!.trim().isNotEmpty) ...[
                          const SizedBox(height: 14),
                          Text(
                            _recipe!.description!.trim(),
                            style: TextStyle(
                              fontFamily: 'HelveticaNow',
                              fontSize: 16,
                              height: 1.45,
                              color: colorScheme.onSurface,
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),
                        Divider(height: 1, color: colorScheme.outlineVariant),
                        const SizedBox(height: 16),
                        _buildSectionTitleWithSeeAll(
                          title: 'Ingredients',
                          showSeeAll: _ingredientsNeedSeeAll(),
                          expanded: _ingredientsExpanded,
                          onToggle: () => setState(
                            () => _ingredientsExpanded = !_ingredientsExpanded,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildIngredientsList(),
                        const SizedBox(height: 24),
                        Divider(height: 1, color: colorScheme.outlineVariant),
                        const SizedBox(height: 16),
                        _buildSectionTitleWithSeeAll(
                          title: 'Instructions',
                          showSeeAll: _instructionsNeedSeeAll(),
                          expanded: _instructionsExpanded,
                          onToggle: () => setState(
                            () => _instructionsExpanded = !_instructionsExpanded,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildInstructions(),
                        const SizedBox(height: 24),
                        Divider(height: 1, color: colorScheme.outlineVariant),
                        const SizedBox(height: 16),
                        _buildRatingsAndReviewsSection(),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
    );
  }

  /// Persistent footer: like + save + Start cooking (not tied to scroll).
  Widget _buildBottomRecipeActions() {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surface,
      elevation: 6,
      shadowColor: Colors.black.withValues(alpha: 0.1),
      surfaceTintColor: Colors.transparent,
      child: SafeArea(
        top: false,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(
                color: cs.outlineVariant.withValues(alpha: 0.65),
              ),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                IconButton(
                  tooltip: 'Like',
                  onPressed: AuthService.instance.isLoggedIn && !_liking
                      ? _toggleLike
                      : null,
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
                          _liked ? Icons.favorite : Icons.favorite_border,
                          color: _liked ? Colors.pinkAccent : nestOrange,
                          size: 26,
                        ),
                ),
                IconButton(
                  tooltip: 'Save',
                  onPressed: AuthService.instance.isLoggedIn && !_saving
                      ? _toggleSave
                      : null,
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
                          _saved ? Icons.bookmark : Icons.bookmark_border,
                          color: wellGreen,
                          size: 26,
                        ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _openCookMode,
                    style: FilledButton.styleFrom(
                      backgroundColor: wellGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      minimumSize: const Size(0, 40),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadii.sm),
                      ),
                    ),
                    icon: const Icon(Icons.play_circle_outline, size: 18),
                    label: const Text(
                      'Start cooking',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
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

  /// Bottom wash — same color progression as [AppGradients.discoverHeroFadeTo].
  Widget _heroBottomFadeScrim() {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      height: 88,
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: AppGradients.recipeDetailHeroImageBottomFadeFor(context),
          ),
        ),
      ),
    );
  }

  /// Curved bridge: continues [AppGradients.discoverHeroFadeTo] into the sheet.
  Widget _buildHeroToBodyCurve() {
    return SizedBox(
      height: _recipeAppBarBottomInset,
      width: double.infinity,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        clipBehavior: Clip.antiAlias,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            gradient: AppGradients.recipeDetailHeroToBodyCurveFor(context),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openRecipePhotoGallery() {
    final urls = _recipe?.galleryDisplayUrls ?? [];
    if (urls.isEmpty) return;
    final start = _galleryIndex.clamp(0, urls.length - 1);
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (context) => FullScreenPhotoGallery(
          urls: urls,
          initialIndex: start,
        ),
      ),
    );
  }

  /// Full-bleed hero for [SliverAppBar] flexible space ([BoxFit.cover]).
  Widget _buildHeroImageBackground() {
    final urls = _recipe!.galleryDisplayUrls;
    if (urls.isEmpty) {
      return Stack(
        fit: StackFit.expand,
        children: [_buildImagePlaceholderExpanded(), _heroBottomFadeScrim()],
      );
    }
    if (urls.length == 1) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
            urls.first,
            fit: BoxFit.cover,
            alignment: Alignment.center,
            width: double.infinity,
            height: double.infinity,
            errorBuilder: (_, __, ___) => _buildImagePlaceholderExpanded(),
          ),
          _heroBottomFadeScrim(),
        ],
      );
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        PageView.builder(
          controller: _galleryPageController,
          itemCount: urls.length,
          onPageChanged: (i) => setState(() => _galleryIndex = i),
          itemBuilder: (context, i) {
            return Image.network(
              urls[i],
              fit: BoxFit.cover,
              alignment: Alignment.center,
              errorBuilder: (_, __, ___) => _buildImagePlaceholderExpanded(),
            );
          },
        ),
        _heroBottomFadeScrim(),
        Positioned(
          bottom: 40,
          left: 0,
          right: 0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_galleryIndex + 1} / ${urls.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildImagePlaceholderExpanded() {
    return ColoredBox(
      color: AppColors.imagePlaceholderGreen,
      child: Center(
        child: Icon(Icons.restaurant_menu, size: 80, color: wellGreen),
      ),
    );
  }

  /// Posted date from [Recipe.createdAt], locale-aware; null if missing/invalid.
  String? _postedDateLabel(BuildContext context) {
    final raw = _recipe?.createdAt;
    if (raw == null || raw.trim().isEmpty) return null;
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return null;
    final date = DateUtils.dateOnly(parsed.toLocal());
    return MaterialLocalizations.of(context).formatShortDate(date);
  }

  String _relativeReviewTime(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    final d = DateTime.tryParse(iso);
    if (d == null) return '';
    final diff = DateTime.now().difference(d);
    if (diff.inDays >= 365) return '${(diff.inDays / 365).floor()}y ago';
    if (diff.inDays >= 30) return '${(diff.inDays / 30).floor()}mo ago';
    if (diff.inDays >= 7) return '${(diff.inDays / 7).floor()}w ago';
    if (diff.inDays >= 1) return '${diff.inDays}d ago';
    if (diff.inHours >= 1) return '${diff.inHours}h ago';
    return 'Today';
  }

  Widget _starRowForValue(double value, {double size = 16}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final idx = i + 1;
        if (value >= idx) {
          return Icon(Icons.star_rounded, color: _reviewStarGold, size: size);
        }
        if (value >= idx - 0.5) {
          return Icon(
            Icons.star_half_rounded,
            color: _reviewStarGold,
            size: size,
          );
        }
        return Icon(
          Icons.star_border_rounded,
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.55),
          size: size,
        );
      }),
    );
  }

  String _reviewCardTitle(RecipeRating r) {
    final c = r.comment?.trim() ?? '';
    if (c.isEmpty) return 'Rated ${r.rating}/5';
    final firstLine = c.split(RegExp(r'\r?\n')).first.trim();
    if (firstLine.length <= 42) return firstLine;
    return '${firstLine.substring(0, 39)}…';
  }

  Widget _buildRatingsAndReviewsSection() {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final avg = _ratings?.averageRating ?? _recipe?.averageRating ?? 0.0;
    final count = _ratings?.ratingsCount ?? _recipe?.ratingsCount ?? 0;
    final ratings = _ratings?.ratings ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Ratings & Reviews',
                style: wellnestSectionTitleStyle(
              color: wellnestHeadingGreen(context),
            ),
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: wellGreen, size: 26),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              avg.toStringAsFixed(1),
              style: theme.textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: cs.onSurface,
                height: 1,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _starRowForValue(avg, size: 20),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.person_outline_rounded,
                        size: 16,
                        color: cs.onSurfaceVariant,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        '$count Ratings',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        if (ratings.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text(
            'Most helpful reviews',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 158,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: ratings.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, i) {
                final r = ratings[i];
                final meta = [
                  _relativeReviewTime(r.createdAt),
                  r.userDisplayName,
                ].where((s) => s.isNotEmpty).join(' · ');
                return SizedBox(
                  width: 268,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: cs.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: wellnestOutlineColor(context)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _reviewCardTitle(r),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: cs.onSurface,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            _starRowForValue(r.rating.toDouble(), size: 14),
                            const Spacer(),
                          ],
                        ),
                        if (meta.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            meta,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                        const SizedBox(height: 6),
                        Expanded(
                          child: Text(
                            r.comment?.trim().isNotEmpty == true
                                ? r.comment!.trim()
                                : 'No written review.',
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: cs.onSurface,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ] else ...[
          const SizedBox(height: 16),
          Text(
            'No reviews yet — open Write a review below.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
        ],
        const SizedBox(height: 20),
        _buildWriteReviewExpandable(),
      ],
    );
  }

  Widget _buildWriteReviewExpandable() {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final hasUserRating = _userRating != null;
    final loggedIn = AuthService.instance.isLoggedIn;

    if (hasUserRating) {
      return Text(
        'You rated this ${_userRating!.rating}/5${_userRating!.comment != null && _userRating!.comment!.trim().isNotEmpty ? ': "${_userRating!.comment}"' : ''}',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: cs.onSurfaceVariant,
          fontSize: 14,
          fontStyle: FontStyle.italic,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.tonalIcon(
          onPressed: () {
            if (!loggedIn) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Sign in to write a review.'),
                  backgroundColor: wellGreen,
                ),
              );
              return;
            }
            setState(() => _writeReviewExpanded = !_writeReviewExpanded);
          },
          icon: Icon(
            _writeReviewExpanded ? Icons.expand_less : Icons.edit_outlined,
            color: cs.primary,
          ),
          label: Text(
            _writeReviewExpanded ? 'Hide review form' : 'Write a review',
            style: TextStyle(fontWeight: FontWeight.w600, color: cs.onSurface),
          ),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ),
        AnimatedCrossFade(
          duration: AppDurations.medium,
          crossFadeState: _writeReviewExpanded && loggedIn
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          firstChild: const SizedBox(width: double.infinity),
          secondChild: loggedIn
              ? Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(5, (i) {
                          final star = i + 1;
                          final selected = (_pendingStars ?? 0) >= star;
                          return IconButton(
                            onPressed: () =>
                                setState(() => _pendingStars = star),
                            icon: Icon(
                              selected
                                  ? Icons.star_rounded
                                  : Icons.star_outline_rounded,
                              color: selected
                                  ? _reviewStarGold
                                  : cs.outline.withValues(alpha: 0.55),
                              size: 32,
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            constraints: const BoxConstraints(
                              minWidth: 40,
                              minHeight: 40,
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _reviewController,
                        maxLength: 1000,
                        maxLines: 4,
                        decoration: InputDecoration(
                          hintText: 'Tell others what you thought (optional)…',
                          hintStyle: TextStyle(
                            fontFamily: 'HelveticaNow',
                            color: cs.onSurfaceVariant.withValues(alpha: 0.65),
                          ),
                          filled: true,
                          fillColor: cs.surface,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: wellnestOutlineColor(context),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: wellnestOutlineColor(context),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: cs.primary,
                              width: 1.5,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          counterText: '',
                        ),
                      ),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: _submittingRating
                            ? null
                            : () async {
                                if ((_pendingStars ?? 0) < 1) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Choose a star rating first.',
                                      ),
                                      backgroundColor: nestOrange,
                                    ),
                                  );
                                  return;
                                }
                                setState(() => _submittingRating = true);
                                try {
                                  await RatingService.instance.submitRating(
                                    recipeId: _recipe!.id,
                                    rating: _pendingStars!,
                                    comment:
                                        _reviewController.text.trim().isEmpty
                                        ? null
                                        : _reviewController.text.trim(),
                                  );
                                  if (!mounted) return;
                                  _reviewController.clear();
                                  setState(() {
                                    _submittingRating = false;
                                    _pendingStars = null;
                                    _writeReviewExpanded = false;
                                  });
                                  _load();
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Thanks for your review!',
                                        ),
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
                                          e.toString().replaceFirst(
                                            'Exception: ',
                                            '',
                                          ),
                                        ),
                                        backgroundColor: nestOrange,
                                      ),
                                    );
                                  }
                                }
                              },
                        style: FilledButton.styleFrom(
                          backgroundColor: wellGreen,
                          minimumSize: const Size(double.infinity, 46),
                        ),
                        child: _submittingRating
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Submit review'),
                      ),
                    ],
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _buildMetaRow() {
    final hasCategory = _recipe!.category != null;
    final w = MediaQuery.sizeOf(context).width;
    const horizontalGutter = 48.0;
    final usable = (w - horizontalGutter).clamp(120.0, double.infinity);
    final categoryCap = (usable * 0.52).clamp(140.0, 260.0).toDouble();
    final categoryLabelMax = (categoryCap - 44).clamp(72.0, 240.0);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _MetaChip(
          icon: Icons.schedule_rounded,
          label: _recipe!.displayPrepLabel,
        ),
        if (hasCategory) ...[
          const SizedBox(width: 8),
          _MetaChip(
            icon: Icons.category_rounded,
            label: _recipe!.category!.name,
            labelMaxWidth: categoryLabelMax,
          ),
        ],
      ],
    );
  }

  Widget _buildSectionTitleWithSeeAll({
    required String title,
    required bool showSeeAll,
    required bool expanded,
    required VoidCallback onToggle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Text(
            title,
            style: wellnestSectionTitleStyle(
              color: wellnestHeadingGreen(context),
            ),
          ),
        ),
        if (showSeeAll)
          TextButton(
            onPressed: onToggle,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.only(left: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              foregroundColor: wellGreen,
            ),
            child: Text(
              expanded ? 'Show less' : 'See all',
              style: const TextStyle(
                fontFamily: kFontHelveticaNow,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
      ],
    );
  }

  double _ingredientLabelMaxWidth(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    const horizontalPadding = 48.0;
    const bulletAndGap = 18.0;
    return (w - horizontalPadding - bulletAndGap).clamp(120.0, double.infinity);
  }

  int _ingredientTotalDisplayLines() {
    final ingredients = _recipe?.ingredients;
    if (ingredients == null || ingredients.isEmpty) return 0;
    final maxW = _ingredientLabelMaxWidth(context);
    final style = Theme.of(context).textTheme.bodyLarge!.copyWith(
          height: 1.5,
          color: Theme.of(context).colorScheme.onSurface,
        );
    var n = 0;
    for (final ing in ingredients) {
      final tp = TextPainter(
        text: TextSpan(text: ing.displayLine, style: style),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: maxW);
      n += tp.computeLineMetrics().length;
    }
    return n;
  }

  bool _ingredientsNeedSeeAll() {
    return _ingredientTotalDisplayLines() > _kIngredientsCollapsedMaxLines;
  }

  double _instructionCardBodyMaxWidth(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    const outerPad = 48.0;
    const cardHorizontalPad = 24.0;
    const avatarAndGap = 48.0;
    return (w - outerPad - cardHorizontalPad - avatarAndGap)
        .clamp(100.0, double.infinity);
  }

  int _instructionSingleBlockLineCount(String text) {
    if (text.isEmpty) return 0;
    final maxW = _instructionCardBodyMaxWidth(context);
    final style = Theme.of(context).textTheme.bodyMedium!.copyWith(
          height: 1.45,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        );
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: maxW);
    return tp.computeLineMetrics().length;
  }

  /// Visual hint under clipped sections; tap expands same as **See all**.
  Widget _collapsedMoreBelowHint({required VoidCallback onTap}) {
    final surface = Theme.of(context).colorScheme.surface;
    final bottomTint =
        Color.lerp(AppColors.heroPaleGreen, surface, 0.42) ?? surface;
    return Tooltip(
      message: 'See all',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            alignment: Alignment.bottomCenter,
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        bottomTint.withValues(alpha: 0),
                        bottomTint.withValues(alpha: 0.94),
                      ],
                      stops: const [0.35, 1.0],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 26,
                  color: wellGreen.withValues(alpha: 0.45),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _instructionsNeedSeeAll() {
    final r = _recipe;
    if (r == null) return false;
    if (r.hasStructuredSteps && (r.steps?.isNotEmpty ?? false)) {
      return r.steps!.length > _kInstructionsCollapsedMaxSteps;
    }
    final steps = r.instructions
        .split(RegExp(r'\r?\n'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    if (steps.length <= 1) {
      final t = r.instructions.trim();
      if (t.isEmpty) return false;
      return _instructionSingleBlockLineCount(t) >
          _kInstructionsCollapsedMaxSteps;
    }
    return steps.length > _kInstructionsCollapsedMaxSteps;
  }

  Widget _buildIngredientsList() {
    final theme = Theme.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final ingredients = _recipe!.ingredients;
    if (ingredients == null || ingredients.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(
          'No ingredients listed.',
          style: TextStyle(
            fontFamily: 'HelveticaNow',
            color: colorScheme.onSurfaceVariant,
            fontSize: 15,
          ),
        ),
      );
    }

    final textStyle = theme.textTheme.bodyLarge?.copyWith(
      color: colorScheme.onSurface,
      height: 1.5,
    );
    final lineHeight =
        (textStyle?.fontSize ?? 16) * (textStyle?.height ?? 1.5);
    final collapsedHeight = lineHeight * _kIngredientsCollapsedMaxLines;

    final collapse =
        !_ingredientsExpanded && _ingredientsNeedSeeAll();

    final column = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: ingredients.map((ing) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 7),
                child: Icon(
                  Icons.circle,
                  size: 8,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  ing.displayLine,
                  style: textStyle,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );

    final padded = Padding(
      padding: const EdgeInsets.only(top: 8),
      child: column,
    );

    if (!collapse) return padded;

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: SizedBox(
        height: collapsedHeight,
        child: Stack(
          clipBehavior: Clip.hardEdge,
          fit: StackFit.expand,
          children: [
            ClipRect(
              child: SingleChildScrollView(
                physics: const NeverScrollableScrollPhysics(),
                child: column,
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: _kCollapsedMoreBelowBandHeight,
              child: _collapsedMoreBelowHint(
                onTap: () => setState(() => _ingredientsExpanded = !_ingredientsExpanded),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Image band width:height — similar strip feel to [WellnestRecipeCard] hero.
  static const double _instructionStepImageAspectRatio = 16 / 10;

  /// Matches create-recipe review step cards ([RecipeFormScreen] review list).
  BoxDecoration _instructionReviewCardDecoration(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return BoxDecoration(
      color: cs.surface,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: wellnestOutlineColor(context)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.04),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    );
  }

  Widget _buildInstructions() {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    if (_recipe!.hasStructuredSteps) {
      final list = _recipe!.steps!;
      final visibleList =
          (!_instructionsExpanded && list.length > _kInstructionsCollapsedMaxSteps)
              ? list.take(_kInstructionsCollapsedMaxSteps).toList()
              : list;
      final showMoreHint = !_instructionsExpanded &&
          list.length > _kInstructionsCollapsedMaxSteps;
      final stepsColumn = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: visibleList.asMap().entries.map((e) {
            final stepIndex = e.key + 1;
            final s = e.value;
            final title = s.displayTitle(stepIndex);
            final body = s.instructions?.trim() ?? '';
            final imgUrl = s.image?.displayUrl ?? s.image?.url;
            final hasThumb = imgUrl != null && imgUrl.trim().isNotEmpty;
            final showPrepChip =
                _recipe!.prepTimingMode == PrepTimingMode.perStep &&
                (s.prepTimeMinutes != null && s.prepTimeMinutes! > 0);

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Container(
                width: double.infinity,
                decoration: _instructionReviewCardDecoration(context),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (hasThumb)
                      AspectRatio(
                        aspectRatio: _instructionStepImageAspectRatio,
                        child: Image.network(
                          imgUrl.trim(),
                          fit: BoxFit.cover,
                          width: double.infinity,
                          alignment: Alignment.center,
                          errorBuilder: (_, __, ___) => ColoredBox(
                            color: cs.surfaceContainerHighest,
                            child: Icon(
                              Icons.image_not_supported_outlined,
                              color: cs.outline,
                              size: 40,
                            ),
                          ),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: wellGreen.withValues(alpha: 0.12),
                            child: Text(
                              '$stepIndex',
                              style: TextStyle(
                                color: wellGreen,
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: cs.onSurface,
                                  ),
                                ),
                                if (showPrepChip) ...[
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.timer_outlined,
                                        size: 14,
                                        color: cs.onSurfaceVariant,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${s.prepTimeMinutes} min',
                                        style: theme.textTheme.labelSmall
                                            ?.copyWith(
                                              color: cs.onSurfaceVariant,
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                    ],
                                  ),
                                ],
                                if (body.isNotEmpty) ...[
                                  SizedBox(height: showPrepChip ? 8 : 6),
                                  SelectableText(
                                    body,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: cs.onSurfaceVariant,
                                      height: 1.45,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
      );
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: showMoreHint
            ? Stack(
                clipBehavior: Clip.none,
                children: [
                  stepsColumn,
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: _kCollapsedMoreBelowBandHeight,
                    child: _collapsedMoreBelowHint(
                      onTap: () =>
                          setState(() => _instructionsExpanded = !_instructionsExpanded),
                    ),
                  ),
                ],
              )
            : stepsColumn,
      );
    }

    final steps = _recipe!.instructions
        .split(RegExp(r'\r?\n'))
        .map((step) => step.trim())
        .where((step) => step.isNotEmpty)
        .toList();

    if (steps.length <= 1) {
      final text = _recipe!.instructions.trim();
      final collapseSingle = !_instructionsExpanded &&
          text.isNotEmpty &&
          _instructionSingleBlockLineCount(text) > _kInstructionsCollapsedMaxSteps;
      final card = Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: _instructionReviewCardDecoration(context),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: wellGreen.withValues(alpha: 0.12),
              child: Text(
                '1',
                style: TextStyle(
                  color: wellGreen,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SelectableText(
                text.isEmpty ? '—' : text,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                  height: 1.45,
                ),
                maxLines: collapseSingle ? _kInstructionsCollapsedMaxSteps : null,
              ),
            ),
          ],
        ),
      );
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: collapseSingle
            ? Stack(
                clipBehavior: Clip.none,
                children: [
                  card,
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: _kCollapsedMoreBelowBandHeight,
                    child: _collapsedMoreBelowHint(
                      onTap: () =>
                          setState(() => _instructionsExpanded = !_instructionsExpanded),
                    ),
                  ),
                ],
              )
            : card,
      );
    }

    final visibleSteps =
        (!_instructionsExpanded && steps.length > _kInstructionsCollapsedMaxSteps)
            ? steps.take(_kInstructionsCollapsedMaxSteps).toList()
            : steps;

    final plainMoreHint = !_instructionsExpanded &&
        steps.length > _kInstructionsCollapsedMaxSteps;

    final plainColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(visibleSteps.length, (index) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: _instructionReviewCardDecoration(context),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: wellGreen.withValues(alpha: 0.12),
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(
                        color: wellGreen,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SelectableText(
                      visibleSteps[index],
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
    );

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: plainMoreHint
          ? Stack(
              clipBehavior: Clip.none,
              children: [
                plainColumn,
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: _kCollapsedMoreBelowBandHeight,
                  child: _collapsedMoreBelowHint(
                    onTap: () =>
                        setState(() => _instructionsExpanded = !_instructionsExpanded),
                  ),
                ),
              ],
            )
          : plainColumn,
    );
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;

  /// Caps label width with ellipsis (long category names). Omit for intrinsic width (prep time).
  final double? labelMaxWidth;

  const _MetaChip({
    required this.icon,
    required this.label,
    this.labelMaxWidth,
  });

  static const Color wellGreen = Color(0xFF097333);

  @override
  Widget build(BuildContext context) {
    final textStyle = const TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: wellGreen,
    );
    final lw = labelMaxWidth;
    final labelWidget = lw != null
        ? ConstrainedBox(
            constraints: BoxConstraints(maxWidth: lw),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textStyle,
            ),
          )
        : Text(label, style: textStyle);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: wellGreen.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: wellGreen),
          const SizedBox(width: 6),
          labelWidget,
        ],
      ),
    );
  }
}
