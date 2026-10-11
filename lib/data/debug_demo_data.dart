import 'package:flutter/material.dart';

import '../data_models.dart';

/// In-memory sample data used only by the debug web app.
///
/// These records are overlaid on PlannerState and never written to SQLite.
class DebugDemoData {
  DebugDemoData._();

  static const googleCategoryId = -92001;
  static const googleEventId = -92002;

  static TaskCategory googleCalendarCategory({DateTime? now}) {
    final start = (now ?? DateTime.now()).add(const Duration(hours: 2));
    final end = start.add(const Duration(hours: 1));
    final event = Event(
      id: googleEventId,
      categoryId: googleCategoryId,
      title: 'Project planning',
      date: _dateOnly(start),
      start: TimeOfDay.fromDateTime(start),
      end: TimeOfDay.fromDateTime(end),
      endDate: _dateOnly(end),
      isCurrent: false,
      allDay: false,
      location: 'Google Meet',
      notes: 'Demo event imported from Google Calendar.',
      srcPlatform: 'google',
      externalId: 'momentum-debug-google-event',
    );

    return TaskCategory(
      id: googleCategoryId,
      title: 'Google Calendar',
      iconName: 'provider_google',
      items: [event],
    );
  }

  static Map<DateTime, List<FocusCategoryTotal>> focusByDay({
    required DateTime firstDay,
    required DateTime lastDay,
    DateTime? now,
  }) {
    final today = _dateOnly(now ?? DateTime.now());
    final first = _dateOnly(firstDay);
    final last = _dateOnly(lastDay);
    final grouped = <DateTime, Map<int, int>>{};

    // Give the current week a clear mix of daily totals and categories.
    const currentWeek = <int, Map<int, int>>{
      0: {0: 48 * 60, 1: 24 * 60},
      1: {0: 62 * 60},
      2: {1: 75 * 60},
      3: {2: 36 * 60},
      4: {0: 54 * 60, 2: 18 * 60},
      5: {1: 42 * 60},
      6: {0: 30 * 60},
    };
    for (final dayEntry in currentWeek.entries) {
      final date = today.subtract(Duration(days: dayEntry.key));
      _addToDay(grouped, date, dayEntry.value);
    }

    // Add a deterministic pattern across the previous year for the heatmap.
    for (var offset = 7; offset <= 363; offset++) {
      if (offset % 7 != 1 && offset % 7 != 3 && offset % 7 != 5) continue;
      final date = today.subtract(Duration(days: offset));
      final categoryIndex =
          (offset ~/ 7 + offset % 3) % _focusCategories.length;
      final seconds = (20 + (offset * 17) % 150) * 60;
      _addToDay(grouped, date, {categoryIndex: seconds});
    }

    return {
      for (final entry in grouped.entries)
        if (!entry.key.isBefore(first) && !entry.key.isAfter(last))
          entry.key: [
            for (final categoryEntry in entry.value.entries)
              FocusCategoryTotal(
                categoryId: _focusCategories[categoryEntry.key].id,
                categoryTitle: _focusCategories[categoryEntry.key].title,
                categoryIcon: _focusCategories[categoryEntry.key].icon,
                totalSeconds: categoryEntry.value,
              ),
          ],
    };
  }

  static const _focusCategories = <_DemoFocusCategory>[
    _DemoFocusCategory(-92101, 'Study', 'mi_school'),
    _DemoFocusCategory(-92102, 'Work', 'mi_work'),
    _DemoFocusCategory(-92103, 'Personal', 'mi_person'),
  ];

  static void _addToDay(
    Map<DateTime, Map<int, int>> totals,
    DateTime date,
    Map<int, int> additions,
  ) {
    final day = _dateOnly(date);
    final categoryTotals = totals.putIfAbsent(day, () => <int, int>{});
    for (final entry in additions.entries) {
      categoryTotals.update(
        entry.key,
        (seconds) => seconds + entry.value,
        ifAbsent: () => entry.value,
      );
    }
  }

  static DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);
}

class _DemoFocusCategory {
  const _DemoFocusCategory(this.id, this.title, this.icon);

  final int id;
  final String title;
  final String icon;
}
