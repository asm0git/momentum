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
        version: 3,
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
        account_email TEXT NOT NULL,
        api_token TEXT NOT NULL,
        last_sync_time TEXT
      )
    ''');
    await db.execute('CREATE INDEX idx_tasks_due ON tasks(due)');
    await db.execute('CREATE INDEX idx_tasks_category ON tasks(category_id)');
    await db.execute('CREATE INDEX idx_events_start ON events(start_time)');
    await db.execute('CREATE INDEX idx_events_category ON events(category_id)');
    await _createOccurrenceAndFocusTables(db);
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
        if (item is Event) {
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
