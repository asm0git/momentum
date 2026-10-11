import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momentum/app_theme.dart';
import 'package:momentum/calendar_view_mode.dart';
import 'package:momentum/data_models.dart';
import 'package:momentum/widgets/calendar.dart';
import 'package:momentum/widgets/week.dart';

void main() {
  testWidgets('calendar shows three chronological bars then overflow', (
    tester,
  ) async {
    final day = DateTime(2025, 1, 6);
    final items = <PlannerItem>[
      _task('Afternoon task', day, const TimeOfDay(hour: 14, minute: 0)),
      _event('Morning event', day, const TimeOfDay(hour: 10, minute: 0)),
      _task('Morning task', day, const TimeOfDay(hour: 9, minute: 0)),
      _event(
        'All-day event',
        day,
        const TimeOfDay(hour: 0, minute: 0),
        allDay: true,
      ),
    ];

    await _pumpWeeks(tester, [items], [DateTime(2025, 1, 5)]);

    final orderedItems = [items[3], items[2], items[1]];
    final tops = [
      for (final item in orderedItems) tester.getTopLeft(_barFor(item)).dy,
    ];
    expect(tops, orderedEquals(tops.toList()..sort()));
    expect(tops.toSet(), hasLength(3));
    expect(find.text('All-day event'), findsOneWidget);
    expect(find.text('Morning task'), findsOneWidget);
    expect(find.text('Morning event'), findsOneWidget);
    expect(find.text('Afternoon task'), findsNothing);
    expect(find.text('+1 more'), findsOneWidget);
  });

  testWidgets('multi-day events continue across week rows', (tester) async {
    final event = Event(
      title: 'Conference week',
      date: DateTime(2025, 1, 10),
      endDate: DateTime(2025, 1, 14),
      start: const TimeOfDay(hour: 9, minute: 0),
      end: const TimeOfDay(hour: 17, minute: 0),
      isCurrent: false,
      allDay: false,
    );
    await _pumpWeeks(
      tester,
      [
        [event],
        [event],
      ],
      [DateTime(2025, 1, 5), DateTime(2025, 1, 12)],
    );

    final segments = _barsFor(event);
    expect(segments, findsNWidgets(2));
    final firstWeek = tester.getRect(segments.first);
    final secondWeek = tester.getRect(segments.last);
    expect(firstWeek.width, closeTo(196, 0.1));
    expect(firstWeek.left, closeTo(502, 0.1));
    expect(secondWeek.width, closeTo(296, 0.1));
    expect(secondWeek.left, closeTo(2, 0.1));
  });

  testWidgets('recurring multi-day events repeat with their full span', (
    tester,
  ) async {
    final event = Event(
      title: 'Weekly span',
      date: DateTime(2025, 1, 2),
      endDate: DateTime(2025, 1, 4),
      start: const TimeOfDay(hour: 9, minute: 0),
      end: const TimeOfDay(hour: 17, minute: 0),
      isCurrent: false,
      allDay: true,
      repeat: 'Every week',
    );

    await _pumpWeeks(
      tester,
      [
        [event],
        [event],
      ],
      [DateTime(2025, 1, 5), DateTime(2025, 1, 12)],
    );

    expect(find.text('Weekly span'), findsNWidgets(2));
    final segments = find.byWidgetPredicate(
      (widget) =>
          widget is Container &&
          widget.key is ValueKey<String> &&
          (widget.key! as ValueKey<String>).value.contains('-Weekly span-'),
    );
    expect(segments, findsNWidgets(2));
    expect(tester.getRect(segments.first).width, closeTo(296, 0.1));
    expect(tester.getRect(segments.last).width, closeTo(296, 0.1));
  });

  testWidgets('compact one-week calendar hides bars and keeps date selection', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(700, 500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final day = DateTime(2025, 1, 6);
    DateTime? selectedDate;
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme,
        home: Scaffold(
          body: SingleChildScrollView(
            child: CalendarWidget(
              initialDate: day,
              viewMode: CalendarViewMode.oneWeekWithoutIndicators,
              items: [
                _task('Hidden task', day, const TimeOfDay(hour: 9, minute: 0)),
              ],
              onDateSelected: (date) => selectedDate = date,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      _barsFor(_task('Hidden task', day, const TimeOfDay(hour: 9, minute: 0))),
      findsOneWidget,
    );
    expect(
      tester
          .widget<AnimatedOpacity>(
            find.byKey(const ValueKey('calendar-week-items-opacity')),
          )
          .opacity,
      0,
    );
    expect(
      tester.getSize(find.byType(WeekWidget)).height,
      calendarDateOnlyWeekHeight,
    );

    await tester.tap(find.text('6'));
    expect(selectedDate, day);
  });

  testWidgets('crowded dates show three titles and a hidden item count', (
    tester,
  ) async {
    final day = DateTime(2025, 1, 6);
    final items = [
      for (var index = 0; index < 7; index++)
        _task('Task $index', day, TimeOfDay(hour: 8 + index, minute: 0)),
    ];
    DateTime? selectedDate;

    await _pumpWeeks(
      tester,
      [items],
      [DateTime(2025, 1, 5)],
      onDaySelected: (date) => selectedDate = date,
    );

    for (var index = 0; index < 3; index++) {
      expect(find.text('Task $index'), findsOneWidget);
    }
    expect(find.text('Task 3'), findsNothing);
    expect(find.text('Task 4'), findsNothing);
    expect(find.text('Task 5'), findsNothing);
    expect(find.text('Task 6'), findsNothing);
    expect(find.text('+4 more'), findsOneWidget);

    await tester.tap(find.text('6'));
    expect(selectedDate, DateTime(2025, 1, 6));
  });
}

Future<void> _pumpWeeks(
  WidgetTester tester,
  List<List<PlannerItem>> itemsByWeek,
  List<DateTime> starts, {
  ValueChanged<DateTime>? onDaySelected,
}) async {
  tester.view.physicalSize = const Size(700, 500);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      theme: appTheme,
      home: Scaffold(
        body: SingleChildScrollView(
          child: Column(
            children: [
              for (var index = 0; index < itemsByWeek.length; index++)
                SizedBox(
                  height: calendarItemsWeekHeight,
                  child: WeekWidget(
                    days: [
                      for (var offset = 0; offset < 7; offset++)
                        starts[index].add(Duration(days: offset)),
                    ],
                    selectedDay: starts[index],
                    items: itemsByWeek[index],
                    onDaySelected: onDaySelected ?? (_) {},
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Finder _barFor(PlannerItem item) => _barsFor(item);

Finder _barsFor(PlannerItem item) => find.byWidgetPredicate(
  (widget) =>
      widget is Container &&
      widget.key is ValueKey<String> &&
      (widget.key! as ValueKey<String>).value.contains('-${item.title}-') &&
      (widget.key! as ValueKey<String>).value.endsWith(
        DateTime(
          item.date.year,
          item.date.month,
          item.date.day,
        ).toIso8601String(),
      ),
);

Task _task(String title, DateTime date, TimeOfDay time) => Task(
  title: title,
  date: date,
  isChecked: false,
  time: time,
  estimatedDuration: const Duration(minutes: 30),
);

Event _event(
  String title,
  DateTime date,
  TimeOfDay start, {
  bool allDay = false,
}) => Event(
  title: title,
  date: date,
  start: start,
  end: const TimeOfDay(hour: 11, minute: 0),
  isCurrent: false,
  allDay: allDay,
);
