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

class RecipeDetailScreen extends StatefulWidget {
  final int recipeId;

  const RecipeDetailScreen({super.key, required this.recipeId});

  @override
  State<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends State<RecipeDetailScreen> {
  static const Color wellGreen = Color(0xFF097333);
  static const Color nestOrange = Color(0xFFEF5026);

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
  final PageController _galleryPageController = PageController();
  int _galleryIndex = 0;
  int? _currentUserId;
  bool get _isOwner =>
      _recipe != null &&
      _currentUserId != null &&
      _recipe!.userId == _currentUserId;

  @override
  void dispose() {
    _galleryPageController.dispose();
    _reviewController.dispose();
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
        actions: [
          if (_recipe != null && AuthService.instance.isLoggedIn)
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, color: colorScheme.onSurface),
              onSelected: (v) async {
                if (v == 'edit') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => RecipeFormScreen(recipe: _recipe),
                    ),
                  ).then((_) => _load());
                } else if (v == 'report' && AuthService.instance.isLoggedIn) {
                  await _reportRecipe();
                } else if (v == 'delete') {
                  await _deleteRecipe();
                }
              },
              itemBuilder: (context) => [
                if (_isOwner)
                  const PopupMenuItem(value: 'delete', child: Text('Delete')),
                if (_isOwner)
                  const PopupMenuItem(value: 'edit', child: Text('Edit')),
                if (AuthService.instance.isLoggedIn)
                  const PopupMenuItem(value: 'report', child: Text('Report')),
              ],
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: wellGreen))
          : _error != null
          ? Center(
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
            )
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildRecipeImage(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Step 1: Title & Author
                        Text(
                          _recipe!.title,
                          style: georgiaProTextStyle(
                            fontSize: 26,
                            color: wellGreen,
                          ).copyWith(letterSpacing: 0),
                        ),
                        if (_recipe!.description != null &&
                            _recipe!.description!.trim().isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Text(
                            _recipe!.description!.trim(),
                            style: TextStyle(
                              fontFamily: 'HelveticaNow',
                              fontSize: 16,
                              height: 1.45,
                              color: Colors.grey.shade800,
                            ),
                          ),
                        ],
                        const SizedBox(height: 6),
                        GestureDetector(
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
                              color: Colors.grey.shade600,
                              fontSize: 14,
                              decoration: _recipe!.userId != null
                                  ? TextDecoration.underline
                                  : TextDecoration.none,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Tags & Ratings Row (horizontal)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            _buildMetaRow(),
                            const Spacer(),
                            const Icon(
                              Icons.star,
                              color: Color(0xFFF9BD21),
                              size: 20,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${(_ratings?.averageRating ?? _recipe?.averageRating ?? 0.0).toStringAsFixed(1)} (${_ratings?.ratingsCount ?? _recipe?.ratingsCount ?? 0})',
                              style: TextStyle(
                                fontFamily: 'HelveticaNow',
                                fontSize: 14,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Step 3: Action Buttons
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed:
                                    AuthService.instance.isLoggedIn && !_liking
                                    ? () async {
                                        setState(() => _liking = true);
                                        try {
                                          if (_liked) {
                                            await VoteService.instance
                                                .unlikeRecipe(_recipe!.id);
                                            if (mounted) {
                                              setState(() => _liked = false);
                                            }
                                          } else {
                                            await VoteService.instance
                                                .likeRecipe(_recipe!.id);
                                            if (mounted) {
                                              setState(() => _liked = true);
                                            }
                                          }
                                        } catch (e) {
                                          if (mounted) {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  e.toString().replaceFirst(
                                                    'Exception: ',
                                                    '',
                                                  ),
                                                ),
                                              ),
                                            );
                                          }
                                        } finally {
                                          if (mounted) {
                                            setState(() => _liking = false);
                                          }
                                        }
                                      }
                                    : null,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: nestOrange,
                                  side: const BorderSide(color: nestOrange),
                                ),
                                child: _liking
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: nestOrange,
                                        ),
                                      )
                                    : Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            _liked
                                                ? Icons.favorite
                                                : Icons.favorite_border,
                                            size: 20,
                                            color: _liked
                                                ? Colors.pink
                                                : nestOrange,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            _liked ? 'Liked' : 'Like',
                                            style: const TextStyle(
                                              color: nestOrange,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                              ),
                            ),
                            AppSpacing.gapH16,
                            Expanded(
                              child: OutlinedButton(
                                onPressed:
                                    AuthService.instance.isLoggedIn && !_saving
                                    ? () async {
                                        setState(() => _saving = true);
                                        try {
                                          if (_saved) {
                                            await SavedRecipeService.instance
                                                .unsaveRecipe(_recipe!.id);
                                            if (mounted) {
                                              setState(() => _saved = false);
                                            }
                                          } else {
                                            await SavedRecipeService.instance
                                                .saveRecipe(_recipe!.id);
                                            if (mounted) {
                                              setState(() => _saved = true);
                                            }
                                          }
                                          if (mounted) {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  _saved
                                                      ? 'Saved to favorites'
                                                      : 'Removed from favorites',
                                                ),
                                                backgroundColor: wellGreen,
                                              ),
                                            );
                                          }
                                        } catch (e) {
                                          if (mounted) {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  e.toString().replaceFirst(
                                                    'Exception: ',
                                                    '',
                                                  ),
                                                ),
                                              ),
                                            );
                                          }
                                        } finally {
                                          if (mounted) {
                                            setState(() => _saving = false);
                                          }
                                        }
                                      }
                                    : null,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: wellGreen,
                                  side: const BorderSide(color: wellGreen),
                                ),
                                child: _saving
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: wellGreen,
                                        ),
                                      )
                                    : Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            _saved
                                                ? Icons.bookmark
                                                : Icons.bookmark_border,
                                            size: 20,
                                            color: wellGreen,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            _saved ? 'Saved' : 'Save',
                                            style: const TextStyle(
                                              color: wellGreen,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        // Step 4: Flat content sections
                        Divider(height: 1, color: Colors.grey[300]),
                        const SizedBox(height: 16),
                        _buildSectionTitle('Reviews'),
                        const SizedBox(height: 12),
                        _buildInteractiveRating(),
                        AppSpacing.gapV8,
                        _buildReviewsList(),
                        const SizedBox(height: 24),
                        Divider(height: 1, color: Colors.grey[300]),
                        const SizedBox(height: 16),
                        _buildSectionTitle('Ingredients'),
                        const SizedBox(height: 12),
                        _buildIngredientsList(),
                        const SizedBox(height: 24),
                        Divider(height: 1, color: Colors.grey[300]),
                        const SizedBox(height: 16),
                        _buildSectionTitle('Instructions'),
                        const SizedBox(height: 12),
                        _buildInstructions(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildRecipeImage() {
    const double imageHeight = 240;
    final urls = _recipe!.galleryDisplayUrls;
    if (urls.isEmpty) {
      return _buildImagePlaceholder(imageHeight);
    }
    if (urls.length == 1) {
      return Container(
        height: imageHeight,
        width: double.infinity,
        color: AppColors.imagePlaceholderGreen,
        child: Image.network(
          urls.first,
          fit: BoxFit.cover,
          alignment: Alignment.center,
          errorBuilder: (_, __, ___) => _buildImagePlaceholder(imageHeight),
        ),
      );
    }
    return SizedBox(
      height: imageHeight,
      width: double.infinity,
      child: Stack(
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
                errorBuilder: (_, __, ___) =>
                    _buildImagePlaceholder(imageHeight),
              );
            },
          ),
          Positioned(
            bottom: 10,
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
      ),
    );
  }

  Widget _buildImagePlaceholder(double height) {
    return Container(
      height: height,
      width: double.infinity,
      color: AppColors.imagePlaceholderGreen,
      child: Icon(Icons.restaurant_menu, size: 80, color: wellGreen),
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

  Widget _buildMetaRow() {
    final hasCategory = _recipe!.category != null;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _MetaChip(
          icon: Icons.schedule_rounded,
          label: '${_recipe!.prepTime} min',
        ),
        if (hasCategory) ...[
          const SizedBox(width: 8),
          _MetaChip(
            icon: Icons.category_rounded,
            label: _recipe!.category!.name,
          ),
        ],
      ],
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
    final colorScheme = Theme.of(context).colorScheme;
    final ingredients = _recipe!.ingredients;
    if (ingredients == null || ingredients.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(
          'No ingredients listed.',
          style: TextStyle(
            fontFamily: 'HelveticaNow',
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
        children: ingredients.map((ing) {
          final qty = ing.quantity.toInt() == ing.quantity
              ? ing.quantity.toInt().toString()
              : ing.quantity.toString();
          final amount = ing.unit.isEmpty ? qty : '$qty ${ing.unit}';
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
                    amount.isNotEmpty ? '$amount ${ing.name}' : ing.name,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: colorScheme.onSurface,
                      height: 1.5,
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

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MetaChip({required this.icon, required this.label});

  static const Color wellGreen = Color(0xFF097333);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: wellGreen.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: wellGreen),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: wellGreen,
            ),
          ),
        ],
      ),
    );
  }
}
