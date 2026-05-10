import 'package:flutter/material.dart';

/// Photo grid (Facebook-style): up to **five** visible tiles; when there are more
/// than five, the fifth tile keeps the fifth image with a “View more photos” overlay.
class PostPhotoCollage extends StatelessWidget {
  const PostPhotoCollage({
    super.key,
    required this.urls,
    this.borderRadius = 16,
    this.spacing = 4,
  });

  final List<String> urls;
  final double borderRadius;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    if (urls.isEmpty) return const SizedBox.shrink();

    final n = urls.length;
    final moreThanFive = n > 5;
    final visible = moreThanFive
        ? urls.take(5).toList()
        : urls.take(n.clamp(0, 5)).toList();

    Widget tile(
      String url, {
      bool overlayMore = false,
      int moreCount = 0,
      bool overlayViewMore = false,
      int extraBeyondFive = 0,
    }) {
      final r = borderRadius > 0
          ? BorderRadius.circular(borderRadius)
          : BorderRadius.zero;
      return ClipRRect(
        borderRadius: r,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              url,
              fit: BoxFit.cover,
              alignment: Alignment.center,
              errorBuilder: (_, _, _) => Container(
                color: const Color(0xFFEFF3EF),
                alignment: Alignment.center,
                child: const Icon(Icons.broken_image_outlined),
              ),
            ),
            if (overlayMore && moreCount > 0)
              Container(
                alignment: Alignment.center,
                color: Colors.black.withValues(alpha: 0.45),
                child: Text(
                  '+$moreCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 28,
                  ),
                ),
              ),
            if (overlayViewMore)
              Container(
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 6),
                color: Colors.black.withValues(alpha: 0.5),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'View more photos',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: borderRadius < 8 ? 12 : 14,
                        height: 1.2,
                      ),
                    ),
                    if (extraBeyondFive > 0) ...[
                      const SizedBox(height: 4),
                      Text(
                        '+$extraBeyondFive',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.95),
                          fontWeight: FontWeight.w600,
                          fontSize: borderRadius < 8 ? 18 : 22,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ),
      );
    }

    const height = 280.0;

    if (visible.length == 1 && !moreThanFive) {
      return ClipRRect(
        borderRadius: borderRadius > 0
            ? BorderRadius.circular(borderRadius)
            : BorderRadius.zero,
        child: SizedBox(
          height: height,
          width: double.infinity,
          child: tile(visible.first),
        ),
      );
    }

    if (visible.length == 2 && !moreThanFive) {
      return SizedBox(
        height: height,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: tile(visible[0])),
            SizedBox(width: spacing),
            Expanded(child: tile(visible[1])),
          ],
        ),
      );
    }

    if (visible.length == 3 && !moreThanFive) {
      return SizedBox(
        height: height,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(flex: 3, child: tile(visible[0])),
            SizedBox(width: spacing),
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: tile(visible[1])),
                  SizedBox(height: spacing),
                  Expanded(child: tile(visible[2])),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // Five thumbnails — two on top, three on bottom (same when total > 5, overlay on last).
    if (visible.length == 5) {
      final lastExtra = moreThanFive ? (n - 5) : 0;
      return SizedBox(
        height: height,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: tile(visible[0])),
                  SizedBox(width: spacing),
                  Expanded(child: tile(visible[1])),
                ],
              ),
            ),
            SizedBox(height: spacing),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: tile(visible[2])),
                  SizedBox(width: spacing),
                  Expanded(child: tile(visible[3])),
                  SizedBox(width: spacing),
                  Expanded(
                    child: moreThanFive
                        ? tile(
                            visible[4],
                            overlayViewMore: true,
                            extraBeyondFive: lastExtra,
                          )
                        : tile(visible[4]),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // Four photos (2×2)
    return SizedBox(
      height: height,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: tile(visible[0])),
                SizedBox(width: spacing),
                Expanded(child: tile(visible[1])),
              ],
            ),
          ),
          SizedBox(height: spacing),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: tile(visible[2])),
                SizedBox(width: spacing),
                Expanded(child: tile(visible[3])),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
