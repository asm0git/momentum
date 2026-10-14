// Public constructor labels keep the injected dependencies private.
// ignore_for_file: prefer_initializing_formals

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/model_serialization.dart';
import '../data/recurrence.dart';
import '../data_models.dart';

typedef AutomaticFocusBatchEntry = ({
  DateTime date,
  int seconds,
  FocusTaskSelection selection,
});

typedef AutomaticFocusBatchWriter =
    Future<void> Function(Iterable<AutomaticFocusBatchEntry> entries);

/// A scheduled event's active window and the category used for focus history.
class ScheduledEventFocusInterval {
  const ScheduledEventFocusInterval(this.start, this.end, this.selection);

  final DateTime start;
  final DateTime end;
  final FocusTaskSelection selection;
}

/// Focus seconds grouped for one local day and category.
class AutomaticFocusBucket {
  const AutomaticFocusBucket({
    required this.date,
    required this.selection,
    required this.seconds,
  });

  final DateTime date;
  final FocusTaskSelection selection;
  final int seconds;
}

/// Splits event windows at their boundaries and local midnight, then groups
/// covered seconds by day and category. Overlaps prefer the earliest event.
List<AutomaticFocusBucket> aggregateAutomaticFocusBuckets({
  required Iterable<ScheduledEventFocusInterval> intervals,
  required DateTime from,
  required DateTime through,
}) {
  if (!through.isAfter(from)) return const [];

  final eventIntervals = intervals.toList()
    ..sort((first, second) {
      final byStart = first.start.compareTo(second.start);
      if (byStart != 0) return byStart;
      return first.selection.taskId.compareTo(second.selection.taskId);
    });
  final boundaries = <DateTime>{from, through};
  for (final interval in eventIntervals) {
    if (interval.start.isAfter(from) && interval.start.isBefore(through)) {
      boundaries.add(interval.start);
    }
    if (interval.end.isAfter(from) && interval.end.isBefore(through)) {
      boundaries.add(interval.end);
    }
  }

  var midnight = DateTime(from.year, from.month, from.day + 1);
  while (midnight.isBefore(through)) {
    boundaries.add(midnight);
    midnight = DateTime(midnight.year, midnight.month, midnight.day + 1);
  }

  final orderedBoundaries = boundaries.toList()..sort();
  final totals = <DateTime, Map<int, _MutableAutomaticFocusBucket>>{};
  for (var index = 0; index + 1 < orderedBoundaries.length; index++) {
    final start = orderedBoundaries[index];
    final end = orderedBoundaries[index + 1];
    if (!end.isAfter(start)) continue;

    ScheduledEventFocusInterval? active;
    for (final interval in eventIntervals) {
      if (!start.isBefore(interval.start) && !end.isAfter(interval.end)) {
        active = interval;
        break;
      }
    }
    if (active == null) continue;

    final seconds = end.difference(start).inSeconds;
    if (seconds <= 0) continue;
    final day = dateOnly(start);
    final byCategory = totals.putIfAbsent(
      day,
      () => <int, _MutableAutomaticFocusBucket>{},
    );
    final categoryId = active.selection.categoryId;
    final bucket = byCategory[categoryId];
    if (bucket == null) {
      byCategory[categoryId] = _MutableAutomaticFocusBucket(
        selection: active.selection,
        seconds: seconds,
      );
    } else {
      bucket.seconds += seconds;
    }
  }

  return [
    for (final dayEntry in totals.entries)
      for (final bucket in dayEntry.value.values)
        AutomaticFocusBucket(
          date: dayEntry.key,
          selection: bucket.selection,
          seconds: bucket.seconds,
        ),
  ];
}

/// Owns automatic event-focus interval calculation and persistence retries.
class AutomaticEventFocusCoordinator {
  AutomaticEventFocusCoordinator({
    required Iterable<Event> Function() events,
    required FocusTaskSelection? Function(PlannerItem item) selectionForItem,
    required AutomaticFocusBatchWriter recordBatch,
    required VoidCallback onRecorded,
    required DateTime Function() clock,
    required bool enabled,
  }) : _events = events,
       _selectionForItem = selectionForItem,
       _recordBatch = recordBatch,
       _onRecorded = onRecorded,
       _clock = clock,
       _enabled = enabled;

  final Iterable<Event> Function() _events;
  final FocusTaskSelection? Function(PlannerItem item) _selectionForItem;
  final AutomaticFocusBatchWriter _recordBatch;
  final VoidCallback _onRecorded;
  final DateTime Function() _clock;
  final bool _enabled;
  Timer? _timer;
  DateTime? _cursor;
  bool _isRecording = false;
  bool _failureLogged = false;
  bool _isDisposed = false;

  void start() {
    _cursor ??= _clock();
    if (_enabled) {
      _timer ??= Timer.periodic(
        const Duration(seconds: 10),
        (_) => unawaited(recordCurrentInterval()),
      );
    }
  }

  FocusTaskSelection? eventFocusSelectionAt(DateTime instant) {
    final intervals = _eventFocusIntervals(
      instant.subtract(const Duration(seconds: 1)),
      instant.add(const Duration(seconds: 1)),
    );
    for (final interval in intervals) {
      if (!instant.isBefore(interval.start) && instant.isBefore(interval.end)) {
        return interval.selection;
      }
    }
    return null;
  }

  DateTime? nextEventFocusBoundaryAfter(DateTime instant, DateTime through) {
    DateTime? next;
    for (final interval in _eventFocusIntervals(instant, through)) {
      for (final boundary in [interval.start, interval.end]) {
        if (boundary.isAfter(instant) &&
            !boundary.isAfter(through) &&
            (next == null || boundary.isBefore(next))) {
          next = boundary;
        }
      }
    }
    return next;
  }

  Future<void> recordCurrentInterval() async {
    if (_isDisposed || _isRecording) return;
    final from = _cursor;
    final through = _clock();
    if (from == null || !through.isAfter(from)) {
      _cursor = through;
      return;
    }

    _isRecording = true;
    try {
      final intervals = _eventFocusIntervals(from, through);
      final buckets = aggregateAutomaticFocusBuckets(
        intervals: intervals,
        from: from,
        through: through,
      );
      if (buckets.isNotEmpty) {
        await _recordBatch(
          buckets.map(
            (bucket) => (
              date: bucket.date,
              seconds: bucket.seconds,
              selection: bucket.selection,
            ),
          ),
        );
        _cursor = through;
        _failureLogged = false;
        if (!_isDisposed) _onRecorded();
      } else {
        _cursor = through;
        _failureLogged = false;
      }
    } catch (error) {
      // Keep the cursor unchanged so the next interval retries the full batch.
      if (!_failureLogged) {
        debugPrint('Automatic focus recording failed; retrying: $error');
        _failureLogged = true;
      }
    } finally {
      _isRecording = false;
    }
  }

  void dispose() {
    _isDisposed = true;
    _timer?.cancel();
  }

  List<ScheduledEventFocusInterval> _eventFocusIntervals(
    DateTime from,
    DateTime through,
  ) {
    if (!through.isAfter(from)) return const [];
    final events = _events().toList(growable: false);
    if (events.isEmpty) return const [];
    final longestDurationDays = events
        .map(
          (event) =>
              dateOnly(event.endDate).difference(dateOnly(event.date)).inDays,
        )
        .fold<int>(0, (longest, days) => days > longest ? days : longest)
        .clamp(0, 3660)
        .toInt();
    final firstDay = dateOnly(
      from,
    ).subtract(Duration(days: longestDurationDays + 1));
    final lastDay = dateOnly(through);
    final result = <ScheduledEventFocusInterval>[];

    for (final series in events) {
      for (final occurrenceDate in recurrenceDatesInRange(
        series,
        from: firstDay,
        through: lastDay,
      )) {
        final occurrence = eventOccurrenceForDate(series, occurrenceDate);
        final start = occurrence.allDay
            ? dateOnly(occurrence.date)
            : eventStartDateTime(occurrence);
        var end = occurrence.allDay
            ? dateOnly(occurrence.endDate).add(const Duration(days: 1))
            : eventEndDateTime(occurrence);
        if (!end.isAfter(start)) end = start.add(const Duration(days: 1));
        if (!end.isAfter(from) || !start.isBefore(through)) continue;
        final selection =
            _selectionForItem(occurrence) ??
            FocusTaskSelection(
              taskId: occurrence.id ?? 0,
              taskTitle: occurrence.title,
              categoryId: -1,
              categoryTitle: 'Unassigned',
              categoryIcon: 'mi_timer',
              isEvent: true,
            );
        result.add(ScheduledEventFocusInterval(start, end, selection));
      }
    }

    result.sort((first, second) {
      final byStart = first.start.compareTo(second.start);
      if (byStart != 0) return byStart;
      return first.selection.taskId.compareTo(second.selection.taskId);
    });
    return result;
  }
}

class _MutableAutomaticFocusBucket {
  _MutableAutomaticFocusBucket({
    required this.selection,
    required this.seconds,
  });

  final FocusTaskSelection selection;
  int seconds;
}
