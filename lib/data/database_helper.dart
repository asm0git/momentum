import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../data_models.dart';
import 'database_factory_native.dart'
    if (dart.library.js_interop) 'database_factory_web.dart'
    as platform;
import 'model_serialization.dart';
import 'sample_data.dart';

class DatabaseHelper {
  DatabaseHelper._({
    this._factory,
    this._databasePath,
    this.seedOnCreate = true,
  });

  static final DatabaseHelper instance = DatabaseHelper._();

  @visibleForTesting
  factory DatabaseHelper.forTesting({
    required DatabaseFactory factory,
    required String databasePath,
    bool seedOnCreate = true,
  }) => DatabaseHelper._(
    factory: factory,
    databasePath: databasePath,
    seedOnCreate: seedOnCreate,
  );

  final DatabaseFactory? _factory;
  final String? _databasePath;
  final bool seedOnCreate;
  Future<Database>? _databaseFuture;

  Future<Database> get database => _databaseFuture ??= _openDatabase();

  Future<Database> _openDatabase() async {
    final factory = _factory ?? platform.platformDatabaseFactory;
    final path =
        _databasePath ??
        (kIsWeb
            ? 'momentum.db'
            : p.join(await factory.getDatabasesPath(), 'momentum.db'));
    return factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 6,
        onConfigure: (db) async => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: (db, version) async {
          await _createSchema(db);
          if (seedOnCreate) await _seed(db);
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 3) {
            // Preserve existing rows while adding recurring-item support.
            await db.execute(
              "ALTER TABLE tasks ADD COLUMN repeat TEXT NOT NULL DEFAULT 'Never'",
            );
            await db.execute('ALTER TABLE tasks ADD COLUMN repeat_until TEXT');
            await db.execute('ALTER TABLE events ADD COLUMN repeat_until TEXT');
            await _createOccurrenceAndFocusTables(db);
          }
          if (oldVersion < 4) {
            await _migrateLinkedAccountsV4(db);
            await db.execute(
              'CREATE INDEX IF NOT EXISTS idx_tasks_source ON tasks(src_platform, external_id)',
            );
            await db.execute(
              'CREATE INDEX IF NOT EXISTS idx_events_source ON events(src_platform, external_id)',
            );
            await db.execute('''
              CREATE UNIQUE INDEX IF NOT EXISTS idx_canvas_task_external_id
              ON tasks(external_id)
              WHERE src_platform = 'canvas' AND external_id IS NOT NULL
            ''');
            await db.execute('''
              CREATE UNIQUE INDEX IF NOT EXISTS idx_canvas_event_external_id
              ON events(external_id)
              WHERE src_platform = 'canvas' AND external_id IS NOT NULL
            ''');
          }
          if (oldVersion < 5) {
            await db.execute('''
              CREATE UNIQUE INDEX IF NOT EXISTS idx_imported_task_provider_id
              ON tasks(src_platform, external_id)
              WHERE src_platform IN ('canvas', 'google', 'outlook')
                AND external_id IS NOT NULL
            ''');
            await db.execute('''
              CREATE UNIQUE INDEX IF NOT EXISTS idx_imported_event_provider_id
              ON events(src_platform, external_id)
              WHERE src_platform IN ('canvas', 'google', 'outlook')
                AND external_id IS NOT NULL
            ''');
          }
          if (oldVersion < 6) {
            await db.delete(
              'events',
              where: 'title = ?',
              whereArgs: ["Janisa's Birthday"],
            );
          }
        },
      ),
    );
  }

  Future<void> _createSchema(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL UNIQUE COLLATE NOCASE,
        icon_name TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE tasks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        category_id INTEGER,
        title TEXT NOT NULL,
        description TEXT NOT NULL DEFAULT '',
        due TEXT NOT NULL,
        estimated_duration_minutes INTEGER NOT NULL DEFAULT 0,
        repeat TEXT NOT NULL DEFAULT 'Never',
        repeat_until TEXT,
        priority INTEGER,
        is_completed INTEGER NOT NULL DEFAULT 0 CHECK (is_completed IN (0, 1)),
        src_platform TEXT,
        external_id TEXT,
        FOREIGN KEY (category_id) REFERENCES categories(id) ON DELETE SET NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE events (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        category_id INTEGER,
        title TEXT NOT NULL,
        start_time TEXT NOT NULL,
        end_time TEXT NOT NULL,
        location TEXT,
        is_all_day INTEGER NOT NULL DEFAULT 0 CHECK (is_all_day IN (0, 1)),
        is_current INTEGER NOT NULL DEFAULT 0 CHECK (is_current IN (0, 1)),
        repeat TEXT NOT NULL DEFAULT 'Never',
        repeat_until TEXT,
        notes TEXT NOT NULL DEFAULT '',
        src_platform TEXT,
        external_id TEXT,
        FOREIGN KEY (category_id) REFERENCES categories(id) ON DELETE SET NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE ai_plans (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        plan_date TEXT NOT NULL,
        ordered_task_ids TEXT NOT NULL,
        generated_timestamp TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE linked_accounts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        platform_name TEXT NOT NULL,
        account_name TEXT NOT NULL,
        account_email TEXT,
        provider_url TEXT,
        remote_user_id TEXT,
        category_id INTEGER,
        last_sync_time TEXT,
        FOREIGN KEY (category_id) REFERENCES categories(id) ON DELETE SET NULL
      )
    ''');
    await db.execute('CREATE INDEX idx_tasks_due ON tasks(due)');
    await db.execute('CREATE INDEX idx_tasks_category ON tasks(category_id)');
    await db.execute('CREATE INDEX idx_events_start ON events(start_time)');
    await db.execute('CREATE INDEX idx_events_category ON events(category_id)');
    await db.execute(
      'CREATE INDEX idx_tasks_source ON tasks(src_platform, external_id)',
    );
    await db.execute(
      'CREATE INDEX idx_events_source ON events(src_platform, external_id)',
    );
    await db.execute('''
      CREATE UNIQUE INDEX idx_canvas_task_external_id
      ON tasks(external_id)
      WHERE src_platform = 'canvas' AND external_id IS NOT NULL
    ''');
    await db.execute('''
      CREATE UNIQUE INDEX idx_canvas_event_external_id
      ON events(external_id)
      WHERE src_platform = 'canvas' AND external_id IS NOT NULL
    ''');
    await db.execute('''
      CREATE UNIQUE INDEX idx_imported_task_provider_id
      ON tasks(src_platform, external_id)
      WHERE src_platform IN ('google', 'outlook') AND external_id IS NOT NULL
    ''');
    await db.execute('''
      CREATE UNIQUE INDEX idx_imported_event_provider_id
      ON events(src_platform, external_id)
      WHERE src_platform IN ('google', 'outlook') AND external_id IS NOT NULL
    ''');
    await _createOccurrenceAndFocusTables(db);
  }

  Future<void> _migrateLinkedAccountsV4(DatabaseExecutor db) async {
    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'linked_accounts'",
    );
    if (tables.isEmpty) {
      await db.execute('''
        CREATE TABLE linked_accounts (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          platform_name TEXT NOT NULL,
          account_name TEXT NOT NULL,
          account_email TEXT,
          provider_url TEXT,
          remote_user_id TEXT,
          category_id INTEGER,
          last_sync_time TEXT,
          FOREIGN KEY (category_id) REFERENCES categories(id) ON DELETE SET NULL
        )
      ''');
      return;
    }

    // Copy account metadata, but intentionally discard the legacy plaintext
    // credential column. Every old connection must be authorized again.
    await db.execute(
      'ALTER TABLE linked_accounts RENAME TO linked_accounts_v3',
    );
    await db.execute('''
      CREATE TABLE linked_accounts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        platform_name TEXT NOT NULL,
        account_name TEXT NOT NULL,
        account_email TEXT,
        provider_url TEXT,
        remote_user_id TEXT,
        category_id INTEGER,
        last_sync_time TEXT,
        FOREIGN KEY (category_id) REFERENCES categories(id) ON DELETE SET NULL
      )
    ''');
    await db.execute('''
      INSERT INTO linked_accounts
        (id, platform_name, account_name, account_email, last_sync_time)
      SELECT id, platform_name, COALESCE(account_email, 'Linked account'),
        account_email, last_sync_time
      FROM linked_accounts_v3
    ''');
    await db.execute('DROP TABLE linked_accounts_v3');
  }

  Future<void> _createOccurrenceAndFocusTables(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE task_occurrence_completions (
        task_id INTEGER NOT NULL,
        occurrence_date TEXT NOT NULL,
        PRIMARY KEY (task_id, occurrence_date),
        FOREIGN KEY (task_id) REFERENCES tasks(id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE focus_daily_totals (
        focus_date TEXT PRIMARY KEY,
        total_seconds INTEGER NOT NULL DEFAULT 0 CHECK (total_seconds >= 0)
      )
    ''');
  }

  Future<void> _seed(DatabaseExecutor db) async {
    for (final category in createSampleCategories()) {
      final categoryId = await db.insert('categories', categoryToMap(category));
      for (final item in category.items) {
        item.categoryId = categoryId;
        if (item is Task) {
          await db.insert('tasks', taskToMap(item));
        } else if (item is Event) {
          await db.insert('events', eventToMap(item));
        }
      }
    }
  }

  @visibleForTesting
  Future<void> close() async {
    final openDatabase = _databaseFuture;
    _databaseFuture = null;
    if (openDatabase != null) await (await openDatabase).close();
  }
}
