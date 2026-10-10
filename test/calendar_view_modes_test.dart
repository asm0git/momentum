import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show SemanticsAction;
import 'package:flutter_test/flutter_test.dart';
import 'package:momentum/app_theme.dart';
import 'package:momentum/calendar_view_mode.dart';
import 'package:momentum/screens/calendar_screen.dart';
import 'package:momentum/services/calendar_view_preferences.dart';
import 'package:momentum/state/planner_state.dart';
import 'package:momentum/widgets/calendar.dart';
import 'package:momentum/widgets/calendar_resize_handle.dart';
import 'package:momentum/widgets/days.dart';
import 'package:momentum/widgets/week.dart';
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

      SharedPreferences.setMockInitialValues({'calendar_view_mode': 'unknown'});
      expect(await CalendarViewPreferences.load(), CalendarViewMode.fullMonth);
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
      mode: CalendarViewMode.fourWeeksWithoutIndicators,
      initialDate: DateTime(2025, 1, 15),
    );
    expect(find.byType(WeekWidget), findsNWidgets(4));

    await _pumpCalendar(
      tester,
      mode: CalendarViewMode.fullMonth,
      initialDate: DateTime(2025, 1, 15),
    );
    expect(find.byType(WeekWidget), findsNWidgets(5));
  });

  testWidgets('four-week view fades indicators while other views retain them', (
    tester,
  ) async {
    await _pumpCalendar(
      tester,
      mode: CalendarViewMode.oneWeek,
      initialDate: DateTime(2025, 1, 15),
    );
    expect(_indicatorOpacityFor(tester, DateTime(2025, 1, 15)), 1);

    await _pumpCalendar(
      tester,
      mode: CalendarViewMode.fourWeeksWithoutIndicators,
      initialDate: DateTime(2025, 1, 15),
    );
    expect(_indicatorOpacityFor(tester, DateTime(2025, 1, 15)), 0);
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
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _ResizableCalendarHarness(
        initialMode: CalendarViewMode.fullMonth,
        fullMonthWeekCount: 6,
      ),
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
      const Offset(0, -80),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 140));
    final intermediateHeight = tester.getSize(calendar).height;
    final intermediateTodoTop = tester.getTopLeft(todoSection).dy;
    await tester.pumpAndSettle();
    final finalHeight = tester.getSize(calendar).height;
    final finalTodoTop = tester.getTopLeft(todoSection).dy;

    expect(find.text('Four weeks without task indicators'), findsOneWidget);
    expect(intermediateHeight, lessThan(initialHeight));
    expect(intermediateHeight, greaterThan(finalHeight));
    expect(intermediateTodoTop, lessThan(initialTodoTop));
    expect(intermediateTodoTop, greaterThan(finalTodoTop));
    expect(finalHeight, lessThan(initialHeight));
    expect(finalTodoTop, lessThan(initialTodoTop));
    expect(find.byType(WeekWidget), findsNWidgets(4));
  });

  testWidgets('equal-height four-week and full-month modes switch by drag', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _ResizableCalendarHarness(
        initialMode: CalendarViewMode.fullMonth,
        fullMonthWeekCount: 4,
        initialDate: DateTime(2026, 2, 15),
      ),
    );
    final calendar = find.byKey(const ValueKey('animated-calendar'));
    final fullMonthHeight = tester.getSize(calendar).height;

    await tester.drag(
      find.byKey(const ValueKey('calendar-resize-handle')),
      const Offset(0, -24),
    );
    await tester.pumpAndSettle();
    expect(find.text('Four weeks without task indicators'), findsOneWidget);
    expect(tester.getSize(calendar).height, closeTo(fullMonthHeight, 0.1));

    await tester.drag(
      find.byKey(const ValueKey('calendar-resize-handle')),
      const Offset(0, 24),
    );
    await tester.pumpAndSettle();
    expect(find.text('Full month'), findsOneWidget);
    expect(tester.getSize(calendar).height, closeTo(fullMonthHeight, 0.1));
  });

  testWidgets('a long drag can skip intermediate modes', (tester) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _ResizableCalendarHarness(
        initialMode: CalendarViewMode.fullMonth,
        fullMonthWeekCount: 6,
      ),
    );

    await tester.drag(
      find.byKey(const ValueKey('calendar-resize-handle')),
      const Offset(0, -280),
    );
    await tester.pumpAndSettle();

    expect(find.text('Two weeks'), findsOneWidget);
    expect(find.byType(WeekWidget), findsNWidgets(2));
  });

  testWidgets('resize handle exposes its current value and size actions', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      _ResizableCalendarHarness(
        initialMode: CalendarViewMode.fullMonth,
        fullMonthWeekCount: 5,
      ),
    );

    final data = tester
        .getSemantics(
          find.byKey(const ValueKey('calendar-resize-handle-semantics')),
        )
        .getSemanticsData();
    expect(data.label, 'Calendar height');
    expect(data.value, 'Full month');
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

    final planner = PlannerState(autoSyncCanvasOnStartup: false);
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
    final planner = PlannerState(autoSyncCanvasOnStartup: false);
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
  final indicator = find.descendant(
    of: day,
    matching: find.byType(AnimatedOpacity),
  );
  return tester.widget<AnimatedOpacity>(indicator).opacity;
}

class _ResizableCalendarHarness extends StatefulWidget {
  _ResizableCalendarHarness({
    required this.initialMode,
    required this.fullMonthWeekCount,
    DateTime? initialDate,
  }) : initialDate = initialDate ?? DateTime(2025, 3, 15);

  final CalendarViewMode initialMode;
  final int fullMonthWeekCount;
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
                fullMonthWeekCount: widget.fullMonthWeekCount,
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
