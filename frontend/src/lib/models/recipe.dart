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

/// How prep time is entered for the recipe.
enum PrepTimingMode {
  overall,
  perStep,
}

PrepTimingMode prepTimingModeFromApi(String? raw) {
  switch (raw) {
    case 'per_step':
      return PrepTimingMode.perStep;
    case 'overall':
    default:
      return PrepTimingMode.overall;
  }
}

String prepTimingModeToApi(PrepTimingMode mode) {
  switch (mode) {
    case PrepTimingMode.perStep:
      return 'per_step';
    case PrepTimingMode.overall:
      return 'overall';
  }
}

/// One ordered cooking step from the API.
class RecipeStepInfo {
  final int id;
  final int sortOrder;
  final String? title;
  final String? instructions;
  final int? prepTimeMinutes;
  final RecipeImageRef? image;

  RecipeStepInfo({
    required this.id,
    required this.sortOrder,
    this.title,
    this.instructions,
    this.prepTimeMinutes,
    this.image,
  });

  factory RecipeStepInfo.fromJson(Map<String, dynamic> json) {
    RecipeImageRef? img;
    final rawImg = json['image'];
    if (rawImg is Map<String, dynamic>) {
      img = RecipeImageRef.fromJson(rawImg);
    }

    return RecipeStepInfo(
      id: json['id'] as int,
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      title: json['title'] as String?,
      instructions: json['instructions'] as String?,
      prepTimeMinutes: (json['prep_time_minutes'] as num?)?.toInt(),
      image: img,
    );
  }

  /// Non-empty title for UI, or a fallback label.
  String displayTitle(int indexOneBased) {
    final t = title?.trim() ?? '';
    if (t.isNotEmpty) return t;
    return 'Step $indexOneBased';
  }

  bool get hasBody =>
      (instructions?.trim().isNotEmpty ?? false) ||
      (title?.trim().isNotEmpty ?? false);
}

/// Recipe model matching backend API (with category, user, ingredients, image).
class Recipe {
  final int id;
  final int? userId;
  final int categoryId;
  final String title;
  final String? description;
  final String instructions;
  final int prepTime; // minutes (total or sum when per-step)
  final PrepTimingMode prepTimingMode;
  final String? createdAt;
  final String? updatedAt;
  final CategoryInfo? category;
  final UserInfo? user;
  final List<RecipeIngredientInfo>? ingredients;
  final String? imageUrl;
  final List<RecipeImageRef> galleryImages;
  final List<RecipeStepInfo>? steps;
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
    this.prepTimingMode = PrepTimingMode.overall,
    this.createdAt,
    this.updatedAt,
    this.category,
    this.user,
    this.ingredients,
    this.imageUrl,
    this.galleryImages = const [],
    this.steps,
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

    List<RecipeStepInfo>? steps;
    final rawSteps = json['steps'] as List<dynamic>?;
    if (rawSteps != null && rawSteps.isNotEmpty) {
      steps = rawSteps
          .map((e) => RecipeStepInfo.fromJson(e as Map<String, dynamic>))
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
      prepTimingMode: prepTimingModeFromApi(json['prep_timing_mode'] as String?),
      createdAt: json['created_at'] as String?,
      updatedAt: json['updated_at'] as String?,
      category: cat,
      user: u,
      ingredients: ingredients,
      imageUrl: json['image_url'] as String?,
      galleryImages: gallery,
      steps: steps,
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
        'prep_timing_mode': prepTimingModeToApi(prepTimingMode),
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

  bool get hasStructuredSteps => steps != null && steps!.isNotEmpty;

  /// Chip label for prep time on cards and detail.
  String get displayPrepLabel {
    if (prepTimingMode == PrepTimingMode.perStep && prepTime <= 0) {
      return 'Prep varies';
    }
    if (prepTime <= 0) return '—';
    return '$prepTime min';
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

  /// Single line for UI and editing. Free-text lines are stored with quantity 1 and unit `unit`.
  String get displayLine {
    final u = unit.trim().toLowerCase();
    if ((u.isEmpty || u == 'unit') && quantity == 1.0) {
      return name;
    }
    final qtyStr =
        quantity.toInt() == quantity ? quantity.toInt().toString() : quantity.toString();
    final unitPart = unit.trim();
    final amount = unitPart.isEmpty ? qtyStr : '$qtyStr $unitPart';
    return '$amount $name'.trim();
  }
}
