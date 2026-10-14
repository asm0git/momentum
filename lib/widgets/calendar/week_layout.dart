import '../../data/recurrence.dart';
import '../../data_models.dart';

class CalendarWeekPlacement {
  const CalendarWeekPlacement({
    required this.item,
    required this.ordinal,
    required this.startColumn,
    required this.endColumn,
    required this.lane,
    required this.continuesBefore,
    required this.continuesAfter,
  });

  final PlannerItem item;
  final int ordinal;
  final int startColumn;
  final int endColumn;
  final int lane;
  final bool continuesBefore;
  final bool continuesAfter;

  bool get isCompleted => switch (item) {
    Task task => task.isChecked,
    Event _ => false,
  };
}

/// Expands visible recurring items and assigns each occurrence a calendar row.
List<CalendarWeekPlacement> placeCalendarWeekItems({
  required List<PlannerItem> items,
  required DateTime firstDate,
  required DateTime lastDate,
  required List<(int, DateTime)> visibleDates,
}) {
  if (visibleDates.isEmpty) return const [];

  final rangeStart = dateOnly(firstDate);
  final rangeEnd = dateOnly(lastDate);
  final occurrences = <_CalendarOccurrence>[];
  var ordinal = 0;
  for (final item in items) {
    if (item is Event) {
      final durationDays = dateOnly(
        item.endDate,
      ).difference(dateOnly(item.date)).inDays.clamp(0, 3650).toInt();
      final searchStart = rangeStart.subtract(Duration(days: durationDays));
      for (final occurrenceDate in recurrenceDatesInRange(
        item,
        from: searchStart,
        through: rangeEnd,
      )) {
        final occurrence = eventOccurrenceForDate(item, occurrenceDate);
        final startsOn = dateOnly(occurrence.date);
        final endsOn = dateOnly(occurrence.endDate);
        if (endsOn.isBefore(rangeStart) || startsOn.isAfter(rangeEnd)) {
          continue;
        }
        occurrences.add(
          _CalendarOccurrence(
            item: occurrence,
            startsOn: startsOn,
            endsOn: endsOn.isBefore(startsOn) ? startsOn : endsOn,
            ordinal: ordinal++,
          ),
        );
      }
    } else if (item is Task) {
      for (final occurrenceDate in recurrenceDatesInRange(
        item,
        from: rangeStart,
        through: rangeEnd,
      )) {
        final occurrence = occurrenceForDate(item, occurrenceDate);
        occurrences.add(
          _CalendarOccurrence(
            item: occurrence,
            startsOn: dateOnly(occurrenceDate),
            endsOn: dateOnly(occurrenceDate),
            ordinal: ordinal++,
          ),
        );
      }
    }
  }
  occurrences.sort(_compareCalendarOccurrences);

  final firstColumn = visibleDates.first.$1;
  final lastColumn = visibleDates.last.$1;
  final laneEndColumns = <int>[];
  final placements = <CalendarWeekPlacement>[];
  for (final occurrence in occurrences) {
    final startColumn = _columnForDate(
      visibleDates,
      occurrence.startsOn,
      beforeColumn: firstColumn,
      afterColumn: lastColumn,
    );
    final endColumn = _columnForDate(
      visibleDates,
      occurrence.endsOn,
      beforeColumn: firstColumn,
      afterColumn: lastColumn,
    );
    if (endColumn < startColumn) continue;

    var lane = 0;
    while (lane < laneEndColumns.length &&
        startColumn <= laneEndColumns[lane]) {
      lane++;
    }
    if (lane == laneEndColumns.length) {
      laneEndColumns.add(endColumn);
    } else {
      laneEndColumns[lane] = endColumn;
    }

    placements.add(
      CalendarWeekPlacement(
        item: occurrence.item,
        ordinal: occurrence.ordinal,
        startColumn: startColumn,
        endColumn: endColumn,
        lane: lane,
        continuesBefore: occurrence.startsOn.isBefore(rangeStart),
        continuesAfter: occurrence.endsOn.isAfter(rangeEnd),
      ),
    );
  }
  return placements;
}

class _CalendarOccurrence {
  const _CalendarOccurrence({
    required this.item,
    required this.startsOn,
    required this.endsOn,
    required this.ordinal,
  });

  final PlannerItem item;
  final DateTime startsOn;
  final DateTime endsOn;
  final int ordinal;

  DateTime get scheduledAt {
    return switch (item) {
      Task task => DateTime(
        startsOn.year,
        startsOn.month,
        startsOn.day,
        task.time.hour,
        task.time.minute,
      ),
      Event event => DateTime(
        startsOn.year,
        startsOn.month,
        startsOn.day,
        event.allDay ? 0 : event.start.hour,
        event.allDay ? 0 : event.start.minute,
      ),
    };
  }
}

int _compareCalendarOccurrences(
  _CalendarOccurrence first,
  _CalendarOccurrence second,
) {
  final dayComparison = first.startsOn.compareTo(second.startsOn);
  if (dayComparison != 0) return dayComparison;

  final firstAllDay = switch (first.item) {
    Task _ => false,
    Event event => event.allDay,
  };
  final secondAllDay = switch (second.item) {
    Task _ => false,
    Event event => event.allDay,
  };
  if (firstAllDay != secondAllDay) return firstAllDay ? -1 : 1;

  final scheduleComparison = first.scheduledAt.compareTo(second.scheduledAt);
  if (scheduleComparison != 0) return scheduleComparison;

  final titleComparison = first.item.title.toLowerCase().compareTo(
    second.item.title.toLowerCase(),
  );
  if (titleComparison != 0) return titleComparison;
  return first.ordinal.compareTo(second.ordinal);
}

int _columnForDate(
  List<(int, DateTime)> dates,
  DateTime date, {
  required int beforeColumn,
  required int afterColumn,
}) {
  for (final (column, visibleDate) in dates) {
    if (_sameDay(date, visibleDate)) return column;
  }
  if (date.isBefore(dates.first.$2)) return beforeColumn;
  return afterColumn;
}

bool _sameDay(DateTime first, DateTime second) =>
    first.year == second.year &&
    first.month == second.month &&
    first.day == second.day;
