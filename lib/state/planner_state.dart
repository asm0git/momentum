import 'package:flutter/foundation.dart';

import '../data/planner_repository.dart';
import '../data/recurrence.dart';
import '../data_models.dart';

class PlannerState extends ChangeNotifier {
  PlannerState({PlannerRepository? repository})
    : _repository = repository ?? PlannerRepository();

  final PlannerRepository _repository;
  List<TaskCategory> _categories = [];
  List<PlannerItem> _items = [];
  Set<String> _taskOccurrenceCompletionKeys = {};
  bool _isLoading = true;
  Object? _error;

  List<TaskCategory> get categories => List.unmodifiable(_categories);
  List<PlannerItem> get items => List.unmodifiable(_items);
  bool get isLoading => _isLoading;
  Object? get error => _error;

  PlannerItem? get nextUpcomingItem {
    final now = DateTime.now();
    return _nextUpcomingFrom(_items, now);
  }

  PlannerItem? nextUpcomingItemForCategory(int categoryId, DateTime now) =>
      _nextUpcomingFrom(
        _items.where((item) => item.categoryId == categoryId),
        now,
      );

  List<PlannerItem> itemsForDate(DateTime date) => _itemsForRange(date, date);

  List<PlannerItem> itemsForRange(DateTime firstDay, DateTime lastDay) =>
      _itemsForRange(firstDay, lastDay);

  /// Returns one visible row per category item. Recurring items are represented
  /// by their next date, with task completion scoped to that occurrence.
  List<PlannerItem> itemsForCategory(int categoryId) {
    final today = dateOnly(DateTime.now());
    final result = <PlannerItem>[];
    for (final series in _items.where(
      (item) => item.categoryId == categoryId,
    )) {
      if (!isRecurring(series)) {
        result.add(series);
        continue;
      }
      for (final occurrenceDate in recurrenceDatesInRange(
        series,
        from: today,
        through: DateTime(9999, 12, 31),
      )) {
        final completed =
            series is Task &&
            series.id != null &&
            _taskOccurrenceCompletionKeys.contains(
              taskOccurrenceKey(series.id!, occurrenceDate),
            );
        if (completed) continue;
        result.add(
          occurrenceForDate(series, occurrenceDate, isCompleted: completed),
        );
        break;
      }
    }
    result.sort(_compareItems);
    return result;
  }

  /// Resolves a generated calendar occurrence to the saved series record.
  PlannerItem seriesFor(PlannerItem occurrence) {
    final id = occurrence.id;
    if (id == null) return occurrence;
    return _items.firstWhere(
      (item) => item.runtimeType == occurrence.runtimeType && item.id == id,
      orElse: () => occurrence,
    );
  }

  Future<void> initialize() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      await _reloadSnapshot();
    } catch (error) {
      _error = error;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> retry() => initialize();

  Future<void> _reloadSnapshot() async {
    final categories = await _repository.getCategoriesWithItems();
    final items = await _repository.getAllItems();
    final occurrenceCompletions = await _repository
        .getTaskOccurrenceCompletionKeys();
    _categories = categories;
    _items = items;
    _taskOccurrenceCompletionKeys = occurrenceCompletions;
    _error = null;
  }

  Future<void> _afterWrite(Future<void> Function() write) async {
    await write();
    try {
      await _reloadSnapshot();
      notifyListeners();
    } catch (error) {
      _error = error;
      notifyListeners();
      rethrow;
    }
  }

  Future<TaskCategory> addCategory(TaskCategory category) async {
    await _afterWrite(() async {
      await _repository.insertCategory(category);
    });
    return category;
  }

  Future<void> updateCategory(TaskCategory category) => _afterWrite(() async {
    await _repository.updateCategory(category);
  });

  Future<void> deleteCategory(int id) => _afterWrite(() async {
    await _repository.deleteCategory(id);
  });

  Future<Task> saveTask(Task task) async {
    await _afterWrite(() async {
      if (task.id == null) {
        await _repository.insertTask(task);
      } else {
        final updated = await _repository.updateTask(task);
        if (!updated) {
          throw StateError('The task was not updated in local storage.');
        }
      }
    });
    final savedTask = _items
        .whereType<Task>()
        .where((saved) => saved.id == task.id)
        .firstOrNull;
    if (savedTask == null) {
      throw StateError('The saved task could not be reloaded.');
    }
    return savedTask;
  }

  Future<Event> saveEvent(Event event) async {
    await _afterWrite(() async {
      if (event.id == null) {
        await _repository.insertEvent(event);
      } else {
        await _repository.updateEvent(event);
      }
    });
    return event;
  }

  Future<void> setTaskCompleted(Task task, bool isCompleted) =>
      _afterWrite(() async {
        final occurrenceDate = task.occurrenceDate;
        if (isRecurring(task) && task.id != null && occurrenceDate != null) {
          await _repository.setTaskOccurrenceCompleted(
            task.id!,
            occurrenceDate,
            isCompleted,
          );
          return;
        }
        task.isChecked = isCompleted;
        await _repository.updateTask(task);
      });

  Future<void> deleteItem(PlannerItem item) => _afterWrite(() async {
    final id = item.id;
    if (id == null) return;
    if (item is Task) {
      await _repository.deleteTask(id);
    } else if (item is Event) {
      await _repository.deleteEvent(id);
    }
  });

  Future<PlannerItem?> getNextUpcomingItem(DateTime now) =>
      _repository.getNextUpcomingItem(now);

  Future<List<PlannerItem>> getItemsForDate(DateTime date) =>
      _repository.getItemsForDate(date);

  Future<List<Task>> getTasksForDate(DateTime date) =>
      _repository.getTasksForDate(date);

  Future<int> getFocusSecondsForDate(DateTime date) =>
      _repository.getFocusSecondsForDate(date);

  Future<void> addFocusSeconds(DateTime date, int seconds) =>
      _repository.addFocusSeconds(date, seconds);

  List<PlannerItem> _itemsForRange(DateTime firstDay, DateTime lastDay) {
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
