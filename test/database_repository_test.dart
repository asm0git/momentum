import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momentum/data/database_helper.dart';
import 'package:momentum/data/calendar_sync_repository.dart';
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
  late CalendarSyncRepository calendarSyncRepository;

  setUpAll(() => sqfliteFfiInit());

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp('momentum_test_');
    databaseHelper = DatabaseHelper.forTesting(
      factory: databaseFactoryFfi,
      databasePath: p.join(tempDirectory.path, 'momentum.db'),
      seedOnCreate: false,
    );
    repository = PlannerRepository(databaseHelper: databaseHelper);
    calendarSyncRepository = CalendarSyncRepository(
      databaseHelper: databaseHelper,
    );
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
      repeat: RecurrenceRule.weekly,
      repeatUntil: DateTime(2026, 11, 7),
      description: 'Chapter 3',
      priority: 2,
      sourcePlatform: 'local',
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
      repeat: RecurrenceRule.weekly,
      repeatUntil: DateTime(2026, 11, 7),
      sourcePlatform: 'local',
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
      accountName: 'Planner',
      accountEmail: 'a@example.test',
      providerUrl: 'https://calendar.example.test',
      remoteUserId: 'remote-1',
      categoryId: 4,
      lastSyncTime: DateTime(2026, 10, 7, 8, 30),
    );

    expect(categoryFromMap(categoryToMap(category)).title, 'School');
    final taskCopy = taskFromMap(taskToMap(task));
    expect(taskDateTime(taskCopy), DateTime(2026, 10, 7, 9, 25));
    expect(taskCopy.estimatedDuration, const Duration(minutes: 65));
    expect(taskCopy.isChecked, isTrue);
    expect(taskCopy.description, 'Chapter 3');
    expect(taskToMap(task)['repeat'], 'Every week');
    expect(taskCopy.repeat, RecurrenceRule.weekly);
    expect(taskCopy.repeatUntil, DateTime(2026, 11, 7));
    final eventCopy = eventFromMap(eventToMap(event));
    expect(eventStartDateTime(eventCopy), DateTime(2026, 10, 7, 23, 30));
    expect(eventEndDateTime(eventCopy), DateTime(2026, 10, 8, 0, 15));
    expect(eventToMap(event)['repeat'], 'Every week');
    expect(eventCopy.repeat, RecurrenceRule.weekly);
    expect(
      taskFromMap({...taskToMap(task), 'repeat': 'Every fortnight'}).repeat,
      RecurrenceRule.never,
    );
    expect(
      eventFromMap({...eventToMap(event), 'repeat': 'Every fortnight'}).repeat,
      RecurrenceRule.never,
    );
    expect(eventCopy.repeatUntil, DateTime(2026, 11, 7));
    expect(dailyPlanFromMap(dailyPlanToMap(plan)).orderedTaskIds, [7, 10]);
    final accountCopy = linkedAccountFromMap(linkedAccountToMap(account));
    expect(accountCopy.accountName, 'Planner');
    expect(accountCopy.providerUrl, 'https://calendar.example.test');
  });

  test('row decoders report malformed required column values', () {
    final task = Task(
      title: 'Read',
      date: DateTime(2026, 10, 7),
      time: const TimeOfDay(hour: 9, minute: 25),
      estimatedDuration: const Duration(minutes: 65),
      isChecked: false,
    );
    final event = Event(
      title: 'Meeting',
      date: DateTime(2026, 10, 7),
      start: const TimeOfDay(hour: 10, minute: 0),
      end: const TimeOfDay(hour: 11, minute: 0),
      isCurrent: false,
      allDay: false,
    );
    final plan = DailyPlan(
      planDate: DateTime(2026, 10, 7),
      orderedTaskIds: [7, 10],
      generatedTimestamp: DateTime(2026, 10, 7, 8),
    );
    final account = LinkedAccount(
      platformName: 'Calendar',
      accountName: 'Planner',
    );

    void expectColumnError(void Function() decode, String column) {
      expect(
        decode,
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            contains(column),
          ),
        ),
      );
    }

    final missingDue = Map<String, Object?>.from(taskToMap(task))
      ..remove('due');
    expectColumnError(() {
      taskFromMap(missingDue);
    }, 'due');
    expectColumnError(() {
      taskFromMap({...taskToMap(task), 'estimated_duration_minutes': '65'});
    }, 'estimated_duration_minutes');
    expectColumnError(() {
      eventFromMap({...eventToMap(event), 'start_time': 'not-a-date'});
    }, 'start_time');
    expectColumnError(() {
      dailyPlanFromMap({
        ...dailyPlanToMap(plan),
        'ordered_task_ids': '{broken',
      });
    }, 'ordered_task_ids');
    expectColumnError(() {
      linkedAccountFromMap({
        ...linkedAccountToMap(account),
        'platform_name': null,
      });
    }, 'platform_name');
  });

  test('row decoders report malformed optional column values', () {
    final task = Task(
      title: 'Read',
      date: DateTime(2026, 10, 7),
      time: const TimeOfDay(hour: 9, minute: 25),
      estimatedDuration: const Duration(minutes: 65),
      isChecked: false,
    );
    final event = Event(
      title: 'Meeting',
      date: DateTime(2026, 10, 7),
      start: const TimeOfDay(hour: 10, minute: 0),
      end: const TimeOfDay(hour: 11, minute: 0),
      isCurrent: false,
      allDay: false,
    );
    final account = LinkedAccount(
      platformName: 'Calendar',
      accountName: 'Planner',
    );

    void expectColumnError(void Function() decode, String column) {
      expect(
        decode,
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            contains(column),
          ),
        ),
      );
    }

    expectColumnError(() {
      taskFromMap({...taskToMap(task), 'id': '7'});
    }, 'id');
    expectColumnError(() {
      taskFromMap({...taskToMap(task), 'category_id': '4'});
    }, 'category_id');
    expectColumnError(() {
      taskFromMap({...taskToMap(task), 'description': 12});
    }, 'description');
    expectColumnError(() {
      taskFromMap({...taskToMap(task), 'priority': 'high'});
    }, 'priority');
    expectColumnError(() {
      taskFromMap({...taskToMap(task), 'src_platform': 1});
    }, 'src_platform');
    expectColumnError(() {
      eventFromMap({...eventToMap(event), 'location': false});
    }, 'location');
    expectColumnError(() {
      eventFromMap({...eventToMap(event), 'notes': 12});
    }, 'notes');
    expectColumnError(() {
      linkedAccountFromMap({...linkedAccountToMap(account), 'provider_url': 4});
    }, 'provider_url');
    expectColumnError(() {
      linkedAccountFromMap({
        ...linkedAccountToMap(account),
        'category_id': '2',
      });
    }, 'category_id');
    expectColumnError(() {
      optionalStringFromMap({'external_id': 3}, 'external_id');
    }, 'external_id');

    final taskWithNulls = taskFromMap({
      ...taskToMap(task),
      'id': null,
      'category_id': null,
      'description': null,
      'priority': null,
      'src_platform': null,
      'external_id': null,
    });
    expect(taskWithNulls.id, isNull);
    expect(taskWithNulls.categoryId, isNull);
    expect(taskWithNulls.description, isEmpty);
    expect(taskWithNulls.priority, isNull);
    expect(taskWithNulls.sourcePlatform, isNull);
    expect(taskWithNulls.externalId, isNull);

    final eventWithNulls = eventFromMap({
      ...eventToMap(event),
      'location': null,
      'notes': null,
      'src_platform': null,
      'external_id': null,
    });
    expect(eventWithNulls.location, isNull);
    expect(eventWithNulls.notes, isEmpty);
    expect(eventWithNulls.sourcePlatform, isNull);
    expect(eventWithNulls.externalId, isNull);

    final accountWithNulls = linkedAccountFromMap({
      ...linkedAccountToMap(account),
      'account_name': null,
      'account_email': null,
      'provider_url': null,
      'remote_user_id': null,
      'category_id': null,
    });
    expect(accountWithNulls.accountName, 'Linked account');
    expect(accountWithNulls.accountEmail, isNull);
    expect(accountWithNulls.providerUrl, isNull);
    expect(accountWithNulls.remoteUserId, isNull);
    expect(accountWithNulls.categoryId, isNull);
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

      final account = await calendarSyncRepository.insertLinkedAccount(
        LinkedAccount(
          platformName: 'Calendar',
          accountName: 'Planner',
          accountEmail: 'planner@example.test',
        ),
      );
      account.lastSyncTime = DateTime(2026, 10, 7, 9);
      expect(await calendarSyncRepository.updateLinkedAccount(account), isTrue);
      expect(
        (await calendarSyncRepository.getLinkedAccount(
          account.id!,
        ))?.lastSyncTime,
        DateTime(2026, 10, 7, 9),
      );

      expect(await repository.deleteTask(task.id!), isTrue);
      expect(await repository.deleteEvent(event.id!), isTrue);
      expect(await repository.deleteDailyPlan(plan.id!), isTrue);
      expect(
        await calendarSyncRepository.deleteLinkedAccount(account.id!),
        isTrue,
      );
      expect(
        await repository.deleteCategory(
          category.id!,
          disposition: CategoryDeleteDisposition.deleteItems,
        ),
        isTrue,
      );
      expect(
        await repository.deleteCategory(
          destinationCategory.id!,
          disposition: CategoryDeleteDisposition.deleteItems,
        ),
        isTrue,
      );
      expect(await repository.getTasks(), isEmpty);
      expect(await repository.getEvents(), isEmpty);
    },
  );

  test(
    'provider calendar sync upserts imported events without duplicates',
    () async {
      final firstSync = CalendarSyncPayload(
        accountName: 'Student Calendar',
        accountEmail: 'student@example.test',
        remoteUserId: 'google-user-4',
        providerUrl: '',
        syncedAt: DateTime(2026, 10, 9, 10),
        tasks: const [],
        events: [
          CalendarEventImport(
            externalId: 'primary:event-19',
            title: 'Study group',
            start: DateTime(2026, 10, 12, 9),
            end: DateTime(2026, 10, 12, 10),
            description: 'Review chapter 4',
            location: 'Library',
          ),
        ],
        providerName: 'google',
      );
      final account = await calendarSyncRepository.applyCalendarSync(firstSync);
      final initialEvents = (await repository.getAllItems())
          .whereType<Event>()
          .toList();
      expect(account.platformName, 'google');
      expect(account.categoryId, isNotNull);
      expect(initialEvents, hasLength(1));
      expect(initialEvents.single.categoryId, account.categoryId);

      await calendarSyncRepository.applyCalendarSync(
        CalendarSyncPayload(
          accountName: 'Student Calendar',
          accountEmail: 'student@example.test',
          remoteUserId: 'google-user-4',
          providerUrl: '',
          syncedAt: DateTime(2026, 10, 9, 11),
          tasks: const [],
          events: [
            CalendarEventImport(
              externalId: 'primary:event-19',
              title: 'Study group moved',
              start: DateTime(2026, 10, 12, 11),
              end: DateTime(2026, 10, 12, 12),
              description: 'Updated agenda',
              location: 'Room 2',
            ),
          ],
          providerName: 'google',
        ),
      );

      final refreshedEvents = (await repository.getAllItems())
          .whereType<Event>()
          .toList();
      expect(refreshedEvents, hasLength(1));
      expect(refreshedEvents.single.id, initialEvents.single.id);
      expect(refreshedEvents.single.title, 'Study group moved');
      expect(refreshedEvents.single.notes, 'Updated agenda');
      expect(refreshedEvents.single.location, 'Room 2');
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

  test(
    'deleting a category also deletes its tasks, events, and completions',
    () async {
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
          repeat: RecurrenceRule.weekly,
        ),
      );
      final occurrenceDate = DateTime(2026, 10, 14);
      await repository.setTaskOccurrenceCompleted(
        task.id!,
        occurrenceDate,
        true,
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

      expect(
        await repository.deleteCategory(
          category.id!,
          disposition: CategoryDeleteDisposition.deleteItems,
        ),
        isTrue,
      );
      expect(await repository.getCategory(category.id!), isNull);
      expect(await repository.getTask(task.id!), isNull);
      expect(await repository.getEvent(event.id!), isNull);
      expect(await repository.getTaskOccurrenceCompletionKeys(), isEmpty);
    },
  );

  test(
    'moving category contents preserves tasks, events, and recurrence',
    () async {
      final source = await repository.insertCategory(
        TaskCategory(title: 'Gym', iconName: 'gym', items: []),
      );
      final destination = await repository.insertCategory(
        TaskCategory(title: 'Health', iconName: 'health', items: []),
      );
      final task = await repository.insertTask(
        Task(
          categoryId: source.id,
          title: 'Workout',
          date: DateTime(2026, 10, 7),
          time: const TimeOfDay(hour: 17, minute: 0),
          estimatedDuration: const Duration(hours: 1),
          isChecked: false,
          repeat: RecurrenceRule.weekly,
          repeatUntil: DateTime(2026, 12, 1),
        ),
      );
      await repository.setTaskOccurrenceCompleted(
        task.id!,
        DateTime(2026, 10, 14),
        true,
      );
      final event = await repository.insertEvent(
        Event(
          categoryId: source.id,
          title: 'Class',
          date: DateTime(2026, 10, 7),
          start: const TimeOfDay(hour: 18, minute: 0),
          end: const TimeOfDay(hour: 19, minute: 0),
          isCurrent: false,
          allDay: false,
          repeat: RecurrenceRule.monthly,
          repeatUntil: DateTime(2027, 1, 1),
        ),
      );

      expect(
        await repository.deleteCategory(
          source.id!,
          disposition: CategoryDeleteDisposition.moveItems,
          destinationCategoryId: destination.id,
        ),
        isTrue,
      );

      final movedTask = await repository.getTask(task.id!);
      final movedEvent = await repository.getEvent(event.id!);
      expect(movedTask?.categoryId, destination.id);
      expect(movedTask?.repeat, RecurrenceRule.weekly);
      expect(movedTask?.repeatUntil, DateTime(2026, 12, 1));
      expect(movedEvent?.categoryId, destination.id);
      expect(movedEvent?.repeat, RecurrenceRule.monthly);
      expect(movedEvent?.repeatUntil, DateTime(2027, 1, 1));
      expect(await repository.getTaskOccurrenceCompletionKeys(), {
        taskOccurrenceKey(task.id!, DateTime(2026, 10, 14)),
      });
      expect((await repository.getCategory(destination.id!))?.title, 'Health');
    },
  );

  test(
    'Canvas sync upserts stable IDs and keeps local task completion',
    () async {
      final first = CalendarSyncPayload(
        accountName: 'Canvas Student',
        accountEmail: 'student@example.test',
        remoteUserId: '42',
        providerUrl: 'https://canvas.example.test',
        syncedAt: DateTime(2026, 10, 7, 9),
        tasks: [
          CalendarTaskImport(
            externalId: 'assignment:course_8:3',
            title: 'Essay',
            due: DateTime(2026, 10, 8, 17),
            description: 'First description',
          ),
        ],
        events: [
          CalendarEventImport(
            externalId: 'event:99',
            title: 'Lecture',
            start: DateTime(2026, 10, 9, 10),
            end: DateTime(2026, 10, 9, 11),
            location: 'Room A',
          ),
        ],
      );
      final account = await calendarSyncRepository.applyCalendarSync(first);
      final task = (await repository.getTasks()).single;
      final event = (await repository.getEvents()).single;
      expect(account.categoryId, isNotNull);
      expect(
        (await repository.getCategory(account.categoryId!))?.iconName,
        CalendarProvider.canvas.categoryIcon,
      );
      expect(task.sourcePlatform, 'canvas');
      expect(task.externalId, 'assignment:course_8:3');
      expect(event.externalId, 'event:99');
      task.isChecked = true;
      await repository.updateTask(task);

      await calendarSyncRepository.applyCalendarSync(
        CalendarSyncPayload(
          accountName: 'Canvas Student',
          accountEmail: 'student@example.test',
          remoteUserId: '42',
          providerUrl: 'https://canvas.example.test',
          syncedAt: DateTime(2026, 10, 7, 10),
          tasks: [
            CalendarTaskImport(
              externalId: 'assignment:course_8:3',
              title: 'Essay updated',
              due: DateTime(2026, 10, 10, 17),
              description: 'Updated description',
            ),
          ],
          events: const [],
        ),
      );
      final tasksAfterSync = await repository.getTasks();
      final eventsAfterSync = await repository.getEvents();
      expect(tasksAfterSync, hasLength(1));
      expect(tasksAfterSync.single.id, task.id);
      expect(tasksAfterSync.single.title, 'Essay updated');
      expect(tasksAfterSync.single.isChecked, isTrue);
      expect(tasksAfterSync.single.date, DateTime(2026, 10, 10));
      expect(eventsAfterSync, hasLength(1));
      expect(eventsAfterSync.single.id, event.id);

      await calendarSyncRepository.applyCalendarSync(
        CalendarSyncPayload(
          accountName: 'Canvas Student',
          accountEmail: 'student@example.test',
          remoteUserId: '42',
          providerUrl: 'https://canvas.example.test',
          syncedAt: DateTime(2026, 10, 7, 11),
          tasks: const [],
          events: const [],
        ),
        removeMissingTasks: true,
        removeMissingEvents: true,
      );
      expect(await repository.getTasks(), isEmpty);
      expect(await repository.getEvents(), isEmpty);
    },
  );

  test(
    'a failed Canvas batch leaves stored records and sync metadata intact',
    () async {
      final baseline = CalendarSyncPayload(
        accountName: 'Canvas Student',
        accountEmail: null,
        remoteUserId: '42',
        providerUrl: 'https://canvas.example.test',
        syncedAt: DateTime(2026, 10, 7, 9),
        tasks: [
          CalendarTaskImport(
            externalId: 'assignment:course_8:3',
            title: 'Original title',
            due: DateTime(2026, 10, 8, 17),
          ),
        ],
        events: const [],
      );
      final account = await calendarSyncRepository.applyCalendarSync(baseline);
      final db = await databaseHelper.database;
      await db.execute('''
      CREATE TRIGGER reject_canvas_record BEFORE INSERT ON tasks
      WHEN NEW.title = 'Reject this row'
      BEGIN SELECT RAISE(ABORT, 'test sync failure'); END
    ''');

      await expectLater(
        calendarSyncRepository.applyCalendarSync(
          CalendarSyncPayload(
            accountName: 'Canvas Student',
            accountEmail: null,
            remoteUserId: '42',
            providerUrl: 'https://canvas.example.test',
            syncedAt: DateTime(2026, 10, 7, 10),
            tasks: [
              CalendarTaskImport(
                externalId: 'assignment:course_8:3',
                title: 'Changed title',
                due: DateTime(2026, 10, 10, 17),
              ),
              CalendarTaskImport(
                externalId: 'assignment:course_8:4',
                title: 'Reject this row',
                due: DateTime(2026, 10, 11, 17),
              ),
            ],
            events: const [],
          ),
        ),
        throwsA(isA<DatabaseException>()),
      );

      expect((await repository.getTasks()).single.title, 'Original title');
      expect(
        (await calendarSyncRepository.getLinkedAccount(
          account.id!,
        ))?.lastSyncTime,
        DateTime(2026, 10, 7, 9),
      );
    },
  );

  test('a sync fails when its linked account update affects no rows', () async {
    final originalPayload = CalendarSyncPayload(
      accountName: 'Original account',
      accountEmail: 'student@example.test',
      remoteUserId: '42',
      providerUrl: 'https://canvas.example.test',
      syncedAt: DateTime(2026, 10, 7, 9),
      tasks: const [],
      events: const [],
    );
    final account = await calendarSyncRepository.applyCalendarSync(
      originalPayload,
    );
    final db = await databaseHelper.database;
    await db.execute('''
      CREATE TRIGGER ignore_linked_account_update
      BEFORE UPDATE ON linked_accounts
      BEGIN SELECT RAISE(IGNORE); END
    ''');

    await expectLater(
      calendarSyncRepository.applyCalendarSync(
        CalendarSyncPayload(
          accountName: 'Changed account',
          accountEmail: 'student@example.test',
          remoteUserId: '42',
          providerUrl: 'https://canvas.example.test',
          syncedAt: DateTime(2026, 10, 7, 10),
          tasks: const [],
          events: const [],
        ),
      ),
      throwsA(isA<StateError>()),
    );

    expect(
      (await calendarSyncRepository.getLinkedAccount(account.id!))?.accountName,
      'Original account',
    );
  });

  test(
    'v3 to v4 migration preserves planner rows and removes local token',
    () async {
      final legacyPath = p.join(tempDirectory.path, 'legacy_v3.db');
      final legacy = await databaseFactoryFfi.openDatabase(
        legacyPath,
        options: OpenDatabaseOptions(
          version: 3,
          onCreate: (db, version) async {
            await db.execute('''
            CREATE TABLE categories (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              title TEXT NOT NULL UNIQUE,
              icon_name TEXT NOT NULL
            )
          ''');
            await db.execute('''
            CREATE TABLE tasks (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              category_id INTEGER, title TEXT NOT NULL, description TEXT NOT NULL,
              due TEXT NOT NULL, estimated_duration_minutes INTEGER NOT NULL,
              repeat TEXT NOT NULL DEFAULT 'Never', repeat_until TEXT,
              priority INTEGER, is_completed INTEGER NOT NULL,
              src_platform TEXT, external_id TEXT
            )
          ''');
            await db.execute('''
            CREATE TABLE events (
              id INTEGER PRIMARY KEY AUTOINCREMENT, category_id INTEGER,
              title TEXT NOT NULL, start_time TEXT NOT NULL, end_time TEXT NOT NULL,
              location TEXT, is_all_day INTEGER NOT NULL, is_current INTEGER NOT NULL,
              repeat TEXT NOT NULL DEFAULT 'Never', repeat_until TEXT,
              notes TEXT NOT NULL DEFAULT '', src_platform TEXT, external_id TEXT
            )
          ''');
            await db.execute('''
            CREATE TABLE linked_accounts (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              platform_name TEXT NOT NULL, account_email TEXT NOT NULL,
              api_token TEXT NOT NULL, last_sync_time TEXT
            )
          ''');
            await db.insert('categories', {
              'id': 1,
              'title': 'School',
              'icon_name': 'mi_school',
            });
            await db.insert('tasks', {
              'id': 2,
              'category_id': 1,
              'title': 'Keep task',
              'description': '',
              'due': '2026-10-08T09:00:00',
              'estimated_duration_minutes': 0,
              'repeat': 'Never',
              'is_completed': 0,
            });
            await db.insert('events', {
              'id': 3,
              'category_id': 1,
              'title': 'Keep event',
              'start_time': '2026-10-08T10:00:00',
              'end_time': '2026-10-08T11:00:00',
              'is_all_day': 0,
              'is_current': 0,
              'repeat': 'Never',
              'notes': '',
            });
            await db.insert('linked_accounts', {
              'id': 4,
              'platform_name': 'canvas',
              'account_email': 'student@example.test',
              'api_token': 'plaintext-secret-that-must-be-dropped',
              'last_sync_time': '2026-10-08T08:00:00',
            });
          },
        ),
      );
      await legacy.close();

      final migratedHelper = DatabaseHelper.forTesting(
        factory: databaseFactoryFfi,
        databasePath: legacyPath,
        seedOnCreate: false,
      );
      final migratedDb = await migratedHelper.database;
      final tasks = await migratedDb.query('tasks');
      final events = await migratedDb.query('events');
      final categories = await migratedDb.query('categories');
      final columns = await migratedDb.rawQuery(
        'PRAGMA table_info(linked_accounts)',
      );
      final accounts = await migratedDb.query('linked_accounts');
      expect(tasks.single['title'], 'Keep task');
      expect(events.single['title'], 'Keep event');
      expect(categories.single['title'], 'School');
      expect(columns.map((row) => row['name']), isNot(contains('api_token')));
      expect(accounts.single['account_email'], 'student@example.test');
      expect(accounts.single['provider_url'], isNull);
      await migratedHelper.close();
    },
  );

  test('invalid category move leaves source data unchanged', () async {
    final source = await repository.insertCategory(
      TaskCategory(title: 'Source', iconName: 'source', items: []),
    );
    final task = await repository.insertTask(
      Task(
        categoryId: source.id,
        title: 'Preserved',
        date: DateTime(2026, 10, 7),
        time: const TimeOfDay(hour: 9, minute: 0),
        estimatedDuration: const Duration(minutes: 30),
        isChecked: false,
      ),
    );

    await expectLater(
      repository.deleteCategory(
        source.id!,
        disposition: CategoryDeleteDisposition.moveItems,
        destinationCategoryId: 9999,
      ),
      throwsStateError,
    );
    expect((await repository.getTask(task.id!))?.categoryId, source.id);
    expect(await repository.getCategory(source.id!), isNotNull);
  });

  test(
    'category move transaction rolls back all item changes on failure',
    () async {
      final source = await repository.insertCategory(
        TaskCategory(title: 'Source', iconName: 'source', items: []),
      );
      final destination = await repository.insertCategory(
        TaskCategory(title: 'Destination', iconName: 'destination', items: []),
      );
      final task = await repository.insertTask(
        Task(
          categoryId: source.id,
          title: 'Preserved task',
          date: DateTime(2026, 10, 7),
          time: const TimeOfDay(hour: 9, minute: 0),
          estimatedDuration: const Duration(minutes: 30),
          isChecked: false,
        ),
      );
      final event = await repository.insertEvent(
        Event(
          categoryId: source.id,
          title: 'Preserved event',
          date: DateTime(2026, 10, 7),
          start: const TimeOfDay(hour: 10, minute: 0),
          end: const TimeOfDay(hour: 11, minute: 0),
          isCurrent: false,
          allDay: false,
        ),
      );
      final db = await databaseHelper.database;
      await db.execute('''
      CREATE TRIGGER fail_event_category_move
      BEFORE UPDATE OF category_id ON events
      BEGIN
        SELECT RAISE(ABORT, 'test rollback');
      END
    ''');

      await expectLater(
        repository.deleteCategory(
          source.id!,
          disposition: CategoryDeleteDisposition.moveItems,
          destinationCategoryId: destination.id,
        ),
        throwsA(anything),
      );
      expect((await repository.getTask(task.id!))?.categoryId, source.id);
      expect((await repository.getEvent(event.id!))?.categoryId, source.id);
      expect(await repository.getCategory(source.id!), isNotNull);
    },
  );

  test('recurring task completion is stored per occurrence date', () async {
    final task = await repository.insertTask(
      Task(
        title: 'Weekly review',
        date: DateTime(2026, 10, 1),
        time: const TimeOfDay(hour: 9, minute: 0),
        estimatedDuration: const Duration(minutes: 30),
        isChecked: false,
        repeat: RecurrenceRule.weekly,
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
      repeat: RecurrenceRule.daily,
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
      repeat: RecurrenceRule.weekly,
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
      repeat: RecurrenceRule.monthly,
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
      repeat: RecurrenceRule.yearly,
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

    final maximumDate = DateTime(9999, 12, 31);
    final finalDayDaily = Task(
      title: 'Final day',
      date: maximumDate,
      time: const TimeOfDay(hour: 9, minute: 0),
      estimatedDuration: Duration.zero,
      isChecked: false,
      repeat: RecurrenceRule.daily,
    );
    expect(
      recurrenceDatesInRange(
        finalDayDaily,
        from: maximumDate,
        through: maximumDate,
      ),
      [maximumDate],
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
      expect((await repository.getTasks()).single.repeat, RecurrenceRule.never);
      expect((await repository.getEvents()).single.title, 'Existing event');
    },
  );

  test('first-launch fixtures seed categories without planner items', () async {
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
    // Starter categories are intentional, while items remain empty so a
    // clean install exercises the user's own storage flow.
    expect(firstEvents, isEmpty);
    await databaseHelper.close();
    databaseHelper = DatabaseHelper.forTesting(
      factory: databaseFactoryFfi,
      databasePath: p.join(tempDirectory.path, 'seed.db'),
    );
    repository = PlannerRepository(databaseHelper: databaseHelper);
    expect(
      (await repository.getCategories()).map((item) => item.title),
      containsAll(['School', 'Personal', 'Work', 'Gym']),
    );
    expect(await repository.getTasks(), isEmpty);
    expect(await repository.getEvents(), isEmpty);
  });
}
