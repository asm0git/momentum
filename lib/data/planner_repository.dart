import 'package:flutter/material.dart';
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

  /// Applies a complete Canvas response in one local transaction. Existing
  /// completion state and item IDs are retained when a remote item is refreshed.
  Future<LinkedAccount> applyCanvasSync(
    CanvasSyncPayload payload, {
    bool replaceExistingImports = false,
  }) => applyCalendarSync(
    payload,
    replaceExistingImports: replaceExistingImports,
  );

  Future<LinkedAccount> applyCalendarSync(
    CanvasSyncPayload payload, {
    bool replaceExistingImports = false,
  }) async {
    final db = await _databaseHelper.database;
    final provider = payload.providerName.toLowerCase();
    final providerInfo = CalendarProvider.values.firstWhere(
      (value) => value.key == provider,
      orElse: () => throw ArgumentError.value(
        payload.providerName,
        'providerName',
        'Unknown calendar provider.',
      ),
    );
    return db.transaction((txn) async {
      final accounts = await txn.query(
        'linked_accounts',
        where: 'LOWER(platform_name) = ?',
        whereArgs: [provider],
        limit: 1,
      );
      final existingAccount = accounts.isEmpty
          ? null
          : linkedAccountFromMap(accounts.single);

      final oldRemoteUserId = existingAccount?.remoteUserId?.trim();
      final newRemoteUserId = payload.remoteUserId.trim();
      final oldProviderUrl = existingAccount?.providerUrl?.trim();
      final newProviderUrl = payload.providerUrl.trim();
      final accountChanged =
          (oldRemoteUserId?.isNotEmpty == true &&
              newRemoteUserId.isNotEmpty &&
              oldRemoteUserId != newRemoteUserId) ||
          (oldProviderUrl?.isNotEmpty == true &&
              newProviderUrl.isNotEmpty &&
              oldProviderUrl != newProviderUrl);
      if (replaceExistingImports || accountChanged) {
        // Only remove records imported from this provider. Locally created
        // planner items and imports from other calendars remain untouched.
        await txn.delete(
          'tasks',
          where: 'src_platform = ?',
          whereArgs: [provider],
        );
        await txn.delete(
          'events',
          where: 'src_platform = ?',
          whereArgs: [provider],
        );
      }

      TaskCategory? category;
      final existingCategoryId = existingAccount?.categoryId;
      if (existingCategoryId != null) {
        final rows = await txn.query(
          'categories',
          where: 'id = ?',
          whereArgs: [existingCategoryId],
          limit: 1,
        );
        if (rows.isNotEmpty) category ??= categoryFromMap(rows.single);
      }
      if (category == null) {
        final rows = await txn.query(
          'categories',
          where: 'title = ? COLLATE NOCASE',
          whereArgs: [providerInfo.title],
          limit: 1,
        );
        category = rows.isEmpty
            ? TaskCategory(
                title: providerInfo.title,
                iconName: providerInfo.categoryIcon,
                items: [],
              )
            : categoryFromMap(rows.single);
        category.id ??= await txn.insert('categories', categoryToMap(category));
      }

      final account = LinkedAccount(
        id: existingAccount?.id,
        platformName: provider,
        accountName: payload.accountName,
        accountEmail: payload.accountEmail,
        providerUrl: payload.providerUrl,
        remoteUserId: payload.remoteUserId,
        categoryId: category.id,
        lastSyncTime: payload.syncedAt,
      );
      if (account.id == null) {
        account.id = await txn.insert(
          'linked_accounts',
          linkedAccountToMap(account),
        );
      } else {
        await txn.update(
          'linked_accounts',
          linkedAccountToMap(account)..remove('id'),
          where: 'id = ?',
          whereArgs: [account.id],
        );
      }

      for (final imported in payload.tasks) {
        final rows = await txn.query(
          'tasks',
          where: 'src_platform = ? AND external_id = ?',
          whereArgs: [provider, imported.externalId],
          limit: 1,
        );
        if (rows.isEmpty) {
          final due = imported.due.toLocal();
          await txn.insert(
            'tasks',
            taskToMap(
              Task(
                categoryId: category.id,
                title: imported.title,
                date: DateTime(due.year, due.month, due.day),
                time: TimeOfDay(hour: due.hour, minute: due.minute),
                estimatedDuration: Duration.zero,
                isChecked: false,
                description: imported.description,
                srcPlatform: provider,
                externalId: imported.externalId,
              ),
            ),
          );
        } else {
          final old = taskFromMap(rows.single);
          final due = imported.due.toLocal();
          old
            ..categoryId = category.id
            ..title = imported.title
            ..date = DateTime(due.year, due.month, due.day)
            ..time = TimeOfDay(hour: due.hour, minute: due.minute)
            ..description = imported.description
            ..srcPlatform = provider
            ..externalId = imported.externalId;
          await txn.update(
            'tasks',
            taskToMap(old)..remove('id'),
            where: 'id = ?',
            whereArgs: [old.id],
          );
        }
      }

      for (final imported in payload.events) {
        final rows = await txn.query(
          'events',
          where: 'src_platform = ? AND external_id = ?',
          whereArgs: [provider, imported.externalId],
          limit: 1,
        );
        final start = imported.start.toLocal();
        final end = imported.end.toLocal();
        if (rows.isEmpty) {
          await txn.insert(
            'events',
            eventToMap(
              Event(
                categoryId: category.id,
                title: imported.title,
                date: DateTime(start.year, start.month, start.day),
                endDate: DateTime(end.year, end.month, end.day),
                start: TimeOfDay(hour: start.hour, minute: start.minute),
                end: TimeOfDay(hour: end.hour, minute: end.minute),
                isCurrent: false,
                allDay: imported.allDay,
                location: imported.location,
                notes: imported.description,
                srcPlatform: provider,
                externalId: imported.externalId,
              ),
            ),
          );
        } else {
          final old = eventFromMap(rows.single);
          old
            ..categoryId = category.id
            ..title = imported.title
            ..date = DateTime(start.year, start.month, start.day)
            ..endDate = DateTime(end.year, end.month, end.day)
            ..start = TimeOfDay(hour: start.hour, minute: start.minute)
            ..end = TimeOfDay(hour: end.hour, minute: end.minute)
            ..allDay = imported.allDay
            ..location = imported.location
            ..notes = imported.description
            ..srcPlatform = provider
            ..externalId = imported.externalId;
          await txn.update(
            'events',
            eventToMap(old)..remove('id'),
            where: 'id = ?',
            whereArgs: [old.id],
          );
        }
      }
      return account;
    });
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

  Future<Map<DateTime, int>> getFocusTotalsForRange(
    DateTime firstDay,
    DateTime lastDay,
  ) async {
    final db = await _databaseHelper.database;
    final first = dateOnly(firstDay).toIso8601String();
    final last = dateOnly(lastDay).toIso8601String();
    final rows = await db.query(
      'focus_daily_totals',
      columns: ['focus_date', 'total_seconds'],
      where: 'focus_date >= ? AND focus_date <= ?',
      whereArgs: [first, last],
      orderBy: 'focus_date',
    );
    return {
      for (final row in rows)
        dateOnly(DateTime.parse(row['focus_date']! as String)):
            row['total_seconds']! as int,
    };
  }

  Future<List<FocusCategoryTotal>> getFocusCategoryTotalsForRange(
    DateTime firstDay,
    DateTime lastDay,
  ) async {
    final db = await _databaseHelper.database;
    final rows = await db.rawQuery(
      '''
      SELECT totals.category_id,
        COALESCE(categories.title, totals.category_title) AS category_title,
        COALESCE(categories.icon_name, totals.category_icon) AS category_icon,
        SUM(totals.total_seconds) AS total_seconds
      FROM focus_daily_category_totals AS totals
      LEFT JOIN categories ON categories.id = totals.category_id
      WHERE totals.focus_date >= ? AND totals.focus_date <= ?
      GROUP BY totals.category_id, category_title, category_icon
      ORDER BY total_seconds DESC, category_title COLLATE NOCASE
      ''',
      [
        dateOnly(firstDay).toIso8601String(),
        dateOnly(lastDay).toIso8601String(),
      ],
    );
    return rows
        .map(
          (row) => FocusCategoryTotal(
            categoryId: row['category_id']! as int,
            categoryTitle: row['category_title']! as String,
            categoryIcon: row['category_icon']! as String,
            totalSeconds: row['total_seconds']! as int,
          ),
        )
        .toList();
  }

  Future<void> addFocusSeconds(
    DateTime date,
    int seconds,
    FocusTaskSelection selection,
  ) async {
    if (seconds <= 0) return;
    final db = await _databaseHelper.database;
    final focusDate = dateOnly(date).toIso8601String();
    await db.transaction((txn) async {
      await txn.rawInsert(
        '''
        INSERT INTO focus_daily_totals (focus_date, total_seconds)
        VALUES (?, ?)
        ON CONFLICT(focus_date) DO UPDATE SET
          total_seconds = total_seconds + excluded.total_seconds
        ''',
        [focusDate, seconds],
      );
      await txn.rawInsert(
        '''
        INSERT INTO focus_daily_category_totals
          (focus_date, category_id, category_title, category_icon, total_seconds)
        VALUES (?, ?, ?, ?, ?)
        ON CONFLICT(focus_date, category_id) DO UPDATE SET
          category_title = excluded.category_title,
          category_icon = excluded.category_icon,
          total_seconds = total_seconds + excluded.total_seconds
        ''',
        [
          focusDate,
          selection.categoryId,
          selection.categoryTitle,
          selection.categoryIcon,
          seconds,
        ],
      );
    });
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
