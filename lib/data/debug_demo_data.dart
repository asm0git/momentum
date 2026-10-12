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

    // Use a date-seeded sample so the preview looks varied across weekdays,
    // while staying stable for the same day during a session or test run.
    for (
      var date = first;
      !date.isAfter(last) && !date.isAfter(today);
      date = DateTime(date.year, date.month, date.day + 1)
    ) {
      final activity = _hashDate(date, 0x1b873593);
      if (activity % 100 < 22) continue;

      final intensity = _hashDate(date, 0x85ebca6b) % 100;
      final durationRoll = _hashDate(date, 0xc2b2ae35);
      final minutes = switch (intensity) {
        < 18 => 10 + durationRoll % 20,
        < 48 => 30 + durationRoll % 30,
        < 82 => 60 + durationRoll % 60,
        _ => 121 + durationRoll % 60,
      };

      final categoryRoll = _hashDate(date, 0x27d4eb2f);
      final primaryCategory = categoryRoll % _focusCategories.length;
      final additions = <int, int>{primaryCategory: minutes * 60};
      if (_hashDate(date, 0x165667b1) % 4 == 0) {
        final otherCategory =
            (primaryCategory + 1 + categoryRoll % 2) % _focusCategories.length;
        final otherMinutes = minutes ~/ 3;
        additions[primaryCategory] = (minutes - otherMinutes) * 60;
        additions[otherCategory] = otherMinutes * 60;
      }
      _addToDay(grouped, date, additions);
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

  static int _hashDate(DateTime date, int salt) {
    var hash = date.year * 10000 + date.month * 100 + date.day + salt;
    hash = (hash * 1664525 + 1013904223) & 0xffffffff;
    hash ^= hash >> 16;
    hash = (hash * 1664525 + 1013904223) & 0xffffffff;
    return (hash ^ (hash >> 16)) & 0xffffffff;
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
