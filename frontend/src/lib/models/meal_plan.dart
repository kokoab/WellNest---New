class MealPlanRecipeSummary {
  final int id;
  final String title;
  final int prepTime;
  final String? category;
  final String? imageUrl;

  const MealPlanRecipeSummary({
    required this.id,
    required this.title,
    required this.prepTime,
    this.category,
    this.imageUrl,
  });

  factory MealPlanRecipeSummary.fromJson(Map<String, dynamic> json) {
    return MealPlanRecipeSummary(
      id: (json['id'] as num).toInt(),
      title: json['title'] as String? ?? '',
      prepTime: (json['prep_time'] as num?)?.toInt() ?? 0,
      category: json['category'] as String?,
      imageUrl: json['image_url'] as String?,
    );
  }
}

class MealPlan {
  final int id;
  final int recipeId;
  final DateTime plannedDate;
  final String mealSlot;
  final MealPlanRecipeSummary? recipe;

  const MealPlan({
    required this.id,
    required this.recipeId,
    required this.plannedDate,
    required this.mealSlot,
    this.recipe,
  });

  factory MealPlan.fromJson(Map<String, dynamic> json) {
    return MealPlan(
      id: (json['id'] as num).toInt(),
      recipeId: (json['recipe_id'] as num).toInt(),
      plannedDate: DateTime.parse(json['planned_date'] as String),
      mealSlot: json['meal_slot'] as String? ?? 'dinner',
      recipe: json['recipe'] != null
          ? MealPlanRecipeSummary.fromJson(json['recipe'] as Map<String, dynamic>)
          : null,
    );
  }
}

class MealPlanExport {
  final String weekStart;
  final String weekEnd;
  final String userName;
  final List<MealPlanExportRow> meals;

  const MealPlanExport({
    required this.weekStart,
    required this.weekEnd,
    required this.userName,
    required this.meals,
  });

  factory MealPlanExport.fromJson(Map<String, dynamic> json) {
    final list = json['meals'] as List<dynamic>? ?? [];
    return MealPlanExport(
      weekStart: json['week_start'] as String? ?? '',
      weekEnd: json['week_end'] as String? ?? '',
      userName: json['user_name'] as String? ?? '',
      meals: list.map((e) => MealPlanExportRow.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }
}

class MealPlanExportRow {
  final String date;
  final String day;
  final String mealSlot;
  final String recipeTitle;
  final int? prepTime;

  const MealPlanExportRow({
    required this.date,
    required this.day,
    required this.mealSlot,
    required this.recipeTitle,
    this.prepTime,
  });

  factory MealPlanExportRow.fromJson(Map<String, dynamic> json) {
    return MealPlanExportRow(
      date: json['date'] as String? ?? '',
      day: json['day'] as String? ?? '',
      mealSlot: json['meal_slot'] as String? ?? '',
      recipeTitle: json['recipe_title'] as String? ?? '—',
      prepTime: (json['prep_time'] as num?)?.toInt(),
    );
  }
}
