import '../data_models.dart';

DateTime dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

bool isRecurring(PlannerItem item) => _repeatFor(item) != 'Never';

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
  if (item is Task) {
    if (!isRecurring(item)) return item;
    return Task(
      id: item.id,
      categoryId: item.categoryId,
      title: item.title,
      date: day,
      isChecked: isCompleted,
      time: item.time,
      estimatedDuration: item.estimatedDuration,
      repeat: item.repeat,
      repeatUntil: item.repeatUntil,
      occurrenceDate: day,
      description: item.description,
      priority: item.priority,
      sourcePlatform: item.sourcePlatform,
      externalId: item.externalId,
    );
  }

  if (item is Event) {
    if (!isRecurring(item)) return item;
    final durationDays = dateOnly(item.endDate).difference(dateOnly(item.date));
    return Event(
      id: item.id,
      categoryId: item.categoryId,
      title: item.title,
      date: day,
      endDate: day.add(durationDays),
      start: item.start,
      end: item.end,
      isCurrent: item.isCurrent,
      allDay: item.allDay,
      location: item.location,
      notes: item.notes,
      repeat: item.repeat,
      repeatUntil: item.repeatUntil,
      occurrenceDate: day,
      sourcePlatform: item.sourcePlatform,
      externalId: item.externalId,
    );
  }

  return item;
}

DateTime? _nextOnOrAfter(PlannerItem item, DateTime target) {
  final start = dateOnly(item.date);
  final from = dateOnly(target);
  final rule = _repeatFor(item);
  if (rule == 'Never') {
    return !start.isBefore(from) && _withinUntil(item, start) ? start : null;
  }

  DateTime candidate;
  switch (rule) {
    case 'Every day':
      final days = from.isAfter(start) ? from.difference(start).inDays : 0;
      candidate = start.add(Duration(days: days));
      break;
    case 'Every week':
      final days = from.isAfter(start) ? from.difference(start).inDays : 0;
      final weeks = (days / 7).ceil();
      candidate = start.add(Duration(days: weeks * 7));
      break;
    case 'Every month':
      var months = _monthDifference(start, from).clamp(0, 120000).toInt();
      candidate = _inMonth(start, months);
      if (candidate.isBefore(from)) candidate = _inMonth(start, ++months);
      break;
    case 'Every year':
      var years = (from.year - start.year).clamp(0, 10000).toInt();
      candidate = _inYear(start, years);
      if (candidate.isBefore(from)) candidate = _inYear(start, ++years);
      break;
    default:
      return !start.isBefore(from) && _withinUntil(item, start) ? start : null;
  }
  return _withinUntil(item, candidate) ? candidate : null;
}

DateTime? _nextAfter(PlannerItem item, DateTime date) {
  if (_repeatFor(item) == 'Never') return null;
  final nextTarget = dateOnly(date).add(const Duration(days: 1));
  return _nextOnOrAfter(item, nextTarget);
}

String _repeatFor(PlannerItem item) => switch (item) {
  Task task => task.repeat,
  Event event => event.repeat,
  _ => 'Never',
};

DateTime? _untilFor(PlannerItem item) => switch (item) {
  Task task => task.repeatUntil,
  Event event => event.repeatUntil,
  _ => null,
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
