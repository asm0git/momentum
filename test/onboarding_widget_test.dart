import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momentum/app_theme.dart';
import 'package:momentum/data/database_helper.dart';
import 'package:momentum/data/planner_repository.dart';
import 'package:momentum/screens/add_calendars_screen.dart';
import 'package:momentum/screens/calendar_screen.dart';
import 'package:momentum/screens/welcome_screen.dart';
import 'package:momentum/services/onboarding_preferences.dart';
import 'package:momentum/state/planner_state.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Directory tempDirectory;
  late DatabaseHelper databaseHelper;
  late PlannerState planner;

  setUpAll(() => sqfliteFfiInit());

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    tempDirectory = await Directory.systemTemp.createTemp('momentum_start_');
    databaseHelper = DatabaseHelper.forTesting(
      factory: databaseFactoryFfi,
      databasePath: '${tempDirectory.path}/planner.db',
      seedOnCreate: false,
    );
    planner = PlannerState(
      repository: PlannerRepository(databaseHelper: databaseHelper),
      autoSyncCanvasOnStartup: false,
    );
    await planner.initialize();
  });

  tearDown(() async {
    planner.dispose();
    await databaseHelper.close();
    await tempDirectory.delete(recursive: true);
  });

  test(
    'startup sends first-time users to welcome and returning users home',
    () {
      expect(
        resolveStartupRoute(setupComplete: false, location: Uri.parse('/')),
        '/welcome',
      );
      expect(
        resolveStartupRoute(setupComplete: true, location: Uri.parse('/')),
        '/dashboard',
      );
      expect(
        resolveStartupRoute(
          setupComplete: false,
          location: Uri.parse('/?calendar_provider=google'),
        ),
        '/calendars',
      );
    },
  );

  testWidgets('Get started opens provider setup', (tester) async {
    await tester.pumpWidget(
      _app(
        planner,
        home: const WelcomeScreen(),
        routes: {
          '/calendars': (_) => const AddCalendarsScreen(onboarding: true),
        },
      ),
    );
    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();

    expect(find.text('Canvas'), findsOneWidget);
    expect(find.text('Google Calendar'), findsOneWidget);
    expect(find.text('Outlook'), findsOneWidget);
  });

  testWidgets('Skip button skips linking and persists completion', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        planner,
        home: const AddCalendarsScreen(onboarding: true),
        routes: {'/dashboard': (_) => const Text('Dashboard ready')},
      ),
    );
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();

    expect(find.text('Dashboard ready'), findsOneWidget);
    expect(await OnboardingPreferences.isComplete(), isTrue);
  });

  testWidgets('Calendar screen has an easy-to-find Add calendars button', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        planner,
        home: const CalendarScreen(),
        routes: {'/calendars': (_) => const AddCalendarsScreen()},
      ),
    );
    await tester.tap(find.byKey(const ValueKey('calendar-add-calendars')));
    await tester.pumpAndSettle();

    expect(find.text('Google Calendar'), findsOneWidget);
    expect(find.text('Skip'), findsOneWidget);
  });
}

Widget _app(
  PlannerState planner, {
  required Widget home,
  Map<String, WidgetBuilder> routes = const {},
}) => ChangeNotifierProvider<PlannerState>.value(
  value: planner,
  child: MaterialApp(theme: appTheme, home: home, routes: routes),
);
