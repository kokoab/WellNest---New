/// Recipe model matching backend API (with category and user relations).
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
