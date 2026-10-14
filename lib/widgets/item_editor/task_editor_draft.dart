import 'package:flutter/material.dart';

import '../../data_models.dart';

/// Holds task-only form values while the shared item editor is open.
class TaskEditorDraft {
  TaskEditorDraft({Task? initialTask})
    : deadline = initialTask?.date ?? DateTime.now(),
      deadlineTime = initialTask?.time ?? const TimeOfDay(hour: 9, minute: 0),
      estimatedDuration =
          initialTask?.estimatedDuration ?? const Duration(hours: 1),
      notesController = TextEditingController(
        text: initialTask?.description ?? '',
      );

  final TextEditingController notesController;
  DateTime deadline;
  TimeOfDay deadlineTime;
  Duration estimatedDuration;

  void setDeadline(DateTime value) {
    deadline = DateTime(value.year, value.month, value.day);
  }

  Task toTask({
    required Task? original,
    required int categoryId,
    required String title,
    required RecurrenceRule repeat,
    required DateTime? repeatUntil,
  }) => Task(
    id: original?.id,
    categoryId: categoryId,
    title: title,
    date: DateTime(deadline.year, deadline.month, deadline.day),
    time: deadlineTime,
    estimatedDuration: estimatedDuration,
    repeat: repeat,
    repeatUntil: repeatUntil,
    isChecked: original?.isChecked ?? false,
    description: notesController.text.trim(),
    priority: original?.priority,
    sourcePlatform: original?.sourcePlatform,
    externalId: original?.externalId,
  );

  void dispose() => notesController.dispose();
}
