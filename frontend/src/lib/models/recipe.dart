import '../utils/media_url.dart';

/// One recipe photo from the API (ordered gallery).
class RecipeImageRef {
  final int id;
  final int sortOrder;
  final String url;

  RecipeImageRef({
    required this.id,
    required this.sortOrder,
    required this.url,
  });

  factory RecipeImageRef.fromJson(Map<String, dynamic> json) {
    return RecipeImageRef(
      id: json['id'] as int,
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      url: json['url'] as String? ?? json['image_url'] as String? ?? '',
    );
  }

  String? get displayUrl => resolveStorageDisplayUrl(url.isEmpty ? null : url);
}

/// Recipe model matching backend API (with category, user, ingredients, image).
class Recipe {
  final int id;
  final int? userId;
  final int categoryId;
  final String title;
  final String? description;
  final String instructions;
  final int prepTime; // minutes
  final String? createdAt;
  final String? updatedAt;
  final CategoryInfo? category;
  final UserInfo? user;
  final List<RecipeIngredientInfo>? ingredients;
  final String? imageUrl;
  final List<RecipeImageRef> galleryImages;
  final double? averageRating;
  final int? ratingsCount;
  final int? viewsCount;

  Recipe({
    required this.id,
    this.userId,
    required this.categoryId,
    required this.title,
    this.description,
    required this.instructions,
    required this.prepTime,
    this.createdAt,
    this.updatedAt,
    this.category,
    this.user,
    this.ingredients,
    this.imageUrl,
    this.galleryImages = const [],
    this.averageRating,
    this.ratingsCount,
    this.viewsCount,
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
    List<RecipeImageRef> gallery = const [];
    final rawImgs = json['images'] as List<dynamic>?;
    if (rawImgs != null && rawImgs.isNotEmpty) {
      gallery = rawImgs
          .map((e) => RecipeImageRef.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    return Recipe(
      id: json['id'] as int,
      userId: json['user_id'] as int?,
      categoryId: json['category_id'] as int,
      title: json['title'] as String? ?? '',
      description: json['description'] as String?,
      instructions: json['instructions'] as String? ?? '',
      prepTime: (json['prep_time'] as num?)?.toInt() ?? 0,
      createdAt: json['created_at'] as String?,
      updatedAt: json['updated_at'] as String?,
      category: cat,
      user: u,
      ingredients: ingredients,
      imageUrl: json['image_url'] as String?,
      galleryImages: gallery,
      averageRating: (json['average_rating'] as num?)?.toDouble(),
      ratingsCount: json['ratings_count'] as int?,
      viewsCount: (json['views_count'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toJson() => {
        'category_id': categoryId,
        'title': title,
        if (description != null) 'description': description,
        'instructions': instructions,
        'prep_time': prepTime,
      };

  String get userDisplayName {
    if (user == null) return 'Unknown';
    return '${user!.firstName} ${user!.lastName}'.trim();
  }

  /// Image URL for display. Uses frontend base URL to fix Docker internal host issues.
  String? get displayImageUrl => resolveStorageDisplayUrl(imageUrl);

  /// Ordered gallery URLs for detail screens (falls back to single [imageUrl]).
  List<String> get galleryDisplayUrls {
    if (galleryImages.isNotEmpty) {
      return galleryImages
          .map((e) => e.displayUrl)
          .whereType<String>()
          .where((u) => u.isNotEmpty)
          .toList();
    }
    final u = displayImageUrl;
    if (u != null && u.isNotEmpty) return [u];
    return [];
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
