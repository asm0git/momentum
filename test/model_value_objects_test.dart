import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momentum/models/calendar_models.dart';
import 'package:momentum/models/focus_models.dart';
import 'package:momentum/models/planner_models.dart';

void main() {
  test('calendar providers expose their keys, labels, and category icons', () {
    expect(CalendarProvider.values.map((provider) => provider.key), [
      'canvas',
      'google',
      'outlook',
    ]);
    expect(CalendarProvider.values.map((provider) => provider.title), [
      'Canvas',
      'Google Calendar',
      'Outlook',
    ]);
    expect(CalendarProvider.values.map((provider) => provider.categoryIcon), [
      'provider_canvas',
      'provider_google',
      'provider_outlook',
    ]);
  });

  test(
    'calendar import and account models preserve their values and defaults',
    () {
      final due = DateTime(2026, 10, 9, 15);
      final task = CalendarTaskImport(
        externalId: 'task-1',
        title: 'Read chapter',
        due: due,
      );
      final event = CalendarEventImport(
        externalId: 'event-1',
        title: 'Study group',
        start: due,
        end: due,
        description: 'Bring notes',
        location: 'Library',
      );
      final payload = CalendarSyncPayload(
        accountName: 'Student',
        accountEmail: 'student@example.test',
        remoteUserId: 'remote-1',
        providerUrl: 'https://calendar.example.test',
        syncedAt: due,
        tasks: [task],
        events: [event],
      );
      final account = LinkedAccount(
        platformName: 'google',
        accountName: 'Student',
      );

      expect(task.description, isEmpty);
      expect(event.allDay, isFalse);
      expect(event.description, 'Bring notes');
      expect(event.location, 'Library');
      expect(payload.providerName, 'canvas');
      expect(payload.tasks, [task]);
      expect(payload.events, [event]);
      expect(account.accountName, 'Student');
      expect(account.accountEmail, isNull);
      account.lastSyncTime = due;
      expect(account.lastSyncTime, due);
    },
  );

  test(
    'focus selections compare all values and provide an unassigned value',
    () {
      const selection = FocusTaskSelection(
        taskId: 7,
        taskTitle: 'Read chapter',
        categoryId: 4,
        categoryTitle: 'School',
        categoryIcon: 'mi_school',
      );
      const equalSelection = FocusTaskSelection(
        taskId: 7,
        taskTitle: 'Read chapter',
        categoryId: 4,
        categoryTitle: 'School',
        categoryIcon: 'mi_school',
      );
      const eventSelection = FocusTaskSelection(
        taskId: 7,
        taskTitle: 'Read chapter',
        categoryId: 4,
        categoryTitle: 'School',
        categoryIcon: 'mi_school',
        isEvent: true,
      );

      expect(selection, equalSelection);
      expect(selection.hashCode, equalSelection.hashCode);
      expect(selection, isNot(eventSelection));
      expect(FocusTaskSelection.unassigned.categoryId, -1);
      expect(FocusTaskSelection.unassigned.categoryTitle, 'Unassigned');
    },
  );

  test('focus category totals retain their summary fields', () {
    const total = FocusCategoryTotal(
      categoryId: 4,
      categoryTitle: 'School',
      categoryIcon: 'mi_school',
      totalSeconds: 1800,
    );

    expect(total.categoryId, 4);
    expect(total.categoryTitle, 'School');
    expect(total.categoryIcon, 'mi_school');
    expect(total.totalSeconds, 1800);
  });

  test('planner models preserve schedule metadata and pending item counts', () {
    final date = DateTime(2026, 10, 9);
    final task = Task(
      id: 7,
      categoryId: 4,
      title: 'Read chapter',
      date: date,
      isChecked: false,
      time: const TimeOfDay(hour: 9, minute: 30),
      estimatedDuration: const Duration(minutes: 25),
      repeat: RecurrenceRule.weekly,
      repeatUntil: DateTime(2026, 11, 9),
      description: 'Chapter 4',
      priority: 2,
      sourcePlatform: 'canvas',
      externalId: 'assignment-7',
    );
    final completedTask = Task(
      title: 'Finished task',
      date: date,
      isChecked: true,
      time: const TimeOfDay(hour: 10, minute: 0),
      estimatedDuration: Duration.zero,
    );
    final event = Event(
      id: 8,
      categoryId: 4,
      title: 'Study group',
      date: date,
      start: const TimeOfDay(hour: 11, minute: 0),
      end: const TimeOfDay(hour: 12, minute: 0),
      isCurrent: true,
      allDay: false,
      location: 'Library',
      notes: 'Bring notes',
      repeat: RecurrenceRule.daily,
      repeatUntil: DateTime(2026, 10, 12),
      occurrenceDate: DateTime(2026, 10, 10),
      sourcePlatform: 'google',
      externalId: 'event-8',
    );
    final category = TaskCategory(
      id: 4,
      title: 'School',
      iconName: 'mi_school',
      items: [task, completedTask, event],
    );
    final plan = DailyPlan(
      id: 9,
      planDate: date,
      orderedTaskIds: [7],
      generatedTimestamp: DateTime(2026, 10, 9, 8),
    );

    expect(task.repeat, RecurrenceRule.weekly);
    expect(task.repeatUntil, DateTime(2026, 11, 9));
    expect(task.description, 'Chapter 4');
    expect(task.priority, 2);
    expect(task.sourcePlatform, 'canvas');
    expect(task.externalId, 'assignment-7');
    expect(event.endDate, date);
    expect(event.occurrenceDate, DateTime(2026, 10, 10));
    expect(event.location, 'Library');
    expect(event.notes, 'Bring notes');
    expect(category.pendingCount, 2);
    expect(plan.orderedTaskIds, [7]);
    expect(plan.generatedTimestamp, DateTime(2026, 10, 9, 8));
    expect(RecurrenceRule.values, hasLength(5));
    expect(CategoryDeleteDisposition.values, [
      CategoryDeleteDisposition.deleteItems,
      CategoryDeleteDisposition.moveItems,
    ]);
  });
}
