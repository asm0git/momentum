import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momentum/data/database_helper.dart';
import 'package:momentum/data/planner_repository.dart';
import 'package:momentum/data_models.dart';
import 'package:momentum/state/automatic_event_focus_coordinator.dart';
import 'package:momentum/state/focus_timer_state.dart';
import 'package:momentum/state/planner_state.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Directory tempDirectory;
  late DatabaseHelper databaseHelper;
  late PlannerState planner;
  late DateTime now;
  late FocusTimerState timer;
  late FocusTaskSelection selection;

  setUpAll(() => sqfliteFfiInit());

  setUp(() async {
    now = DateTime(2026, 10, 9, 10);
    tempDirectory = await Directory.systemTemp.createTemp('momentum_focus_');
    databaseHelper = DatabaseHelper.forTesting(
      factory: databaseFactoryFfi,
      databasePath: p.join(tempDirectory.path, 'focus.db'),
      seedOnCreate: false,
    );
    planner = PlannerState(
      repository: PlannerRepository(databaseHelper: databaseHelper),
      autoSyncCalendarsOnStartup: false,
      clock: () => now,
      startAutomaticEventFocusTimer: false,
    );
    await planner.initialize();
    final category = await planner.addCategory(
      TaskCategory(title: 'School', iconName: 'mi_school', items: []),
    );
    await planner.saveTask(
      Task(
        categoryId: category.id,
        title: 'Study',
        date: DateTime(2026, 10, 9),
        isChecked: false,
        time: const TimeOfDay(hour: 10, minute: 0),
        estimatedDuration: Duration.zero,
      ),
    );
    selection = planner.selectableFocusTasks.single;
    timer = FocusTimerState(
      workMinutes: 1,
      breakMinutes: 1,
      clock: () => now,
      startTicker: false,
    )..attachFocusHistorySource(planner);
    timer.selectTask(selection);
    await planner.getFocusSecondsForDate(now);
  });

  tearDown(() async {
    if (timer.isRunning) timer.toggleRunning();
    await timer.flushPendingForTesting();
    timer.dispose();
    planner.dispose();
    await databaseHelper.close();
    await tempDirectory.delete(recursive: true);
  });

  test('work phases cycle continuously into rest and back to work', () async {
    timer.toggleRunning();
    now = now.add(const Duration(seconds: 65));
    await timer.tickForTesting();

    expect(timer.isRunning, isTrue);
    expect(timer.phase, FocusPhase.rest);
    expect(timer.remainingSeconds, 55);
    expect(timer.totalFocusSecondsToday, 60);
    await timer.flushPendingForTesting();
    final categoryTotals = await planner.getFocusCategoryTotalsForRange(
      now,
      now,
    );
    expect(categoryTotals.single.totalSeconds, 60);

    now = now.add(const Duration(seconds: 55));
    await timer.tickForTesting();
    expect(timer.phase, FocusPhase.work);
    expect(timer.remainingSeconds, 60);
    expect(timer.totalFocusSecondsToday, 60);
  });

  test('pause and resume accumulates only work seconds', () async {
    timer.toggleRunning();
    now = now.add(const Duration(seconds: 10));
    await timer.tickForTesting();
    timer.toggleRunning();
    await timer.flushPendingForTesting();
    expect(await planner.getFocusSecondsForDate(now), 10);

    timer.toggleRunning();
    now = now.add(const Duration(seconds: 5));
    await timer.tickForTesting();
    timer.toggleRunning();
    await timer.flushPendingForTesting();

    expect(timer.totalFocusSecondsToday, 15);
    expect(await planner.getFocusSecondsForDate(now), 15);
    final categoryTotals = await planner.getFocusCategoryTotalsForRange(
      now,
      now,
    );
    expect(categoryTotals.single.totalSeconds, 15);
  });

  test('timer starts without a task and records focus as unassigned', () async {
    timer.selectTask(null);
    expect(timer.toggleRunning(), isTrue);
    expect(timer.isRunning, isTrue);

    now = now.add(const Duration(seconds: 12));
    await timer.tickForTesting();
    timer.toggleRunning();
    await timer.flushPendingForTesting();

    expect(await planner.getFocusSecondsForDate(now), 12);
    final categoryTotals = await planner.getFocusCategoryTotalsForRange(
      now,
      now,
    );
    expect(categoryTotals, hasLength(1));
    expect(categoryTotals.single.categoryId, -1);
    expect(categoryTotals.single.categoryTitle, 'Unassigned');
    expect(categoryTotals.single.categoryIcon, 'mi_timer');
    expect(categoryTotals.single.totalSeconds, 12);
  });

  test('task selection stays locked while the timer is running', () {
    expect(timer.toggleRunning(), isTrue);
    expect(timer.selectTask(null), isFalse);
    expect(timer.selectedTask, selection);
    expect(timer.toggleRunning(), isTrue);
  });

  test(
    'picker includes only incomplete categorized tasks and one repeat series',
    () async {
      final category = planner.categories.single;
      final today = DateTime.now();
      final recurring = await planner.saveTask(
        Task(
          categoryId: category.id,
          title: 'Daily reading',
          date: DateTime(today.year, today.month, today.day),
          isChecked: false,
          time: const TimeOfDay(hour: 9, minute: 0),
          estimatedDuration: Duration.zero,
          repeat: RecurrenceRule.daily,
          repeatUntil: DateTime(today.year, today.month, today.day + 5),
        ),
      );
      final completed = await planner.saveTask(
        Task(
          categoryId: category.id,
          title: 'Already done',
          date: DateTime(today.year, today.month, today.day),
          isChecked: true,
          time: const TimeOfDay(hour: 9, minute: 0),
          estimatedDuration: Duration.zero,
        ),
      );
      final unassigned = await planner.saveTask(
        Task(
          title: 'No category',
          date: DateTime(today.year, today.month, today.day),
          isChecked: false,
          time: const TimeOfDay(hour: 9, minute: 0),
          estimatedDuration: Duration.zero,
        ),
      );

      final ids = planner.selectableFocusTasks
          .map((task) => task.taskId)
          .toList();
      expect(ids.where((id) => id == recurring.id).length, 1);
      expect(ids, contains(selection.taskId));
      expect(ids, isNot(contains(completed.id)));
      expect(ids, isNot(contains(unassigned.id)));
    },
  );

  test(
    'task changes while paused attribute later work to the new category',
    () async {
      timer.toggleRunning();
      now = now.add(const Duration(seconds: 5));
      await timer.tickForTesting();
      timer.toggleRunning();
      await timer.flushPendingForTesting();

      final otherCategory = await planner.addCategory(
        TaskCategory(title: 'Personal', iconName: 'mi_person', items: []),
      );
      await planner.saveTask(
        Task(
          categoryId: otherCategory.id,
          title: 'Read',
          date: DateTime(2026, 10, 9),
          isChecked: false,
          time: const TimeOfDay(hour: 11, minute: 0),
          estimatedDuration: Duration.zero,
        ),
      );
      final nextSelection = planner.selectableFocusTasks.singleWhere(
        (task) => task.categoryId == otherCategory.id,
      );
      expect(timer.selectTask(nextSelection), isTrue);
      timer.toggleRunning();
      now = now.add(const Duration(seconds: 4));
      await timer.tickForTesting();
      timer.toggleRunning();
      await timer.flushPendingForTesting();

      final totals = await planner.getFocusCategoryTotalsForRange(now, now);
      expect(
        {for (final total in totals) total.categoryTitle: total.totalSeconds},
        {'School': 5, 'Personal': 4},
      );
    },
  );

  test(
    'preset selection applies immediately and resets the current phase',
    () async {
      timer.toggleRunning();
      now = now.add(const Duration(seconds: 12));
      await timer.tickForTesting();
      timer.selectPreset(workMinutes: 45, breakMinutes: 10);

      expect(timer.isRunning, isTrue);
      expect(timer.phase, FocusPhase.work);
      expect(timer.workMinutes, 45);
      expect(timer.breakMinutes, 10);
      expect(timer.remainingSeconds, 45 * 60);
      expect(timer.totalFocusSecondsToday, 12);
      timer.toggleRunning();
      await timer.flushPendingForTesting();
    },
  );

  test(
    'focus totals split at local midnight and persist by calendar date',
    () async {
      timer.dispose();
      now = DateTime(2026, 10, 9, 23, 59, 58);
      timer = FocusTimerState(
        workMinutes: 1,
        breakMinutes: 1,
        clock: () => now,
        startTicker: false,
      )..attachFocusHistorySource(planner);
      timer.selectTask(selection);
      await planner.getFocusSecondsForDate(now);

      timer.toggleRunning();
      now = now.add(const Duration(seconds: 5));
      await timer.tickForTesting();
      await timer.flushPendingForTesting();

      expect(await planner.getFocusSecondsForDate(DateTime(2026, 10, 9)), 2);
      expect(await planner.getFocusSecondsForDate(DateTime(2026, 10, 10)), 3);
      expect(timer.totalFocusSecondsToday, 3);
      final categoryTotals = await planner.getFocusCategoryTotalsForRange(
        DateTime(2026, 10, 9),
        DateTime(2026, 10, 10),
      );
      expect(categoryTotals.single.totalSeconds, 5);
    },
  );

  test('automatic event focus aggregation groups by day and category', () {
    final from = DateTime(2026, 10, 9, 23, 59, 58);
    final midnight = DateTime(2026, 10, 10);
    final through = DateTime(2026, 10, 10, 0, 0, 5);
    const firstCategory = FocusTaskSelection(
      taskId: 1,
      taskTitle: 'First event',
      categoryId: 4,
      categoryTitle: 'School',
      categoryIcon: 'mi_school',
      isEvent: true,
    );
    const overlappingCategory = FocusTaskSelection(
      taskId: 2,
      taskTitle: 'Overlapping event',
      categoryId: 5,
      categoryTitle: 'Personal',
      categoryIcon: 'mi_person',
      isEvent: true,
    );
    const laterSameCategory = FocusTaskSelection(
      taskId: 3,
      taskTitle: 'Later event',
      categoryId: 4,
      categoryTitle: 'School',
      categoryIcon: 'mi_school',
      isEvent: true,
    );

    final buckets = aggregateAutomaticFocusBuckets(
      intervals: [
        ScheduledEventFocusInterval(
          midnight.add(const Duration(seconds: 2)),
          through,
          laterSameCategory,
        ),
        ScheduledEventFocusInterval(
          from.add(const Duration(seconds: 1)),
          midnight.add(const Duration(seconds: 3)),
          overlappingCategory,
        ),
        ScheduledEventFocusInterval(
          from,
          midnight.add(const Duration(seconds: 2)),
          firstCategory,
        ),
      ],
      from: from,
      through: through,
    );

    expect(
      [
        for (final bucket in buckets)
          (
            date: bucket.date,
            categoryId: bucket.selection.categoryId,
            seconds: bucket.seconds,
          ),
      ],
      [
        (date: DateTime(2026, 10, 9), categoryId: 4, seconds: 2),
        (date: DateTime(2026, 10, 10), categoryId: 4, seconds: 4),
        (date: DateTime(2026, 10, 10), categoryId: 5, seconds: 1),
      ],
    );
    expect(buckets[1].selection, firstCategory);
  });

  testWidgets(
    'automatic event focus starts at the clock and records every 10 seconds',
    (tester) async {
      var clockNow = DateTime(2026, 10, 9, 10);
      final event = Event(
        title: 'Scheduled study session',
        date: clockNow,
        start: const TimeOfDay(hour: 10, minute: 0),
        end: const TimeOfDay(hour: 11, minute: 0),
        isCurrent: false,
        allDay: false,
      );
      const eventSelection = FocusTaskSelection(
        taskId: 7,
        taskTitle: 'Scheduled study session',
        categoryId: 4,
        categoryTitle: 'School',
        categoryIcon: 'mi_school',
        isEvent: true,
      );
      final recorded = <AutomaticFocusBatchEntry>[];
      var onRecordedCount = 0;
      final coordinator = AutomaticEventFocusCoordinator(
        events: () => [event],
        selectionForItem: (_) => eventSelection,
        recordBatch: (entries) async => recorded.addAll(entries),
        onRecorded: () => onRecordedCount++,
        clock: () => clockNow,
        enabled: true,
      );

      coordinator.start();
      clockNow = clockNow.add(const Duration(seconds: 10));
      await tester.pump(const Duration(seconds: 10));
      await tester.pump();

      expect(recorded, [
        (date: DateTime(2026, 10, 9), seconds: 10, selection: eventSelection),
      ]);
      expect(onRecordedCount, 1);
      coordinator.dispose();
    },
  );

  test('event focus selection uses half-open event boundaries', () {
    final eventStart = DateTime(2026, 10, 9, 10);
    final eventEnd = DateTime(2026, 10, 9, 11);
    final event = Event(
      title: 'Scheduled study session',
      date: eventStart,
      start: const TimeOfDay(hour: 10, minute: 0),
      end: const TimeOfDay(hour: 11, minute: 0),
      isCurrent: false,
      allDay: false,
    );
    const eventSelection = FocusTaskSelection(
      taskId: 7,
      taskTitle: 'Scheduled study session',
      categoryId: 4,
      categoryTitle: 'School',
      categoryIcon: 'mi_school',
      isEvent: true,
    );
    final coordinator = AutomaticEventFocusCoordinator(
      events: () => [event],
      selectionForItem: (_) => eventSelection,
      recordBatch: (_) async {},
      onRecorded: () {},
      clock: () => eventStart,
      enabled: false,
    );

    expect(coordinator.eventFocusSelectionAt(eventStart), eventSelection);
    expect(
      coordinator.eventFocusSelectionAt(
        eventEnd.subtract(const Duration(seconds: 1)),
      ),
      eventSelection,
    );
    expect(
      coordinator.eventFocusSelectionAt(
        eventStart.subtract(const Duration(seconds: 1)),
      ),
      isNull,
    );
    expect(coordinator.eventFocusSelectionAt(eventEnd), isNull);
    coordinator.dispose();
  });

  test('next event focus boundary is the nearest future half-open edge', () {
    final eventStart = DateTime(2026, 10, 9, 10);
    final eventEnd = DateTime(2026, 10, 9, 11);
    final event = Event(
      title: 'Scheduled study session',
      date: eventStart,
      start: const TimeOfDay(hour: 10, minute: 0),
      end: const TimeOfDay(hour: 11, minute: 0),
      isCurrent: false,
      allDay: false,
    );
    final coordinator = AutomaticEventFocusCoordinator(
      events: () => [event],
      selectionForItem: (_) => selection,
      recordBatch: (_) async {},
      onRecorded: () {},
      clock: () => eventStart,
      enabled: false,
    );

    expect(
      coordinator.nextEventFocusBoundaryAfter(
        eventStart.subtract(const Duration(hours: 1)),
        eventEnd,
      ),
      eventStart,
    );
    expect(
      coordinator.nextEventFocusBoundaryAfter(eventStart, eventEnd),
      eventEnd,
    );
    expect(
      coordinator.nextEventFocusBoundaryAfter(
        eventEnd,
        eventEnd.add(const Duration(hours: 1)),
      ),
      isNull,
    );
    coordinator.dispose();
  });

  testWidgets('disposed automatic event focus cannot record again', (
    tester,
  ) async {
    var clockNow = DateTime(2026, 10, 9, 10);
    final event = Event(
      title: 'Scheduled study session',
      date: clockNow,
      start: const TimeOfDay(hour: 10, minute: 0),
      end: const TimeOfDay(hour: 11, minute: 0),
      isCurrent: false,
      allDay: false,
    );
    final recorded = <AutomaticFocusBatchEntry>[];
    final coordinator = AutomaticEventFocusCoordinator(
      events: () => [event],
      selectionForItem: (_) => selection,
      recordBatch: (entries) async => recorded.addAll(entries),
      onRecorded: () {},
      clock: () => clockNow,
      enabled: true,
    );

    coordinator.start();
    coordinator.dispose();
    clockNow = clockNow.add(const Duration(seconds: 10));
    await tester.pump(const Duration(seconds: 10));
    await coordinator.recordCurrentInterval();

    expect(recorded, isEmpty);
  });

  test(
    'automatic event focus retries a failed batch without duplication',
    () async {
      await planner.saveEvent(
        Event(
          categoryId: selection.categoryId,
          title: 'Scheduled study session',
          date: DateTime(now.year, now.month, now.day),
          start: TimeOfDay.fromDateTime(now),
          end: TimeOfDay.fromDateTime(now.add(const Duration(minutes: 1))),
          isCurrent: false,
          allDay: false,
        ),
      );
      final database = await databaseHelper.database;
      await database.execute('''
      CREATE TRIGGER fail_focus_category_total
      BEFORE INSERT ON focus_daily_category_totals
      BEGIN SELECT RAISE(ABORT, 'simulated focus write failure'); END
    ''');
      final initialRevision = planner.focusHistoryRevision;
      now = now.add(const Duration(seconds: 5));

      await planner.recordAutomaticEventFocusForTesting();

      expect(await planner.getFocusSecondsForDate(now), 0);
      expect(await planner.getFocusCategoryTotalsForRange(now, now), isEmpty);
      expect(planner.focusHistoryRevision, initialRevision);

      await database.execute('DROP TRIGGER fail_focus_category_total');
      await planner.recordAutomaticEventFocusForTesting();

      expect(await planner.getFocusSecondsForDate(now), 5);
      expect(
        (await planner.getFocusCategoryTotalsForRange(
          now,
          now,
        )).single.totalSeconds,
        5,
      );
      expect(planner.focusHistoryRevision, initialRevision + 1);

      await planner.recordAutomaticEventFocusForTesting();
      expect(await planner.getFocusSecondsForDate(now), 5);
      expect(planner.focusHistoryRevision, initialRevision + 1);
    },
  );

  test(
    'timer retries failed focus writes without dropping pending seconds',
    () async {
      final database = await databaseHelper.database;
      await database.execute('''
        CREATE TRIGGER fail_focus_category_total
        BEFORE INSERT ON focus_daily_category_totals
        BEGIN SELECT RAISE(ABORT, 'simulated focus write failure'); END
      ''');

      timer.toggleRunning();
      now = now.add(const Duration(seconds: 5));
      await timer.tickForTesting();
      timer.toggleRunning();
      await timer.flushPendingForTesting();

      expect(timer.hasPendingFocusHistoryWriteFailure, isTrue);
      expect(timer.totalFocusSecondsToday, 5);
      expect(await planner.getFocusSecondsForDate(now), 0);

      await database.execute('DROP TRIGGER fail_focus_category_total');
      await timer.retryPendingFocusHistoryWrite();

      expect(timer.hasPendingFocusHistoryWriteFailure, isFalse);
      expect(await planner.getFocusSecondsForDate(now), 5);
      expect(
        (await planner.getFocusCategoryTotalsForRange(
          now,
          now,
        )).single.totalSeconds,
        5,
      );
      await timer.flushPendingForTesting();
      expect(await planner.getFocusSecondsForDate(now), 5);
    },
  );
}
