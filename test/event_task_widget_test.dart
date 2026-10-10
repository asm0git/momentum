import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momentum/app_theme.dart';
import 'package:momentum/data_models.dart';
import 'package:momentum/widgets/task_list_container.dart';
import 'package:momentum/widgets/task_widget.dart';
import 'package:momentum/widgets/days.dart';

void main() {
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
}
