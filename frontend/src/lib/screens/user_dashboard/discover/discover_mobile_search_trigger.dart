import 'package:flutter/material.dart';
import 'package:wellnest/theme/app_spacing.dart';
import 'package:wellnest/theme/app_theme.dart';

/// Tappable search bar on narrow screens; opens the full mobile search overlay.
class DiscoverMobileSearchTrigger extends StatelessWidget {
  const DiscoverMobileSearchTrigger({
    super.key,
    required this.displayText,
    required this.onTap,
  });

  final String displayText;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isEmpty = displayText.isEmpty;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        decoration: BoxDecoration(
          color: wellnestCardSurface(context),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: wellnestOutlineColor(context), width: 1),
        ),
        child: Row(
          children: [
            Icon(Icons.search, color: cs.primary, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                isEmpty ? 'Search by name or ingredients...' : displayText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 16,
                  color: isEmpty
                      ? wellnestCaptionColor(context)
                      : cs.onSurface,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
