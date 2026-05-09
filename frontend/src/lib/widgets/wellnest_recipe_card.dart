import 'package:flutter/material.dart';
import 'package:my_app/models/recipe.dart';
import 'package:my_app/theme/app_spacing.dart';
import 'package:my_app/theme/app_theme.dart';

/// Discover grid card: image stack with gradients, bookmark top-right, title on image.
class WellnestRecipeCard extends StatelessWidget {
  /// Width / height (same as [AspectRatio.aspectRatio]).
  final Recipe recipe;
  final VoidCallback? onBookmarkTap;
  final bool bookmarkSaving;
  final bool isBookmarked;
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

  @override
  Widget build(BuildContext context) {
    final accentYellow = AppColors.accentYellow;

    Widget imageCore = recipe.displayImageUrl != null &&
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
                    color: AppColors.primaryGreen,
                    value: loadingProgress.expectedTotalBytes != null
                        ? loadingProgress.cumulativeBytesLoaded /
                            loadingProgress.expectedTotalBytes!
                        : null,
                  ),
                ),
              );
            },
            errorBuilder: (_, _, _) => _placeholder(),
          )
        : _placeholder();

    final stack = Stack(
      fit: StackFit.expand,
      children: [
        imageCore,
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          height: 72,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.45),
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
          height: 96,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.62),
                    Colors.black.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (recipe.category != null)
          Positioned(
            left: AppSpacing.sm,
            top: AppSpacing.sm,
            child: IgnorePointer(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.88),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  recipe.category!.name,
                  style: TextStyle(
                    color: AppColors.primaryGreen,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    fontFamily: kFontHelveticaNow,
                  ),
                ),
              ),
            ),
          ),
        Positioned(
          top: AppSpacing.sm,
          right: AppSpacing.sm,
          child: Material(
            color: Colors.white.withValues(alpha: 0.88),
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onBookmarkTap,
              customBorder: const CircleBorder(),
              child: SizedBox(
                width: 40,
                height: 40,
                child: bookmarkSaving
                    ? const Padding(
                        padding: EdgeInsets.all(10),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primaryGreen,
                        ),
                      )
                    : Icon(
                        isBookmarked
                            ? Icons.bookmark_rounded
                            : Icons.bookmark_outline_rounded,
                        color: isBookmarked
                            ? AppColors.accentOrange
                            : AppColors.primaryGreen,
                        size: 22,
                      ),
              ),
            ),
          ),
        ),
        Positioned(
          left: AppSpacing.sm,
          right: AppSpacing.sm,
          bottom: AppSpacing.sm,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                recipe.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: kFontGeorgiaPro,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  height: 1.2,
                  color: Colors.white,
                  shadows: [
                    Shadow(
                      color: Color(0x66000000),
                      blurRadius: 8,
                    ),
                  ],
                ),
              ),
              AppSpacing.gapV8,
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                children: [
                  _MiniMeta(
                    icon: Icons.schedule_rounded,
                    label: '${recipe.prepTime} min',
                    accentYellow: accentYellow,
                  ),
                  _MiniMeta(
                    icon: Icons.star_rounded,
                    label: (recipe.averageRating ?? 0).toStringAsFixed(1),
                    accentYellow: accentYellow,
                  ),
                  _MiniMeta(
                    icon: Icons.visibility_outlined,
                    label: '${recipe.viewsCount ?? 0}',
                    accentYellow: accentYellow,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );

    final content = heroTag != null
        ? Hero(
            tag: heroTag!,
            child: Material(color: Colors.transparent, child: stack),
          )
        : stack;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.md),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadii.md),
        child: AspectRatio(
          aspectRatio: aspectRatio,
          child: ColoredBox(
            color: AppColors.imagePlaceholderGreen,
            child: content,
          ),
        ),
      ),
    );
  }

  Widget _placeholder() {
    return ColoredBox(
      color: AppColors.imagePlaceholderGreen,
      child: Center(
        child: Icon(
          Icons.restaurant_menu_rounded,
          size: 48,
          color: AppColors.primaryGreen.withValues(alpha: 0.35),
        ),
      ),
    );
  }
}

class _MiniMeta extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color accentYellow;

  const _MiniMeta({
    required this.icon,
    required this.label,
    required this.accentYellow,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: accentYellow),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontFamily: kFontHelveticaNow,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Colors.white.withValues(alpha: 0.95),
          ),
        ),
      ],
    );
  }
}
