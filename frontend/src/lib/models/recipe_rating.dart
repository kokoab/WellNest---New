import '../utils/json_helpers.dart';

/// Single rating/review for a recipe.
class RecipeRating {
  final int id;
  final int recipeId;
  final int userId;
  final int rating;
  final String? comment;
  final String? createdAt;
  final RecipeRatingUser? user;

  RecipeRating({
    required this.id,
    required this.recipeId,
    required this.userId,
    required this.rating,
    this.comment,
    this.createdAt,
    this.user,
  });

  factory RecipeRating.fromJson(Map<String, dynamic> json) {
    RecipeRatingUser? u;
    if (json['user'] != null) {
      final uj = json['user'] as Map<String, dynamic>;
      u = RecipeRatingUser(
        id: jsonDecodeInt(uj['id']),
        firstName: uj['first_name'] as String? ?? '',
        lastName: uj['last_name'] as String? ?? '',
      );
    }
    return RecipeRating(
      id: (json['id'] as num).toInt(),
      recipeId: (json['recipe_id'] as num).toInt(),
      userId: (json['user_id'] as num).toInt(),
      rating: jsonDecodeInt(json['rating']),
      comment: json['comment'] as String?,
      createdAt: json['created_at'] as String?,
      user: u,
    );
  }

  String get userDisplayName {
    if (user == null) return 'Anonymous';
    return '${user!.firstName} ${user!.lastName}'.trim();
  }
}

class RecipeRatingUser {
  final int id;
  final String firstName;
  final String lastName;
  RecipeRatingUser({
    required this.id,
    required this.firstName,
    required this.lastName,
  });
}
