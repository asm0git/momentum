import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momentum/data/database_helper.dart';
import 'package:momentum/data/model_serialization.dart';
import 'package:momentum/data/planner_repository.dart';
import 'package:momentum/data_models.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Directory tempDirectory;
  late DatabaseHelper databaseHelper;
  late PlannerRepository repository;

  setUpAll(() => sqfliteFfiInit());

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp('momentum_test_');
    databaseHelper = DatabaseHelper.forTesting(
      factory: databaseFactoryFfi,
      databasePath: p.join(tempDirectory.path, 'momentum.db'),
      seedOnCreate: false,
    );
    repository = PlannerRepository(databaseHelper: databaseHelper);
    await databaseHelper.database;
  });

  tearDown(() async {
    await databaseHelper.close();
    await tempDirectory.delete(recursive: true);
  });

  test('serializes all five models and local date/time fields', () {
    final category = TaskCategory(
      id: 4,
      title: 'School',
      iconName: 'school',
      items: const [],
    );
    final task = Task(
      id: 7,
      categoryId: 4,
      title: 'Read',
      date: DateTime(2026, 10, 7),
      time: const TimeOfDay(hour: 9, minute: 25),
      estimatedDuration: const Duration(minutes: 65),
      isChecked: true,
      description: 'Chapter 3',
      priority: 2,
      srcPlatform: 'local',
      externalId: 'external-1',
    );
    final event = Event(
      id: 8,
      categoryId: 4,
      title: 'Meeting',
      date: DateTime(2026, 10, 7),
      endDate: DateTime(2026, 10, 8),
      start: const TimeOfDay(hour: 23, minute: 30),
      end: const TimeOfDay(hour: 0, minute: 15),
      isCurrent: true,
      allDay: false,
      location: 'Room 2',
      notes: 'Bring notes',
      repeat: 'Every week',
      srcPlatform: 'local',
      externalId: 'event-1',
    );
    final plan = DailyPlan(
      id: 9,
      planDate: DateTime(2026, 10, 7),
      orderedTaskIds: [7, 10],
      generatedTimestamp: DateTime(2026, 10, 7, 8, 0),
    );
    final account = LinkedAccount(
      id: 10,
      platformName: 'Calendar',
      accountEmail: 'a@example.test',
      apiToken: 'stored-locally',
      lastSyncTime: DateTime(2026, 10, 7, 8, 30),
    );

    expect(categoryFromMap(categoryToMap(category)).title, 'School');
    final taskCopy = taskFromMap(taskToMap(task));
    expect(taskDateTime(taskCopy), DateTime(2026, 10, 7, 9, 25));
    expect(taskCopy.estimatedDuration, const Duration(minutes: 65));
    expect(taskCopy.isChecked, isTrue);
    expect(taskCopy.description, 'Chapter 3');
    final eventCopy = eventFromMap(eventToMap(event));
    expect(eventStartDateTime(eventCopy), DateTime(2026, 10, 7, 23, 30));
    expect(eventEndDateTime(eventCopy), DateTime(2026, 10, 8, 0, 15));
    expect(eventCopy.repeat, 'Every week');
    expect(dailyPlanFromMap(dailyPlanToMap(plan)).orderedTaskIds, [7, 10]);
    expect(
      linkedAccountFromMap(linkedAccountToMap(account)).apiToken,
      'stored-locally',
    );
  });

  test(
    'CRUD works for categories, tasks, events, plans, and accounts',
    () async {
      final category = await repository.insertCategory(
        TaskCategory(title: 'Work', iconName: 'work', items: []),
      );
      expect(category.id, isNotNull);
      category.title = 'Office';
      expect(await repository.updateCategory(category), isTrue);
      expect((await repository.getCategory(category.id!))?.title, 'Office');

      final task = await repository.insertTask(
        Task(
          categoryId: category.id,
          title: 'Report',
          date: DateTime(2026, 10, 7),
          time: const TimeOfDay(hour: 10, minute: 0),
          estimatedDuration: const Duration(minutes: 45),
          isChecked: false,
        ),
      );
      task.description = 'Q4';
      expect(await repository.updateTask(task), isTrue);
      expect((await repository.getTask(task.id!))?.description, 'Q4');

      final event = await repository.insertEvent(
        Event(
          categoryId: category.id,
          title: 'Review',
          date: DateTime(2026, 10, 7),
          start: const TimeOfDay(hour: 11, minute: 0),
          end: const TimeOfDay(hour: 12, minute: 0),
          isCurrent: false,
          allDay: false,
        ),
      );
      event.notes = 'Slides';
      expect(await repository.updateEvent(event), isTrue);
      expect((await repository.getEvent(event.id!))?.notes, 'Slides');

      final plan = await repository.insertDailyPlan(
        DailyPlan(
          planDate: DateTime(2026, 10, 7),
          orderedTaskIds: [task.id!],
          generatedTimestamp: DateTime(2026, 10, 7, 8),
        ),
      );
      plan.orderedTaskIds = [];
      expect(await repository.updateDailyPlan(plan), isTrue);
      expect(
        (await repository.getDailyPlan(plan.id!))?.orderedTaskIds,
        isEmpty,
      );

      final account = await repository.insertLinkedAccount(
        LinkedAccount(
          platformName: 'Calendar',
          accountEmail: 'planner@example.test',
          apiToken: 'token',
        ),
      );
      account.lastSyncTime = DateTime(2026, 10, 7, 9);
      expect(await repository.updateLinkedAccount(account), isTrue);
      expect(
        (await repository.getLinkedAccount(account.id!))?.lastSyncTime,
        DateTime(2026, 10, 7, 9),
      );

      expect(await repository.deleteTask(task.id!), isTrue);
      expect(await repository.deleteEvent(event.id!), isTrue);
      expect(await repository.deleteDailyPlan(plan.id!), isTrue);
      expect(await repository.deleteLinkedAccount(account.id!), isTrue);
      expect(await repository.deleteCategory(category.id!), isTrue);
      expect(await repository.getTasks(), isEmpty);
      expect(await repository.getEvents(), isEmpty);
    },
  );

  test(
    'date queries and next-up select the matching and earliest records',
    () async {
      final today = DateTime(2026, 10, 7);
      final category = await repository.insertCategory(
        TaskCategory(title: 'Personal', iconName: 'personal', items: []),
      );
      final completed = await repository.insertTask(
        Task(
          categoryId: category.id,
          title: 'Completed earlier',
          date: today,
          time: const TimeOfDay(hour: 8, minute: 0),
          estimatedDuration: Duration.zero,
          isChecked: true,
        ),
      );
      final task = await repository.insertTask(
        Task(
          categoryId: category.id,
          title: 'Task',
          date: today,
          time: const TimeOfDay(hour: 11, minute: 0),
          estimatedDuration: const Duration(minutes: 30),
          isChecked: false,
        ),
      );
      final tomorrowTask = await repository.insertTask(
        Task(
          title: 'Tomorrow',
          date: today.add(const Duration(days: 1)),
          time: const TimeOfDay(hour: 9, minute: 0),
          estimatedDuration: Duration.zero,
          isChecked: false,
        ),
      );
      final event = await repository.insertEvent(
        Event(
          categoryId: category.id,
          title: 'Earlier event',
          date: today,
          start: const TimeOfDay(hour: 10, minute: 0),
          end: const TimeOfDay(hour: 10, minute: 30),
          isCurrent: false,
          allDay: false,
        ),
      );

      expect(
        (await repository.getTasksForDate(today)).map((item) => item.title),
        ['Completed earlier', 'Task'],
      );
      expect(
        (await repository.getItemsForDate(today)).map((item) => item.title),
        ['Completed earlier', 'Earlier event', 'Task'],
      );
      expect(
        await repository.getNextUpcomingItem(DateTime(2026, 10, 7, 9)),
        isA<Event>().having((item) => item.title, 'title', 'Earlier event'),
      );
      await repository.deleteEvent(event.id!);
      expect(
        await repository.getNextUpcomingItem(DateTime(2026, 10, 7, 9)),
        isA<Task>().having((item) => item.title, 'title', 'Task'),
      );
      await repository.deleteTask(task.id!);
      await repository.deleteTask(tomorrowTask.id!);
      expect(
        await repository.getNextUpcomingItem(DateTime(2026, 10, 7, 9)),
        isNull,
      );
      expect(await repository.getTask(completed.id!), isNotNull);
    },
  );

  test('deleting a category unassigns its tasks and events', () async {
    final category = await repository.insertCategory(
      TaskCategory(title: 'Gym', iconName: 'gym', items: []),
    );
    final task = await repository.insertTask(
      Task(
        categoryId: category.id,
        title: 'Workout',
        date: DateTime(2026, 10, 7),
        time: const TimeOfDay(hour: 17, minute: 0),
        estimatedDuration: const Duration(hours: 1),
        isChecked: false,
      ),
    );
    final event = await repository.insertEvent(
      Event(
        categoryId: category.id,
        title: 'Class',
        date: DateTime(2026, 10, 7),
        start: const TimeOfDay(hour: 18, minute: 0),
        end: const TimeOfDay(hour: 19, minute: 0),
        isCurrent: false,
        allDay: false,
      ),
    );

    expect(await repository.deleteCategory(category.id!), isTrue);
    expect((await repository.getTask(task.id!))?.categoryId, isNull);
    expect((await repository.getEvent(event.id!))?.categoryId, isNull);
  });

  test(
    'first-launch fixtures seed once and deleted data stays deleted',
    () async {
      await databaseHelper.close();
      databaseHelper = DatabaseHelper.forTesting(
        factory: databaseFactoryFfi,
        databasePath: p.join(tempDirectory.path, 'seed.db'),
      );
      repository = PlannerRepository(databaseHelper: databaseHelper);
      final firstCategories = await repository.getCategories();
      final firstTasks = await repository.getTasks();
      final firstEvents = await repository.getEvents();
      expect(
        firstCategories.map((item) => item.title),
        containsAll(['School', 'Personal', 'Work', 'Gym']),
      );
      expect(firstTasks, isNotEmpty);
      expect(firstEvents, isNotEmpty);
      await repository.deleteTask(firstTasks.first.id!);
      final countAfterDelete = (await repository.getTasks()).length;
      await databaseHelper.close();
      databaseHelper = DatabaseHelper.forTesting(
        factory: databaseFactoryFfi,
        databasePath: p.join(tempDirectory.path, 'seed.db'),
      );
      repository = PlannerRepository(databaseHelper: databaseHelper);
      expect((await repository.getTasks()).length, countAfterDelete);
    },
  );
}
