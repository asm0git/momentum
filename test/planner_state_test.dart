import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momentum/data/database_helper.dart';
import 'package:momentum/data/planner_repository.dart';
import 'package:momentum/data_models.dart';
import 'package:momentum/state/planner_state.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Directory tempDirectory;
  late DatabaseHelper databaseHelper;
  late PlannerRepository repository;
  late PlannerState planner;

  setUpAll(() => sqfliteFfiInit());

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp('momentum_state_');
    databaseHelper = DatabaseHelper.forTesting(
      factory: databaseFactoryFfi,
      databasePath: '${tempDirectory.path}/planner.db',
      seedOnCreate: false,
    );
    repository = PlannerRepository(databaseHelper: databaseHelper);
    planner = PlannerState(
      repository: repository,
      autoSyncCalendarsOnStartup: false,
      startAutomaticEventFocusTimer: false,
    );
  });

  tearDown(() async {
    planner.dispose();
    await databaseHelper.close();
    await tempDirectory.delete(recursive: true);
  });

  test('initialize loads the saved planner snapshot', () async {
    final category = await repository.insertCategory(
      TaskCategory(title: 'School', iconName: 'mi_school', items: []),
    );
    await repository.insertTask(
      Task(
        categoryId: category.id,
        title: 'Read chapter',
        date: DateTime(2026, 10, 20),
        time: const TimeOfDay(hour: 10, minute: 30),
        estimatedDuration: const Duration(minutes: 25),
        isChecked: false,
      ),
    );

    await planner.initialize();

    expect(planner.isLoading, isFalse);
    expect(planner.error, isNull);
    expect(planner.categories.single.title, 'School');
    expect(planner.items.whereType<Task>().single.title, 'Read chapter');
    expect(planner.categories.single.items.single.title, 'Read chapter');
  });

  test(
    'retry reports a load error and recovers when storage is available',
    () async {
      await planner.initialize();
      await planner.addCategory(
        TaskCategory(title: 'Personal', iconName: 'personal', items: []),
      );
      final database = await databaseHelper.database;
      await database.execute(
        'ALTER TABLE categories RENAME TO categories_temporarily_unavailable',
      );

      await planner.retry();

      expect(planner.isLoading, isFalse);
      expect(planner.error, isNotNull);
      expect(planner.categories.single.title, 'Personal');

      await database.execute(
        'ALTER TABLE categories_temporarily_unavailable RENAME TO categories',
      );
      await planner.retry();

      expect(planner.isLoading, isFalse);
      expect(planner.error, isNull);
      expect(planner.categories.single.title, 'Personal');
    },
  );

  test('category projection selects the next incomplete recurrence', () async {
    final category = await planner.addCategory(
      TaskCategory(title: 'Study', iconName: 'mi_school', items: []),
    );
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final tomorrow = todayDate.add(const Duration(days: 1));
    await planner.saveTask(
      Task(
        categoryId: category.id,
        title: 'Daily reading',
        date: todayDate,
        time: const TimeOfDay(hour: 9, minute: 0),
        estimatedDuration: const Duration(minutes: 25),
        isChecked: false,
        repeat: RecurrenceRule.daily,
        repeatUntil: tomorrow,
      ),
    );
    final todayOccurrence = planner
        .itemsForDate(todayDate)
        .whereType<Task>()
        .single;

    await planner.setTaskCompleted(todayOccurrence, true);

    final projected = planner
        .itemsForCategory(category.id!)
        .whereType<Task>()
        .single;
    expect(projected.occurrenceDate, tomorrow);
    expect(projected.isChecked, isFalse);
  });

  test(
    'To-Do hides expired imports and advances to the next occurrence',
    () async {
      final category = await planner.addCategory(
        TaskCategory(title: 'Imported', iconName: 'mi_school', items: []),
      );
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final yesterday = today.subtract(const Duration(days: 1));
      final tomorrow = today.add(const Duration(days: 1));
      final fixedNow = DateTime(today.year, today.month, today.day, 23, 59);

      await planner.saveTask(
        Task(
          categoryId: category.id,
          title: 'Expired import',
          date: yesterday,
          time: const TimeOfDay(hour: 8, minute: 0),
          estimatedDuration: const Duration(minutes: 25),
          isChecked: false,
          sourcePlatform: 'canvas',
        ),
      );
      await planner.saveTask(
        Task(
          categoryId: category.id,
          title: 'Manual task',
          date: yesterday,
          time: const TimeOfDay(hour: 8, minute: 0),
          estimatedDuration: const Duration(minutes: 25),
          isChecked: false,
        ),
      );
      await planner.saveTask(
        Task(
          categoryId: category.id,
          title: 'Imported daily task',
          date: today,
          time: const TimeOfDay(hour: 8, minute: 0),
          estimatedDuration: const Duration(minutes: 25),
          isChecked: false,
          repeat: RecurrenceRule.daily,
          repeatUntil: tomorrow,
          sourcePlatform: 'canvas',
        ),
      );

      final visible = planner.todoItemsForCategory(category.id!, now: fixedNow);

      expect(visible.map((item) => item.title), [
        'Manual task',
        'Imported daily task',
      ]);
      expect(
        visible
            .whereType<Task>()
            .singleWhere((task) => task.title == 'Imported daily task')
            .occurrenceDate,
        tomorrow,
      );
    },
  );

  test('focus candidates sort by time, then category and title', () async {
    final alpha = await planner.addCategory(
      TaskCategory(title: 'Alpha', iconName: 'mi_school', items: []),
    );
    final work = await planner.addCategory(
      TaskCategory(title: 'Work', iconName: 'mi_work', items: []),
    );
    final today = DateTime.now();
    final tomorrow = DateTime(today.year, today.month, today.day + 1);

    await planner.saveTask(
      Task(
        categoryId: work.id,
        title: 'Zeta task',
        date: tomorrow,
        time: const TimeOfDay(hour: 9, minute: 0),
        estimatedDuration: const Duration(minutes: 25),
        isChecked: false,
      ),
    );
    await planner.saveTask(
      Task(
        categoryId: alpha.id,
        title: 'Beta task',
        date: tomorrow,
        time: const TimeOfDay(hour: 9, minute: 0),
        estimatedDuration: const Duration(minutes: 25),
        isChecked: false,
      ),
    );
    await planner.saveTask(
      Task(
        categoryId: work.id,
        title: 'Early task',
        date: tomorrow,
        time: const TimeOfDay(hour: 8, minute: 0),
        estimatedDuration: const Duration(minutes: 25),
        isChecked: false,
      ),
    );

    expect(planner.selectableFocusItems.map((item) => item.taskTitle), [
      'Early task',
      'Beta task',
      'Zeta task',
    ]);
  });
}
