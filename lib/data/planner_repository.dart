import 'package:sqflite/sqflite.dart';

import '../data_models.dart';
import 'database_helper.dart';
import 'model_serialization.dart';
import 'recurrence.dart';

class PlannerRepository {
  PlannerRepository({DatabaseHelper? databaseHelper})
    : _databaseHelper = databaseHelper ?? DatabaseHelper.instance;

  final DatabaseHelper _databaseHelper;

  /// Shared by repositories that must participate in the same local store.
  DatabaseHelper get databaseHelper => _databaseHelper;

  Future<TaskCategory> insertCategory(TaskCategory category) async {
    final db = await _databaseHelper.database;
    category.id = await db.insert('categories', categoryToMap(category));
    return category;
  }

  Future<List<TaskCategory>> getCategories() async {
    final db = await _databaseHelper.database;
    final rows = await db.query('categories', orderBy: 'title COLLATE NOCASE');
    return rows.map(categoryFromMap).toList();
  }

  Future<TaskCategory?> getCategory(int id) async {
    final db = await _databaseHelper.database;
    final rows = await db.query('categories', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : categoryFromMap(rows.first);
  }

  Future<bool> updateCategory(TaskCategory category) async {
    if (category.id == null) return false;
    final db = await _databaseHelper.database;
    return await db.update(
          'categories',
          categoryToMap(category),
          where: 'id = ?',
          whereArgs: [category.id],
        ) >
        0;
  }

  Future<bool> deleteCategory(
    int id, {
    required CategoryDeleteDisposition disposition,
    int? destinationCategoryId,
  }) async {
    final db = await _databaseHelper.database;
    return db.transaction((txn) async {
      final sourceRows = await txn.query(
        'categories',
        columns: ['id'],
        where: 'id = ?',
        whereArgs: [id],
      );
      if (sourceRows.isEmpty) return false;

      if (disposition == CategoryDeleteDisposition.moveItems) {
        final destinationId = destinationCategoryId;
        if (destinationId == null || destinationId == id) {
          throw ArgumentError.value(
            destinationCategoryId,
            'destinationCategoryId',
            'Choose a different existing category.',
          );
        }
        final destinationRows = await txn.query(
          'categories',
          columns: ['id'],
          where: 'id = ?',
          whereArgs: [destinationId],
        );
        if (destinationRows.isEmpty) {
          throw StateError('The destination category no longer exists.');
        }

        await txn.update(
          'tasks',
          {'category_id': destinationId},
          where: 'category_id = ?',
          whereArgs: [id],
        );
        await txn.update(
          'events',
          {'category_id': destinationId},
          where: 'category_id = ?',
          whereArgs: [id],
        );
      } else {
        await txn.delete('tasks', where: 'category_id = ?', whereArgs: [id]);
        await txn.delete('events', where: 'category_id = ?', whereArgs: [id]);
      }

      return await txn.delete('categories', where: 'id = ?', whereArgs: [id]) >
          0;
    });
  }

  Future<Task> insertTask(Task task) async {
    final db = await _databaseHelper.database;
    task.id = await db.insert('tasks', taskToMap(task));
    return task;
  }

  Future<List<Task>> getTasks() async {
    final db = await _databaseHelper.database;
    final rows = await db.query('tasks', orderBy: 'due');
    return rows.map(taskFromMap).toList();
  }

  Future<Task?> getTask(int id) async {
    final db = await _databaseHelper.database;
    final rows = await db.query('tasks', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : taskFromMap(rows.first);
  }

  Future<bool> updateTask(Task task) async {
    if (task.id == null) return false;
    final db = await _databaseHelper.database;
    final values = taskToMap(task)..remove('id');
    final updatedRows = await db.update(
      'tasks',
      values,
      where: 'id = ?',
      whereArgs: [task.id],
    );
    if (updatedRows == 0) return false;

    // Confirm the category change reached storage before reporting success.
    final savedTask = await getTask(task.id!);
    return savedTask?.categoryId == task.categoryId;
  }

  Future<bool> deleteTask(int id) async {
    final db = await _databaseHelper.database;
    return await db.delete('tasks', where: 'id = ?', whereArgs: [id]) > 0;
  }

  Future<Event> insertEvent(Event event) async {
    final db = await _databaseHelper.database;
    event.id = await db.insert('events', eventToMap(event));
    return event;
  }

  Future<List<Event>> getEvents() async {
    final db = await _databaseHelper.database;
    final rows = await db.query('events', orderBy: 'start_time');
    return rows.map(eventFromMap).toList();
  }

  Future<Event?> getEvent(int id) async {
    final db = await _databaseHelper.database;
    final rows = await db.query('events', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : eventFromMap(rows.first);
  }

  Future<bool> updateEvent(Event event) async {
    if (event.id == null) return false;
    final db = await _databaseHelper.database;
    return await db.update(
          'events',
          eventToMap(event),
          where: 'id = ?',
          whereArgs: [event.id],
        ) >
        0;
  }

  Future<bool> deleteEvent(int id) async {
    final db = await _databaseHelper.database;
    return await db.delete('events', where: 'id = ?', whereArgs: [id]) > 0;
  }

  Future<DailyPlan> insertDailyPlan(DailyPlan plan) async {
    final db = await _databaseHelper.database;
    plan.id = await db.insert('ai_plans', dailyPlanToMap(plan));
    return plan;
  }

  Future<List<DailyPlan>> getDailyPlans() async {
    final db = await _databaseHelper.database;
    final rows = await db.query('ai_plans', orderBy: 'plan_date');
    return rows.map(dailyPlanFromMap).toList();
  }

  Future<DailyPlan?> getDailyPlan(int id) async {
    final db = await _databaseHelper.database;
    final rows = await db.query('ai_plans', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : dailyPlanFromMap(rows.first);
  }

  Future<bool> updateDailyPlan(DailyPlan plan) async {
    if (plan.id == null) return false;
    final db = await _databaseHelper.database;
    return await db.update(
          'ai_plans',
          dailyPlanToMap(plan),
          where: 'id = ?',
          whereArgs: [plan.id],
        ) >
        0;
  }

  Future<bool> deleteDailyPlan(int id) async {
    final db = await _databaseHelper.database;
    return await db.delete('ai_plans', where: 'id = ?', whereArgs: [id]) > 0;
  }

  Future<List<PlannerItem>> getAllItems() async {
    final db = await _databaseHelper.database;
    final rows = await db.rawQuery('''
      SELECT 'task' AS item_type, id, category_id, title, description, due,
        estimated_duration_minutes, repeat, repeat_until, priority,
        is_completed, src_platform, external_id, NULL AS start_time,
        NULL AS end_time, NULL AS location, NULL AS is_all_day,
        NULL AS is_current, NULL AS notes
      FROM tasks
      UNION ALL
      SELECT 'event' AS item_type, id, category_id, title, NULL AS description,
        NULL AS due, NULL AS estimated_duration_minutes, repeat,
        repeat_until, NULL AS priority, NULL AS is_completed,
        src_platform, external_id, start_time, end_time, location, is_all_day,
        is_current, notes
      FROM events
    ''');
    return rows.map(_itemFromUnionRow).toList();
  }

  Future<List<PlannerItem>> getItemsForDate(DateTime day) async {
    final target = dateOnly(day);
    final completionKeys = await getTaskOccurrenceCompletionKeys();
    final items = <PlannerItem>[];
    for (final series in await getAllItems()) {
      for (final occurrenceDate in recurrenceDatesInRange(
        series,
        from: target,
        through: target,
      )) {
        final completed =
            series is Task &&
            series.id != null &&
            completionKeys.contains(
              taskOccurrenceKey(series.id!, occurrenceDate),
            );
        items.add(
          occurrenceForDate(series, occurrenceDate, isCompleted: completed),
        );
      }
    }
    items.sort(_compareItems);
    return items;
  }

  Future<Set<String>> getTaskOccurrenceCompletionKeys() async {
    final db = await _databaseHelper.database;
    final rows = await db.query(
      'task_occurrence_completions',
      columns: ['task_id', 'occurrence_date'],
    );
    return {
      for (final row in rows)
        taskOccurrenceKey(
          _requiredInt(row, 'task_id'),
          _requiredDateTime(row, 'occurrence_date'),
        ),
    };
  }

  Future<void> setTaskOccurrenceCompleted(
    int taskId,
    DateTime date,
    bool completed,
  ) async {
    final db = await _databaseHelper.database;
    final occurrenceDate = dateOnly(date).toIso8601String();
    if (completed) {
      await db.insert('task_occurrence_completions', {
        'task_id': taskId,
        'occurrence_date': occurrenceDate,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    } else {
      await db.delete(
        'task_occurrence_completions',
        where: 'task_id = ? AND occurrence_date = ?',
        whereArgs: [taskId, occurrenceDate],
      );
    }
  }

  int _requiredInt(Map<String, Object?> row, String column) {
    final value = row[column];
    if (value is int) return value;
    throw FormatException('Expected SQL column "$column" to be an integer.');
  }

  DateTime _requiredDateTime(Map<String, Object?> row, String column) {
    final value = row[column];
    if (value is! String) {
      throw FormatException('Expected SQL column "$column" to be a string.');
    }
    try {
      return DateTime.parse(value);
    } on FormatException {
      throw FormatException(
        'Expected SQL column "$column" to contain a valid date.',
        value,
      );
    }
  }

  Future<List<Task>> getTasksForDate(DateTime day) async {
    return (await getItemsForDate(day)).whereType<Task>().toList();
  }

  Future<PlannerItem?> getNextUpcomingItem(DateTime now) async {
    final completionKeys = await getTaskOccurrenceCompletionKeys();
    PlannerItem? next;
    DateTime? nextTime;
    for (final series in await getAllItems()) {
      for (final day in recurrenceDatesInRange(
        series,
        from: dateOnly(now),
        through: DateTime(9999, 12, 31),
      )) {
        final isCompleted =
            series is Task &&
            series.id != null &&
            (isRecurring(series)
                ? completionKeys.contains(taskOccurrenceKey(series.id!, day))
                : series.isChecked);
        if (isCompleted) continue;
        final occurrence = occurrenceForDate(
          series,
          day,
          isCompleted: isCompleted,
        );
        final scheduled = switch (occurrence) {
          Task task => taskDateTime(task),
          Event event => eventStartDateTime(event),
        };
        final isCurrentAllDay = switch (occurrence) {
          Task _ => false,
          Event event => event.allDay && _sameDay(event.date, now),
        };
        if (scheduled.isBefore(now) && !isCurrentAllDay) continue;
        if (nextTime == null || scheduled.isBefore(nextTime)) {
          next = occurrence;
          nextTime = scheduled;
        }
        break;
      }
    }
    return next;
  }

  Future<List<TaskCategory>> getCategoriesWithItems() async {
    final categories = await getCategories();
    final items = await getAllItems();
    final itemsByCategory = <int, List<PlannerItem>>{};
    for (final item in items) {
      final categoryId = item.categoryId;
      if (categoryId != null) {
        itemsByCategory.putIfAbsent(categoryId, () => []).add(item);
      }
    }
    for (final category in categories) {
      category.items = itemsByCategory[category.id] ?? [];
    }
    return categories;
  }

  PlannerItem _itemFromUnionRow(Map<String, Object?> row) {
    final itemType = row['item_type'];
    if (itemType == 'task') {
      return taskFromMap({
        for (final key in [
          'id',
          'category_id',
          'title',
          'description',
          'due',
          'estimated_duration_minutes',
          'repeat',
          'repeat_until',
          'priority',
          'is_completed',
          'src_platform',
          'external_id',
        ])
          key: row[key],
      });
    }
    if (itemType != 'event') {
      throw FormatException('Unknown planner item type: $itemType');
    }
    return eventFromMap({
      for (final key in [
        'id',
        'category_id',
        'title',
        'start_time',
        'end_time',
        'location',
        'is_all_day',
        'is_current',
        'repeat',
        'repeat_until',
        'notes',
        'src_platform',
        'external_id',
      ])
        key: row[key],
    });
  }

  int _compareItems(PlannerItem first, PlannerItem second) =>
      _scheduledDate(first).compareTo(_scheduledDate(second));

  DateTime _scheduledDate(PlannerItem item) => switch (item) {
    Task task => taskDateTime(task),
    Event event => eventStartDateTime(event),
  };

  bool _sameDay(DateTime first, DateTime second) =>
      first.year == second.year &&
      first.month == second.month &&
      first.day == second.day;
}
