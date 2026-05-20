import 'package:flutter/material.dart';
import 'package:wellnest/theme/app_theme.dart';

import 'discover_colors.dart';
import 'popular_cuisine_item.dart';

/// Popular cuisines + recent searches shown when the Discover search field is focused.
class DiscoverSearchDiscoveryPanel extends StatelessWidget {
  const DiscoverSearchDiscoveryPanel({
    super.key,
    required this.popularCuisines,
    required this.loadingPopularCuisines,
    required this.recentSearches,
    required this.onCuisineTap,
    required this.onRecentSearchTap,
    required this.onClearRecentSearches,
    this.boxed = true,
    this.horizontalInset = 0,
  });

  final List<PopularCuisineItem> popularCuisines;
  final bool loadingPopularCuisines;
  final List<String> recentSearches;
  final ValueChanged<String> onCuisineTap;
  final ValueChanged<String> onRecentSearchTap;
  final VoidCallback onClearRecentSearches;
  final bool boxed;
  final double horizontalInset;

  @override
  Widget build(BuildContext context) {
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Popular Cuisines',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: DiscoverColors.wellGreen,
          ),
        ),
        const SizedBox(height: 10),
        if (loadingPopularCuisines)
          const LinearProgressIndicator(
            minHeight: 2,
            color: DiscoverColors.wellGreen,
          )
        else if (popularCuisines.isEmpty)
          Text(
            'No popular cuisines yet.',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          )
        else
          SizedBox(
            height: 118,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: popularCuisines.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final item = popularCuisines[index];
                return InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => onCuisineTap(item.searchTerm),
                  child: SizedBox(
                    width: 110,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: item.imageUrl != null
                              ? Image.network(
                                  item.imageUrl!,
                                  height: 82,
                                  width: 110,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) =>
                                      _CuisinePlaceholder(label: item.label),
                                )
                              : _CuisinePlaceholder(label: item.label),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          item.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        const SizedBox(height: 14),
        Row(
          children: [
            const Expanded(
              child: Text(
                'Recent Searches',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: DiscoverColors.wellGreen,
                ),
              ),
            ),
            if (recentSearches.isNotEmpty)
              TextButton(
                onPressed: onClearRecentSearches,
                child: const Text('Clear'),
              ),
          ],
        ),
        if (recentSearches.isEmpty)
          Text(
            'Your recent searches will appear here.',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: recentSearches
                .map(
                  (query) => ActionChip(
                    label: Text(query),
                    onPressed: () => onRecentSearchTap(query),
                    avatar: const Icon(
                      Icons.history_rounded,
                      size: 16,
                      color: DiscoverColors.wellGreen,
                    ),
                    labelStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
                .toList(),
          ),
      ],
    );

    if (!boxed) {
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: horizontalInset),
        child: SizedBox(width: double.infinity, child: content),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: wellnestCardDecoration(context),
      child: content,
    );
  }
}

class _CuisinePlaceholder extends StatelessWidget {
  const _CuisinePlaceholder({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 82,
      width: 110,
      decoration: BoxDecoration(
        color: const Color(0xFFE7F1EA),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Text(
          label.isNotEmpty ? label.substring(0, 1).toUpperCase() : '🍽',
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: DiscoverColors.wellGreen,
          ),
        ),
      ),
    );
  }
}
