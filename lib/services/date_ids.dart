/// Date helpers used across the app (Firestore ids, widget, etc.).
///
/// We keep these rules centralized so week/day navigation stays consistent.
class DateIds {
  /// Fixed weekly planner document.
  ///
  /// Activities saved here are weekday templates, so "Monday" remains Monday
  /// across calendar weeks instead of becoming an empty new date next week.
  static const String routineWeekId = 'weekly-routine';

  /// Day id: YYYY-MM-DD (local date).
  static String dayId(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  /// Fixed weekday day id: weekday-1 ... weekday-7 (Monday ... Sunday).
  static String routineDayId(DateTime date) {
    return routineDayIdFromWeekday(date.weekday);
  }

  static String routineDayIdFromWeekday(int weekday) {
    if (weekday < DateTime.monday || weekday > DateTime.sunday) {
      throw ArgumentError.value(weekday, 'weekday', 'Must be between 1 and 7');
    }

    return 'weekday-$weekday';
  }

  /// ISO week id: YYYY-Www (e.g. 2025-W52).
  ///
  /// Uses ISO-8601: weeks start on Monday and week 1 is the week with the first Thursday.
  static String weekId(DateTime date) {
    final iso = _isoWeek(date);
    final y = iso.year.toString().padLeft(4, '0');
    final w = iso.week.toString().padLeft(2, '0');
    return '$y-W$w';
  }

  /// Returns ISO week-year and week number.
  static ({int year, int week}) _isoWeek(DateTime date) {
    // Normalize to local date (ignore time).
    final d = DateTime(date.year, date.month, date.day);

    // ISO weekday: Monday=1 ... Sunday=7
    final int weekday = d.weekday;

    // Shift date to Thursday of this week.
    final thursday = d.add(Duration(days: 4 - weekday));

    // Week-year is the year of that Thursday.
    final weekYear = thursday.year;

    // Find first Thursday of week-year.
    final jan4 = DateTime(weekYear, 1, 4);
    final jan4Weekday = jan4.weekday;
    final firstThursday = jan4.add(Duration(days: 4 - jan4Weekday));

    // Compute week number.
    final diffDays = thursday.difference(firstThursday).inDays;
    final weekNumber = 1 + (diffDays ~/ 7);

    return (year: weekYear, week: weekNumber);
  }
}
