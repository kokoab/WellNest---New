import 'package:flutter/material.dart';
import 'package:my_app/models/recipe.dart';
import 'package:my_app/theme/app_theme.dart';

/// Discover masonry card — ratings chip on the image; prep time plain in the footer.
class WellnestRecipeCard extends StatelessWidget {
  static const double _radius = 16;

  /// Bookmark hit target on the image; ratings chip uses the same vertical extent.
  static const double _overlayChipHeight = 30;
  static const EdgeInsets _ratingsChipPadding = EdgeInsets.symmetric(
    horizontal: 10,
    vertical: 6,
  );

  final Recipe recipe;
  final VoidCallback? onBookmarkTap;
  final bool bookmarkSaving;
  final bool isBookmarked;

  /// Image band width / height only; footer height follows title (multi-line) and metadata.
  /// Use ~0.65–0.75 for portrait photo strips in masonry grids.
  final double aspectRatio;
  final String? heroTag;

  const WellnestRecipeCard({
    super.key,
    required this.recipe,
    required this.onBookmarkTap,
    required this.bookmarkSaving,
    required this.isBookmarked,
    required this.aspectRatio,
    this.heroTag,
  });

  Color _outlineColor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.light
      ? const Color(0xFFC5C5C5).withValues(alpha: 0.95)
      : Colors.white.withValues(alpha: 0.18);

  /// Slight per-recipe jitter so image band heights vary in masonry columns.
  double _imageBandAspectRatio() {
    final delta = ((recipe.id % 11) - 5) * 0.007;
    return (aspectRatio + delta).clamp(0.62, 0.78);
  }

  @override
  Widget build(BuildContext context) {
    final authorLine =
        recipe.user != null && recipe.userDisplayName.trim().isNotEmpty
        ? 'By ${recipe.userDisplayName}'
        : 'By WellNest Community';
    final categoryLine = recipe.category?.name.trim().isNotEmpty == true
        ? recipe.category!.name
        : 'Uncategorized';
    final viewsCount = recipe.viewsCount ?? 0;
    final avgRating = (recipe.averageRating ?? 0).toStringAsFixed(1);

    Widget card = Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_radius),
        border: Border.all(color: _outlineColor(context), width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            aspectRatio: _imageBandAspectRatio(),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(_radius),
                    ),
                    child: _buildImage(),
                  ),
                ),
                Positioned(
                  top: 10,
                  left: 10,
                  child: Container(
                    constraints: const BoxConstraints(
                      minHeight: _overlayChipHeight,
                    ),
                    padding: _ratingsChipPadding,
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
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.star_rounded,
                          size: 14,
                          color: AppColors.accentYellow,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          avgRating,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                            height: 1,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (onBookmarkTap != null)
                  Positioned(
                    top: 10,
                    right: 10,
                    child: SizedBox(
                      width: _overlayChipHeight,
                      height: _overlayChipHeight,
                      child: IconButton.filledTonal(
                        onPressed: bookmarkSaving ? null : onBookmarkTap,
                        icon: bookmarkSaving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Icon(
                                isBookmarked
                                    ? Icons.bookmark
                                    : Icons.bookmark_border,
                                color: isBookmarked
                                    ? AppColors.accentOrange
                                    : AppColors.primaryGreen,
                                size: 18,
                              ),
                        tooltip: isBookmarked
                            ? 'Remove favorite'
                            : 'Save favorite',
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white.withValues(alpha: 0.9),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          fixedSize: const Size(
                            _overlayChipHeight,
                            _overlayChipHeight,
                          ),
                          iconSize: 18,
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  recipe.title,
                  maxLines: 5,
                  overflow: TextOverflow.ellipsis,
                  style: helveticaNow(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey.shade900,
                  ).copyWith(height: 1.25),
                ),
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        authorLine,
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.schedule_rounded,
                          size: 13,
                          color: AppColors.primaryGreen.withValues(alpha: 0.85),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          recipe.displayPrepLabel,
                          style: TextStyle(
                            color: Colors.grey.shade800,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.1,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.flatware_rounded,
                      size: 13,
                      color: AppColors.primaryGreen.withValues(alpha: 0.85),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        categoryLine,
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.visibility_outlined,
                          size: 13,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          '$viewsCount',
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
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
    );

    if (heroTag != null) {
      card = Hero(
        tag: heroTag!,
        child: Material(color: Colors.transparent, child: card),
      );
    }

    return card;
  }

  Widget _buildImage() {
    if (recipe.displayImageUrl != null && recipe.displayImageUrl!.isNotEmpty) {
      return Image.network(
        recipe.displayImageUrl!,
        fit: BoxFit.cover,
        alignment: Alignment.center,
        width: double.infinity,
        height: double.infinity,
        cacheWidth: 600,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            color: AppColors.imagePlaceholderGreen,
            child: const Center(
              child: CircularProgressIndicator(color: AppColors.primaryGreen),
            ),
          );
        },
        errorBuilder: (_, _, _) => _placeholder(),
      );
    }
    return _placeholder();
  }

  Widget _placeholder() {
    return ColoredBox(
      color: AppColors.imagePlaceholderGreen,
      child: Center(
        child: Icon(
          Icons.restaurant_menu_rounded,
          size: 38,
          color: AppColors.primaryGreen.withValues(alpha: 0.35),
        ),
      ),
    );
  }
}
