import 'package:flutter/material.dart';

import '../../data_models.dart';

/// Holds event-only form values while the shared item editor is open.
class EventEditorDraft {
  EventEditorDraft({Event? initialEvent})
    : allDay = initialEvent?.allDay ?? false,
      startDate = initialEvent?.date ?? DateTime.now(),
      endDate = initialEvent?.endDate ?? DateTime.now(),
      startTime = initialEvent?.start ?? const TimeOfDay(hour: 9, minute: 0),
      endTime = initialEvent?.end ?? const TimeOfDay(hour: 10, minute: 0),
      notesController = TextEditingController(text: initialEvent?.notes ?? '') {
    if (!allDay) normalizeEndDateTime();
  }

  final TextEditingController notesController;
  bool allDay;
  DateTime startDate;
  DateTime endDate;
  TimeOfDay startTime;
  TimeOfDay endTime;

  void setAllDay(bool value) {
    allDay = value;
    if (value) {
      endDate = _dateOnly(startDate);
    } else {
      normalizeEndDateTime();
    }
  }

  void setAllDayDate(DateTime value) {
    startDate = _dateOnly(value);
    endDate = startDate;
  }

  void setStartDate(DateTime value) {
    startDate = _dateOnly(value);
    if (_dateOnly(endDate).isBefore(startDate)) endDate = startDate;
    normalizeEndDateTime();
  }

  void setStartTime(TimeOfDay value) {
    startTime = value;
    normalizeEndDateTime();
  }

  void setEndDate(DateTime value) {
    final selectedDate = _dateOnly(value);
    endDate = selectedDate.isBefore(_dateOnly(startDate))
        ? _dateOnly(startDate)
        : selectedDate;
    normalizeEndDateTime();
  }

  void setEndTime(TimeOfDay value) {
    endTime = value;
    normalizeEndDateTime();
  }

  void normalizeEndDateTime() {
    if (allDay) return;

    final startsAt = DateTime(
      startDate.year,
      startDate.month,
      startDate.day,
      startTime.hour,
      startTime.minute,
    );
    final endsAt = DateTime(
      endDate.year,
      endDate.month,
      endDate.day,
      endTime.hour,
      endTime.minute,
    );
    if (!endsAt.isAfter(startsAt)) {
      final earliestEnd = startsAt.add(const Duration(minutes: 1));
      endDate = _dateOnly(earliestEnd);
      endTime = TimeOfDay.fromDateTime(earliestEnd);
    }
  }

  Event toEvent({
    required Event? original,
    required int categoryId,
    required String title,
    required RecurrenceRule repeat,
    required DateTime? repeatUntil,
  }) => Event(
    id: original?.id,
    categoryId: categoryId,
    title: title,
    date: _dateOnly(startDate),
    endDate: _dateOnly(endDate),
    start: allDay ? const TimeOfDay(hour: 0, minute: 0) : startTime,
    end: allDay ? const TimeOfDay(hour: 0, minute: 0) : endTime,
    isCurrent: original?.isCurrent ?? false,
    allDay: allDay,
    location: original?.location,
    notes: notesController.text.trim(),
    repeat: repeat,
    repeatUntil: repeatUntil,
    sourcePlatform: original?.sourcePlatform,
    externalId: original?.externalId,
  );

  void dispose() => notesController.dispose();
}

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);
