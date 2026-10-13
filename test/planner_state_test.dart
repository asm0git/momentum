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
}
