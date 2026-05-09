import 'package:flutter/material.dart';

/// Detail-only photo grid (Facebook-style): up to **five** visible tiles; extra photos summarized as "+N".
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
    final showOverflow = n > 5;
    final visible = showOverflow ? urls.take(4).toList() : urls.take(n.clamp(0, 5)).toList();
    final overflowCount = showOverflow ? n - 4 : 0;

    Widget tile(String url, {bool overlayMore = false, int moreCount = 0}) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              url,
              fit: BoxFit.cover,
              alignment: Alignment.center,
              errorBuilder: (_, __, ___) => Container(
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
          ],
        ),
      );
    }

    const height = 280.0;

    if (visible.length == 1 && !showOverflow) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: SizedBox(
          height: height,
          width: double.infinity,
          child: tile(visible.first),
        ),
      );
    }

    if (visible.length == 2 && !showOverflow) {
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

    if (visible.length == 3 && !showOverflow) {
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

    // Exactly five photos — two on top, three on bottom.
    if (visible.length == 5 && !showOverflow) {
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
                  Expanded(child: tile(visible[4])),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // Four photos (2×2), or four thumbnails + overflow on the fourth cell when >5 total
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
                Expanded(
                  child: showOverflow
                      ? tile(
                          visible[3],
                          overlayMore: true,
                          moreCount: overflowCount,
                        )
                      : tile(visible[3]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
