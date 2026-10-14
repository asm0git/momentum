import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momentum/app_theme.dart';
import 'package:momentum/data/database_helper.dart';
import 'package:momentum/data/planner_repository.dart';
import 'package:momentum/data_models.dart';
import 'package:momentum/state/planner_state.dart';
import 'package:momentum/widgets/planner/item_actions.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Directory tempDirectory;
  late DatabaseHelper databaseHelper;
  late PlannerState planner;

  setUpAll(() => sqfliteFfiInit());

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp(
      'momentum_item_actions_',
    );
    databaseHelper = DatabaseHelper.forTesting(
      factory: databaseFactoryFfi,
      databasePath: '${tempDirectory.path}/item-actions.db',
      seedOnCreate: false,
    );
    planner = PlannerState(
      repository: PlannerRepository(databaseHelper: databaseHelper),
      autoSyncCalendarsOnStartup: false,
    );
    await planner.initialize();
  });

  tearDown(() async {
    planner.dispose();
    await databaseHelper.close();
    await tempDirectory.delete(recursive: true);
  });

  testWidgets('canceling item deletion leaves the stored row intact', (
    tester,
  ) async {
    final task = await _saveTask(tester, planner);
    await tester.pumpWidget(_app(planner, task));

    await tester.tap(find.text('Delete task'));
    await tester.pumpAndSettle();
    expect(find.text('Delete item?'), findsOneWidget);
    expect(find.textContaining(task.title), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(planner.items.whereType<Task>().single.id, task.id);
  });

  testWidgets('confirming item deletion removes the selected row', (
    tester,
  ) async {
    final task = await _saveTask(tester, planner);
    await tester.pumpWidget(_app(planner, task));

    await tester.tap(find.text('Delete task'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Delete item?'), findsNothing);
    expect(planner.items.whereType<Task>(), isEmpty);
  });
}

Future<Task> _saveTask(WidgetTester tester, PlannerState planner) async =>
    (await tester.runAsync(
      () => planner.saveTask(
        Task(
          title: 'Read chapter',
          date: DateTime(2026, 10, 9),
          isChecked: false,
          time: const TimeOfDay(hour: 9, minute: 0),
          estimatedDuration: Duration.zero,
        ),
      ),
    ))!;

Widget _app(PlannerState planner, Task task) =>
    ChangeNotifierProvider<PlannerState>.value(
      value: planner,
      child: MaterialApp(
        theme: appTheme,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () {
                confirmDeleteItem(context, task);
              },
              child: const Text('Delete task'),
            ),
          ),
        ),
      ),
    );
