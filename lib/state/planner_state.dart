import 'package:flutter/foundation.dart';

import '../data/planner_repository.dart';
import '../data_models.dart';

class PlannerState extends ChangeNotifier {
  PlannerState({PlannerRepository? repository})
    : _repository = repository ?? PlannerRepository();

  final PlannerRepository _repository;
  List<TaskCategory> _categories = [];
  List<PlannerItem> _items = [];
  bool _isLoading = true;
  Object? _error;

  List<TaskCategory> get categories => List.unmodifiable(_categories);
  List<PlannerItem> get items => List.unmodifiable(_items);
  bool get isLoading => _isLoading;
  Object? get error => _error;

  PlannerItem? get nextUpcomingItem {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final upcoming =
        _items.where((item) {
          if (item is Task) {
            return !item.isChecked && _scheduledDate(item).isAfter(now);
          }
          final event = item as Event;
          return _scheduledDate(event).isAfter(now) ||
              (event.allDay && _sameDay(event.date, today));
        }).toList()..sort(
          (first, second) =>
              _scheduledDate(first).compareTo(_scheduledDate(second)),
        );
    return upcoming.isEmpty ? null : upcoming.first;
  }

  List<TaskCategory> get categoriesWithUnassignedItems {
    final categories = List<TaskCategory>.from(_categories);
    final unassigned = _items.where((item) => item.categoryId == null).toList();
    if (unassigned.isNotEmpty) {
      categories.add(
        TaskCategory(title: 'None', iconName: '', items: unassigned),
      );
    }
    return categories;
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
    _categories = categories;
    _items = items;
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
