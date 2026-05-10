/// Week helpers aligned with backend meal-plan windows (Mon–Sun).
abstract final class MealPlanWeekUtils {
  /// Monday-based week start (same as legacy dashboard planner).
  static DateTime startOfWeekMonday(DateTime date) {
    final normalized = DateTime(date.year, date.month, date.day);
    return normalized.subtract(Duration(days: normalized.weekday - 1));
  }

  static DateTime normalize(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  static String shortWeekdayLabel(DateTime day) {
    const labels = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    return labels[day.weekday - 1];
  }

  static String fullWeekdayName(DateTime day) {
    const names = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    return names[day.weekday - 1];
  }

  /// Compact range label for the week strip (e.g. "Jan 6 – 12").
  static String rangeLabel(DateTime start, DateTime end) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final sm = months[start.month - 1];
    final em = months[end.month - 1];
    if (start.month == end.month) {
      return '$sm ${start.day} – ${end.day}';
    }
    return '$sm ${start.day} – $em ${end.day}';
  }

  /// Index 0–6 within [weekStart, weekStart+6] for [day], or 0 if outside.
  static int dayIndexInWeek(DateTime weekStart, DateTime day) {
    final start = normalize(weekStart);
    final d = normalize(day);
    final diff = d.difference(start).inDays;
    if (diff < 0 || diff > 6) return 0;
    return diff;
  }

  /// e.g. "May 10, 2026"
  static String formatLongDate(DateTime date) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    final m = months[date.month - 1];
    return '$m ${date.day}, ${date.year}';
  }

  static String toIsoDate(DateTime date) {
    final d = normalize(date);
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  /// Prefer today's column when the week contains today; otherwise Monday.
  static int initialDayPageIndex(DateTime weekStart) {
    final today = normalize(DateTime.now());
    final ws = normalize(weekStart);
    final last = ws.add(const Duration(days: 6));
    if (today.isBefore(ws) || today.isAfter(last)) return 0;
    return today.difference(ws).inDays;
  }
}
