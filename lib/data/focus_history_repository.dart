import '../data_models.dart';
import 'database_helper.dart';
import 'recurrence.dart';

/// Persists and reads Pomodoro and automatic focus totals.
class FocusHistoryRepository {
  FocusHistoryRepository({DatabaseHelper? databaseHelper})
    : _databaseHelper = databaseHelper ?? DatabaseHelper.instance;

  final DatabaseHelper _databaseHelper;

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
    return rows.isEmpty ? 0 : _requiredInt(rows.single, 'total_seconds');
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
        dateOnly(_requiredDateTime(row, 'focus_date')):
            _requiredInt(row, 'total_seconds'),
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
            categoryId: _requiredInt(row, 'category_id'),
            categoryTitle: _requiredString(row, 'category_title'),
            categoryIcon: _requiredString(row, 'category_icon'),
            totalSeconds: _requiredInt(row, 'total_seconds'),
          ),
        )
        .toList();
  }

  Future<void> addFocusSeconds(
    DateTime date,
    int seconds,
    FocusTaskSelection selection,
  ) => addFocusSecondsBatch([
    (date: date, seconds: seconds, selection: selection),
  ]);

  Future<void> addFocusSecondsBatch(
    Iterable<({DateTime date, int seconds, FocusTaskSelection selection})>
    entries,
  ) async {
    final writes = entries.where((entry) => entry.seconds > 0).toList();
    if (writes.isEmpty) return;
    final db = await _databaseHelper.database;
    await db.transaction((txn) async {
      for (final entry in writes) {
        final focusDate = dateOnly(entry.date).toIso8601String();
        await txn.rawInsert(
          '''
          INSERT INTO focus_daily_totals (focus_date, total_seconds)
          VALUES (?, ?)
          ON CONFLICT(focus_date) DO UPDATE SET
            total_seconds = total_seconds + excluded.total_seconds
          ''',
          [focusDate, entry.seconds],
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
            entry.selection.categoryId,
            entry.selection.categoryTitle,
            entry.selection.categoryIcon,
            entry.seconds,
          ],
        );
      }
    });
  }
}

int _requiredInt(Map<String, Object?> row, String column) {
  final value = row[column];
  if (value is int) return value;
  throw FormatException('Expected SQL column "$column" to be an integer.');
}

String _requiredString(Map<String, Object?> row, String column) {
  final value = row[column];
  if (value is String) return value;
  throw FormatException('Expected SQL column "$column" to be a string.');
}

DateTime _requiredDateTime(Map<String, Object?> row, String column) {
  final value = _requiredString(row, column);
  try {
    return DateTime.parse(value);
  } on FormatException {
    throw FormatException(
      'Expected SQL column "$column" to contain a valid date.',
      value,
    );
  }
}
