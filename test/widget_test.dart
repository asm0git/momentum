import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momentum/app_theme.dart';
import 'package:momentum/data/database_helper.dart';
import 'package:momentum/data/planner_repository.dart';
import 'package:momentum/data_models.dart';
import 'package:momentum/screens/dashboard_screen.dart';
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
    tempDirectory = await Directory.systemTemp.createTemp('momentum_widget_');
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

  testWidgets('shared changes rebuild Dashboard, Calendar, and To-Do views', (
    tester,
  ) async {
    await tester.pumpWidget(_app(planner, const _ReactivePlannerViews()));

    final category = (await tester.runAsync(
      () => planner.addCategory(
        TaskCategory(title: 'School', iconName: 'school', items: []),
      ),
    ))!;
    await tester.pump();
    final task = (await tester.runAsync(
      () => planner.saveTask(
        Task(
          categoryId: category.id,
          title: 'Draft outline',
          date: DateTime.now(),
          time: const TimeOfDay(hour: 15, minute: 0),
          estimatedDuration: const Duration(minutes: 30),
          isChecked: false,
          description: 'First pass',
        ),
      ),
    ))!;
    await tester.pump();
    expect(find.text('Dashboard: Draft outline'), findsOneWidget);
    expect(find.text('Calendar: Draft outline'), findsOneWidget);
    expect(find.text('To-Do: Draft outline'), findsOneWidget);

    task.title = 'Revise outline';
    task.description = 'Second pass';
    await tester.runAsync(() => planner.saveTask(task));
    await tester.pump();
    expect(find.text('Draft outline'), findsNothing);
    expect(find.text('Dashboard: Revise outline'), findsOneWidget);
    expect(find.text('Calendar: Revise outline'), findsOneWidget);
    expect(find.text('To-Do: Revise outline'), findsOneWidget);

    final destination = (await tester.runAsync(
      () => planner.addCategory(
        TaskCategory(title: 'Personal', iconName: 'personal', items: []),
      ),
    ))!;
    task.categoryId = destination.id;
    final movedTask = (await tester.runAsync(() => planner.saveTask(task)))!;
    await tester.pump();
    expect(movedTask.categoryId, destination.id);
    expect(
      planner.categories
          .firstWhere((item) => item.id == category.id)
          .pendingCount,
      0,
    );
    expect(
      planner.categories
          .firstWhere((item) => item.id == destination.id)
          .pendingCount,
      1,
    );
    expect(planner.items.whereType<Task>().single.categoryId, destination.id);

    await tester.runAsync(() => planner.setTaskCompleted(task, true));
    await tester.pump();
    expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isTrue);

    await tester.runAsync(() => planner.deleteItem(task));
    await tester.pump();
    expect(find.text('Dashboard: Revise outline'), findsNothing);
    expect(find.text('Calendar: Revise outline'), findsNothing);
    expect(find.text('To-Do: Revise outline'), findsNothing);
  });

  testWidgets('event-only categories count and preview their event', (
    tester,
  ) async {
    await tester.pumpWidget(_app(planner, const _ReactivePlannerViews()));
    final category = await tester.runAsync(
      () => planner.addCategory(
        TaskCategory(title: 'Events', iconName: 'event', items: []),
      ),
    );
    final event = await tester.runAsync(() {
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      return planner.saveEvent(
        Event(
          categoryId: category!.id,
          title: 'Conference',
          date: DateTime(tomorrow.year, tomorrow.month, tomorrow.day),
          start: const TimeOfDay(hour: 10, minute: 0),
          end: const TimeOfDay(hour: 11, minute: 0),
          isCurrent: false,
          allDay: false,
        ),
      );
    });
    final savedEvent = event!;
    await tester.pump();

    expect(
      planner.categories
          .singleWhere((item) => item.id == category!.id)
          .pendingCount,
      1,
    );
    expect(planner.itemsForCategory(category!.id!).single, isA<Event>());
    expect(
      planner.nextUpcomingItemForCategory(category.id!, DateTime.now()),
      isA<Event>().having((item) => item.title, 'title', savedEvent.title),
    );
    expect(
      planner.nextUpcomingItem,
      isA<Event>().having((item) => item.title, 'title', savedEvent.title),
    );
  });

  testWidgets('To-Do shows stored categories and expands the selected one', (
    tester,
  ) async {
    final category = await tester.runAsync(
      () => planner.addCategory(
        TaskCategory(title: 'Selected category', iconName: 'school', items: []),
      ),
    );
    await tester.runAsync(() {
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      return planner.saveTask(
        Task(
          categoryId: category!.id,
          title: 'Visible task',
          date: DateTime(tomorrow.year, tomorrow.month, tomorrow.day),
          time: const TimeOfDay(hour: 9, minute: 0),
          estimatedDuration: const Duration(minutes: 30),
          isChecked: false,
        ),
      );
    });

    await tester.pumpWidget(
      _app(planner, TodoScreen(initialCategoryId: category!.id)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Selected category'), findsOneWidget);
    expect(find.text('Visible task'), findsOneWidget);
    expect(find.text('1 pending'), findsOneWidget);
    expect(find.text('None'), findsNothing);

    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();

    expect(planner.items.whereType<Task>().single.isChecked, isTrue);
    expect(find.text('0 pending'), findsOneWidget);
  });

  testWidgets('dashboard category preview opens To-Do and completes a task', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final category = (await tester.runAsync(
      () => planner.addCategory(
        TaskCategory(title: 'Tomorrow', iconName: 'personal', items: []),
      ),
    ))!;
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    await tester.runAsync(
      () => planner.saveTask(
        Task(
          categoryId: category.id,
          title: 'Prepare presentation',
          date: DateTime(tomorrow.year, tomorrow.month, tomorrow.day),
          time: const TimeOfDay(hour: 9, minute: 0),
          estimatedDuration: const Duration(minutes: 30),
          isChecked: false,
        ),
      ),
    );

    await tester.pumpWidget(
      _app(
        planner,
        const DashboardScreen(),
        routes: {
          '/todo': (_) => TodoScreen(initialCategoryId: category.id),
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Up next:'), findsOneWidget);
    expect(find.text('Prepare presentation'), findsWidgets);
    await tester.ensureVisible(
      find.byKey(const ValueKey('dashboard-category-Tomorrow')),
    );
    await tester.tap(find.byKey(const ValueKey('dashboard-category-Tomorrow')));
    await tester.pumpAndSettle();

    expect(find.byType(TodoScreen), findsOneWidget);
    expect(find.text('Prepare presentation'), findsOneWidget);
    expect(find.text('1 pending'), findsOneWidget);
    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();

    expect(planner.items.whereType<Task>().single.isChecked, isTrue);
    expect(find.text('0 pending'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Widget _app(
  PlannerState planner,
  Widget child, {
  Map<String, WidgetBuilder> routes = const {},
}) =>
    ChangeNotifierProvider<PlannerState>.value(
      value: planner,
      child: MaterialApp(theme: appTheme, home: child, routes: routes),
    );

class _ReactivePlannerViews extends StatelessWidget {
  const _ReactivePlannerViews();

  @override
  Widget build(BuildContext context) {
    final planner = context.watch<PlannerState>();
    final task = planner.items.whereType<Task>().firstOrNull;
    final title = task?.title ?? 'No tasks';

    return Scaffold(
      body: Column(
        children: [
          Text('Dashboard: $title'),
          Text('Calendar: $title'),
          Text('To-Do: $title'),
          if (task != null)
            Checkbox(
              value: task.isChecked,
              onChanged: (value) {
                if (value != null) {
                  context.read<PlannerState>().setTaskCompleted(task, value);
                }
              },
            ),
        ],
      ),
    );
  }
}
