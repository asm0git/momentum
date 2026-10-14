import '../data_models.dart';

DateTime dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

bool isRecurring(PlannerItem item) => _repeatFor(item) != RecurrenceRule.never;

String taskOccurrenceKey(int taskId, DateTime date) {
  final day = dateOnly(date);
  return '$taskId:${day.year.toString().padLeft(4, '0')}-'
      '${day.month.toString().padLeft(2, '0')}-'
      '${day.day.toString().padLeft(2, '0')}';
}

Iterable<DateTime> recurrenceDatesInRange(
  PlannerItem item, {
  required DateTime from,
  required DateTime through,
}) sync* {
  final rangeStart = dateOnly(from);
  final rangeEnd = dateOnly(through);
  if (rangeEnd.isBefore(rangeStart)) return;

  var occurrence = _nextOnOrAfter(item, rangeStart);
  while (occurrence != null && !occurrence.isAfter(rangeEnd)) {
    yield occurrence;
    if (occurrence == rangeEnd) return;
    occurrence = _nextAfter(item, occurrence);
  }
}

DateTime? nextOccurrenceOnOrAfter(PlannerItem item, DateTime from) =>
    _nextOnOrAfter(item, dateOnly(from));

DateTime? nextOccurrenceAfter(PlannerItem item, DateTime date) =>
    _nextAfter(item, dateOnly(date));

PlannerItem occurrenceForDate(
  PlannerItem item,
  DateTime occurrenceDate, {
  bool isCompleted = false,
}) {
  final day = dateOnly(occurrenceDate);
  return switch (item) {
    Task task => _taskOccurrenceForDate(task, day, isCompleted),
    Event event => _eventOccurrenceForDate(event, day),
  };
}

/// Returns a typed event occurrence for event-specific callers.
Event eventOccurrenceForDate(Event event, DateTime occurrenceDate) =>
    _eventOccurrenceForDate(event, dateOnly(occurrenceDate));

Task _taskOccurrenceForDate(Task task, DateTime day, bool isCompleted) {
  if (!isRecurring(task)) return task;
  return Task(
    id: task.id,
    categoryId: task.categoryId,
    title: task.title,
    date: day,
    isChecked: isCompleted,
    time: task.time,
    estimatedDuration: task.estimatedDuration,
    repeat: task.repeat,
    repeatUntil: task.repeatUntil,
    occurrenceDate: day,
    description: task.description,
    priority: task.priority,
    sourcePlatform: task.sourcePlatform,
    externalId: task.externalId,
  );
}

Event _eventOccurrenceForDate(Event event, DateTime day) {
  if (!isRecurring(event)) return event;
  return Event(
    id: event.id,
    categoryId: event.categoryId,
    title: event.title,
    date: day,
    endDate: day.add(dateOnly(event.endDate).difference(dateOnly(event.date))),
    start: event.start,
    end: event.end,
    isCurrent: event.isCurrent,
    allDay: event.allDay,
    location: event.location,
    notes: event.notes,
    repeat: event.repeat,
    repeatUntil: event.repeatUntil,
    occurrenceDate: day,
    sourcePlatform: event.sourcePlatform,
    externalId: event.externalId,
  );
}

DateTime? _nextOnOrAfter(PlannerItem item, DateTime target) {
  final start = dateOnly(item.date);
  final from = dateOnly(target);
  final rule = _repeatFor(item);
  DateTime candidate;
  switch (rule) {
    case RecurrenceRule.never:
      return !start.isBefore(from) && _withinUntil(item, start) ? start : null;
    case RecurrenceRule.daily:
      final days = from.isAfter(start) ? from.difference(start).inDays : 0;
      candidate = start.add(Duration(days: days));
      break;
    case RecurrenceRule.weekly:
      final days = from.isAfter(start) ? from.difference(start).inDays : 0;
      final weeks = (days / 7).ceil();
      candidate = start.add(Duration(days: weeks * 7));
      break;
    case RecurrenceRule.monthly:
      var months = _monthDifference(start, from).clamp(0, 120000).toInt();
      candidate = _inMonth(start, months);
      if (candidate.isBefore(from)) candidate = _inMonth(start, ++months);
      break;
    case RecurrenceRule.yearly:
      var years = (from.year - start.year).clamp(0, 10000).toInt();
      candidate = _inYear(start, years);
      if (candidate.isBefore(from)) candidate = _inYear(start, ++years);
      break;
  }
  return _withinUntil(item, candidate) ? candidate : null;
}

DateTime? _nextAfter(PlannerItem item, DateTime date) {
  if (_repeatFor(item) == RecurrenceRule.never) return null;
  final nextTarget = dateOnly(date).add(const Duration(days: 1));
  return _nextOnOrAfter(item, nextTarget);
}

RecurrenceRule _repeatFor(PlannerItem item) => switch (item) {
  Task task => task.repeat,
  Event event => event.repeat,
};

DateTime? _untilFor(PlannerItem item) => switch (item) {
  Task task => task.repeatUntil,
  Event event => event.repeatUntil,
};

bool _withinUntil(PlannerItem item, DateTime date) {
  final until = _untilFor(item);
  return until == null || !dateOnly(date).isAfter(dateOnly(until));
}

int _monthDifference(DateTime start, DateTime target) =>
    (target.year - start.year) * 12 + target.month - start.month;

DateTime _inMonth(DateTime start, int monthOffset) {
  final monthStart = DateTime(start.year, start.month + monthOffset, 1);
  final monthEndDay = DateTime(monthStart.year, monthStart.month + 1, 0).day;
  return DateTime(
    monthStart.year,
    monthStart.month,
    start.day.clamp(1, monthEndDay).toInt(),
  );
}

DateTime _inYear(DateTime start, int yearOffset) {
  final targetYear = start.year + yearOffset;
  final lastDay = DateTime(targetYear, start.month + 1, 0).day;
  return DateTime(targetYear, start.month, start.day.clamp(1, lastDay).toInt());
}
