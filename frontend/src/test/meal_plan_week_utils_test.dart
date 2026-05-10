import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/utils/meal_plan_week_utils.dart';

void main() {
  group('MealPlanWeekUtils', () {
    test('startOfWeekMonday returns Monday', () {
      // Wednesday 13 May 2026
      final wed = DateTime(2026, 5, 13);
      final mon = MealPlanWeekUtils.startOfWeekMonday(wed);
      expect(mon.weekday, DateTime.monday);
      expect(mon.day, 11);
      expect(mon.month, 5);
    });

    test('initialDayPageIndex returns offset within week', () {
      final mon = DateTime(2026, 5, 11);
      expect(MealPlanWeekUtils.initialDayPageIndex(mon), 0);
      final wedInWeek = DateTime(2026, 5, 13);
      expect(MealPlanWeekUtils.dayIndexInWeek(mon, wedInWeek), 2);
    });

    test('formatLongDate uses Month D, YYYY', () {
      expect(
        MealPlanWeekUtils.formatLongDate(DateTime(2026, 5, 10)),
        'May 10, 2026',
      );
    });
  });
}
