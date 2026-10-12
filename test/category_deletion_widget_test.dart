import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momentum/app_theme.dart';
import 'package:momentum/data/database_helper.dart';
import 'package:momentum/data/planner_repository.dart';
import 'package:momentum/data_models.dart';
import 'package:momentum/screens/todo_screen.dart';
import 'package:momentum/state/planner_state.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Directory tempDirectory;
  late DatabaseHelper databaseHelper;
  late PlannerState planner;

  setUpAll(() => sqfliteFfiInit());

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp(
      'momentum_category_delete_',
    );
    databaseHelper = DatabaseHelper.forTesting(
      factory: databaseFactoryFfi,
      databasePath: '${tempDirectory.path}/planner.db',
      seedOnCreate: false,
    );
    planner = PlannerState(
      repository: PlannerRepository(databaseHelper: databaseHelper),
    );
    await planner.initialize();
  });

  tearDown(() async {
    planner.dispose();
    await databaseHelper.close();
    await tempDirectory.delete(recursive: true);
  });

  testWidgets('To-Do creates a category from the top action', (tester) async {
    await tester.pumpWidget(_app(planner));

    final actionFinder = find.descendant(
      of: find.byKey(const ValueKey('todo-new-category')),
      matching: find.byType(OutlinedButton),
    );
    expect(actionFinder, findsOneWidget);
    expect(
      tester
          .widget<OutlinedButton>(actionFinder)
          .style
          ?.backgroundColor
          ?.resolve({}),
      AppColors.surface,
    );
    expect(find.byIcon(Icons.add_circle_outline), findsOneWidget);

    await tester.tap(actionFinder);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Projects');
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      for (
        var attempt = 0;
        attempt < 50 && planner.categories.isEmpty;
        attempt++
      ) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
    });
    await tester.pump();

    expect(planner.categories.single.title, 'Projects');
    expect(find.text('Projects'), findsOneWidget);
  });

  testWidgets('canceling category deletion leaves the category intact', (
    tester,
  ) async {
    final category = (await tester.runAsync(
      () => planner.addCategory(
        TaskCategory(title: 'Empty', iconName: 'mi_folder', items: []),
      ),
    ))!;
    await tester.pumpWidget(_app(planner));

    await _openCategoryDeleteDialog(tester, 'Empty');
    expect(find.text('Delete category?'), findsOneWidget);
    final title = tester.widget<Text>(find.text('Delete category?'));
    _expectTypography(
      title.style,
      appTheme.textTheme.bodyMedium!.copyWith(color: AppColors.primary),
    );
    final description = tester.widget<Text>(
      find.textContaining('This cannot be undone.'),
    );
    _expectTypography(
      description.style,
      appTheme.textTheme.bodyMedium!.copyWith(
        color: AppColors.onSurface,
        fontWeight: FontWeight.w400,
      ),
    );
    expect(
      find.descendant(
        of: find.byType(Dialog),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Padding &&
              widget.padding == const EdgeInsets.all(AppSpacing.md),
        ),
      ),
      findsAtLeastNWidgets(1),
    );

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(planner.categories.single.id, category.id);
  });

  testWidgets('moving category contents reassigns tasks and events', (
    tester,
  ) async {
    final source = (await tester.runAsync(
      () => planner.addCategory(
        TaskCategory(title: 'Source', iconName: 'mi_folder', items: []),
      ),
    ))!;
    final destination = (await tester.runAsync(
      () => planner.addCategory(
        TaskCategory(title: 'Destination', iconName: 'mi_school', items: []),
      ),
    ))!;
    await tester.runAsync(() async {
      await planner.saveTask(
        Task(
          categoryId: source.id,
          title: 'Moved task',
          date: DateTime(2026, 10, 10),
          time: const TimeOfDay(hour: 9, minute: 0),
          estimatedDuration: const Duration(minutes: 30),
          isChecked: false,
          repeat: 'Every week',
          repeatUntil: DateTime(2026, 12, 1),
        ),
      );
      await planner.saveEvent(
        Event(
          categoryId: source.id,
          title: 'Moved event',
          date: DateTime(2026, 10, 10),
          start: const TimeOfDay(hour: 11, minute: 0),
          end: const TimeOfDay(hour: 12, minute: 0),
          isCurrent: false,
          allDay: false,
          repeat: 'Every month',
          repeatUntil: DateTime(2027, 1, 1),
        ),
      );
    });
    await tester.pumpWidget(_app(planner));

    await _openCategoryDeleteDialog(tester, 'Source');
    await tester.tap(find.text('Move items to another category'));
    await tester.pumpAndSettle();
    final moveAndDeleteFinder = find.widgetWithText(
      FilledButton,
      'Move & delete',
    );
    final disabledMoveButton = tester.widget<FilledButton>(moveAndDeleteFinder);
    expect(disabledMoveButton.onPressed, isNull);
    expect(
      disabledMoveButton.style?.backgroundColor?.resolve({
        WidgetState.disabled,
      }),
      AppColors.disabled,
    );
    final destinationPicker = find.byType(DropdownButton<String?>);
    await tester.ensureVisible(destinationPicker);
    await tester.pumpAndSettle();
    await tester.tap(destinationPicker);
    await tester.pumpAndSettle();
    expect(find.text('Destination'), findsNWidgets(2));
    await tester.tap(find.text('Destination').last);
    await tester.pumpAndSettle();
    expect(find.text('Choose a category'), findsNothing);
    expect(
      tester.widget<FilledButton>(moveAndDeleteFinder).onPressed,
      isNotNull,
    );
    expect(
      tester
          .widget<FilledButton>(moveAndDeleteFinder)
          .style
          ?.backgroundColor
          ?.resolve({}),
      AppColors.primary,
    );
    await tester.tap(find.text('Move & delete'));
    await tester.pumpAndSettle();
    expect(find.text('Delete category?'), findsNothing);
    await _waitForCategoryCount(tester, planner, 1);

    expect(planner.categories.map((item) => item.id), [destination.id]);
    expect(planner.items.whereType<Task>().single.categoryId, destination.id);
    expect(planner.items.whereType<Event>().single.categoryId, destination.id);
    expect(planner.items.whereType<Task>().single.repeat, 'Every week');
    expect(planner.items.whereType<Event>().single.repeat, 'Every month');
  });

  testWidgets('deleting category contents removes its tasks and events', (
    tester,
  ) async {
    final category = (await tester.runAsync(
      () => planner.addCategory(
        TaskCategory(title: 'Remove all', iconName: 'mi_folder', items: []),
      ),
    ))!;
    await tester.runAsync(() async {
      await planner.saveTask(
        Task(
          categoryId: category.id,
          title: 'Task to remove',
          date: DateTime(2026, 10, 10),
          time: const TimeOfDay(hour: 9, minute: 0),
          estimatedDuration: const Duration(minutes: 30),
          isChecked: false,
        ),
      );
      await planner.saveEvent(
        Event(
          categoryId: category.id,
          title: 'Event to remove',
          date: DateTime(2026, 10, 10),
          start: const TimeOfDay(hour: 11, minute: 0),
          end: const TimeOfDay(hour: 12, minute: 0),
          isCurrent: false,
          allDay: false,
        ),
      );
    });
    await tester.pumpWidget(_app(planner));

    await _openCategoryDeleteDialog(tester, 'Remove all');
    expect(find.text('No other categories are available.'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Delete all'))
          .onPressed,
      isNull,
    );
    await tester.tap(find.text('Delete all items'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete all'));
    await tester.pumpAndSettle();
    await _waitForCategoryCount(tester, planner, 0);

    expect(planner.categories, isEmpty);
    expect(planner.items, isEmpty);
  });
}

void _expectTypography(TextStyle? actual, TextStyle expected) {
  expect(actual?.fontFamily, expected.fontFamily);
  expect(actual?.fontSize, expected.fontSize);
  expect(actual?.fontWeight, expected.fontWeight);
  expect(actual?.letterSpacing, expected.letterSpacing);
  expect(actual?.height, expected.height);
  expect(actual?.color, expected.color);
}

Future<void> _waitForCategoryCount(
  WidgetTester tester,
  PlannerState planner,
  int expectedCount,
) async {
  await tester.runAsync(() async {
    final timeout = DateTime.now().add(const Duration(seconds: 3));
    while (planner.categories.length != expectedCount &&
        DateTime.now().isBefore(timeout)) {
      await Future<void>.delayed(const Duration(milliseconds: 25));
    }
  });
  await tester.pumpAndSettle();
}

Future<void> _openCategoryDeleteDialog(
  WidgetTester tester,
  String title,
) async {
  await tester.drag(find.text(title), const Offset(-180, 0));
  await tester.pumpAndSettle();
  final swipe = find.byKey(ValueKey('category-swipe-$title'));
  final deleteButton = find.descendant(
    of: swipe,
    matching: find.byTooltip('Delete category'),
  );
  expect(deleteButton, findsOneWidget);
  await tester.tap(deleteButton);
  await tester.pumpAndSettle();
}

Widget _app(PlannerState planner) => ChangeNotifierProvider<PlannerState>.value(
  value: planner,
  child: MaterialApp(theme: appTheme, home: const TodoScreen()),
);
