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
        id: uj['id'] as int? ?? 0,
        firstName: uj['first_name'] as String? ?? '',
        lastName: uj['last_name'] as String? ?? '',
      );
    }
    return RecipeRating(
      id: json['id'] as int,
      recipeId: json['recipe_id'] as int,
      userId: json['user_id'] as int,
      rating: json['rating'] as int? ?? 0,
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
