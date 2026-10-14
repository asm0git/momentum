import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momentum/data/recurrence.dart';
import 'package:momentum/data_models.dart';
import 'package:momentum/state/planner_snapshot_queries.dart';

void main() {
  group('PlannerSnapshotQueries', () {
    test('expands recurring tasks and applies occurrence completion', () {
      final category = TaskCategory(
        id: 1,
        title: 'School',
        iconName: 'mi_school',
        items: const [],
      );
      final firstDay = DateTime(2026, 10, 14);
      final task = _task(
        id: 10,
        categoryId: category.id,
        title: 'Read a chapter',
        date: firstDay,
        repeat: RecurrenceRule.daily,
        repeatUntil: DateTime(2026, 10, 16),
      );
      final queries = _queries(
        categories: [category],
        items: [task],
        completedKeys: [taskOccurrenceKey(10, DateTime(2026, 10, 15))],
      );

      final occurrences = queries
          .itemsForRange(DateTime(2026, 10, 14, 17), DateTime(2026, 10, 16, 8))
          .whereType<Task>()
          .toList();

      expect(occurrences.map((item) => item.occurrenceDate), [
        DateTime(2026, 10, 14),
        DateTime(2026, 10, 15),
        DateTime(2026, 10, 16),
      ]);
      expect(occurrences.map((item) => item.isChecked), [false, true, false]);
      expect(task.date, firstDay, reason: 'The stored series stays unchanged.');
    });

    test('To-Do hides expired imports and advances a recurring import', () {
      final category = TaskCategory(
        id: 2,
        title: 'Imported',
        iconName: 'mi_calendar',
        items: const [],
      );
      final now = DateTime(2026, 10, 14, 12);
      final importedDaily = _task(
        id: 20,
        categoryId: category.id,
        title: 'Daily feed task',
        date: DateTime(2026, 10, 14),
        hour: 8,
        repeat: RecurrenceRule.daily,
        repeatUntil: DateTime(2026, 10, 16),
        sourcePlatform: 'canvas',
      );
      final queries = _queries(
        categories: [category],
        items: [
          _task(
            id: 21,
            categoryId: category.id,
            title: 'Expired feed task',
            date: DateTime(2026, 10, 13),
            sourcePlatform: 'canvas',
          ),
          _task(
            id: 22,
            categoryId: category.id,
            title: 'Manual task',
            date: DateTime(2026, 10, 13),
          ),
          importedDaily,
          _event(
            id: 23,
            categoryId: category.id,
            title: 'Expired all-day import',
            date: DateTime(2026, 10, 13),
            endDate: DateTime(2026, 10, 13),
            allDay: true,
            sourcePlatform: 'google',
          ),
          _event(
            id: 24,
            categoryId: category.id,
            title: 'Current all-day import',
            date: DateTime(2026, 10, 14),
            endDate: DateTime(2026, 10, 14),
            allDay: true,
            sourcePlatform: 'outlook',
          ),
        ],
      );

      final visible = queries.todoItemsForCategory(category.id!, now: now);

      expect(visible.map((item) => item.title), [
        'Manual task',
        'Current all-day import',
        'Daily feed task',
      ]);
      expect(
        visible
            .whereType<Task>()
            .singleWhere((item) => item.id == 20)
            .occurrenceDate,
        DateTime(2026, 10, 15),
      );
      expect(importedDaily.date, DateTime(2026, 10, 14));
    });

    test(
      'focus selections sort scheduled tasks and events and omit checked tasks',
      () {
        final school = TaskCategory(
          id: 3,
          title: 'School',
          iconName: 'mi_school',
          items: const [],
        );
        final work = TaskCategory(
          id: 4,
          title: 'Work',
          iconName: 'mi_work',
          items: const [],
        );
        final tomorrow = DateTime(2026, 10, 15);
        final queries = _queries(
          categories: [work, school],
          items: [
            _task(
              id: 30,
              categoryId: work.id,
              title: 'Beta task',
              date: tomorrow,
            ),
            _task(
              id: 31,
              categoryId: school.id,
              title: 'Alpha task',
              date: tomorrow,
            ),
            _task(
              id: 32,
              categoryId: school.id,
              title: 'Completed task',
              date: tomorrow,
              isChecked: true,
            ),
            _event(
              id: 33,
              categoryId: work.id,
              title: 'Morning event',
              date: tomorrow,
              hour: 8,
            ),
          ],
        );

        final selections = queries.selectableFocusItems(
          DateTime(2026, 10, 14, 12),
        );

        expect(selections.map((item) => item.taskTitle), [
          'Morning event',
          'Alpha task',
          'Beta task',
        ]);
        expect(selections.first.isEvent, isTrue);
        expect(selections[1].categoryIcon, 'mi_school_display');
        expect(queries.selectableFocusTasks(DateTime(2026, 10, 14, 12)), [
          selections[1],
          selections[2],
        ]);
      },
    );
  });
}

PlannerSnapshotQueries _queries({
  required List<TaskCategory> categories,
  required List<PlannerItem> items,
  List<String> completedKeys = const [],
}) => PlannerSnapshotQueries(
  categories: categories,
  items: items,
  taskOccurrenceCompletionKeys: completedKeys,
  categoryDisplayIconName: (category) => '${category.iconName}_display',
);

Task _task({
  required int id,
  required int? categoryId,
  required String title,
  required DateTime date,
  int hour = 9,
  bool isChecked = false,
  RecurrenceRule repeat = RecurrenceRule.never,
  DateTime? repeatUntil,
  String? sourcePlatform,
}) => Task(
  id: id,
  categoryId: categoryId,
  title: title,
  date: date,
  isChecked: isChecked,
  time: TimeOfDay(hour: hour, minute: 0),
  estimatedDuration: const Duration(minutes: 25),
  repeat: repeat,
  repeatUntil: repeatUntil,
  sourcePlatform: sourcePlatform,
);

Event _event({
  required int id,
  required int? categoryId,
  required String title,
  required DateTime date,
  int hour = 9,
  DateTime? endDate,
  bool allDay = false,
  String? sourcePlatform,
}) => Event(
  id: id,
  categoryId: categoryId,
  title: title,
  date: date,
  endDate: endDate,
  start: TimeOfDay(hour: hour, minute: 0),
  end: TimeOfDay(hour: hour + 1, minute: 0),
  isCurrent: false,
  allDay: allDay,
  sourcePlatform: sourcePlatform,
);
