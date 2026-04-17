import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:my_app/theme/app_theme.dart';

class _Bone extends StatelessWidget {
  final double? width;
  final double? height;
  final double radius;
  final BoxShape shape;

  const _Bone({
    this.width,
    this.height,
    this.radius = 8,
    this.shape = BoxShape.rectangle,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.08) : Colors.grey.shade300,
        borderRadius:
            shape == BoxShape.circle ? null : BorderRadius.circular(radius),
        shape: shape,
      ),
    );
  }
}

/// Pulsing shimmer wrapper that adapts to light/dark theme.
class _ShimmerWrap extends StatelessWidget {
  final Widget child;

  const _ShimmerWrap({required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Shimmer.fromColors(
      baseColor: isDark ? const Color(0xFF2A3B33) : Colors.grey.shade300,
      highlightColor: isDark ? const Color(0xFF3B4F45) : Colors.grey.shade100,
      child: child,
    );
  }
}

/// Skeleton matching the masonry recipe card: image block + text lines.
class RecipeCardSkeleton extends StatelessWidget {
  final double aspectRatio;

  const RecipeCardSkeleton({super.key, this.aspectRatio = 1.0});

  @override
  Widget build(BuildContext context) {
    return _ShimmerWrap(
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(AppRadii.md),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 1 / aspectRatio,
              child: const _Bone(radius: 0),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _Bone(width: double.infinity, height: 14),
                  const SizedBox(height: 6),
                  const _Bone(width: 80, height: 14),
                  const SizedBox(height: 8),
                  _Bone(width: 50, height: 20, radius: 20),
                  const SizedBox(height: 8),
                  Row(
                    children: const [
                      _Bone(width: 60, height: 12),
                      SizedBox(width: 8),
                      _Bone(width: 30, height: 12),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Skeleton matching the top-ranked horizontal card: 220x180 container.
class TopRankedCardSkeleton extends StatelessWidget {
  const TopRankedCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return _ShimmerWrap(
      child: Container(
        width: 220,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _Bone(width: double.infinity, radius: 12),
            ),
            const SizedBox(height: 8),
            const _Bone(width: 140, height: 14),
            const SizedBox(height: 4),
            Row(
              children: const [
                _Bone(width: 70, height: 12),
                Spacer(),
                _Bone(width: 30, height: 12),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Skeleton matching a carousel slide: full-bleed image with text overlay at the bottom.
class CarouselSlideSkeleton extends StatelessWidget {
  const CarouselSlideSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return _ShimmerWrap(
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(AppRadii.lg),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const _Bone(radius: 0),
            Positioned(
              left: 14,
              right: 14,
              bottom: 14,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  _Bone(width: 36, height: 20, radius: 12),
                  SizedBox(height: 6),
                  _Bone(width: 160, height: 16),
                  SizedBox(height: 6),
                  _Bone(width: 100, height: 13),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Skeleton matching the saved-recipe list row: 90x90 thumb + text.
class SavedRecipeCardSkeleton extends StatelessWidget {
  const SavedRecipeCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return _ShimmerWrap(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _Bone(width: 90, height: 90, radius: 12),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    _Bone(width: double.infinity, height: 16),
                    SizedBox(height: 8),
                    _Bone(width: 120, height: 14),
                    SizedBox(height: 8),
                    _Bone(width: 80, height: 14),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            const _Bone(width: 24, height: 24, shape: BoxShape.circle),
          ],
        ),
      ),
    );
  }
}
