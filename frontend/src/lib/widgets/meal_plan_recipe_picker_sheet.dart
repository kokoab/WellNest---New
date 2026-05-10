import 'package:flutter/material.dart';

import 'package:my_app/models/recipe.dart';
import 'package:my_app/services/saved_recipe_service.dart';
import 'package:my_app/theme/app_theme.dart';

class MealPlanRecipePickerResult {
  const MealPlanRecipePickerResult._({this.recipe, this.skipped = false});

  const MealPlanRecipePickerResult.recipe(Recipe recipe)
    : this._(recipe: recipe);

  const MealPlanRecipePickerResult.skipped() : this._(skipped: true);

  final Recipe? recipe;
  final bool skipped;
}

/// Bottom sheet: pick a saved recipe for a given day and meal slot.
Future<MealPlanRecipePickerResult?> showMealPlanRecipePicker(
  BuildContext context, {
  required DateTime day,
  required String mealSlotKey,
  required String mealSlotLabel,
}) {
  return showModalBottomSheet<MealPlanRecipePickerResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => MealPlanRecipePickerSheet(
      day: day,
      mealSlotKey: mealSlotKey,
      mealSlotLabel: mealSlotLabel,
    ),
  );
}

class MealPlanRecipePickerSheet extends StatefulWidget {
  final DateTime day;
  final String mealSlotKey;
  final String mealSlotLabel;

  const MealPlanRecipePickerSheet({
    super.key,
    required this.day,
    required this.mealSlotKey,
    required this.mealSlotLabel,
  });

  @override
  State<MealPlanRecipePickerSheet> createState() =>
      _MealPlanRecipePickerSheetState();
}

class _MealPlanRecipePickerSheetState extends State<MealPlanRecipePickerSheet> {
  List<Recipe> _recipes = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await SavedRecipeService.instance.fetchSavedRecipes();
      if (mounted) {
        setState(() {
          _recipes = data.recipes;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final dayName = _weekdayName(widget.day.weekday);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.65,
      ),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
            child: Row(
              children: [
                Icon(
                  Icons.restaurant_menu,
                  size: 22,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$dayName · ${widget.mealSlotLabel}',
                        style: TextStyle(
                          fontFamily: kFontAppFamily,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Pick from saved recipes or mark this meal skipped',
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: Icon(Icons.block_rounded, color: colorScheme.secondary),
            title: Text('Skipped eating ${widget.mealSlotLabel.toLowerCase()}'),
            subtitle: const Text('Use this when you did not eat this meal.'),
            onTap: () => Navigator.pop(
              context,
              const MealPlanRecipePickerResult.skipped(),
            ),
          ),
          const Divider(height: 1),
          Flexible(
            child: _loading
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: CircularProgressIndicator(),
                    ),
                  )
                : _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: colorScheme.onSurfaceVariant),
                      ),
                    ),
                  )
                : _recipes.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.bookmark_border,
                            size: 48,
                            color: colorScheme.onSurfaceVariant.withValues(
                              alpha: 0.5,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No saved recipes yet',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Save recipes from Discover to plan meals.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _recipes.length,
                    separatorBuilder: (_, _) =>
                        const Divider(height: 1, indent: 72),
                    itemBuilder: (context, index) {
                      final recipe = _recipes[index];
                      final isDark = theme.brightness == Brightness.dark;
                      return ListTile(
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: SizedBox(
                            width: 48,
                            height: 48,
                            child: recipe.displayImageUrl != null
                                ? Image.network(
                                    recipe.displayImageUrl!,
                                    fit: BoxFit.cover,
                                    cacheWidth: 96,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        color: isDark
                                            ? colorScheme
                                                  .surfaceContainerHighest
                                            : kImagePlaceholderGreen,
                                        child: Icon(
                                          Icons.restaurant,
                                          size: 20,
                                          color: colorScheme.onSurfaceVariant,
                                        ),
                                      );
                                    },
                                  )
                                : Container(
                                    color: isDark
                                        ? colorScheme.surfaceContainerHighest
                                        : kImagePlaceholderGreen,
                                    child: Icon(
                                      Icons.restaurant,
                                      size: 20,
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                          ),
                        ),
                        title: Text(
                          recipe.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        subtitle: Text(
                          '${recipe.prepTime} min',
                          style: TextStyle(color: colorScheme.onSurfaceVariant),
                        ),
                        trailing: Icon(
                          Icons.add_circle_outline,
                          color: colorScheme.primary,
                          size: 22,
                        ),
                        onTap: () => Navigator.pop(
                          context,
                          MealPlanRecipePickerResult.recipe(recipe),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  static String _weekdayName(int weekday) {
    const names = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    return names[weekday - 1];
  }
}
