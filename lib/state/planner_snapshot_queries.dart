import '../data/model_serialization.dart';
import '../data/recurrence.dart';
import '../data_models.dart';

/// Read-only projections over one consistent planner snapshot.
class PlannerSnapshotQueries {
  PlannerSnapshotQueries({
    required Iterable<TaskCategory> categories,
    required Iterable<PlannerItem> items,
    required Iterable<String> taskOccurrenceCompletionKeys,
    required this.categoryDisplayIconName,
  }) : _categories = List.unmodifiable(categories),
       _items = List.unmodifiable(items),
       _taskOccurrenceCompletionKeys = Set.unmodifiable(
         taskOccurrenceCompletionKeys,
       );

  final List<TaskCategory> _categories;
  final List<PlannerItem> _items;
  final Set<String> _taskOccurrenceCompletionKeys;
  final String Function(TaskCategory category) categoryDisplayIconName;

  PlannerItem? nextUpcomingItem(DateTime now) => _nextUpcomingFrom(_items, now);

  PlannerItem? nextUpcomingItemForCategory(int categoryId, DateTime now) =>
      _nextUpcomingFrom(
        _items.where((item) => item.categoryId == categoryId),
        now,
      );

  List<PlannerItem> itemsForDate(DateTime date) => itemsForRange(date, date);

  List<PlannerItem> itemsForRange(DateTime firstDay, DateTime lastDay) {
    final from = dateOnly(firstDay);
    final through = dateOnly(lastDay);
    final result = <PlannerItem>[];
    for (final series in _items) {
      for (final occurrenceDate in recurrenceDatesInRange(
        series,
        from: from,
        through: through,
      )) {
        final completed =
            series is Task &&
            series.id != null &&
            _taskOccurrenceCompletionKeys.contains(
              taskOccurrenceKey(series.id!, occurrenceDate),
            );
        result.add(
          occurrenceForDate(series, occurrenceDate, isCompleted: completed),
        );
      }
    }
    result.sort(_compareItems);
    return result;
  }

  /// Returns one visible row per category item, with recurring tasks at their
  /// next incomplete occurrence.
  List<PlannerItem> itemsForCategory(int categoryId, {required DateTime now}) {
    final today = dateOnly(now);
    final result = <PlannerItem>[];
    for (final series in _items.where(
      (item) => item.categoryId == categoryId,
    )) {
      if (!isRecurring(series)) {
        result.add(series);
        continue;
      }
      for (final occurrence in _incompleteOccurrences(series, from: today)) {
        result.add(occurrence);
        break;
      }
    }
    result.sort(_compareItems);
    return result;
  }

  /// Hides expired imported items without changing the stored planner series.
  List<PlannerItem> todoItemsForCategory(
    int categoryId, {
    required DateTime now,
  }) {
    final result = <PlannerItem>[];
    for (final candidate in itemsForCategory(categoryId, now: now)) {
      if (!_isImported(candidate)) {
        result.add(candidate);
        continue;
      }

      final series = seriesFor(candidate);
      if (!isRecurring(series)) {
        if (!_hasEnded(candidate, now)) result.add(candidate);
        continue;
      }

      for (final occurrence in _incompleteOccurrences(
        series,
        from: dateOnly(now),
      )) {
        if (_hasEnded(occurrence, now)) continue;
        result.add(occurrence);
        break;
      }
    }
    result.sort(_compareItems);
    return List.unmodifiable(result);
  }

  /// Incomplete categorized tasks and active or upcoming events for focus.
  List<FocusTaskSelection> selectableFocusItems(DateTime now) {
    final candidates = <(DateTime, FocusTaskSelection)>[];

    for (final category in _categories) {
      final categoryId = category.id;
      if (categoryId == null) continue;
      for (final task in todoItemsForCategory(
        categoryId,
        now: now,
      ).whereType<Task>()) {
        if (task.isChecked || task.id == null) continue;
        candidates.add((
          _scheduledDate(task),
          FocusTaskSelection(
            taskId: task.id!,
            taskTitle: task.title,
            categoryId: categoryId,
            categoryTitle: category.title,
            categoryIcon: categoryDisplayIconName(category),
          ),
        ));
      }
    }

    for (final series in _items.whereType<Event>()) {
      final occurrence = _nextSelectableEventOccurrence(series, now);
      if (occurrence == null) continue;
      final selection = focusSelectionForItem(occurrence);
      if (selection != null) {
        candidates.add((_scheduledDate(occurrence), selection));
      }
    }

    candidates.sort((first, second) {
      final byDate = first.$1.compareTo(second.$1);
      if (byDate != 0) return byDate;
      final byCategory = first.$2.categoryTitle.toLowerCase().compareTo(
        second.$2.categoryTitle.toLowerCase(),
      );
      return byCategory != 0
          ? byCategory
          : first.$2.taskTitle.toLowerCase().compareTo(
              second.$2.taskTitle.toLowerCase(),
            );
    });
    return List.unmodifiable(candidates.map((candidate) => candidate.$2));
  }

  List<FocusTaskSelection> selectableFocusTasks(DateTime now) =>
      List.unmodifiable(
        selectableFocusItems(now).where((item) => !item.isEvent),
      );

  FocusTaskSelection? focusSelectionForItem(PlannerItem? item) {
    if (item == null) return null;
    final category = _categoryForId(item.categoryId);
    if (item is Task && category == null) return null;
    if (item.id == null && item is Task) return null;
    return FocusTaskSelection(
      taskId: item.id ?? 0,
      taskTitle: item.title,
      categoryId: category?.id ?? -1,
      categoryTitle: category?.title ?? 'Unassigned',
      categoryIcon: category == null
          ? 'mi_timer'
          : categoryDisplayIconName(category),
      isEvent: item is Event,
    );
  }

  PlannerItem seriesFor(PlannerItem occurrence) {
    final id = occurrence.id;
    if (id == null) return occurrence;
    for (final item in _items) {
      if (item.runtimeType == occurrence.runtimeType && item.id == id) {
        return item;
      }
    }
    return occurrence;
  }

  TaskCategory? _categoryForId(int? id) {
    for (final category in _categories) {
      if (category.id == id) return category;
    }
    return null;
  }

  Iterable<PlannerItem> _incompleteOccurrences(
    PlannerItem series, {
    required DateTime from,
  }) sync* {
    for (final occurrenceDate in recurrenceDatesInRange(
      series,
      from: from,
      through: DateTime(9999, 12, 31),
    )) {
      final completed =
          series is Task &&
          series.id != null &&
          _taskOccurrenceCompletionKeys.contains(
            taskOccurrenceKey(series.id!, occurrenceDate),
          );
      if (completed) continue;
      yield occurrenceForDate(series, occurrenceDate, isCompleted: completed);
    }
  }

  Event? _nextSelectableEventOccurrence(Event series, DateTime now) {
    for (final occurrenceDate in recurrenceDatesInRange(
      series,
      from: dateOnly(now),
      through: DateTime(9999, 12, 31),
    )) {
      final occurrence = occurrenceForDate(series, occurrenceDate) as Event;
      if (!_hasEnded(occurrence, now)) return occurrence;
    }
    return null;
  }

  bool _isImported(PlannerItem item) => switch (item) {
    Task task => task.sourcePlatform?.trim().isNotEmpty ?? false,
    Event event => event.sourcePlatform?.trim().isNotEmpty ?? false,
    _ => false,
  };

  bool _hasEnded(PlannerItem item, DateTime now) {
    if (item is Task) return !taskDateTime(item).isAfter(now);
    if (item is Event) {
      if (item.allDay) {
        final endExclusive = dateOnly(
          item.endDate,
        ).add(const Duration(days: 1));
        return !endExclusive.isAfter(now);
      }
      var end = eventEndDateTime(item);
      if (!end.isAfter(eventStartDateTime(item))) {
        end = end.add(const Duration(days: 1));
      }
      return !end.isAfter(now);
    }
    return false;
  }

  PlannerItem? _nextUpcomingFrom(Iterable<PlannerItem> source, DateTime now) {
    final today = dateOnly(now);
    PlannerItem? next;
    DateTime? nextAt;
    for (final series in source) {
      for (final occurrenceDate in recurrenceDatesInRange(
        series,
        from: today,
        through: DateTime(9999, 12, 31),
      )) {
        final completed =
            series is Task &&
            (isRecurring(series)
                ? series.id != null &&
                      _taskOccurrenceCompletionKeys.contains(
                        taskOccurrenceKey(series.id!, occurrenceDate),
                      )
                : series.isChecked);
        if (completed) continue;
        final occurrence = occurrenceForDate(
          series,
          occurrenceDate,
          isCompleted: completed,
        );
        final startsAt = _scheduledDate(occurrence);
        final allDayIsToday =
            occurrence is Event &&
            occurrence.allDay &&
            _sameDay(occurrence.date, today);
        if (startsAt.isBefore(now) && !allDayIsToday) continue;
        if (nextAt == null || startsAt.isBefore(nextAt)) {
          next = occurrence;
          nextAt = startsAt;
        }
        break;
      }
    }
    return next;
  }

  int _compareItems(PlannerItem first, PlannerItem second) =>
      _scheduledDate(first).compareTo(_scheduledDate(second));

  DateTime _scheduledDate(PlannerItem item) {
    if (item is Task) {
      return DateTime(
        item.date.year,
        item.date.month,
        item.date.day,
        item.time.hour,
        item.time.minute,
      );
    }
    final event = item as Event;
    return DateTime(
      event.date.year,
      event.date.month,
      event.date.day,
      event.start.hour,
      event.start.minute,
    );
  }

  bool _sameDay(DateTime first, DateTime second) =>
      first.year == second.year &&
      first.month == second.month &&
      first.day == second.day;
}
