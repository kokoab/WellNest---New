import '../utils/json_helpers.dart';
import '../utils/media_url.dart';

class RecipeRankingItem {
  final int id;
  final String title;
  final String? imageUrl;
  final String? category;
  final double averageRating;
  final int ratingsCount;
  final int viewsCount;
  final double score;

  RecipeRankingItem({
    required this.id,
    required this.title,
    this.imageUrl,
    this.category,
    required this.averageRating,
    required this.ratingsCount,
    required this.viewsCount,
    required this.score,
  });

  factory RecipeRankingItem.fromJson(Map<String, dynamic> json) {
    return RecipeRankingItem(
      id: jsonDecodeInt(json['id']),
      title: json['title'] as String? ?? '',
      imageUrl: json['image_url'] as String?,
      category: json['category'] as String?,
      averageRating: (json['average_rating'] as num?)?.toDouble() ?? 0.0,
      ratingsCount: (json['ratings_count'] as num?)?.toInt() ?? 0,
      viewsCount: (json['views_count'] as num?)?.toInt() ?? 0,
      score: (json['score'] as num?)?.toDouble() ?? 0.0,
    );
  }

  String? get displayImageUrl => resolveStorageDisplayUrl(imageUrl);
}
