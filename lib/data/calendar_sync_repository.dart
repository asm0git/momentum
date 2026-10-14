import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';

import '../data_models.dart';
import 'database_helper.dart';
import 'model_serialization.dart';

/// Persists a provider response as one atomic local update.
class CalendarSyncRepository {
  CalendarSyncRepository({DatabaseHelper? databaseHelper})
    : _databaseHelper = databaseHelper ?? DatabaseHelper.instance;

  final DatabaseHelper _databaseHelper;

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

  /// Applies a provider response in one transaction. Missing imported rows are
  /// retained unless replacement or cleanup is explicitly requested.
  Future<LinkedAccount> applyCalendarSync(
    CalendarSyncPayload payload, {
    bool replaceExistingImports = false,
    bool removeMissingTasks = false,
    bool removeMissingEvents = false,
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
        final updatedRows = await txn.update(
          'linked_accounts',
          linkedAccountToMap(account)..remove('id'),
          where: 'id = ?',
          whereArgs: [account.id],
        );
        if (updatedRows == 0) {
          throw StateError(
            'The linked calendar account was not updated during sync.',
          );
        }
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
                sourcePlatform: provider,
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
            ..sourcePlatform = provider
            ..externalId = imported.externalId;
          await txn.update(
            'tasks',
            taskToMap(old)..remove('id'),
            where: 'id = ?',
            whereArgs: [old.id],
          );
        }
      }

      if (removeMissingTasks) {
        await _removeMissingImportedItems(
          txn,
          table: 'tasks',
          provider: provider,
          importedIds: payload.tasks.map((task) => task.externalId).toSet(),
        );
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
                sourcePlatform: provider,
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
            ..sourcePlatform = provider
            ..externalId = imported.externalId;
          await txn.update(
            'events',
            eventToMap(old)..remove('id'),
            where: 'id = ?',
            whereArgs: [old.id],
          );
        }
      }

      if (removeMissingEvents) {
        await _removeMissingImportedItems(
          txn,
          table: 'events',
          provider: provider,
          importedIds: payload.events.map((event) => event.externalId).toSet(),
        );
      }
      return account;
    });
  }

  Future<void> _removeMissingImportedItems(
    Transaction txn, {
    required String table,
    required String provider,
    required Set<String> importedIds,
  }) async {
    final rows = await txn.query(
      table,
      columns: ['id', 'external_id'],
      where: 'src_platform = ?',
      whereArgs: [provider],
    );
    for (final row in rows) {
      final externalId = optionalStringFromMap(row, 'external_id');
      if (externalId == null || !importedIds.contains(externalId)) {
        await txn.delete(table, where: 'id = ?', whereArgs: [row['id']]);
      }
    }
  }
}
