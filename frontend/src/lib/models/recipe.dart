import '../config/app_config.dart';

/// Recipe model matching backend API (with category, user, ingredients, image).
class Recipe {
  final int id;
  final int? userId;
  final int categoryId;
  final String title;
  final String instructions;
  final int prepTime; // minutes
  final String? createdAt;
  final String? updatedAt;
  final CategoryInfo? category;
  final UserInfo? user;
  final List<RecipeIngredientInfo>? ingredients;
  final String? imageUrl;
  final double? averageRating;
  final int? ratingsCount;

  Recipe({
    required this.id,
    this.userId,
    required this.categoryId,
    required this.title,
    required this.instructions,
    required this.prepTime,
    this.createdAt,
    this.updatedAt,
    this.category,
    this.user,
    this.ingredients,
    this.imageUrl,
    this.averageRating,
    this.ratingsCount,
  });

  factory Recipe.fromJson(Map<String, dynamic> json) {
    CategoryInfo? cat;
    if (json['category'] != null) {
      final c = json['category'] as Map<String, dynamic>;
      cat = CategoryInfo(
        id: c['id'] as int? ?? 0,
        name: c['name'] as String? ?? '',
      );
    }
    UserInfo? u;
    if (json['user'] != null) {
      final uj = json['user'] as Map<String, dynamic>;
      u = UserInfo(
        id: uj['id'] as int? ?? 0,
        firstName: uj['first_name'] as String? ?? '',
        lastName: uj['last_name'] as String? ?? '',
      );
    }
    List<RecipeIngredientInfo>? ingredients;
    if (json['ingredients'] != null) {
      final list = json['ingredients'] as List<dynamic>;
      ingredients = list.map((e) {
        final m = e as Map<String, dynamic>;
        final pivot = m['pivot'] as Map<String, dynamic>? ?? {};
        return RecipeIngredientInfo(
          name: m['name'] as String? ?? '',
          quantity: (pivot['quantity'] as num?)?.toDouble() ?? 0,
          unit: pivot['unit'] as String? ?? '',
        );
      }).toList();
    }
    return Recipe(
      id: json['id'] as int,
      userId: json['user_id'] as int?,
      categoryId: json['category_id'] as int,
      title: json['title'] as String? ?? '',
      instructions: json['instructions'] as String? ?? '',
      prepTime: (json['prep_time'] as num?)?.toInt() ?? 0,
      createdAt: json['created_at'] as String?,
      updatedAt: json['updated_at'] as String?,
      category: cat,
      user: u,
      ingredients: ingredients,
      imageUrl: json['image_url'] as String?,
      averageRating: (json['average_rating'] as num?)?.toDouble(),
      ratingsCount: json['ratings_count'] as int?,
    );
  }

  Map<String, dynamic> toJson() => {
        'category_id': categoryId,
        'title': title,
        'instructions': instructions,
        'prep_time': prepTime,
      };

  String get userDisplayName {
    if (user == null) return 'Unknown';
    return '${user!.firstName} ${user!.lastName}'.trim();
  }

  /// Image URL for display. Uses frontend base URL to fix Docker internal host issues.
  String? get displayImageUrl {
    if (imageUrl == null || imageUrl!.isEmpty) return null;
    final url = imageUrl!;
    final base = AppConfig.baseUrl.replaceAll(RegExp(r'/api$'), '');
    if (url.startsWith('http')) {
      final uri = Uri.tryParse(url);
      if (uri != null && uri.path.startsWith('/storage/')) {
        return '$base${uri.path}';
      }
    }
    if (url.startsWith('/')) return base + url;
    return url;
  }
}

class CategoryInfo {
  final int id;
  final String name;
  CategoryInfo({required this.id, required this.name});
}

class UserInfo {
  final int id;
  final String firstName;
  final String lastName;
  UserInfo({
    required this.id,
    required this.firstName,
    required this.lastName,
  });
}

class RecipeIngredientInfo {
  final String name;
  final double quantity;
  final String unit;
  RecipeIngredientInfo({
    required this.name,
    required this.quantity,
    required this.unit,
  });
}
