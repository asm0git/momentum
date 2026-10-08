import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momentum/data/database_helper.dart';
import 'package:momentum/data/model_serialization.dart';
import 'package:momentum/data/planner_repository.dart';
import 'package:momentum/data/recurrence.dart';
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
      repeat: 'Every week',
      repeatUntil: DateTime(2026, 11, 7),
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
      repeatUntil: DateTime(2026, 11, 7),
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
    expect(taskCopy.repeat, 'Every week');
    expect(taskCopy.repeatUntil, DateTime(2026, 11, 7));
    final eventCopy = eventFromMap(eventToMap(event));
    expect(eventStartDateTime(eventCopy), DateTime(2026, 10, 7, 23, 30));
    expect(eventEndDateTime(eventCopy), DateTime(2026, 10, 8, 0, 15));
    expect(eventCopy.repeat, 'Every week');
    expect(eventCopy.repeatUntil, DateTime(2026, 11, 7));
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
      final destinationCategory = await repository.insertCategory(
        TaskCategory(title: 'Personal', iconName: 'personal', items: []),
      );
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
      task.categoryId = destinationCategory.id;
      expect(await repository.updateTask(task), isTrue);
      expect(
        (await repository.getTask(task.id!))?.categoryId,
        destinationCategory.id,
      );
      final categoriesWithItems = await repository.getCategoriesWithItems();
      expect(
        categoriesWithItems
            .firstWhere((item) => item.id == category.id)
            .items
            .whereType<Task>(),
        isEmpty,
      );
      expect(
        categoriesWithItems
            .firstWhere((item) => item.id == destinationCategory.id)
            .items
            .whereType<Task>()
            .map((item) => item.id),
        contains(task.id),
      );

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
      expect(await repository.deleteCategory(destinationCategory.id!), isTrue);
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

  test('recurring task completion is stored per occurrence date', () async {
    final task = await repository.insertTask(
      Task(
        title: 'Weekly review',
        date: DateTime(2026, 10, 1),
        time: const TimeOfDay(hour: 9, minute: 0),
        estimatedDuration: const Duration(minutes: 30),
        isChecked: false,
        repeat: 'Every week',
        repeatUntil: DateTime(2026, 10, 15),
      ),
    );

    expect(
      (await repository.getItemsForDate(DateTime(2026, 10, 8))).single,
      isA<Task>().having(
        (item) => item.occurrenceDate,
        'occurrence date',
        DateTime(2026, 10, 8),
      ),
    );
    await repository.setTaskOccurrenceCompleted(
      task.id!,
      DateTime(2026, 10, 8),
      true,
    );
    expect(
      (await repository.getItemsForDate(DateTime(2026, 10, 8))).single,
      isA<Task>().having((item) => item.isChecked, 'completed', isTrue),
    );
    expect(
      (await repository.getItemsForDate(DateTime(2026, 10, 15))).single,
      isA<Task>().having((item) => item.isChecked, 'completed', isFalse),
    );
    expect(await repository.getItemsForDate(DateTime(2026, 10, 16)), isEmpty);
  });

  test('recurrence expands through inclusive until and clamps month ends', () {
    final daily = Task(
      title: 'Daily',
      date: DateTime(2026, 10, 1),
      time: const TimeOfDay(hour: 8, minute: 0),
      estimatedDuration: Duration.zero,
      isChecked: false,
      repeat: 'Every day',
      repeatUntil: DateTime(2026, 10, 3),
    );
    expect(
      recurrenceDatesInRange(
        daily,
        from: DateTime(2026, 10, 1),
        through: DateTime(2026, 10, 4),
      ),
      [DateTime(2026, 10, 1), DateTime(2026, 10, 2), DateTime(2026, 10, 3)],
    );

    final weekly = Task(
      title: 'Weekly',
      date: DateTime(2026, 10, 1),
      time: const TimeOfDay(hour: 9, minute: 0),
      estimatedDuration: Duration.zero,
      isChecked: false,
      repeat: 'Every week',
      repeatUntil: DateTime(2026, 10, 15),
    );
    expect(
      recurrenceDatesInRange(
        weekly,
        from: DateTime(2026, 10, 1),
        through: DateTime(2026, 10, 16),
      ),
      [DateTime(2026, 10, 1), DateTime(2026, 10, 8), DateTime(2026, 10, 15)],
    );

    final monthly = Event(
      title: 'Monthly',
      date: DateTime(2026, 1, 31),
      start: const TimeOfDay(hour: 9, minute: 0),
      end: const TimeOfDay(hour: 10, minute: 0),
      isCurrent: false,
      allDay: false,
      repeat: 'Every month',
      repeatUntil: DateTime(2026, 4, 30),
    );
    expect(
      recurrenceDatesInRange(
        monthly,
        from: DateTime(2026, 1, 1),
        through: DateTime(2026, 5, 1),
      ),
      [
        DateTime(2026, 1, 31),
        DateTime(2026, 2, 28),
        DateTime(2026, 3, 31),
        DateTime(2026, 4, 30),
      ],
    );

    final yearly = Event(
      title: 'Birthday',
      date: DateTime(2024, 2, 29),
      start: const TimeOfDay(hour: 0, minute: 0),
      end: const TimeOfDay(hour: 0, minute: 0),
      isCurrent: false,
      allDay: true,
      repeat: 'Every year',
      repeatUntil: DateTime(2028, 2, 29),
    );
    expect(
      recurrenceDatesInRange(
        yearly,
        from: DateTime(2024, 1, 1),
        through: DateTime(2029, 1, 1),
      ),
      [
        DateTime(2024, 2, 29),
        DateTime(2025, 2, 28),
        DateTime(2026, 2, 28),
        DateTime(2027, 2, 28),
        DateTime(2028, 2, 29),
      ],
    );
  });

  test(
    'version 2 database migration preserves existing task and event data',
    () async {
      final path = p.join(tempDirectory.path, 'migration.db');
      final oldDb = await databaseFactoryFfi.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: 2,
          onCreate: (db, version) async {
            await db.execute('''CREATE TABLE categories (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT NOT NULL UNIQUE COLLATE NOCASE,
            icon_name TEXT NOT NULL
          )''');
            await db.execute('''CREATE TABLE tasks (
            id INTEGER PRIMARY KEY AUTOINCREMENT, category_id INTEGER,
            title TEXT NOT NULL, description TEXT NOT NULL DEFAULT '',
            due TEXT NOT NULL, estimated_duration_minutes INTEGER NOT NULL DEFAULT 0,
            priority INTEGER, is_completed INTEGER NOT NULL DEFAULT 0,
            src_platform TEXT, external_id TEXT,
            FOREIGN KEY (category_id) REFERENCES categories(id) ON DELETE SET NULL
          )''');
            await db.execute('''CREATE TABLE events (
            id INTEGER PRIMARY KEY AUTOINCREMENT, category_id INTEGER,
            title TEXT NOT NULL, start_time TEXT NOT NULL, end_time TEXT NOT NULL,
            location TEXT, is_all_day INTEGER NOT NULL DEFAULT 0,
            is_current INTEGER NOT NULL DEFAULT 0,
            repeat TEXT NOT NULL DEFAULT 'Never', notes TEXT NOT NULL DEFAULT '',
            src_platform TEXT, external_id TEXT,
            FOREIGN KEY (category_id) REFERENCES categories(id) ON DELETE SET NULL
          )''');
            final categoryId = await db.insert('categories', {
              'title': 'Saved',
              'icon_name': 'school',
            });
            await db.insert('tasks', {
              'category_id': categoryId,
              'title': 'Keep me',
              'description': 'Prior local task',
              'due': DateTime(2026, 10, 9, 9).toIso8601String(),
              'estimated_duration_minutes': 30,
              'is_completed': 0,
            });
            await db.insert('events', {
              'category_id': categoryId,
              'title': 'Existing event',
              'start_time': DateTime(2026, 10, 9, 10).toIso8601String(),
              'end_time': DateTime(2026, 10, 9, 11).toIso8601String(),
              'repeat': 'Never',
            });
          },
        ),
      );
      await oldDb.close();

      await databaseHelper.close();
      databaseHelper = DatabaseHelper.forTesting(
        factory: databaseFactoryFfi,
        databasePath: path,
        seedOnCreate: false,
      );
      repository = PlannerRepository(databaseHelper: databaseHelper);
      expect((await repository.getTasks()).single.title, 'Keep me');
      expect((await repository.getTasks()).single.repeat, 'Never');
      expect((await repository.getEvents()).single.title, 'Existing event');
    },
  );

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
      expect(firstTasks, isEmpty);
      expect(firstEvents, isNotEmpty);
      await repository.deleteEvent(firstEvents.first.id!);
      final eventCountAfterDelete = (await repository.getEvents()).length;
      await databaseHelper.close();
      databaseHelper = DatabaseHelper.forTesting(
        factory: databaseFactoryFfi,
        databasePath: p.join(tempDirectory.path, 'seed.db'),
      );
      repository = PlannerRepository(databaseHelper: databaseHelper);
      expect(await repository.getTasks(), isEmpty);
      expect((await repository.getEvents()).length, eventCountAfterDelete);
    },
  );
}
