import 'package:flutter/material.dart';
import 'package:my_app/models/recipe.dart';

class WeeklyMealPlannerStrip extends StatelessWidget {
  final DateTime weekStart;
  final Map<DateTime, int?> selections;
  final List<Recipe> recipes;
  final void Function(DateTime nextWeekStart) onWeekChanged;
  final void Function(DateTime day, int? recipeId) onAssignRecipe;

  const WeeklyMealPlannerStrip({
    super.key,
    required this.weekStart,
    required this.selections,
    required this.recipes,
    required this.onWeekChanged,
    required this.onAssignRecipe,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final weekDays = List.generate(
      7,
      (index) => DateTime(
        weekStart.year,
        weekStart.month,
        weekStart.day + index,
      ),
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Weekly Meal Planner',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => onWeekChanged(weekStart.subtract(const Duration(days: 7))),
                icon: const Icon(Icons.chevron_left),
              ),
              Text(
                _rangeLabel(weekDays.first, weekDays.last),
                style: TextStyle(color: colorScheme.onSurfaceVariant),
              ),
              IconButton(
                onPressed: () => onWeekChanged(weekStart.add(const Duration(days: 7))),
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: weekDays.map((day) {
                final recipeId = selections[_normalized(day)];
                final recipe = recipeId == null
                    ? null
                    : recipes.cast<Recipe?>().firstWhere(
                          (item) => item?.id == recipeId,
                          orElse: () => null,
                        );

                return Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: InkWell(
                    onTap: () => _showRecipePicker(context, day),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      width: 92,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest.withOpacity(0.45),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _dayLabel(day),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${day.day}',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: colorScheme.primary,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            recipe?.title ?? 'Tap to plan',
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: recipe == null
                                  ? colorScheme.onSurfaceVariant
                                  : colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showRecipePicker(BuildContext context, DateTime day) async {
    final pickedId = await showModalBottomSheet<int?>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text('Plan for ${_dayLabel(day)}'),
                trailing: TextButton(
                  onPressed: () => Navigator.pop(context, null),
                  child: const Text('Clear'),
                ),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: recipes.map((recipe) {
                    return ListTile(
                      title: Text(recipe.title),
                      subtitle: Text('${recipe.prepTime} min'),
                      onTap: () => Navigator.pop(context, recipe.id),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );

    onAssignRecipe(_normalized(day), pickedId);
  }

  static DateTime _normalized(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  static String _dayLabel(DateTime day) {
    const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return labels[day.weekday - 1];
  }

  static String _rangeLabel(DateTime start, DateTime end) {
    return '${start.month}/${start.day} - ${end.month}/${end.day}';
  }
}
