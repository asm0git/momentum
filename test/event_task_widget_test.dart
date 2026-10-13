import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momentum/app_theme.dart';
import 'package:momentum/data/database_helper.dart';
import 'package:momentum/data/planner_repository.dart';
import 'package:momentum/data_models.dart';
import 'package:momentum/state/planner_state.dart';
import 'package:momentum/widgets/item_editor/add_item_popup.dart';
import 'package:momentum/widgets/planner/task_list_container.dart';
import 'package:momentum/widgets/planner/task_widget.dart';
import 'package:momentum/widgets/calendar/days.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Directory tempDirectory;
  late DatabaseHelper databaseHelper;
  late _TestPlannerRepository repository;
  late PlannerState planner;

  setUpAll(() => sqfliteFfiInit());

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp('momentum_item_ui_');
    databaseHelper = DatabaseHelper.forTesting(
      factory: databaseFactoryFfi,
      databasePath: '${tempDirectory.path}/planner.db',
      seedOnCreate: false,
    );
    repository = _TestPlannerRepository(databaseHelper: databaseHelper);
    planner = PlannerState(repository: repository);
    await planner.initialize();
  });

  tearDown(() async {
    planner.dispose();
    await databaseHelper.close();
    await tempDirectory.delete(recursive: true);
  });

  testWidgets('weekend calendar dates use the same normal text color', (
    tester,
  ) async {
    final now = DateTime.now();
    final firstOfNextMonth = DateTime(now.year, now.month + 1, 1);
    final daysUntilSaturday =
        (DateTime.saturday - firstOfNextMonth.weekday + 7) % 7;
    final saturday = firstOfNextMonth.add(Duration(days: daysUntilSaturday));
    final sunday = saturday.add(const Duration(days: 1));

    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme,
        home: Scaffold(
          body: SizedBox(
            height: 100,
            child: Row(
              children: [
                Expanded(
                  child: DayWidget(
                    date: saturday,
                    isSelected: false,
                    minimumDate: firstOfNextMonth,
                  ),
                ),
                Expanded(
                  child: DayWidget(
                    date: sunday,
                    isSelected: false,
                    minimumDate: firstOfNextMonth,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    expect(
      tester.widget<Text>(find.text('${saturday.day}')).style?.color,
      AppColors.onSurface,
    );
    expect(
      tester.widget<Text>(find.text('${sunday.day}')).style?.color,
      AppColors.onSurface,
    );
  });

  testWidgets('No tasks appears only when the list contains no task', (
    tester,
  ) async {
    final completedTask = Task(
      title: 'Already complete',
      date: DateTime.now(),
      isChecked: true,
      time: const TimeOfDay(hour: 9, minute: 0),
      estimatedDuration: Duration.zero,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme,
        home: Scaffold(body: TaskListContainer(items: [completedTask])),
      ),
    );
    expect(find.text('No tasks.'), findsNothing);

    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme,
        home: const Scaffold(body: TaskListContainer(items: [])),
      ),
    );
    expect(find.text('No tasks.'), findsOneWidget);
  });

  testWidgets('event-only list suppresses the No tasks state', (tester) async {
    final event = Event(
      title: 'Event without tasks',
      date: DateTime.now(),
      start: const TimeOfDay(hour: 10, minute: 0),
      end: const TimeOfDay(hour: 11, minute: 0),
      isCurrent: false,
      allDay: false,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme,
        home: Scaffold(body: TaskListContainer(items: [event])),
      ),
    );

    expect(find.text('Event without tasks'), findsOneWidget);
    expect(find.text('No tasks.'), findsNothing);
  });

  testWidgets('task rows in a task list stay compact', (tester) async {
    final task = Task(
      title: 'A task title long enough to wrap without the row limit',
      date: DateTime.now(),
      isChecked: false,
      time: const TimeOfDay(hour: 9, minute: 0),
      estimatedDuration: const Duration(minutes: 30),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme,
        home: Scaffold(
          body: TaskListContainer(items: [task], onDelete: (_) {}),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final rowHeight = tester.getSize(find.byType(TaskWidget)).height;
    expect(rowHeight, lessThanOrEqualTo(40));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'combined agenda keeps every item and its category after sorting',
    (tester) async {
      final today = DateTime.now();
      final items = List.generate(
        5,
        (index) => Task(
          title: 'Agenda task $index',
          date: today,
          isChecked: false,
          time: TimeOfDay(hour: 14 - index, minute: 0),
          estimatedDuration: const Duration(minutes: 30),
        ),
      );
      final icons = {
        for (var index = 0; index < items.length; index++)
          items[index]: index.isEven ? 'work' : 'personal',
      };
      Task? checkedTask;
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme,
          home: Scaffold(
            body: TaskListContainer(
              items: items,
              categoryIconForItem: (item) => icons[item],
              maxVisibleItems: null,
              appearanceType: TaskAppearanceType.checkable,
              onChecked: (task, value) => checkedTask = task,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final rows = tester
          .widgetList<TaskWidget>(find.byType(TaskWidget))
          .toList();
      expect(rows, hasLength(5));
      expect(rows.map((row) => row.task), orderedEquals(items.reversed));
      for (final row in rows) {
        expect(row.categoryIconName, icons[row.task]);
      }
      await tester.tap(find.byType(Checkbox).first);
      expect(checkedTask, same(items.last));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'mixed list shows an all-day event icon and keeps tasks checkable',
    (tester) async {
      final today = DateTime.now();
      final task = Task(
        title: 'Prepare notes',
        date: today,
        isChecked: false,
        time: const TimeOfDay(hour: 9, minute: 0),
        estimatedDuration: const Duration(minutes: 30),
      );
      final event = Event(
        title: 'All-day appointment',
        date: today,
        start: const TimeOfDay(hour: 0, minute: 0),
        end: const TimeOfDay(hour: 0, minute: 0),
        isCurrent: false,
        allDay: true,
      );
      Task? checkedTask;
      bool? checkedValue;

      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme,
          home: Scaffold(
            body: TaskListContainer(
              items: [task, event],
              categoryIconName: 'personal',
              appearanceType: TaskAppearanceType.checkable,
              onChecked: (task, value) {
                checkedTask = task;
                checkedValue = value;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(Checkbox), findsOneWidget);
      expect(find.text('Today, All day'), findsOneWidget);
      final eventRow = find.byWidgetPredicate(
        (widget) => widget is TaskWidget && widget.event == event,
      );
      final title = tester.widget<Text>(find.text(event.title));
      expect(title.style?.color, AppColors.secondary);
      final images = tester.widgetList<Image>(
        find.descendant(of: eventRow, matching: find.byType(Image)),
      );
      expect(images, hasLength(2));
      for (final image in images) {
        expect(image.color, title.style?.color);
        expect(image.colorBlendMode, BlendMode.srcIn);
      }
      expect(tester.takeException(), isNull);

      await tester.tap(find.byType(Checkbox));
      expect(checkedTask, same(task));
      expect(checkedValue, isTrue);
    },
  );

  testWidgets(
    'timed event shows its time range with matching normal icon color',
    (tester) async {
      final event = Event(
        title: 'Meeting',
        date: DateTime.now(),
        start: const TimeOfDay(hour: 9, minute: 0),
        end: const TimeOfDay(hour: 10, minute: 0),
        isCurrent: false,
        allDay: false,
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme,
          home: Scaffold(body: TaskWidget.event(event: event)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(Checkbox), findsNothing);
      expect(find.text('Today, 9:00 AM - 10:00 AM'), findsOneWidget);
      expect(
        tester.widget<Text>(find.text('Meeting')).style?.color,
        AppColors.onSurface,
      );
      final icon = tester.widget<Image>(find.byType(Image));
      expect(
        (icon.image as AssetImage).assetName,
        'assets/img/categories/all-day.png',
      );
      expect(icon.color, AppColors.onSurface);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('editing a recurring task preserves its schedule and metadata', (
    tester,
  ) async {
    _setItemEditorViewport(tester);
    final category = (await tester.runAsync(
      () => planner.addCategory(
        TaskCategory(title: 'Study', iconName: 'mi_school', items: []),
      ),
    ))!;
    final repeatUntil = DateTime(2026, 11, 10);
    final original = (await tester.runAsync(
      () => planner.saveTask(
        Task(
          categoryId: category.id,
          title: 'Review notes',
          date: DateTime(2026, 10, 20),
          time: const TimeOfDay(hour: 15, minute: 30),
          estimatedDuration: const Duration(minutes: 45),
          isChecked: true,
          repeat: RecurrenceRule.weekly,
          repeatUntil: repeatUntil,
          description: 'Before edit',
          priority: 2,
          sourcePlatform: 'canvas',
          externalId: 'assignment-17',
        ),
      ),
    ))!;
    PlannerItem? saved;

    await tester.pumpWidget(
      _itemEditorApp(
        planner,
        AddItemPopup(initialItem: original, onSaved: (item) => saved = item),
      ),
    );
    final recurrenceDropdown = find.byWidgetPredicate(
      (widget) => widget is DropdownButton<RecurrenceRule?>,
    );
    expect(recurrenceDropdown, findsOneWidget);
    await tester.tap(recurrenceDropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Every week').last);
    await tester.pumpAndSettle();
    final fields = find.byType(TextField);
    await tester.enterText(fields.first, 'Review chapter');
    await tester.enterText(fields.last, 'Updated notes');
    await tester.ensureVisible(find.text('Save changes'));
    await tester.tap(find.text('Save changes'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();

    expect(saved, isA<Task>());
    final task = saved! as Task;
    expect(task.id, original.id);
    expect(task.categoryId, category.id);
    expect(task.title, 'Review chapter');
    expect(task.date, DateTime(2026, 10, 20));
    expect(task.time, const TimeOfDay(hour: 15, minute: 30));
    expect(task.estimatedDuration, const Duration(minutes: 45));
    expect(task.repeat, RecurrenceRule.weekly);
    expect(task.repeatUntil, repeatUntil);
    expect(task.isChecked, isTrue);
    expect(task.description, 'Updated notes');
    expect(task.priority, 2);
    expect(task.sourcePlatform, 'canvas');
    expect(task.externalId, 'assignment-17');
    expect(tester.takeException(), isNull);
  });

  testWidgets('editing a recurring event preserves its schedule and metadata', (
    tester,
  ) async {
    _setItemEditorViewport(tester);
    final category = (await tester.runAsync(
      () => planner.addCategory(
        TaskCategory(title: 'Work', iconName: 'mi_work', items: []),
      ),
    ))!;
    final repeatUntil = DateTime(2026, 12, 1);
    final original = (await tester.runAsync(
      () => planner.saveEvent(
        Event(
          categoryId: category.id,
          title: 'Project review',
          date: DateTime(2026, 10, 20),
          start: const TimeOfDay(hour: 14, minute: 30),
          endDate: DateTime(2026, 10, 21),
          end: const TimeOfDay(hour: 1, minute: 0),
          isCurrent: true,
          allDay: false,
          location: 'Room 4',
          notes: 'Before edit',
          repeat: RecurrenceRule.monthly,
          repeatUntil: repeatUntil,
          sourcePlatform: 'outlook',
          externalId: 'event-42',
        ),
      ),
    ))!;
    PlannerItem? saved;

    await tester.pumpWidget(
      _itemEditorApp(
        planner,
        AddItemPopup(initialItem: original, onSaved: (item) => saved = item),
      ),
    );
    final fields = find.byType(TextField);
    await tester.enterText(fields.first, 'Updated project review');
    await tester.enterText(fields.last, 'Updated event notes');
    await tester.ensureVisible(find.text('Save changes'));
    await tester.tap(find.text('Save changes'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();

    expect(saved, isA<Event>());
    final event = saved! as Event;
    expect(event.id, original.id);
    expect(event.categoryId, category.id);
    expect(event.title, 'Updated project review');
    expect(event.date, DateTime(2026, 10, 20));
    expect(event.start, const TimeOfDay(hour: 14, minute: 30));
    expect(event.endDate, DateTime(2026, 10, 21));
    expect(event.end, const TimeOfDay(hour: 1, minute: 0));
    expect(event.isCurrent, isTrue);
    expect(event.allDay, isFalse);
    expect(event.location, 'Room 4');
    expect(event.notes, 'Updated event notes');
    expect(event.repeat, RecurrenceRule.monthly);
    expect(event.repeatUntil, repeatUntil);
    expect(event.sourcePlatform, 'outlook');
    expect(event.externalId, 'event-42');
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed item save keeps the draft and offers a retry', (
    tester,
  ) async {
    _setItemEditorViewport(tester);
    final category = (await tester.runAsync(
      () => planner.addCategory(
        TaskCategory(title: 'Work', iconName: 'mi_work', items: []),
      ),
    ))!;
    final original = (await tester.runAsync(
      () => planner.saveTask(
        Task(
          categoryId: category.id,
          title: 'Original task',
          date: DateTime(2026, 10, 20),
          time: const TimeOfDay(hour: 15, minute: 30),
          estimatedDuration: const Duration(minutes: 25),
          isChecked: false,
        ),
      ),
    ))!;
    repository.nextTaskUpdateError = StateError(
      'The task was not updated in local storage.',
    );

    await tester.pumpWidget(
      _itemEditorApp(planner, AddItemPopup(initialItem: original)),
    );
    final fields = find.byType(TextField);
    await tester.enterText(fields.first, 'Updated task title');
    await tester.enterText(fields.last, 'Keep these notes');
    await tester.ensureVisible(find.text('Save changes'));
    await tester.tap(find.text('Save changes'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('This item may have changed. Refresh and try again.'),
      findsOneWidget,
    );
    expect(
      tester.widget<TextField>(fields.first).controller!.text,
      'Updated task title',
    );
    expect(
      tester.widget<TextField>(fields.last).controller!.text,
      'Keep these notes',
    );
    expect(tester.takeException(), isNull);
  });
}

class _TestPlannerRepository extends PlannerRepository {
  _TestPlannerRepository({required super.databaseHelper});

  Object? nextTaskUpdateError;

  @override
  Future<bool> updateTask(Task task) async {
    final error = nextTaskUpdateError;
    nextTaskUpdateError = null;
    if (error != null) throw error;
    return super.updateTask(task);
  }
}

void _setItemEditorViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(900, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Widget _itemEditorApp(PlannerState planner, Widget editor) =>
    ChangeNotifierProvider<PlannerState>.value(
      value: planner,
      child: MaterialApp(
        theme: appTheme,
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: editor,
          ),
        ),
      ),
    );
