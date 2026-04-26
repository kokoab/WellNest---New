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
import 'package:my_app/services/user_service.dart';
import 'package:my_app/screens/user_profile_screen.dart';
class RecipeDetailScreen extends StatefulWidget {
  final int recipeId;

  const RecipeDetailScreen({super.key, required this.recipeId});

  @override
  State<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends State<RecipeDetailScreen> {

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
  bool _editingRating = false;
  final TextEditingController _reviewController = TextEditingController();
  int? _currentUserId;
  bool get _isOwner =>
      _recipe != null &&
      _currentUserId != null &&
      _recipe!.userId == _currentUserId;

  @override
  void dispose() {
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
      RecipeRatingsResponse? ratings;
      RecipeRating? userRating;
      try {
        ratings = await RatingService.instance.fetchRatings(widget.recipeId);
        if (AuthService.instance.isLoggedIn) {
          userRating = await RatingService.instance.fetchUserRating(
            widget.recipeId,
          );
          _saved = await SavedRecipeService.instance.isSaved(widget.recipeId);
        }
      } catch (_) {}

      if (AuthService.instance.isLoggedIn) {
        final user = await UserService.instance.fetchCurrentUser();
        if (mounted && user != null) {
          setState(() => _currentUserId = user.id);
        }
      }
      if (!mounted) return;
      setState(() {
        _recipe = recipe;
        _ratings = ratings;
        _userRating = userRating;
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
          SnackBar(
            content: const Text('Report submitted'),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: Theme.of(context).colorScheme.secondary,
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
        SnackBar(
          content: const Text('Recipe deleted'),
          backgroundColor: Theme.of(context).colorScheme.primary,
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: Theme.of(context).colorScheme.secondary,
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
        title: Text('Recipe', style: theme.textTheme.titleLarge),
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
          ? Center(child: CircularProgressIndicator(color: colorScheme.primary))
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
                      style: TextStyle(color: colorScheme.secondary),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _load,
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
                          style: theme.textTheme.headlineSmall?.copyWith(
                            height: 1.25,
                          ),
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
                                      builder: (context) =>
                                          UserProfileScreen(userId: _recipe!.userId!),
                                    ),
                                  )
                              : null,
                          child: Text(
                            _recipe!.user != null
                                ? 'By ${_recipe!.userDisplayName}'
                                : 'By Unknown',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
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
                            Icon(
                              Icons.star_rounded,
                              color: kAccentYellow,
                              size: 20,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${(_ratings?.averageRating ?? _recipe?.averageRating ?? 0.0).toStringAsFixed(1)} (${_ratings?.ratingsCount ?? _recipe?.ratingsCount ?? 0})',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant,
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
                                onPressed: AuthService.instance.isLoggedIn &&
                                        !_liking
                                    ? () async {
                                        setState(() => _liking = true);
                                        try {
                                          if (_liked) {
                                            await VoteService.instance
                                                .unlikeRecipe(_recipe!.id);
                                            if (mounted)
                                              setState(() => _liked = false);
                                          } else {
                                            await VoteService.instance
                                                .likeRecipe(_recipe!.id);
                                            if (mounted)
                                              setState(() => _liked = true);
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
                                          if (mounted)
                                            setState(() => _liking = false);
                                        }
                                      }
                                    : null,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: colorScheme.secondary,
                                  side: BorderSide(color: colorScheme.secondary),
                                ),
                                child: _liking
                                    ? SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: colorScheme.secondary,
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
                                                : colorScheme.secondary,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            _liked ? 'Liked' : 'Like',
                                            style: TextStyle(
                                              color: colorScheme.secondary,
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
                                onPressed: AuthService.instance.isLoggedIn &&
                                        !_saving
                                    ? () async {
                                        setState(() => _saving = true);
                                        try {
                                          if (_saved) {
                                            await SavedRecipeService.instance
                                                .unsaveRecipe(_recipe!.id);
                                            if (mounted)
                                              setState(() => _saved = false);
                                          } else {
                                            await SavedRecipeService.instance
                                                .saveRecipe(_recipe!.id);
                                            if (mounted)
                                              setState(() => _saved = true);
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
                                                backgroundColor: colorScheme.primary,
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
                                          if (mounted)
                                            setState(() => _saving = false);
                                        }
                                      }
                                    : null,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: colorScheme.primary,
                                  side: BorderSide(color: colorScheme.primary),
                                ),
                                child: _saving
                                    ? SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: colorScheme.primary,
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
                                            color: colorScheme.primary,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            _saved ? 'Saved' : 'Save',
                                            style: TextStyle(
                                              color: colorScheme.primary,
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
                        Divider(height: 1, color: colorScheme.outlineVariant),
                        const SizedBox(height: 16),
                        _buildSectionTitle('Reviews'),
                        const SizedBox(height: 12),
                        _buildInteractiveRating(),
                        AppSpacing.gapV8,
                        _buildReviewsList(),
                        const SizedBox(height: 24),
                        Divider(height: 1, color: colorScheme.outlineVariant),
                        const SizedBox(height: 16),
                        _buildSectionTitle('Ingredients'),
                        const SizedBox(height: 12),
                        _buildIngredientsList(),
                        const SizedBox(height: 24),
                        Divider(height: 1, color: colorScheme.outlineVariant),
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
    if (_recipe!.displayImageUrl != null &&
        _recipe!.displayImageUrl!.isNotEmpty) {
      return Container(
        height: imageHeight,
        width: double.infinity,
        color: AppColors.imagePlaceholderGreen,
        child: Image.network(
          _recipe!.displayImageUrl!,
          fit: BoxFit.cover,
          alignment: Alignment.center,
          cacheWidth: 800,
          cacheHeight: 480,
          errorBuilder: (_, __, ___) => _buildImagePlaceholder(imageHeight),
        ),
      );
    }
    return _buildImagePlaceholder(imageHeight);
  }

  Widget _buildImagePlaceholder(double height) {
    return Container(
      height: height,
      width: double.infinity,
      color: AppColors.imagePlaceholderGreen,
      child: Icon(Icons.restaurant_menu, size: 80, color: kPrimaryGreen),
    );
  }

  Widget _buildReviewsList() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final ratings = _ratings?.ratings ?? [];
    if (ratings.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(
          'No reviews yet. Be the first to rate!',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
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
                style: theme.textTheme.titleSmall?.copyWith(
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                r.comment ?? '',
                style: theme.textTheme.bodyMedium?.copyWith(
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final hasUserRating = _userRating != null;
    final isLoggedIn = AuthService.instance.isLoggedIn;
    final showForm = isLoggedIn && (!hasUserRating || _editingRating);

    if (!showForm && hasUserRating) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                'You rated this ${_userRating!.rating}/5${_userRating!.comment != null && _userRating!.comment!.isNotEmpty ? ': "${_userRating!.comment}"' : ''}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
            const SizedBox(width: 8),
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _editingRating = true;
                  _pendingStars = _userRating!.rating;
                  _reviewController.text = _userRating!.comment ?? '';
                });
              },
              icon: const Icon(Icons.edit_outlined, size: 16),
              label: const Text('Edit'),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ),
      );
    }

    if (!isLoggedIn) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                _editingRating ? 'Update your rating: ' : 'Tap to rate: ',
                style: theme.textTheme.titleSmall,
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(5, (i) {
                  final star = i + 1;
                  final selected = (_pendingStars ?? 0) >= star;
                  return IconButton(
                    onPressed: () => setState(() => _pendingStars = star),
                    icon: Icon(
                      selected ? Icons.star_rounded : Icons.star_border_rounded,
                      color: selected
                          ? kAccentYellow
                          : colorScheme.outlineVariant,
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
              decoration: const InputDecoration(
                hintText: 'Write a review (optional)...',
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                if (_editingRating) ...[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        setState(() {
                          _editingRating = false;
                          _pendingStars = null;
                          _reviewController.clear();
                        });
                      },
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: FilledButton(
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
                                _editingRating = false;
                              });
                              _load();
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      _editingRating
                                          ? 'Rating updated!'
                                          : 'Thanks for your rating!',
                                    ),
                                    backgroundColor: colorScheme.primary,
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
                                    backgroundColor: colorScheme.secondary,
                                  ),
                                );
                              }
                            }
                          },
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 44),
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
                        : Text(_editingRating
                            ? 'Update rating'
                            : 'Submit rating'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(title, style: Theme.of(context).textTheme.titleMedium);
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
            fontFamily: kFontAppFamily,
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

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: colorScheme.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}