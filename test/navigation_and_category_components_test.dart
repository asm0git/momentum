import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momentum/app_theme.dart';
import 'package:momentum/data_models.dart';
import 'package:momentum/navigation_destinations.dart';
import 'package:momentum/widgets/navigation/primary_app_bar.dart';
import 'package:momentum/widgets/planner/add_task_button.dart';
import 'package:momentum/widgets/planner/collapsible_category.dart';
import 'package:momentum/widgets/planner/swipe_to_reveal_delete.dart';

void main() {
  testWidgets('primary app bar uses its destination and blur options', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme,
        home: Scaffold(
          appBar: PrimaryAppBar(
            destination: AppDestination.timer,
            isBlurred: true,
            automaticallyImplyLeading: false,
            actions: [
              IconButton(
                onPressed: () {},
                tooltip: 'History',
                icon: const Icon(Icons.history),
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Timer'), findsOneWidget);
    expect(find.byType(ImageFiltered), findsOneWidget);
    expect(find.byTooltip('History'), findsOneWidget);
    expect(
      tester.widget<PrimaryAppBar>(find.byType(PrimaryAppBar)).preferredSize,
      const Size.fromHeight(AppSpacing.appBarHeight),
    );
  });

  testWidgets('add task button invokes its action and reflects open state', (
    tester,
  ) async {
    final controller = AnimationController(
      vsync: tester,
      duration: const Duration(milliseconds: 100),
    );
    addTearDown(controller.dispose);
    var pressCount = 0;

    Widget buildButton(bool isOpen) => MaterialApp(
      theme: appTheme,
      home: Scaffold(
        body: Center(
          child: AddTaskButton(
            primary: AppColors.primary,
            controller: controller,
            isOpen: isOpen,
            onPressed: () => pressCount++,
          ),
        ),
      ),
    );

    await tester.pumpWidget(buildButton(false));
    expect(
      tester
          .widget<AnimatedContainer>(find.byType(AnimatedContainer))
          .decoration,
      isA<BoxDecoration>().having(
        (decoration) => decoration.color,
        'color',
        AppColors.primary,
      ),
    );
    await tester.tap(find.byTooltip('Add'));
    expect(pressCount, 1);

    controller.forward();
    await tester.pumpWidget(buildButton(true));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<AnimatedContainer>(find.byType(AnimatedContainer))
          .decoration,
      isA<BoxDecoration>().having(
        (decoration) => decoration.color,
        'color',
        AppColors.secondary,
      ),
    );
  });

  testWidgets(
    'category expands on tap and auto-expands when an event arrives',
    (tester) async {
      final task = Task(
        title: 'Read chapter',
        date: DateTime(2026, 10, 9),
        isChecked: false,
        time: const TimeOfDay(hour: 9, minute: 0),
        estimatedDuration: Duration.zero,
      );
      final event = Event(
        title: 'Study group',
        date: DateTime(2026, 10, 9),
        start: const TimeOfDay(hour: 10, minute: 0),
        end: const TimeOfDay(hour: 11, minute: 0),
        isCurrent: false,
        allDay: false,
      );
      const categoryKey = ValueKey('school-category');

      Widget buildCategory(List<PlannerItem> items, {VoidCallback? onDelete}) =>
          MaterialApp(
            theme: appTheme,
            home: Scaffold(
              body: CollapsibleCategory(
                key: categoryKey,
                title: 'School',
                pendingLabel: '1 pending',
                iconName: '',
                items: items,
                onDeleteCategory: onDelete,
              ),
            ),
          );

      await tester.pumpWidget(buildCategory([task]));
      expect(find.text(task.title), findsNothing);
      expect(find.text('1 pending'), findsOneWidget);
      await tester.tap(find.text('School'));
      await tester.pumpAndSettle();
      expect(find.text(task.title), findsOneWidget);
      await tester.tap(find.text('School'));
      await tester.pumpAndSettle();
      expect(find.text(task.title), findsNothing);

      await tester.pumpWidget(buildCategory([task, event], onDelete: () {}));
      await tester.pumpAndSettle();
      expect(find.text(event.title), findsOneWidget);
      expect(
        find.byKey(const ValueKey('category-swipe-School')),
        findsOneWidget,
      );
      expect(find.byType(SwipeToRevealDelete), findsNWidgets(3));
    },
  );
}
