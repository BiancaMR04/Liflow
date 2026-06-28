import 'package:flutter_test/flutter_test.dart';

import 'package:liflow/services/date_ids.dart';

void main() {
  test('DateIds.dayId formats YYYY-MM-DD', () {
    final d = DateTime(2025, 1, 5);
    expect(DateIds.dayId(d), '2025-01-05');
  });

  test('DateIds.weekId follows ISO weeks', () {
    // 2025-01-01 is in ISO week 1 of 2025.
    expect(DateIds.weekId(DateTime(2025, 1, 1)), '2025-W01');

    // 2024-12-30 (Mon) is in ISO week 1 of 2025.
    expect(DateIds.weekId(DateTime(2024, 12, 30)), '2025-W01');
  });

  test('DateIds.routineDayId is fixed by weekday', () {
    expect(DateIds.routineWeekId, 'weekly-routine');
    expect(DateIds.routineDayId(DateTime(2026, 6, 1)), 'weekday-1');
    expect(DateIds.routineDayId(DateTime(2026, 6, 7)), 'weekday-7');
  });
}
