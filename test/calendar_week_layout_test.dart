import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momentum/data_models.dart';
import 'package:momentum/widgets/calendar/week_layout.dart';

void main() {
  final firstDate = DateTime(2025, 1, 5);
  final lastDate = DateTime(2025, 1, 11);
  final visibleDates = [
    for (var column = 0; column < 7; column++)
      (column, firstDate.add(Duration(days: column))),
  ];

  test('recurring multi-day events place each occurrence across its span', () {
    final event = _event(
      'Weekly event',
      date: DateTime(2025, 1, 2),
      endDate: DateTime(2025, 1, 4),
      repeat: RecurrenceRule.weekly,
    );

    final placements = placeCalendarWeekItems(
      items: [event],
      firstDate: firstDate,
      lastDate: lastDate,
      visibleDates: visibleDates,
    );

    expect(placements, hasLength(1));
    expect(placements.single.item.date, DateTime(2025, 1, 9));
    expect(placements.single.startColumn, 4);
    expect(placements.single.endColumn, 6);
    expect(placements.single.lane, 0);
    expect(placements.single.continuesBefore, isFalse);
    expect(placements.single.continuesAfter, isFalse);
  });

  test('multi-day events mark continuations on both sides of a week', () {
    final event = _event(
      'Long event',
      date: DateTime(2025, 1, 3),
      endDate: DateTime(2025, 1, 13),
    );

    final placements = placeCalendarWeekItems(
      items: [event],
      firstDate: firstDate,
      lastDate: lastDate,
      visibleDates: visibleDates,
    );

    expect(placements, hasLength(1));
    final placement = placements.single;
    expect(placement.startColumn, 0);
    expect(placement.endColumn, 6);
    expect(placement.continuesBefore, isTrue);
    expect(placement.continuesAfter, isTrue);
  });

  test('overlapping items use separate lanes and later items reuse lanes', () {
    final items = [
      _task('Monday task', DateTime(2025, 1, 6)),
      _event(
        'Monday to Wednesday',
        date: DateTime(2025, 1, 6),
        endDate: DateTime(2025, 1, 8),
        allDay: true,
      ),
      _event(
        'Thursday event',
        date: DateTime(2025, 1, 9),
        endDate: DateTime(2025, 1, 9),
      ),
    ];

    final placements = placeCalendarWeekItems(
      items: items,
      firstDate: firstDate,
      lastDate: lastDate,
      visibleDates: visibleDates,
    );
    final byTitle = {
      for (final placement in placements) placement.item.title: placement,
    };

    expect(byTitle['Monday to Wednesday']?.lane, 0);
    expect(byTitle['Monday task']?.lane, 1);
    expect(byTitle['Thursday event']?.lane, 0);
  });
}

Event _event(
  String title, {
  required DateTime date,
  required DateTime endDate,
  RecurrenceRule repeat = RecurrenceRule.never,
  bool allDay = false,
}) => Event(
  title: title,
  date: date,
  endDate: endDate,
  start: const TimeOfDay(hour: 9, minute: 0),
  end: const TimeOfDay(hour: 10, minute: 0),
  isCurrent: false,
  allDay: allDay,
  repeat: repeat,
);

Task _task(String title, DateTime date) => Task(
  title: title,
  date: date,
  isChecked: false,
  time: const TimeOfDay(hour: 9, minute: 0),
  estimatedDuration: const Duration(minutes: 30),
);
