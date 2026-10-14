import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:momentum/data/database_helper.dart';
import 'package:momentum/data/focus_history_repository.dart';
import 'package:momentum/data/planner_repository.dart';
import 'package:momentum/data_models.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Directory tempDirectory;
  late DatabaseHelper helper;
  late PlannerRepository repository;
  late FocusHistoryRepository focusRepository;

  setUpAll(() => sqfliteFfiInit());

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp('momentum_insights_');
    helper = DatabaseHelper.forTesting(
      factory: databaseFactoryFfi,
      databasePath: p.join(tempDirectory.path, 'insights.db'),
      seedOnCreate: false,
    );
    repository = PlannerRepository(databaseHelper: helper);
    focusRepository = FocusHistoryRepository(databaseHelper: helper);
  });

  tearDown(() async {
    await helper.close();
    await tempDirectory.delete(recursive: true);
  });

  test(
    'v6 to v7 migration preserves daily totals and starts category history empty',
    () async {
      final legacyPath = p.join(tempDirectory.path, 'v6.db');
      final legacy = await databaseFactoryFfi.openDatabase(
        legacyPath,
        options: OpenDatabaseOptions(
          version: 6,
          onCreate: (db, version) async {
            await db.execute('''
            CREATE TABLE categories (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              title TEXT NOT NULL UNIQUE,
              icon_name TEXT NOT NULL
            )
          ''');
            await db.execute('''
            CREATE TABLE focus_daily_totals (
              focus_date TEXT PRIMARY KEY,
              total_seconds INTEGER NOT NULL DEFAULT 0
            )
          ''');
            await db.insert('categories', {
              'id': 1,
              'title': 'School',
              'icon_name': 'mi_school',
            });
            await db.insert('focus_daily_totals', {
              'focus_date': '2026-10-12T00:00:00.000',
              'total_seconds': 2700,
            });
          },
        ),
      );
      await legacy.close();

      final migratedHelper = DatabaseHelper.forTesting(
        factory: databaseFactoryFfi,
        databasePath: legacyPath,
        seedOnCreate: false,
      );
      final migrated = FocusHistoryRepository(databaseHelper: migratedHelper);
      expect(
        await migrated.getFocusSecondsForDate(DateTime(2026, 10, 12)),
        2700,
      );
      expect(
        await migrated.getFocusCategoryTotalsForRange(
          DateTime(2026, 10, 12),
          DateTime(2026, 10, 18),
        ),
        isEmpty,
      );
      await migratedHelper.close();
    },
  );

  test('daily range and category totals share local date boundaries', () async {
    final category = await repository.insertCategory(
      TaskCategory(title: 'School', iconName: 'mi_school', items: []),
    );
    final selection = FocusTaskSelection(
      taskId: 7,
      taskTitle: 'Read',
      categoryId: category.id!,
      categoryTitle: category.title,
      categoryIcon: category.iconName,
    );
    await focusRepository.addFocusSeconds(
      DateTime(2026, 10, 12, 23, 30),
      600,
      selection,
    );
    await focusRepository.addFocusSeconds(
      DateTime(2026, 10, 18, 8),
      900,
      selection,
    );
    await focusRepository.addFocusSeconds(
      DateTime(2026, 10, 19),
      120,
      selection,
    );

    final daily = await focusRepository.getFocusTotalsForRange(
      DateTime(2026, 10, 12),
      DateTime(2026, 10, 18),
    );
    expect(daily.values.fold<int>(0, (sum, value) => sum + value), 1500);
    final categories = await focusRepository.getFocusCategoryTotalsForRange(
      DateTime(2026, 10, 12),
      DateTime(2026, 10, 18),
    );
    expect(categories.single.totalSeconds, 1500);
    expect(categories.single.categoryTitle, 'School');

    await repository.deleteCategory(
      category.id!,
      disposition: CategoryDeleteDisposition.deleteItems,
    );
    final historical = await focusRepository.getFocusCategoryTotalsForRange(
      DateTime(2026, 10, 12),
      DateTime(2026, 10, 18),
    );
    expect(historical.single.categoryTitle, 'School');
    expect(historical.single.categoryIcon, 'mi_school');
  });
}
