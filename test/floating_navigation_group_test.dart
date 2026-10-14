import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momentum/app_theme.dart';
import 'package:momentum/data/database_helper.dart';
import 'package:momentum/data/planner_repository.dart';
import 'package:momentum/navigation_destinations.dart';
import 'package:momentum/state/planner_state.dart';
import 'package:momentum/widgets/navigation/bottom_navigation_bar.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Directory tempDirectory;
  late DatabaseHelper databaseHelper;
  late PlannerState planner;

  setUpAll(() => sqfliteFfiInit());

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp(
      'momentum_navigation_',
    );
    databaseHelper = DatabaseHelper.forTesting(
      factory: databaseFactoryFfi,
      databasePath: '${tempDirectory.path}/navigation.db',
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

  testWidgets('navigation buttons replace the current named route', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme,
        home: Scaffold(
          body: FloatingNavigationGroup(
            selectedIndex: AppDestination.insights.index,
          ),
        ),
        routes: {
          for (final destination in AppDestination.values)
            destination.route: (_) =>
                Scaffold(body: Text('${destination.title} destination')),
        },
      ),
    );

    await tester.tap(find.byTooltip(AppDestination.calendar.name));
    await tester.pumpAndSettle();

    expect(find.text('Calendar destination'), findsOneWidget);
  });

  testWidgets('Add button opens and toggles closed its popup overlay', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ChangeNotifierProvider<PlannerState>.value(
        value: planner,
        child: MaterialApp(
          theme: appTheme,
          home: Scaffold(
            body: FloatingNavigationGroup(
              selectedIndex: AppDestination.dashboard.index,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('Add'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('add-item-backdrop')), findsOneWidget);
    expect(find.byKey(const ValueKey('add-item-popup')), findsOneWidget);

    await tester.tap(find.byTooltip('Add'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('add-item-backdrop')), findsNothing);
    expect(find.byKey(const ValueKey('add-item-popup')), findsNothing);
  });
}
