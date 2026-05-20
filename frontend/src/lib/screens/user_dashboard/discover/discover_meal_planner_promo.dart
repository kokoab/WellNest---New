import 'package:flutter/material.dart';
import 'package:wellnest/screens/meal_planner_screen.dart';
import 'package:wellnest/theme/app_theme.dart';

import 'discover_colors.dart';

/// Entry point card for the weekly meal planner on Discover.
class DiscoverMealPlannerPromo extends StatelessWidget {
  const DiscoverMealPlannerPromo({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: wellnestCardSurface(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: wellnestOutlineColor(context), width: 1),
      ),
      child: ListTile(
        dense: true,
        visualDensity: const VisualDensity(vertical: -2),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 10,
        ),
        leading: Icon(Icons.calendar_month, color: cs.primary),
        title: Text(
          'Weekly Meal Planner',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: wellnestHeadingGreen(context),
          ),
        ),
        subtitle: Text(
          'Plan breakfast, lunch, and dinner for the week.',
          style: TextStyle(
            fontSize: 12,
            color: wellnestCaptionColor(context),
          ),
        ),
        trailing: const Icon(Icons.chevron_right, color: DiscoverColors.nestOrange),
        onTap: () {
          Navigator.of(context).push<void>(
            MaterialPageRoute<void>(
              builder: (_) => const MealPlannerScreen(),
            ),
          );
        },
      ),
    );
  }
}
