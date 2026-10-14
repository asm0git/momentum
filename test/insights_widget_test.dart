import 'dart:async';
import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momentum/app_theme.dart';
import 'package:momentum/data/database_helper.dart';
import 'package:momentum/data/focus_history_repository.dart';
import 'package:momentum/data/planner_repository.dart';
import 'package:momentum/data_models.dart';
import 'package:momentum/screens/insights_screen.dart';
import 'package:momentum/state/planner_state.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Directory tempDirectory;
  late DatabaseHelper databaseHelper;
  late PlannerRepository repository;
  late _TestInsightsFocusHistoryRepository focusRepository;
  late PlannerState planner;

  setUpAll(() => sqfliteFfiInit());

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp(
      'momentum_insights_ui_',
    );
    databaseHelper = DatabaseHelper.forTesting(
      factory: databaseFactoryFfi,
      databasePath: '${tempDirectory.path}/insights.db',
      seedOnCreate: false,
    );
    repository = PlannerRepository(databaseHelper: databaseHelper);
    focusRepository = _TestInsightsFocusHistoryRepository(
      databaseHelper: databaseHelper,
    );
    planner = PlannerState(
      repository: repository,
      focusHistoryRepository: focusRepository,
    );
    await planner.initialize();
  });

  tearDown(() async {
    planner.dispose();
    await databaseHelper.close();
    await tempDirectory.delete(recursive: true);
  });

  testWidgets('focus heatmap fits the screen and ends on the present date', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ChangeNotifierProvider<PlannerState>.value(
        value: planner,
        child: MaterialApp(theme: appTheme, home: const InsightsScreen()),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    String cellKey(DateTime date) =>
        'insights-heatmap-cell-${date.toIso8601String().substring(0, 10)}';

    final todayCell = find.byKey(ValueKey(cellKey(today)));
    expect(todayCell, findsOneWidget);
    expect(find.byKey(ValueKey(cellKey(tomorrow))), findsNothing);
    expect(find.byKey(const ValueKey('insights-heatmap-scroll')), findsNothing);
    final gridRect = tester.getRect(
      find.byKey(const ValueKey('insights-heatmap-grid')),
    );
    final todayRect = tester.getRect(todayCell);
    expect(
      todayRect.left >= gridRect.left && todayRect.right <= gridRect.right,
      isTrue,
    );
    final visibleCells = find
        .byWidgetPredicate(
          (widget) =>
              widget is Container &&
              widget.key is ValueKey<String> &&
              (widget.key! as ValueKey<String>).value.startsWith(
                'insights-heatmap-cell-',
              ),
        )
        .evaluate()
        .length;
    expect(visibleCells, greaterThan(90));
    expect(visibleCells, lessThan(364));
  });

  testWidgets('failed insights refresh marks old totals stale and retries', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    await tester.runAsync(
      () => planner.addFocusSeconds(today, 1800, FocusTaskSelection.unassigned),
    );

    await tester.pumpWidget(
      ChangeNotifierProvider<PlannerState>.value(
        value: planner,
        child: MaterialApp(theme: appTheme, home: const InsightsScreen()),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
    expect(find.text('30 mins'), findsWidgets);

    focusRepository.nextFocusTotalsError = StateError(
      'private storage details',
    );
    await tester.runAsync(
      () => planner.addFocusSeconds(today, 60, FocusTaskSelection.unassigned),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('insights-load-error')), findsOneWidget);
    expect(
      find.text('Could not refresh insights. Showing the last loaded totals.'),
      findsOneWidget,
    );
    expect(find.text('30 mins'), findsWidgets);
    expect(find.textContaining('private storage details'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('insights-retry')));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('insights-load-error')), findsNothing);
    expect(find.text('31 mins'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'weekly range navigation and category chart react to focus data',
    (tester) async {
      tester.view.physicalSize = const Size(900, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ChangeNotifierProvider<PlannerState>.value(
          value: planner,
          child: MaterialApp(theme: appTheme, home: const InsightsScreen()),
        ),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('Focus time per week'), findsOneWidget);
      final sectionCards = <String, Key>{
        'Focus time per week': const ValueKey('insights-weekly-card'),
        'Focus by category': const ValueKey('insights-category-card'),
        'Focus heatmap': const ValueKey('insights-heatmap-card'),
      };
      for (final section in sectionCards.entries) {
        final heading = tester.getRect(find.text(section.key));
        final card = tester.getRect(find.byKey(section.value));
        expect(card.top - heading.bottom, 4);
        expect(
          find.descendant(
            of: find.byKey(section.value),
            matching: find.text(section.key),
          ),
          findsNothing,
        );
      }
      expect(
        find.byKey(const ValueKey('insights-weekly-bar-chart')),
        findsOneWidget,
      );
      expect(find.text('No categorized focus time this week.'), findsOneWidget);
      expect(find.text('1 hr'), findsOneWidget);
      expect(find.text('40 mins'), findsOneWidget);
      expect(find.text('20 mins'), findsOneWidget);
      expect(find.text('0 mins'), findsOneWidget);

      final monthLabels = find.byWidgetPredicate(
        (widget) =>
            widget is Text &&
            widget.key is ValueKey<String> &&
            (widget.key! as ValueKey<String>).value.startsWith(
              'insights-month-',
            ),
      );
      expect(monthLabels, findsWidgets);
      for (final label in tester.widgetList<Text>(monthLabels)) {
        expect(label.maxLines, 1);
        expect(label.softWrap, isFalse);
      }

      final initialRange = tester
          .widget<Text>(find.byKey(const ValueKey('insights-week-range')))
          .data;
      final historicalQueryCount = focusRepository.focusTotalsRanges
          .where((range) => range.$2.difference(range.$1).inDays > 300)
          .length;
      expect(historicalQueryCount, 1);
      await tester.tap(find.byKey(const ValueKey('insights-previous-week')));
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump();
      await tester.pumpAndSettle();
      final previousRange = tester
          .widget<Text>(find.byKey(const ValueKey('insights-week-range')))
          .data;
      expect(previousRange, isNot(initialRange));
      expect(
        focusRepository.focusTotalsRanges
            .where((range) => range.$2.difference(range.$1).inDays > 300)
            .length,
        historicalQueryCount,
      );

      final category = (await tester.runAsync(
        () => planner.addCategory(
          TaskCategory(title: 'Study', iconName: 'mi_school', items: []),
        ),
      ))!;
      await tester.runAsync(
        () => planner.addFocusSeconds(
          DateTime.now(),
          1800,
          FocusTaskSelection(
            taskId: 2,
            taskTitle: 'Read chapter',
            categoryId: category.id!,
            categoryTitle: category.title,
            categoryIcon: category.iconName,
          ),
        ),
      );
      await tester.runAsync(
        () => planner.addFocusSeconds(
          DateTime.now(),
          120,
          FocusTaskSelection.unassigned,
        ),
      );

      await tester.tap(find.byKey(const ValueKey('insights-next-week')));
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump();
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('insights-category-ring')),
        findsOneWidget,
      );
      expect(find.text('Study'), findsOneWidget);
      expect(find.text('Unassigned'), findsOneWidget);
      expect(find.text('30 mins'), findsWidgets);
      expect(find.byType(Tooltip), findsWidgets);
    },
  );

  testWidgets('keeps the heatmap visible during a weekly reload', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ChangeNotifierProvider<PlannerState>.value(
        value: planner,
        child: MaterialApp(theme: appTheme, home: const InsightsScreen()),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    final heatmap = find.byKey(const ValueKey('insights-heatmap-grid'));
    expect(heatmap, findsOneWidget);

    final pendingWeeklyTotals = Completer<Map<DateTime, int>>();
    focusRepository.nextWeeklyFocusTotals = pendingWeeklyTotals;
    await tester.tap(find.byKey(const ValueKey('insights-previous-week')));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsWidgets);
    expect(heatmap, findsOneWidget);

    pendingWeeklyTotals.complete({});
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(heatmap, findsOneWidget);
  });

  testWidgets('shows weekly charts while heatmap history is still loading', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final pendingHeatmapTotals = Completer<Map<DateTime, int>>();
    focusRepository.nextHistoricalFocusTotals = pendingHeatmapTotals;

    await tester.pumpWidget(
      ChangeNotifierProvider<PlannerState>.value(
        value: planner,
        child: MaterialApp(theme: appTheme, home: const InsightsScreen()),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey('insights-weekly-bar-chart')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('insights-heatmap-grid')), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsWidgets);

    pendingHeatmapTotals.complete({});
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('insights-heatmap-grid')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('weekly bars show selected values and scale the vertical axis', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final today = DateTime.now();
    final monday = DateTime(
      today.year,
      today.month,
      today.day,
    ).subtract(Duration(days: today.weekday - DateTime.monday));
    final category = (await tester.runAsync(
      () => planner.addCategory(
        TaskCategory(title: 'Chart test', iconName: 'mi_school', items: []),
      ),
    ))!;
    final selection = FocusTaskSelection(
      taskId: 999,
      taskTitle: 'Chart test task',
      categoryId: category.id!,
      categoryTitle: category.title,
      categoryIcon: category.iconName,
    );
    await tester.runAsync(() => planner.addFocusSeconds(monday, 30, selection));

    await tester.pumpWidget(
      ChangeNotifierProvider<PlannerState>.value(
        value: planner,
        child: MaterialApp(theme: appTheme, home: const InsightsScreen()),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('36s'), findsOneWidget);
    expect(find.text('24s'), findsOneWidget);
    expect(find.text('12s'), findsOneWidget);
    expect(find.text('0 mins'), findsOneWidget);

    final plot = tester.getRect(
      find.byKey(const ValueKey('insights-weekly-bar-chart')),
    );
    final barPoint = Offset(
      plot.left + plot.width / 14,
      plot.top + plot.height / 2,
    );
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: barPoint);
    await mouse.moveTo(barPoint);
    await tester.pump();
    final tooltipFinder = find.byKey(
      const ValueKey('insights-bar-value-tooltip'),
    );
    expect(tooltipFinder, findsOneWidget);
    expect(
      tester
          .widget<Text>(
            find.descendant(of: tooltipFinder, matching: find.byType(Text)),
          )
          .data,
      contains('30s'),
    );
    await mouse.moveTo(Offset(plot.right + 16, plot.bottom + 16));
    await tester.pump();
    expect(tooltipFinder, findsNothing);
    await mouse.removePointer();

    await tester.runAsync(
      () => planner.addFocusSeconds(monday, 45 * 60 - 30, selection),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('1 hr'), findsOneWidget);
    expect(find.text('40 mins'), findsOneWidget);
    expect(find.text('20 mins'), findsOneWidget);

    final updatedPlot = tester.getRect(
      find.byKey(const ValueKey('insights-weekly-bar-chart')),
    );
    final updatedBarPoint = Offset(
      updatedPlot.left + updatedPlot.width / 14,
      updatedPlot.top + updatedPlot.height / 2,
    );
    await tester.tapAt(updatedBarPoint);
    await tester.pump();
    final tooltipText = tester.widget<Text>(
      find.descendant(
        of: find.byKey(const ValueKey('insights-bar-value-tooltip')),
        matching: find.byType(Text),
      ),
    );
    expect(tooltipText.data, contains('45 mins'));
    expect(tooltipText.data, startsWith('Mon,'));

    for (var day = 0; day < 7; day++) {
      await tester.runAsync(
        () => planner.addFocusSeconds(
          monday.add(Duration(days: day)),
          60 * 60,
          selection,
        ),
      );
    }
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('3 hrs'), findsOneWidget);
    expect(find.text('2 hrs'), findsOneWidget);
    expect(find.text('1 hr'), findsOneWidget);
    expect(find.text('0 mins'), findsOneWidget);
  });
}

class _TestInsightsFocusHistoryRepository extends FocusHistoryRepository {
  _TestInsightsFocusHistoryRepository({required super.databaseHelper});

  Object? nextFocusTotalsError;
  Completer<Map<DateTime, int>>? nextWeeklyFocusTotals;
  Completer<Map<DateTime, int>>? nextHistoricalFocusTotals;
  final focusTotalsRanges = <(DateTime, DateTime)>[];

  @override
  Future<Map<DateTime, int>> getFocusTotalsForRange(
    DateTime firstDay,
    DateTime lastDay,
  ) async {
    focusTotalsRanges.add((firstDay, lastDay));
    if (lastDay.difference(firstDay).inDays <= 6) {
      final pendingTotals = nextWeeklyFocusTotals;
      if (pendingTotals != null) {
        nextWeeklyFocusTotals = null;
        return pendingTotals.future;
      }
    } else if (lastDay.difference(firstDay).inDays > 300) {
      final pendingTotals = nextHistoricalFocusTotals;
      if (pendingTotals != null) {
        nextHistoricalFocusTotals = null;
        return pendingTotals.future;
      }
    }
    final error = nextFocusTotalsError;
    nextFocusTotalsError = null;
    if (error != null) throw error;
    return super.getFocusTotalsForRange(firstDay, lastDay);
  }
}
