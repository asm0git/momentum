import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momentum/data_models.dart';
import 'package:momentum/widgets/item_editor/event_editor_draft.dart';
import 'package:momentum/widgets/item_editor/task_editor_draft.dart';

void main() {
  test('task draft builds an updated task with its task-only fields', () {
    final original = Task(
      id: 12,
      categoryId: 3,
      title: 'Old title',
      date: DateTime(2026, 10, 20),
      time: const TimeOfDay(hour: 8, minute: 30),
      estimatedDuration: const Duration(minutes: 40),
      isChecked: true,
      priority: 2,
      sourcePlatform: 'canvas',
      externalId: 'assignment-12',
      description: 'Old notes',
    );
    final draft = TaskEditorDraft(initialTask: original);
    addTearDown(draft.dispose);
    draft.setDeadline(DateTime(2026, 10, 22, 17));
    draft.notesController.text = '  Updated notes  ';

    final updated = draft.toTask(
      original: original,
      categoryId: 5,
      title: 'Updated title',
      repeat: RecurrenceRule.weekly,
      repeatUntil: DateTime(2026, 11, 5),
    );

    expect(updated.id, original.id);
    expect(updated.categoryId, 5);
    expect(updated.title, 'Updated title');
    expect(updated.date, DateTime(2026, 10, 22));
    expect(updated.time, const TimeOfDay(hour: 8, minute: 30));
    expect(updated.estimatedDuration, const Duration(minutes: 40));
    expect(updated.repeat, RecurrenceRule.weekly);
    expect(updated.repeatUntil, DateTime(2026, 11, 5));
    expect(updated.isChecked, isTrue);
    expect(updated.description, 'Updated notes');
    expect(updated.priority, 2);
    expect(updated.sourcePlatform, 'canvas');
    expect(updated.externalId, 'assignment-12');
  });

  test('event draft normalizes all-day times and preserves event metadata', () {
    final original = Event(
      id: 7,
      categoryId: 3,
      title: 'Old title',
      date: DateTime(2026, 10, 20),
      start: const TimeOfDay(hour: 9, minute: 0),
      end: const TimeOfDay(hour: 10, minute: 0),
      isCurrent: true,
      allDay: false,
      location: 'Room 4',
      sourcePlatform: 'outlook',
      externalId: 'meeting-7',
      notes: 'Old notes',
    );
    final draft = EventEditorDraft(initialEvent: original);
    addTearDown(draft.dispose);
    draft.setAllDay(true);
    draft.setAllDayDate(DateTime(2026, 10, 22, 15));
    draft.notesController.text = ' Updated notes ';

    final updated = draft.toEvent(
      original: original,
      categoryId: 5,
      title: 'Updated title',
      repeat: RecurrenceRule.monthly,
      repeatUntil: DateTime(2026, 12, 22),
    );

    expect(updated.id, original.id);
    expect(updated.categoryId, 5);
    expect(updated.title, 'Updated title');
    expect(updated.date, DateTime(2026, 10, 22));
    expect(updated.endDate, DateTime(2026, 10, 22));
    expect(updated.start, const TimeOfDay(hour: 0, minute: 0));
    expect(updated.end, const TimeOfDay(hour: 0, minute: 0));
    expect(updated.allDay, isTrue);
    expect(updated.isCurrent, isTrue);
    expect(updated.location, 'Room 4');
    expect(updated.notes, 'Updated notes');
    expect(updated.repeat, RecurrenceRule.monthly);
    expect(updated.repeatUntil, DateTime(2026, 12, 22));
    expect(updated.sourcePlatform, 'outlook');
    expect(updated.externalId, 'meeting-7');
  });
}
