import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show SemanticsAction;
import 'package:flutter_test/flutter_test.dart';
import 'package:momentum/app_theme.dart';
import 'package:momentum/calendar_view_mode.dart';
import 'package:momentum/data_models.dart';
import 'package:momentum/screens/calendar_screen.dart';
import 'package:momentum/services/calendar_view_preferences.dart';
import 'package:momentum/state/planner_state.dart';
import 'package:momentum/widgets/calendar/calendar.dart';
import 'package:momentum/widgets/calendar/calendar_resize_handle.dart';
import 'package:momentum/widgets/calendar/days.dart';
import 'package:momentum/widgets/calendar/week.dart';
import 'package:momentum/widgets/category_icon_picker.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'calendar view preference defaults safely and persists its mode',
    () async {
      expect(await CalendarViewPreferences.load(), CalendarViewMode.fullMonth);

      await CalendarViewPreferences.save(CalendarViewMode.twoWeeks);

      expect(await CalendarViewPreferences.load(), CalendarViewMode.twoWeeks);

      await CalendarViewPreferences.save(
        CalendarViewMode.oneWeekWithoutIndicators,
      );
      expect(
        await CalendarViewPreferences.load(),
        CalendarViewMode.oneWeekWithoutIndicators,
      );

      SharedPreferences.setMockInitialValues({'calendar_view_mode': 'unknown'});
      expect(await CalendarViewPreferences.load(), CalendarViewMode.fullMonth);

      SharedPreferences.setMockInitialValues({
        'calendar_view_mode': 'fourWeeksWithoutIndicators',
      });
      expect(
        await CalendarViewPreferences.load(),
        CalendarViewMode.fullMonthWithoutIndicators,
      );
    },
  );

  testWidgets('short views show consecutive weeks from the selected week', (
    tester,
  ) async {
    await _pumpCalendar(
      tester,
      mode: CalendarViewMode.oneWeek,
      initialDate: DateTime(2025, 1, 2),
    );

    expect(find.byType(WeekWidget), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is DayWidget && widget.date == DateTime(2024, 12, 29),
      ),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate(
        (widget) => widget is DayWidget && widget.date == DateTime(2025, 1, 4),
      ),
      findsOneWidget,
    );

    await _pumpCalendar(
      tester,
      mode: CalendarViewMode.twoWeeks,
      initialDate: DateTime(2025, 1, 30),
    );
    expect(find.byType(WeekWidget), findsNWidgets(2));
    expect(
      find.byWidgetPredicate(
        (widget) => widget is DayWidget && widget.date == DateTime(2025, 2, 2),
      ),
      findsOneWidget,
    );

    await _pumpCalendar(
      tester,
      mode: CalendarViewMode.fullMonthWithoutIndicators,
      initialDate: DateTime(2025, 1, 15),
    );
    expect(find.byType(WeekWidget), findsNWidgets(5));

    await _pumpCalendar(
      tester,
      mode: CalendarViewMode.fullMonth,
      initialDate: DateTime(2025, 1, 15),
    );
    expect(find.byType(WeekWidget), findsNWidgets(5));
  });

  testWidgets('compact one-week mode uses date-only row height', (
    tester,
  ) async {
    await _pumpCalendar(
      tester,
      mode: CalendarViewMode.oneWeekWithoutIndicators,
      initialDate: DateTime(2025, 1, 15),
    );

    expect(find.byType(WeekWidget), findsOneWidget);
    expect(
      tester.getSize(find.byType(WeekWidget).first).height,
      calendarDateOnlyWeekHeight,
    );
    expect(_indicatorOpacityFor(tester, DateTime(2025, 1, 15)), 0);
  });

  testWidgets('all six views show their expected rows and event bars', (
    tester,
  ) async {
    final date = DateTime(2025, 1, 15);
    const modes = [
      (CalendarViewMode.oneWeekWithoutIndicators, 1, 0.0),
      (CalendarViewMode.oneWeek, 1, 1.0),
      (CalendarViewMode.twoWeeksWithoutIndicators, 2, 0.0),
      (CalendarViewMode.twoWeeks, 2, 1.0),
      (CalendarViewMode.fullMonthWithoutIndicators, 5, 0.0),
      (CalendarViewMode.fullMonth, 5, 1.0),
    ];

    for (final (mode, weekCount, opacity) in modes) {
      await _pumpCalendar(tester, mode: mode, initialDate: date);
      expect(find.byType(WeekWidget), findsNWidgets(weekCount));
      expect(_indicatorOpacityFor(tester, date), opacity);
    }

    await _pumpCalendar(
      tester,
      mode: CalendarViewMode.fullMonthWithoutIndicators,
      initialDate: date,
    );
    expect(
      find.byWidgetPredicate(
        (widget) => widget is DayWidget && widget.date == DateTime(2025, 1, 31),
      ),
      findsOneWidget,
    );
  });

  testWidgets('six view heights stay ordered for four to six month rows', (
    tester,
  ) async {
    final months = [
      DateTime(2026, 2, 15), // Four rows.
      DateTime(2025, 1, 15), // Five rows.
      DateTime(2025, 3, 15), // Six rows.
    ];
    const largestToSmallest = [
      CalendarViewMode.fullMonth,
      CalendarViewMode.fullMonthWithoutIndicators,
      CalendarViewMode.twoWeeks,
      CalendarViewMode.twoWeeksWithoutIndicators,
      CalendarViewMode.oneWeek,
      CalendarViewMode.oneWeekWithoutIndicators,
    ];

    expect(calendarDateOnlyWeekHeight, 64);
    for (final month in months) {
      final heights = <double>[];
      for (final mode in largestToSmallest) {
        await _pumpCalendar(tester, mode: mode, initialDate: month);
        heights.add(tester.getSize(find.byType(CalendarWidget)).height);
      }
      for (var index = 0; index < heights.length - 1; index++) {
        expect(heights[index], greaterThan(heights[index + 1]));
      }
    }
  });

  testWidgets('compact date-picker calendar ignores the calendar view mode', (
    tester,
  ) async {
    await _pumpCalendar(
      tester,
      mode: CalendarViewMode.oneWeek,
      initialDate: DateTime(2025, 1, 15),
      compact: true,
    );

    expect(find.byType(WeekWidget), findsNWidgets(5));
    expect(find.byType(AnimatedOpacity), findsNothing);
  });

  testWidgets('drag snaps to a mode and animates the calendar height', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _ResizableCalendarHarness(initialMode: CalendarViewMode.fullMonth),
    );
    final calendar = find.byKey(const ValueKey('animated-calendar'));
    final todoSection = find.byKey(const ValueKey('todo-section'));
    final initialHeight = tester.getSize(calendar).height;
    final initialTodoTop = tester.getTopLeft(todoSection).dy;
    final animation = tester.widget<AnimatedSize>(calendar);
    expect(animation.duration, const Duration(milliseconds: 280));
    expect(animation.curve, Curves.easeInOutCubic);

    await tester.drag(
      find.byKey(const ValueKey('calendar-resize-handle')),
      const Offset(0, -calendarItemsWeekHeight),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 140));
    final intermediateHeight = tester.getSize(calendar).height;
    final intermediateTodoTop = tester.getTopLeft(todoSection).dy;
    await tester.pumpAndSettle();
    final finalHeight = tester.getSize(calendar).height;
    final finalTodoTop = tester.getTopLeft(todoSection).dy;

    expect(find.text('Full month without event bars'), findsOneWidget);
    expect(intermediateHeight, lessThan(initialHeight));
    expect(intermediateHeight, greaterThan(finalHeight));
    expect(intermediateTodoTop, lessThan(initialTodoTop));
    expect(intermediateTodoTop, greaterThan(finalTodoTop));
    expect(finalHeight, lessThan(initialHeight));
    expect(finalTodoTop, lessThan(initialTodoTop));
    expect(find.byType(WeekWidget), findsNWidgets(6));
  });

  testWidgets('minimum one-week mode expands to a week with bars', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _ResizableCalendarHarness(initialMode: CalendarViewMode.oneWeek),
    );
    final calendar = find.byKey(const ValueKey('animated-calendar'));
    final regularHeight = tester.getSize(calendar).height;

    await tester.drag(
      find.byKey(const ValueKey('calendar-resize-handle')),
      const Offset(0, -100),
    );
    await tester.pumpAndSettle();
    expect(find.text('Current week without event bars'), findsOneWidget);
    final compactHeight = tester.getSize(calendar).height;
    expect(compactHeight, lessThan(regularHeight));
    expect(
      tester.getSize(find.byType(WeekWidget).first).height,
      calendarDateOnlyWeekHeight,
    );

    await tester.drag(
      find.byKey(const ValueKey('calendar-resize-handle')),
      const Offset(0, 100),
    );
    await tester.pumpAndSettle();
    expect(find.text('Current week with event bars'), findsOneWidget);
    expect(tester.getSize(calendar).height, greaterThan(compactHeight));
  });

  testWidgets('whole-month modes retain all rows when bars are hidden', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _ResizableCalendarHarness(
        initialMode: CalendarViewMode.fullMonth,
        initialDate: DateTime(2026, 2, 15),
      ),
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey('calendar-resize-handle')),
    );
    await tester.pumpAndSettle();
    final calendar = find.byKey(const ValueKey('animated-calendar'));
    final fullMonthHeight = tester.getSize(calendar).height;

    await tester.drag(
      find.byKey(const ValueKey('calendar-resize-handle')),
      const Offset(0, -48),
    );
    await tester.pumpAndSettle();
    expect(find.text('Full month without event bars'), findsOneWidget);
    expect(find.byType(WeekWidget), findsNWidgets(4));
    expect(tester.getSize(calendar).height, lessThan(fullMonthHeight));

    await tester.drag(
      find.byKey(const ValueKey('calendar-resize-handle')),
      const Offset(0, 48),
    );
    await tester.pumpAndSettle();
    expect(find.text('Full month with event bars'), findsOneWidget);
    expect(tester.getSize(calendar).height, closeTo(fullMonthHeight, 0.1));
  });

  testWidgets('any vertical movement changes one adjacent view', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _ResizableCalendarHarness(initialMode: CalendarViewMode.twoWeeks),
    );
    final resizeHandle = find.byKey(const ValueKey('calendar-resize-handle'));
    await tester.tap(resizeHandle);
    await tester.pumpAndSettle();
    expect(find.text('Two weeks with event bars'), findsOneWidget);

    await tester.drag(resizeHandle, const Offset(0, -1));
    await tester.pumpAndSettle();
    expect(find.text('Two weeks without event bars'), findsOneWidget);

    await tester.drag(resizeHandle, const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(find.text('Current week with event bars'), findsOneWidget);
    expect(find.byType(WeekWidget), findsOneWidget);

    await tester.drag(resizeHandle, const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(find.text('Current week without event bars'), findsOneWidget);

    await tester.drag(resizeHandle, const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(find.text('Current week without event bars'), findsOneWidget);

    for (final expectedMode in [
      'Current week with event bars',
      'Two weeks without event bars',
      'Two weeks with event bars',
      'Full month without event bars',
      'Full month with event bars',
      'Full month with event bars',
    ]) {
      await tester.drag(resizeHandle, const Offset(0, 300));
      await tester.pumpAndSettle();
      expect(find.text(expectedMode), findsOneWidget);
    }
  });

  testWidgets('resize handle exposes its current value and size actions', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      _ResizableCalendarHarness(initialMode: CalendarViewMode.fullMonth),
    );

    final data = tester
        .getSemantics(
          find.byKey(const ValueKey('calendar-resize-handle-semantics')),
        )
        .getSemanticsData();
    expect(data.label, 'Calendar height');
    expect(data.value, 'Full month with event bars');
    expect(data.hasAction(SemanticsAction.decrease), isTrue);
    expect(data.hasAction(SemanticsAction.increase), isFalse);
    semantics.dispose();
  });

  testWidgets('calendar screen fits an iPhone 13-sized viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final planner = PlannerState(autoSyncCalendarsOnStartup: false);
    addTearDown(planner.dispose);

    await tester.pumpWidget(
      ChangeNotifierProvider<PlannerState>.value(
        value: planner,
        child: MaterialApp(theme: appTheme, home: const CalendarScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('calendar-resize-handle')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);

    await tester.ensureVisible(
      find.byKey(const ValueKey('calendar-resize-handle')),
    );
    await tester.pumpAndSettle();
    await tester.drag(
      find.byKey(const ValueKey('calendar-resize-handle')),
      const Offset(0, -80),
    );
    await tester.pumpAndSettle();
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getString('calendar_view_mode'), isNot('fullMonth'));
  });

  testWidgets('calendar screen restores the saved view mode', (tester) async {
    SharedPreferences.setMockInitialValues({'calendar_view_mode': 'twoWeeks'});
    final planner = PlannerState(autoSyncCalendarsOnStartup: false);
    addTearDown(planner.dispose);

    await tester.pumpWidget(
      ChangeNotifierProvider<PlannerState>.value(
        value: planner,
        child: MaterialApp(theme: appTheme, home: const CalendarScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(WeekWidget), findsNWidgets(2));
  });

  testWidgets('agenda resolves category icons by id and handles missing ones', (
    tester,
  ) async {
    final today = DateUtils.dateOnly(DateTime.now());
    final matchingTask = Task(
      id: 1,
      categoryId: 7,
      title: 'Categorized agenda task',
      date: today,
      time: const TimeOfDay(hour: 10, minute: 0),
      estimatedDuration: const Duration(minutes: 25),
      isChecked: false,
    );
    final uncategorizedTask = Task(
      id: 2,
      categoryId: 99,
      title: 'Missing category agenda task',
      date: today,
      time: const TimeOfDay(hour: 11, minute: 0),
      estimatedDuration: const Duration(minutes: 25),
      isChecked: false,
    );
    final planner = _CalendarPlannerState(
      categories: [
        TaskCategory(
          id: 7,
          title: 'Study',
          iconName: 'mi_school',
          items: [matchingTask],
        ),
      ],
      items: [matchingTask, uncategorizedTask],
    );
    addTearDown(planner.dispose);

    await tester.pumpWidget(
      ChangeNotifierProvider<PlannerState>.value(
        value: planner,
        child: MaterialApp(theme: appTheme, home: const CalendarScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Categorized agenda task'), findsWidgets);
    expect(find.text('Missing category agenda task'), findsWidgets);
    final icons = tester.widgetList<CategoryIcon>(find.byType(CategoryIcon));
    expect(icons, hasLength(1));
    expect(icons.single.iconName, 'mi_school');
  });
}

class _CalendarPlannerState extends PlannerState {
  _CalendarPlannerState({
    required List<TaskCategory> categories,
    required List<PlannerItem> items,
  }) : _categories = categories,
       _items = items,
       super(
         autoSyncCalendarsOnStartup: false,
         startAutomaticEventFocusTimer: false,
       );

  final List<TaskCategory> _categories;
  final List<PlannerItem> _items;

  @override
  List<TaskCategory> get categories => _categories;

  @override
  List<PlannerItem> get items => _items;

  @override
  List<PlannerItem> itemsForDate(DateTime date) => _items
      .where(
        (item) =>
            item.date.year == date.year &&
            item.date.month == date.month &&
            item.date.day == date.day,
      )
      .toList();
}

Future<void> _pumpCalendar(
  WidgetTester tester, {
  required CalendarViewMode mode,
  required DateTime initialDate,
  bool compact = false,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: appTheme,
      home: Scaffold(
        body: SingleChildScrollView(
          child: CalendarWidget(
            key: ValueKey('$mode-$initialDate-$compact'),
            initialDate: initialDate,
            viewMode: mode,
            compact: compact,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

double _indicatorOpacityFor(WidgetTester tester, DateTime date) {
  final day = find.byWidgetPredicate(
    (widget) => widget is DayWidget && widget.date == date,
  );
  final week = find.ancestor(of: day, matching: find.byType(WeekWidget));
  final indicator = find.descendant(
    of: week,
    matching: find.byKey(const ValueKey('calendar-week-items-opacity')),
  );
  return tester.widget<AnimatedOpacity>(indicator).opacity;
}

class _ResizableCalendarHarness extends StatefulWidget {
  _ResizableCalendarHarness({required this.initialMode, DateTime? initialDate})
    : initialDate = initialDate ?? DateTime(2025, 3, 15);

  final CalendarViewMode initialMode;
  final DateTime initialDate;

  @override
  State<_ResizableCalendarHarness> createState() =>
      _ResizableCalendarHarnessState();
}

class _ResizableCalendarHarnessState extends State<_ResizableCalendarHarness> {
  late CalendarViewMode _mode = widget.initialMode;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: appTheme,
      home: Scaffold(
        body: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AnimatedSize(
                key: const ValueKey('animated-calendar'),
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeInOutCubic,
                alignment: Alignment.topCenter,
                clipBehavior: Clip.hardEdge,
                child: CalendarWidget(
                  initialDate: widget.initialDate,
                  viewMode: _mode,
                ),
              ),
              CalendarResizeHandle(
                mode: _mode,
                onModeChanged: (mode) => setState(() => _mode = mode),
              ),
              Text(_mode.label, key: const ValueKey('todo-section')),
            ],
          ),
        ),
      ),
    );
  }
}
