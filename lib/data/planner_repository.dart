import 'package:sqflite/sqflite.dart';

import '../data_models.dart';
import 'database_helper.dart';
import 'model_serialization.dart';
import 'recurrence.dart';

class PlannerRepository {
  PlannerRepository({DatabaseHelper? databaseHelper})
    : _databaseHelper = databaseHelper ?? DatabaseHelper.instance;

  final DatabaseHelper _databaseHelper;

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

  Future<bool> deleteCategory(int id) async {
    final db = await _databaseHelper.database;
    return await db.delete('categories', where: 'id = ?', whereArgs: [id]) > 0;
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

  Future<LinkedAccount> insertLinkedAccount(LinkedAccount account) async {
    final db = await _databaseHelper.database;
    account.id = await db.insert(
      'linked_accounts',
      linkedAccountToMap(account),
    );
    return account;
  }

  Future<List<LinkedAccount>> getLinkedAccounts() async {
    final db = await _databaseHelper.database;
    final rows = await db.query('linked_accounts', orderBy: 'platform_name');
    return rows.map(linkedAccountFromMap).toList();
  }

  Future<LinkedAccount?> getLinkedAccount(int id) async {
    final db = await _databaseHelper.database;
    final rows = await db.query(
      'linked_accounts',
      where: 'id = ?',
      whereArgs: [id],
    );
    return rows.isEmpty ? null : linkedAccountFromMap(rows.first);
  }

  Future<bool> updateLinkedAccount(LinkedAccount account) async {
    if (account.id == null) return false;
    final db = await _databaseHelper.database;
    return await db.update(
          'linked_accounts',
          linkedAccountToMap(account),
          where: 'id = ?',
          whereArgs: [account.id],
        ) >
        0;
  }

  Future<bool> deleteLinkedAccount(int id) async {
    final db = await _databaseHelper.database;
    return await db.delete(
          'linked_accounts',
          where: 'id = ?',
          whereArgs: [id],
        ) >
        0;
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
          row['task_id']! as int,
          DateTime.parse(row['occurrence_date']! as String),
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

  Future<int> getFocusSecondsForDate(DateTime date) async {
    final db = await _databaseHelper.database;
    final focusDate = dateOnly(date).toIso8601String();
    final rows = await db.query(
      'focus_daily_totals',
      columns: ['total_seconds'],
      where: 'focus_date = ?',
      whereArgs: [focusDate],
      limit: 1,
    );
    return rows.isEmpty ? 0 : rows.single['total_seconds']! as int;
  }

  Future<void> addFocusSeconds(DateTime date, int seconds) async {
    if (seconds <= 0) return;
    final db = await _databaseHelper.database;
    await db.rawInsert(
      '''
      INSERT INTO focus_daily_totals (focus_date, total_seconds)
      VALUES (?, ?)
      ON CONFLICT(focus_date) DO UPDATE SET
        total_seconds = total_seconds + excluded.total_seconds
      ''',
      [dateOnly(date).toIso8601String(), seconds],
    );
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
        final scheduled = occurrence is Task
            ? taskDateTime(occurrence)
            : eventStartDateTime(occurrence as Event);
        final isCurrentAllDay =
            occurrence is Event &&
            occurrence.allDay &&
            _sameDay(occurrence.date, now);
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
    if (row['item_type'] == 'task') {
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

  int _compareItems(PlannerItem first, PlannerItem second) {
    final firstTime = first is Task
        ? taskDateTime(first)
        : eventStartDateTime(first as Event);
    final secondTime = second is Task
        ? taskDateTime(second)
        : eventStartDateTime(second as Event);
    return firstTime.compareTo(secondTime);
  }

  bool _sameDay(DateTime first, DateTime second) =>
      first.year == second.year &&
      first.month == second.month &&
      first.day == second.day;
}
