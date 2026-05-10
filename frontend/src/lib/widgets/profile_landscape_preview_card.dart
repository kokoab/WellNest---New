import 'package:flutter/material.dart';
import 'package:my_app/theme/app_spacing.dart';
import 'package:my_app/theme/app_theme.dart';

/// Full-width landscape row aligned with [WellnestRecipeCard] / cooking-step rows:
/// white surface, grey outline, text left, thumbnail right.
class ProfileLandscapePreviewCard extends StatelessWidget {
  static const double cardRadius = 14;
  static const double imageSize = 78;
  static const double imageRadius = 12;

  final String title;
  final String creatorName;
  final String postedLabel;
  final String? imageUrl;
  final IconData placeholderIcon;
  final VoidCallback onTap;

  const ProfileLandscapePreviewCard({
    super.key,
    required this.title,
    required this.creatorName,
    required this.postedLabel,
    required this.imageUrl,
    required this.placeholderIcon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final img = imageUrl;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(cardRadius),
        child: Ink(
          decoration: BoxDecoration(
            color: cs.brightness == Brightness.dark
                ? cs.surfaceContainerHighest.withValues(alpha: 0.35)
                : Colors.white,
            borderRadius: BorderRadius.circular(cardRadius),
            border: Border.all(color: wellnestOutlineColor(context), width: 1),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.sm2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: helveticaNow(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: cs.onSurface,
                        ).copyWith(height: 1.25),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        creatorName,
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: kFontAppFamily,
                          color: cs.onSurfaceVariant,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.schedule_rounded,
                            size: 14,
                            color: AppColors.primaryGreen.withValues(alpha: 0.85),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              postedLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: kFontAppFamily,
                                color: cs.onSurfaceVariant,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.1,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                SizedBox(
                  width: imageSize,
                  height: imageSize,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(imageRadius),
                    child: img != null && img.isNotEmpty
                        ? Image.network(
                            img,
                            fit: BoxFit.cover,
                            alignment: Alignment.center,
                            width: imageSize,
                            height: imageSize,
                            cacheWidth: 240,
                            errorBuilder: (context, error, stackTrace) =>
                                _PreviewImagePlaceholder(icon: placeholderIcon),
                          )
                        : _PreviewImagePlaceholder(icon: placeholderIcon),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PreviewImagePlaceholder extends StatelessWidget {
  final IconData icon;

  const _PreviewImagePlaceholder({required this.icon});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.imagePlaceholderGreen,
      child: Icon(
        icon,
        color: AppColors.primaryGreen.withValues(alpha: 0.35),
        size: 34,
      ),
    );
  }
}
